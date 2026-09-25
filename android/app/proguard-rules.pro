# R8 (build release, AGP 9) quitaba los constructores sin argumentos de los
# registradores de Firebase: en el log "Could not instantiate
# ...FirebaseMessagingKtxRegistrar / FirebaseInstallationsKtxRegistrar /
# CrashlyticsRegistrar: NoSuchMethodException <init>". Firebase los crea por
# reflexión; la regla que trae firebase-components ("-keep class * implements
# ComponentRegistrar", sin "{ <init>(); }") ya no basta porque R8 dejó de
# conservar el constructor por defecto de forma implícita. Sin el componente
# de Crashlytics, Firebase.initializeApp fallaba en Dart ("FirebaseCrashlytics
# component is not present") y no había token FCM (no llegaban notificaciones).
-keep class * implements com.google.firebase.components.ComponentRegistrar { <init>(); }
-dontwarn com.google.firebase.**
