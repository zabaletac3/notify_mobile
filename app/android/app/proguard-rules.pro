# Endurecimiento de release (plan §5.4). Flutter ya aporta sus propias reglas por defecto
# (embedding, plugins registrados); esto cubre lo específico de AxoNote.

# Mantiene el plugin propio: el registro de plataforma usa el nombre de clase por reflexión.
-keep class com.axonote.axonote_platform.** { *; }

# BiometricPrompt y el resto de androidx.biometric ya traen sus propias reglas de consumidor.
