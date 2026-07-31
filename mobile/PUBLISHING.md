# Publier PausePump — état des lieux

Document de référence unique pour la publication sur les deux stores.
Tenu à jour au fil des sessions : **mis à jour le 25 juillet 2026**.

Une grande partie du travail a été faite depuis un poste **Windows**, qui ne
peut pas produire de build iOS. Ce fichier sert aussi de passation vers un
poste **macOS**, seul capable de compiler et de générer les captures iOS.

---

## Identifiants à connaître

| Quoi | Valeur |
|---|---|
| Package / Bundle ID | `com.ligolabs.pausepump` |
| Bundle ID app watch | `com.ligolabs.pausepump.watchkitapp` |
| Bundle ID extension Live Activity | `com.ligolabs.pausepump.widgets` |
| Compte développeur Google Play | **Wishfast** — `7805417471332562909` |
| App Play Console | `4974267703139581953` |
| Équipe Apple (Team ID) | `5VX5GGKUXD` |
| App Store Connect (Apple ID) | `6794934339` |
| UGS / SKU iOS | `pausepump-ios-001` |
| Site (GitHub Pages) | <https://ligolabs.github.io/PausePump/> |
| Politique de confidentialité | <https://ligolabs.github.io/PausePump/privacy.html> |

Le nom d'éditeur affiché sur Google Play est **Wishfast**, pas LigoLabs : il
est commun à tout le compte et n'est pas modifiable depuis la console pour un
compte d'organisation vérifié. Le changer demande une requête à l'assistance
Play, et renommerait aussi l'éditeur de l'app Wishfast en production.

---

## Google Play — ce qui est fait

