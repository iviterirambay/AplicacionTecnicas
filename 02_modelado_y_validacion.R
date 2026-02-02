# ==============================================================================
# SCRIPT: 02_modelado_y_validacion.R 
# PROYECTO: Análisis de Logs de Red
# DESCRIPCIÓN: Ajuste y validación de modelos (SE, ARMA, ARIMA, SARIMA)
# ==============================================================================

# --- [1] Preparación de Datos ---
# Usaremos la serie por minuto 'traffic_min_ts' del script anterior

# Definir ventana de entrenamiento (80%) y prueba (20%)
n <- length(traffic_min_ts)
n_train <- floor(n * 0.8)
train_ts <- subset(traffic_min_ts, end = n_train)
test_ts  <- subset(traffic_min_ts, start = n_train + 1)

# Función para extraer métricas de error
get_metrics <- function(model_forecast, actual, model_name) {
  acc <- accuracy(model_forecast, actual)
  data.frame(
    Modelo = model_name,
    RMSE = acc[2, "RMSE"],
    MAE = acc[2, "MAE"],
    MAPE = acc[2, "MAPE"]
  )
}

# --- [2] Modelo 1: Suavización Exponencial (Holt-Winters) ---
# Intentamos Holt-Winters. Si no tiene estacionalidad clara, usamos solo tendencia.
fit_hw <- HoltWinters(train_ts, gamma = FALSE) # gamma=FALSE si no hay estacionalidad fija
fc_hw  <- forecast(fit_hw, h = length(test_ts))

# --- [3] Modelo 2: ARMA / ARIMA (Manual vs Automático) ---
# Basado en tus scripts de clase, usamos auto.arima para encontrar el mejor ajuste
fit_auto_arima <- auto.arima(train_ts, stepwise = FALSE, approximation = FALSE)
fc_arima <- forecast(fit_auto_arima, h = length(test_ts))

# --- [4] Modelo 3: SARIMA ---
# Si detectamos estacionalidad (ej. frecuencia 60 para minutos en una hora)
fit_sarima <- stl(train_ts, s.window = "periodic") %>% forecast(method = "arima", h = length(test_ts))

# --- [5] Validación de Supuestos (Residuales) ---
# Tal como en 'ARIMA desempleo Bolivia.R', validamos el mejor modelo
best_model <- fit_auto_arima

png(file.path(path_output, "09_diagnostico_residuales.png"), width = 1000, height = 800, res = 120)
checkresiduals(best_model)
dev.off()

# Test de Normalidad de residuales
shapiro_res <- shapiro.test(residuals(best_model))

# --- [6] Comparación de Modelos ---
metrics_hw    <- get_metrics(fc_hw, test_ts, "Holt-Winters")
metrics_arima <- get_metrics(fc_arima, test_ts, "Auto-ARIMA")
metrics_sarima <- get_metrics(fc_sarima, test_ts, "SARIMA (STL)")

tabla_comparativa <- rbind(metrics_hw, metrics_arima, metrics_sarima)
write.csv(tabla_comparativa, file.path(path_output, "comparacion_modelos.csv"), row.names = FALSE)

# --- [7] Visualización Final del Ajuste ---
p_final <- autoplot(train_ts) +
  autolayer(fc_arima, series = "ARIMA Forecast", PI = FALSE) +
  autolayer(test_ts, series = "Valor Real", color = "black") +
  labs(title = "Comparativa: Predicción vs Realidad",
       subtitle = paste("Mejor Modelo:", fit_auto_arima$method),
       y = "Peticiones", x = "Tiempo") +
  theme_minimal()

ggsave(file.path(path_output, "10_comparativa_final.png"), p_final, width = 10, height = 6)

# Imprimir resumen en consola
cat("\n--- RESULTADOS DE VALIDACIÓN ---\n")
print(tabla_comparativa)
cat("\nTest de Normalidad Residuales (P-Value):", shapiro_res$p.value)

# ==============================================================================
# Sincronización Automática con GitHub
# ==============================================================================

# Cambiar el directorio de trabajo a la raíz del proyecto para que Git funcione
nombre_repo <- "AplicacionTecnicas" 
nombre_user <- "iviterirambay"
remote_url <- paste0("https://github.com/", nombre_user, "/", nombre_repo, ".git")
setwd(path_base)

# 2. Preparar el mensaje del commit
# Usamos shQuote para que los espacios y caracteres especiales no rompan el comando
fecha_ejecucion <- format(Sys.time(), "%Y-%m-%d %H:%M:%S")
mensaje_texto <- paste0("feat (modelos): ", fecha_ejecucion, " | implementar pipeline de modelado predictivo y validación de residuales.\n - Adición de modelos Holt-Winters, Auto-ARIMA y SARIMA.
- Automatización de exportación de métricas (RMSE, MAE, MAPE).
- Generación de gráficos de diagnóstico de residuales y comparativa final.
- Mejora de robustez con validación de entorno.")
comando_commit <- paste0('git commit -m ', shQuote(mensaje_texto))

# 3. Ejecutar Pipeline de Git
message("🚀 Iniciando carga a GitHub...")

# Agregar cambios (Respeta el .gitignore de la configuración en el script 00)
system("git add .")

# Intentar hacer el commit
try(system(comando_commit), silent = TRUE)

# 4. Sincronizar con el servidor
# Hacemos un pull primero por si acaso hubo cambios manuales en el repo de GitHub
system("git pull origin main --rebase")

# Subir los cambios
exit_code <- system("git push origin main")

if(exit_code == 0) {
  message("✅ Sincronización exitosa: Código, datos (.gz) y outputs actualizados.")
} else {
  message("⚠️ Error en el push. Revisa la consola de Git o tus credenciales.")
}


# ==============================================================================
# FINAL DEL SCRIPT
# ==============================================================================