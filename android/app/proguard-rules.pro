# ProGuard / R8 rules para release builds.

# --- WorkManager / Room ---
# androidx.work (WorkManager) se auto-inicializa al arrancar, vía
# androidx.startup.InitializationProvider, y guarda su estado en una base de
# datos Room (androidx.work.impl.WorkDatabase). Room crea la implementación
# generada (WorkDatabase_Impl) por reflexión:
# getDeclaredConstructor().newInstance().
#
# R8 —más agresivo desde AGP 9— no ve ninguna llamada directa a ese
# constructor sin argumentos y lo eliminaba. Entonces la reflexión fallaba con
# «Failed to create an instance of androidx.work.impl.WorkDatabase» y la app
# se cerraba al abrir, antes incluso de arrancar Flutter. Basta con conservar
# el constructor de toda base Room y la implementación de WorkManager.
-keep class * extends androidx.room.RoomDatabase {
    <init>();
}
-keep class androidx.work.impl.WorkDatabase_Impl { *; }
-dontwarn androidx.work.**