- **App créée**, en brouillon, français, gratuite.
- **Les 10 déclarations obligatoires sont validées** : confidentialité,
  annonces (aucune), informations de connexion (rien de restreint),
  classification du contenu (IARC → *Toutes les tranches d'âge*), cible
  (18 ans et plus), sécurité des données (**aucune collecte, aucun partage**),
  identifiant publicitaire (non), applis gouvernementales (non),
  fonctionnalités financières (aucune), applis de santé (*Activité et remise
  en forme*).
- **Déclaration `FOREGROUND_SERVICE_SPECIAL_USE`** remplie, avec la vidéo de
  démonstration exigée par Google, hébergée sur Pages :
  <https://ligolabs.github.io/PausePump/mobile/store/demo-foreground-service.mp4>
- **Fiche Play Store** : nom, description courte (70/80) et description
  longue (1260/4000) enregistrées.

### Google Play — ce qu'il reste

1. **Glisser les images** dans la fiche (l'outil d'automatisation du
   navigateur ne peut pas téléverser de fichiers) :
   - icône → `store/play-icon-512.png`
   - image de présentation → `store/feature-graphic-1024x500.png`
   - captures téléphone → les 5 de `store/screenshots/`
   - captures tablette 7″ → les 4 de `store/screenshots-tablet7/`
   - captures tablette 10″ → les 4 de `store/screenshots-tablet10/`
2. **Catégorie** → « Santé et bien-être » (intitulé exact de l'UI française),
   dans *Paramètres de la fiche Play Store*.
3. **E-mail de contact** de la fiche : vide, obligatoire, et **public**.
4. **Release de production** : glisser
   `build/app/outputs/bundle/release/app-release.aab`, coller les notes de
   version (dans `store/fiche-play-store.md`), choisir les pays.
5. Envoyer en examen.

---

## App Store — ce qui est fait

- **App ID `com.ligolabs.pausepump` enregistré** dans le portail développeur,
  avec la capacité **Time Sensitive Notifications** activée (les entitlements
  du projet la réclament ; sans elle la signature échoue à l'archive).
- **App créée** dans App Store Connect.
- **Fiche remplie** : sous-titre (23/30), description (2648/4000), mots-clés
  (94/100), URL d'assistance et marketing, copyright, catégories
  (*Forme et santé* + *Sports*), URL de politique de confidentialité.
- **Confidentialité de l'app** : questionnaire répondu → *Données non
  collectées*.

- **Captures d'écran produites** au simulateur, aux dimensions exactes
  attendues (aucun recadrage nécessaire) :
  - iPhone 6,5″ → `store/screenshots-ios/`, 5 captures en **1284 × 2778**
    (simulateur iPhone 14 Plus) ;
  - iPad 13″ → `store/screenshots-ipad/`, 5 captures en **2064 × 2752**
    (simulateur iPad Pro 13″ M5). **Obligatoires** : l'app cible
    `TARGETED_DEVICE_FAMILY = 1,2`, donc la console réclame l'onglet iPad.
  - Apple Watch → `store/screenshots-watch/`, 4 captures en **416 × 496**
    (simulateur Series 10 46 mm). **Obligatoires** aussi : le binaire
    embarque une app watchOS.
- **Build `1.0.0 (4)` envoyé** depuis le Mac et accepté par App Store Connect.
  Les builds 1 à 3 l'ont été aussi et restent visibles dans la console : ne
  pas les rattacher, ils précèdent la refonte de l'app watch.

- **Étiquette de confidentialité publiée** (« Données non collectées »).
- **Classification par âge : 4+** dans 172 pays.
- **Tarifs et disponibilité** : gratuit, 175 pays.
- **Déclarations** : dispositif médical réglementé → *non* ; droits relatifs
  au contenu → *aucun contenu tiers*. Les deux sont **exigées avant
  soumission** et n'apparaissent qu'en fin de parcours — la première parce que
  la catégorie est « Forme et santé », la seconde pour toutes les apps.
- **Version 1.0 soumise le 31 juillet 2026** avec le build `1.0.0 (4)`,
  publication automatique après approbation.

### App Store — ce qu'il reste

Attendre le résultat de l'examen (24 à 48 h en général). En cas de rejet, le
point le plus scruté était `UIBackgroundModes = audio`, désormais retiré.

---

## Le build iOS

Deux chemins, au choix.

### En local sur le Mac

```bash
cd mobile
flutter pub get
flutter precache --ios                  # sinon `pod install` échoue (voir plus bas)
gem install xcodeproj --no-document
ruby ios/scripts/setup_ios_targets.rb   # INDISPENSABLE avant toute compilation
flutter build ipa --release --export-options-plist=ios/ExportOptions.plist
```

Le `project.pbxproj` committé est le **shell Flutter brut** : l'extension Live
Activity et l'app watch n'y sont pas. Le script Ruby les recrée à chaque fois.
Ne jamais compiler sans l'avoir lancé.

**Envoi vers App Store Connect sans clé API.** Si le Mac a une session Xcode
authentifiée (celle qui sert déjà à la signature automatique), `xcodebuild`
envoie l'archive tout seul, sans `ASC_KEY_ID` ni mot de passe applicatif —
c'est la voie la plus simple depuis le poste :

```bash
sed 's|<string>export</string>|<string>upload</string>|' \
  ios/ExportOptions.plist > /tmp/UploadOptions.plist
xcodebuild -exportArchive \
  -archivePath build/ios/archive/Runner.xcarchive \
  -exportOptionsPlist /tmp/UploadOptions.plist \
  -exportPath /tmp/upload-out -allowProvisioningUpdates
```

**Pièges de mise en route rencontrés sur un Mac neuf :**

- `pod install` échoue sur « `Flutter.xcframework` must exist » tant que
  `flutter precache --ios` n'a pas été lancé (le clone du SDK ne télécharge
  pas les artefacts iOS).
- Un build **simulateur** exige le runtime **watchOS** (`xcodebuild
  -downloadPlatform watchOS`, ~3,9 Go) : le scheme `Runner` embarque l'app
  watch, donc sans lui xcodebuild s'arrête sur « watchOS 26.2 must be
  installed in order to run the scheme ». Un build **appareil/archive**, lui,
  n'a besoin que du SDK watchOS livré avec Xcode.

### Par la CI

Le workflow `.github/workflows/ios-release.yml` produit une archive signée et
l'envoie sur TestFlight, avec signature automatique via une clé API App Store
Connect. Il faut d'abord créer trois secrets GitHub — `ASC_KEY_ID`,
`ASC_ISSUER_ID`, `ASC_API_KEY_P8` — documentés en en-tête du workflow.

À ne pas confondre avec le job `build-ios` de `mobile-build.yml`, qui compile
en `--no-codesign` : celui-là ne fait que vérifier que le code compile, et
produit un bundle non distribuable.

---

## Captures d'écran — comment elles ont été faites

Le script `scripts/crop_screenshots.js` (Node, sans dépendance) met des
captures brutes aux normes des stores. Il **retire la barre d'état** — qui
expose les notifications personnelles, à ne pas publier — puis complète les
côtés avec le fond de l'app (`#0f1219`, invisible) jusqu'à tomber sur un ratio
**9:16 exact**, le seul accepté par Play avec le 16:9. Un recadrage vertical,
lui, couperait les boutons du bas.

```bash
node scripts/crop_screenshots.js [--out=<dossier>] <captures brutes...>
```

Les captures tablette ont été prises sans émulateur dédié, en faisant rendre
un appareil en tablette :

```bash
adb shell wm size 1080x2400 && adb shell wm density 280   # 7"  → 617 dp
adb shell wm size 1440x3200 && adb shell wm density 240   # 10" → 960 dp
adb shell wm size reset && adb shell wm density reset     # TOUJOURS restaurer
```

Pour iOS, il faudra les refaire au simulateur : les captures Android n'ont pas
les bonnes dimensions, et une fiche App Store doit montrer l'app telle qu'elle
tourne sur iOS.

---

## Pièges rencontrés, à ne pas réintroduire

**Les règles R8 sont obligatoires.** Sans `android/app/proguard-rules.pro`, la
minification release casse la sérialisation Gson de
`flutter_local_notifications` et l'app **plante au lancement du minuteur**
(`RuntimeException: Missing type parameter`). Invisible en debug.

**Le keystore d'upload Android n'est pas dans le dépôt.**
`android/upload-keystore.jks` et `android/key.properties` sont gitignorés et
n'existent **que sur le poste Windows**. Un build release fait sur le Mac
retombera sur la clé debug et sera refusé par Play. Pour publier une mise à
jour Android depuis le Mac, il faut d'abord y copier ces deux fichiers.

**`UIBackgroundModes = audio` a été retiré** de `ios/Runner/Info.plist`. Le
mode était mort sur iOS — le seul chemin de bip en arrière-plan est
conditionné à `Platform.isAndroid` — et il exposait à un rejet 2.5.4. Sur
iOS, la fin de pause passe par la notification locale programmée et la Live
Activity. Ne pas le réintroduire sans vraie lecture audio continue.

**Les versions de l'appex et de l'app watch DOIVENT égaler celle de Runner**,
sinon l'envoi échoue sur `ITMS-90473`. Elles étaient figées en dur à
`1.0.0` / `1` : elles reprennent désormais `$(FLUTTER_BUILD_NAME)` et
`$(FLUTTER_BUILD_NUMBER)`. Pour que ces variables soient résolues dans ces
deux targets, `setup_ios_targets.rb` leur pose `Flutter/Generated.xcconfig`
comme *base configuration* — sans ça elles s'évaluent silencieusement à la
chaîne vide. Ne pas revenir à des littéraux.

**Le son de fin et les écouteurs.** La notification de fin utilise le canal
alarme, qu'Android sort toujours du haut-parleur. `MainActivity.hasHeadphones`
détecte les écouteurs : s'il y en a, la notif est planifiée muette et c'est le
bip in-app (flux média) qui sonne. Ne pas « simplifier » ce chemin.

---

## Fichiers utiles

| Fichier | Contenu |
|---|---|
| `store/fiche-play-store.md` | textes et réponses aux questionnaires Play |
| `store/fiche-app-store.md` | textes, questionnaires et notes de revue Apple |
| `store/screenshots*/` | captures prêtes à téléverser (téléphone, 7″, 10″) |
| `store/demo-foreground-service.mp4` | vidéo justifiant le service de premier plan |
| `scripts/gen_icons.js` | régénère toutes les icônes (Android, iOS, watchOS, store) |
| `scripts/crop_screenshots.js` | met des captures aux normes 9:16 |
| `ios/scripts/setup_ios_targets.rb` | recrée les targets Xcode (widgets + watch) |
