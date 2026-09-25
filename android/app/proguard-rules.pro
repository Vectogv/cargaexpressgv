# R8 (build release) quitaba los constructores sin argumentos de los
# registradores de Firebase: en el log "Could not instantiate
# ...FirebaseMessagingKtxRegistrar / FirebaseInstallationsKtxRegistrar:
# NoSuchMethodException <init>" y el token FCM no se obtenía (no llegaban
# notificaciones). Firebase los crea por reflexión.
#
# Crashlytics queda fuera a propósito: su registrador exige el plugin de
# Gradle de Crashlytics (build ID) que el proyecto no aplica; conservarlo
# hace que la app se cierre al abrir ("The Crashlytics build ID is missing").
-keep class !com.google.firebase.crashlytics.**,** implements com.google.firebase.components.ComponentRegistrar { <init>(); }
-dontwarn com.google.firebase.**
