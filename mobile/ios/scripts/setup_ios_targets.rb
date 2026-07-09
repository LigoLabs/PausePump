#!/usr/bin/env ruby
# frozen_string_literal: true

# ------------------------------------------------------------------------------
# setup_ios_targets.rb — Configure le projet Xcode de PausePump (iOS + watchOS).
#
# Le shell iOS committé (mobile/ios/) est un projet Flutter fraîchement généré :
# les sources Swift natives (Live Activity, sync Watch, app watchOS) existent
# sur le disque mais ne sont PAS référencées dans Runner.xcodeproj. Ce script
# fait ce câblage à la place de Xcode, pour que tout soit reproductible depuis
# un poste Windows/CI sans manipuler le pbxproj à la main.
#
# Ce qu'il fait :
#   a) Target Runner : ajoute les ponts natifs (LiveActivityBridge,
#      WatchSyncBridge, RestTimerAttributes), les sons de notification
#      (triple.wav, bell.wav — copiés dans le bundle) et l'entitlement
#      « notifications time-sensitive » (Runner.entitlements).
#   b) Target PausePumpWidgets : extension WidgetKit (Live Activity /
#      Dynamic Island), créée si absente, embarquée dans Runner.
#   c) Target PausePumpWatch : app watchOS SwiftUI, créée si absente,
#      embarquée dans Runner. Les sources du package SPM WatchEngine sont
#      compilées DIRECTEMENT dans cette target (pas de dépendance SPM dans le
#      projet : le package ne sert qu'aux tests `swift test` côté CI).
#
# IDEMPOTENT : relançable sans dupliquer quoi que ce soit (chaque ajout est
# précédé d'une vérification d'existence par nom/chemin). À relancer :
#   - après tout ajout/suppression de fichier Swift natif ;
#   - après une régénération du shell iOS par `flutter create`.
#
# Prérequis : macOS (ou CI) + gem « xcodeproj » (fournie par CocoaPods, ou
# `gem install xcodeproj --no-document`).
#
# Usage (le cwd n'a pas d'importance, les chemins sont résolus depuis le
# script) :
#   ruby mobile/ios/scripts/setup_ios_targets.rb
# ------------------------------------------------------------------------------

require 'pathname'

begin
  require 'xcodeproj'
rescue LoadError
  warn 'ERREUR : la gem « xcodeproj » est introuvable.'
  warn 'Installez-la avec :  gem install xcodeproj --no-document'
  warn '(elle est aussi fournie par CocoaPods : gem install cocoapods)'
  exit 1
end

# --- Chemins (résolus par rapport à ce script — exécutable depuis tout cwd) ---
IOS_DIR      = File.expand_path('..', __dir__)  # mobile/ios
MOBILE_DIR   = File.expand_path('..', IOS_DIR)  # mobile
PROJECT_PATH = File.join(IOS_DIR, 'Runner.xcodeproj')

# Ponts natifs à ajouter à la target Runner existante.
RUNNER_SWIFT_FILES = %w[
  LiveActivityBridge.swift
  WatchSyncBridge.swift
  RestTimerAttributes.swift
].map { |f| File.join(IOS_DIR, 'Runner', f) }.freeze

# Fichier partagé entre Runner et l'extension widget (ActivityAttributes).
SHARED_ATTRIBUTES_FILE = File.join(IOS_DIR, 'Runner', 'RestTimerAttributes.swift')

# Sons de notification, copiés comme ressources du bundle Runner.
SOUND_FILES = %w[triple.wav bell.wav]
              .map { |f| File.join(MOBILE_DIR, 'assets', 'sounds', f) }.freeze

WIDGETS_DIR      = File.join(IOS_DIR, 'PausePumpWidgets')
WATCH_DIR        = File.join(IOS_DIR, 'PausePumpWatch')
WATCH_ENGINE_DIR = File.join(MOBILE_DIR, 'watch_engine', 'Sources', 'WatchEngine')

ENTITLEMENTS_REL = 'Runner/Runner.entitlements'
ENTITLEMENTS_ABS = File.join(IOS_DIR, ENTITLEMENTS_REL)

