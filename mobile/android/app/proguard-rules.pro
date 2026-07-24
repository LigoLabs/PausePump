# flutter_local_notifications sérialise les notifications planifiées en JSON
# via Gson (réflexion + types génériques). En build release, R8 strippe les
# signatures génériques et renomme les classes → « Missing type parameter »
# dans ScheduledNotification(Boot)Receiver = crash de l'app dès qu'une notif
# est planifiée puis délivrée (lancement du timer), ou à chaque mise à jour
# du package. Règles issues du README du plugin + des règles officielles Gson.
-keepattributes Signature
-keepattributes *Annotation*
-keepattributes EnclosingMethod
-keepattributes InnerClasses

# Gson : TypeToken et ses sous-classes portent les types génériques.
-keep class com.google.gson.reflect.TypeToken { *; }
-keep class * extends com.google.gson.reflect.TypeToken
-keep public class * implements java.lang.reflect.Type

# Modèles du plugin, désérialisés par réflexion : ni renommage ni suppression.
-keep class com.dexterous.** { *; }