WATCH_ENTITLEMENTS_REL = 'PausePumpWatch/PausePumpWatch.entitlements'
WATCH_ENTITLEMENTS_ABS = File.join(IOS_DIR, WATCH_ENTITLEMENTS_REL)

WIDGET_TARGET_NAME = 'PausePumpWidgets'
WATCH_TARGET_NAME  = 'PausePumpWatch'

ENTITLEMENTS_PLIST = <<~PLIST
  <?xml version="1.0" encoding="UTF-8"?>
  <!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
  <plist version="1.0">
  <dict>
  	<key>com.apple.developer.usernotifications.time-sensitive</key>
  	<true/>
  </dict>
  </plist>
PLIST

# --- Journal de ce qui a été fait / déjà en place ------------------------------
$added    = []
$existing = []

def added(msg)
  $added << msg
end

def existing(msg)
  $existing << msg
end

def fail_with(msg)
  warn "ERREUR : #{msg}"
  exit 1
end

# --- Vérifications préalables ---------------------------------------------------
# On refuse de créer des références vers des fichiers absents : le build
# échouerait plus tard de façon obscure. Message clair + exit 1 à la place.
def preflight!
  missing = []
  missing << "#{PROJECT_PATH} (lancez « flutter create » ?)" unless File.directory?(PROJECT_PATH)
  (RUNNER_SWIFT_FILES + SOUND_FILES).each { |f| missing << f unless File.file?(f) }

  widgets_plist = File.join(WIDGETS_DIR, 'Info.plist')
  missing << widgets_plist unless File.file?(widgets_plist)
  missing << File.join(WIDGETS_DIR, '*.swift (aucun fichier trouvé)') if Dir.glob(File.join(WIDGETS_DIR, '*.swift')).empty?

  watch_plist = File.join(WATCH_DIR, 'Info.plist')
  missing << watch_plist unless File.file?(watch_plist)
  missing << File.join(WATCH_DIR, '**/*.swift (aucun fichier trouvé)') if Dir.glob(File.join(WATCH_DIR, '**', '*.swift')).empty?

  missing << File.join(WATCH_ENGINE_DIR, '*.swift (aucun fichier trouvé)') if Dir.glob(File.join(WATCH_ENGINE_DIR, '*.swift')).empty?

  return if missing.empty?

  warn 'ERREUR : fichiers requis introuvables :'
  missing.each { |f| warn "  - #{f}" }
  warn 'Vérifiez que les sources natives (Runner/, PausePumpWidgets/, PausePumpWatch/, watch_engine/) sont bien présentes.'
  exit 1
end

# --- Aides idempotentes ----------------------------------------------------------

# Retourne le sous-groupe direct nommé `name`, en le créant si besoin.
def ensure_group(parent, name, path = nil)
  group = parent.children.find do |child|
    child.is_a?(Xcodeproj::Project::Object::PBXGroup) && child.display_name == name
  end
  return group if group

  added("groupe « #{name} »")
  parent.new_group(name, path)
end

# Retourne la référence de fichier vers `absolute_path` dans `group`,
# en la créant si besoin (chemin stocké relativement au groupe : les fichiers
# hors de ios/ deviennent des chemins « ../... »).
def ensure_file_reference(group, absolute_path)
  wanted = Pathname.new(absolute_path).cleanpath
  ref = group.files.find do |f|
    begin
      f.real_path.cleanpath == wanted
    rescue StandardError
      false
    end
  end
  return ref if ref

  added("référence de fichier « #{File.basename(absolute_path)} »")
  group.new_reference(absolute_path)
end

# Ajoute `file_ref` à la phase de build si elle ne l'y référence pas déjà.
def ensure_build_file(phase, file_ref, label)
  build_file = phase.files.find { |bf| bf.file_ref == file_ref }
  if build_file
    existing(label)
  else
    build_file = phase.add_file_reference(file_ref, true)
    added(label)
  end
  build_file
end

# Applique des build settings identiques sur TOUTES les configurations
# (Debug / Release / Profile) de la target. Réécrire la même valeur est
# sans effet : l'idempotence est gratuite ici.
def apply_build_settings(target, settings)
  target.build_configurations.each do |config|
    settings.each { |key, value| config.build_settings[key] = value }
  end
end

# Dépendance de target (Runner → extension / watch), sans doublon.
def ensure_dependency(app_target, dep_target)
  if app_target.dependencies.any? { |d| d.target && d.target.uuid == dep_target.uuid }
    existing("dépendance #{app_target.name} → #{dep_target.name}")
  else
    app_target.add_dependency(dep_target)
    added("dépendance #{app_target.name} → #{dep_target.name}")
  end
end

# Phase « copy files » nommée, créée seulement si aucune phase de ce nom
# n'existe déjà sur la target.
def ensure_copy_files_phase(target, name, dst_subfolder_spec, dst_path)
  phase = target.copy_files_build_phases.find { |p| p.name == name }
  if phase
    existing("phase « #{name} »")
  else
    phase = target.new_copy_files_build_phase(name)
    added("phase « #{name} »")
  end
  # Réappliqué à chaque run (mêmes valeurs → aucun diff).
  phase.dst_subfolder_spec = dst_subfolder_spec
  phase.dst_path = dst_path
  phase
end

# Embarque le produit d'une target (…appex / ….app) dans une phase copy files.
def ensure_embedded_product(phase, product_ref, attributes)
  build_file = phase.files.find { |bf| bf.file_ref == product_ref }
  if build_file
    existing("#{product_ref.display_name} dans « #{phase.name} »")
  else
    build_file = phase.add_file_reference(product_ref, true)
    added("#{product_ref.display_name} dans « #{phase.name} »")
  end
  build_file.settings = { 'ATTRIBUTES' => attributes } if attributes
  build_file
end

# --- a) Target Runner ------------------------------------------------------------
def setup_runner_target(project, runner, runner_group)
  # Ponts natifs Swift → groupe Runner + phase Sources.
  RUNNER_SWIFT_FILES.each do |abs|
    ref = ensure_file_reference(runner_group, abs)
    ensure_build_file(runner.source_build_phase, ref, "Runner/Sources : #{File.basename(abs)}")
  end

  # Sons de notification → groupe « Sounds » + phase Resources.
  # Les .wav vivent hors de ios/ (mobile/assets/sounds/) : la référence est
  # stockée relative au groupe (« ../assets/sounds/… »).
  sounds_group = ensure_group(project.main_group, 'Sounds')
  SOUND_FILES.each do |abs|
    ref = ensure_file_reference(sounds_group, abs)
    ensure_build_file(runner.resources_build_phase, ref, "Runner/Resources : #{File.basename(abs)}")
  end

  # Entitlement « notifications time-sensitive ».
  if File.file?(ENTITLEMENTS_ABS)
    existing("fichier #{ENTITLEMENTS_REL}")
  else
    File.write(ENTITLEMENTS_ABS, ENTITLEMENTS_PLIST)
    added("fichier #{ENTITLEMENTS_REL}")
  end
  ensure_file_reference(runner_group, ENTITLEMENTS_ABS)
  runner.build_configurations.each do |config|
    if config.build_settings['CODE_SIGN_ENTITLEMENTS']
      existing("CODE_SIGN_ENTITLEMENTS déjà réglé (#{config.name})")
    else
      config.build_settings['CODE_SIGN_ENTITLEMENTS'] = ENTITLEMENTS_REL
      added("CODE_SIGN_ENTITLEMENTS = #{ENTITLEMENTS_REL} (#{config.name})")
    end
  end
end

# --- b) Target extension widget (Live Activity) -----------------------------------
def setup_widget_target(project, runner, runner_group)
  widget = project.targets.find { |t| t.name == WIDGET_TARGET_NAME }
  if widget
    existing("target #{WIDGET_TARGET_NAME}")
  else
    widget = project.new_target(:app_extension, WIDGET_TARGET_NAME, :ios, '16.2')
    added("target #{WIDGET_TARGET_NAME} (extension WidgetKit)")
  end

  widgets_group = ensure_group(project.main_group, WIDGET_TARGET_NAME, WIDGET_TARGET_NAME)

  # Sources de l'extension + RestTimerAttributes.swift partagé avec Runner
  # (le même ActivityAttributes doit être compilé des deux côtés).
  Dir.glob(File.join(WIDGETS_DIR, '*.swift')).sort.each do |abs|
    ref = ensure_file_reference(widgets_group, abs)
    ensure_build_file(widget.source_build_phase, ref, "#{WIDGET_TARGET_NAME}/Sources : #{File.basename(abs)}")
  end
  shared_ref = ensure_file_reference(runner_group, SHARED_ATTRIBUTES_FILE)
  ensure_build_file(widget.source_build_phase, shared_ref,
                    "#{WIDGET_TARGET_NAME}/Sources : #{File.basename(SHARED_ATTRIBUTES_FILE)} (partagé)")

  # Info.plist : référence seule pour la navigation Xcode — surtout PAS dans
  # la phase Resources (il est déjà pris en charge par INFOPLIST_FILE).
  ensure_file_reference(widgets_group, File.join(WIDGETS_DIR, 'Info.plist'))

  # NB : WidgetKit / SwiftUI / ActivityKit sont auto-linkés par le compilateur
  # Swift ; inutile d'ajouter une phase Frameworks explicite.
  apply_build_settings(widget,
                       'PRODUCT_BUNDLE_IDENTIFIER'  => 'com.ligolabs.pausepump.widgets',
                       'INFOPLIST_FILE'             => 'PausePumpWidgets/Info.plist',
                       'GENERATE_INFOPLIST_FILE'    => 'NO',
                       'SWIFT_VERSION'              => '5.0',
                       # Mêmes familles d'appareils que Runner (iPhone + iPad),
                       # sinon la validation App Store rejette l'extension.
                       'TARGETED_DEVICE_FAMILY'     => '1,2',
                       'IPHONEOS_DEPLOYMENT_TARGET' => '16.2',
                       'CODE_SIGN_STYLE'            => 'Automatic',
                       # Alignées sur pubspec.yaml (version: 1.0.0+1) : la
                       # version de l'appex doit ÉGALER celle de l'app hôte.
                       'CURRENT_PROJECT_VERSION'    => '1',
                       'MARKETING_VERSION'          => '1.0.0',
                       'SKIP_INSTALL'               => 'YES',
                       'LD_RUNPATH_SEARCH_PATHS'    => '$(inherited) @executable_path/Frameworks @executable_path/../../Frameworks')

  # Runner dépend de l'extension et l'embarque dans PlugIns/ (spec 13).
  ensure_dependency(runner, widget)
  embed = ensure_copy_files_phase(runner, 'Embed Foundation Extensions', '13', '')
  ensure_embedded_product(embed, widget.product_reference, ['RemoveHeadersOnCopy'])
end

# --- c) Target app watchOS ----------------------------------------------------------
def setup_watch_target(project, runner)
  watch = project.targets.find { |t| t.name == WATCH_TARGET_NAME }
  if watch
    existing("target #{WATCH_TARGET_NAME}")
  else
    watch = project.new_target(:application, WATCH_TARGET_NAME, :watchos, '9.0')
    added("target #{WATCH_TARGET_NAME} (app watchOS)")
  end

  watch_group  = ensure_group(project.main_group, WATCH_TARGET_NAME, WATCH_TARGET_NAME)
  engine_group = ensure_group(project.main_group, 'WatchEngine')

  # Sources de l'app watch (récursif : Model/, Views/…), triées pour un
  # pbxproj déterministe d'un run à l'autre.
  Dir.glob(File.join(WATCH_DIR, '**', '*.swift')).sort.each do |abs|
    ref = ensure_file_reference(watch_group, abs)
    ensure_build_file(watch.source_build_phase, ref, "#{WATCH_TARGET_NAME}/Sources : #{File.basename(abs)}")
  end

  # Sources du package SPM WatchEngine, compilées directement dans la target
  # (références « ../watch_engine/… » relatives au groupe).
  Dir.glob(File.join(WATCH_ENGINE_DIR, '*.swift')).sort.each do |abs|
    ref = ensure_file_reference(engine_group, abs)
    ensure_build_file(watch.source_build_phase, ref, "#{WATCH_TARGET_NAME}/Sources : #{File.basename(abs)} (WatchEngine)")
  end

  # Info.plist : référence seule (voir remarque côté widget).
  ensure_file_reference(watch_group, File.join(WATCH_DIR, 'Info.plist'))

  apply_build_settings(watch,
                       'PRODUCT_BUNDLE_IDENTIFIER' => 'com.ligolabs.pausepump.watchkitapp',
                       'INFOPLIST_FILE'            => 'PausePumpWatch/Info.plist',
                       'GENERATE_INFOPLIST_FILE'   => 'NO',
                       'SWIFT_VERSION'             => '5.0',
                       'TARGETED_DEVICE_FAMILY'    => '4',
                       'WATCHOS_DEPLOYMENT_TARGET' => '9.0',
                       'SDKROOT'                   => 'watchos',
                       'CODE_SIGN_STYLE'           => 'Automatic',
                       'CURRENT_PROJECT_VERSION'   => '1',
                       'MARKETING_VERSION'         => '1.0.0',
                       'SKIP_INSTALL'              => 'YES',
                       'ENABLE_PREVIEWS'           => 'YES')

  # Entitlement « notifications time-sensitive » : la montre planifie ses
  # notifications de fin de phase en .timeSensitive (WatchSessionModel) —
  # sans l'entitlement, le système rétrograde silencieusement le niveau.
  if File.file?(WATCH_ENTITLEMENTS_ABS)
    existing("fichier #{WATCH_ENTITLEMENTS_REL}")
  else
    File.write(WATCH_ENTITLEMENTS_ABS, ENTITLEMENTS_PLIST)
    added("fichier #{WATCH_ENTITLEMENTS_REL}")
  end
  ensure_file_reference(watch_group, WATCH_ENTITLEMENTS_ABS)
  watch.build_configurations.each do |config|
    if config.build_settings['CODE_SIGN_ENTITLEMENTS']
      existing("CODE_SIGN_ENTITLEMENTS déjà réglé (#{WATCH_TARGET_NAME}, #{config.name})")
    else
      config.build_settings['CODE_SIGN_ENTITLEMENTS'] = WATCH_ENTITLEMENTS_REL
      added("CODE_SIGN_ENTITLEMENTS = #{WATCH_ENTITLEMENTS_REL} (#{config.name})")
    end
  end

  # Runner dépend de l'app watch et l'embarque dans <app>/Watch/ :
  # spec 16 = « products directory » + dstPath $(CONTENTS_FOLDER_PATH)/Watch.
  ensure_dependency(runner, watch)
  embed = ensure_copy_files_phase(runner, 'Embed Watch Content', '16', '$(CONTENTS_FOLDER_PATH)/Watch')
  ensure_embedded_product(embed, watch.product_reference, nil)
end

# --- Programme principal --------------------------------------------------------------
def main
  preflight!

  project = Xcodeproj::Project.open(PROJECT_PATH)

  runner = project.targets.find { |t| t.name == 'Runner' }
  fail_with('target « Runner » introuvable dans Runner.xcodeproj') unless runner

  runner_group = project.main_group.children.find do |child|
    child.is_a?(Xcodeproj::Project::Object::PBXGroup) && child.display_name == 'Runner'
  end
  fail_with('groupe « Runner » introuvable dans le projet') unless runner_group

  setup_runner_target(project, runner, runner_group)
  setup_widget_target(project, runner, runner_group)
  setup_watch_target(project, runner)

  project.save

  puts "Projet Xcode mis à jour : #{PROJECT_PATH}"
  unless $added.empty?
    puts ''
    puts "Ajouté (#{$added.size}) :"
    $added.each { |m| puts "  + #{m}" }
  end
  unless $existing.empty?
    puts ''
    puts "Déjà en place (#{$existing.size}) :"
    $existing.each { |m| puts "  = #{m}" }
  end
  puts ''
  puts 'Rappel : relancez ce script après tout ajout de fichier Swift natif ou après « flutter create ».'
end

begin
  main
rescue Xcodeproj::PlainInformative => e
  fail_with("xcodeproj — #{e.message}")
rescue StandardError => e
  warn "ERREUR inattendue : #{e.class} — #{e.message}"
  warn e.backtrace.take(12).join("\n") if e.backtrace
  exit 1
end
