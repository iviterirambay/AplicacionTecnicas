# ==============================================================================
# SCRIPT: 02_modelado_y_validacion.R 
# PROYECTO: Análisis de Logs de Red
# DESCRIPCIÓN: Selección del mejor modelo (SE, ARIMA, SARIMA)
# ==============================================================================

# --- [1] Preparación y Partición de Datos ---
# Asegúrate de que 'traffic_min_ts' esté cargado del script anterior
n <- length(traffic_min_ts)
n_train <- floor(n * 0.8)
train_ts <- subset(traffic_min_ts, end = n_train)
test_ts  <- subset(traffic_min_ts, start = n_train + 1)

# Función para extraer métricas de error (Basado en Accuracy de forecast)
get_metrics <- function(model_forecast, actual, model_name) {
  acc <- accuracy(model_forecast, actual)
  data.frame(
    Modelo = model_name,
    RMSE = acc[2, "RMSE"],
    MAE = acc[2, "MAE"],
    MAPE = acc[2, "MAPE"],
    AIC = ifelse(is.null(model_forecast$model$aic), NA, model_forecast$model$aic)
  )
}

# --- [2] Modelo 1: Suavización Exponencial (Holt-Winters) ---
# Ajustamos con tendencia (gamma=FALSE para no estacional)
fit_hw <- HoltWinters(train_ts, gamma = FALSE) 
fc_hw  <- forecast(fit_hw, h = length(test_ts))

# --- [3] Modelo 2: Auto-ARIMA ---
# Buscamos el mejor (p,d,q)
# fit_arima <- auto.arima(train_ts, stepwise = FALSE, approximation = FALSE)
fit_arima <- Arima(train_ts, order = c(4, 1, 0))
fc_arima  <- forecast(fit_arima, h = length(test_ts))

# --- [4] Modelo 3: SARIMA (vía STL) ---
# Corrección del error previo: guardamos directamente como 'fc_sarima'
fc_sarima <- stl(train_ts, s.window = "periodic") %>% 
  forecast(method = "arima", h = length(test_ts))

# --- [5] Comparación y Selección del "Campeón" ---
metrics_hw    <- get_metrics(fc_hw, test_ts, "Holt-Winters")
metrics_arima <- get_metrics(fc_arima, test_ts, "Auto-ARIMA")
metrics_sarima <- get_metrics(fc_sarima, test_ts, "SARIMA (STL)")

tabla_comparativa <- rbind(metrics_hw, metrics_arima, metrics_sarima) %>%
  arrange(RMSE) # El mejor modelo tendrá el RMSE más bajo

# Guardar tabla de resultados
write.csv(tabla_comparativa, file.path(path_output, "09_comparacion_modelos.csv"), row.names = FALSE)

# Identificar el mejor modelo
mejor_modelo_nombre <- tabla_comparativa$Modelo[1]
fc_mejor <- if(mejor_modelo_nombre == "Auto-ARIMA") fc_arima else 
  if(mejor_modelo_nombre == "Holt-Winters") fc_hw else fc_sarima

# --- [6] Validación de Supuestos del Mejor Modelo ---
# Tal como en 'SARIMA_VENTAS_LICOR.R', validamos residuales
png(file.path(path_output, "10_diagnostico_mejor_modelo.png"), width = 1000, height = 800, res = 120)
checkresiduals(fc_mejor)
dev.off()

# Test de Normalidad (Shapiro-Wilk)
residuos <- residuals(fc_mejor)
shapiro_res <- shapiro.test(residuos)

# --- [7] Visualización Final: Predicción vs Realidad ---
p_final <- autoplot(train_ts) +
  autolayer(fc_mejor, series = paste("Predicción:", mejor_modelo_nombre), PI = TRUE, alpha = 0.2) +
  autolayer(test_ts, series = "Valor Real", color = "black") +
  labs(title = "Validación Final del Modelo de Tráfico",
       subtitle = paste("Ganador:", mejor_modelo_nombre, "| RMSE:", round(tabla_comparativa$RMSE[1], 2)),
       y = "Peticiones", x = "Tiempo (Minutos)") +
  theme_minimal() +
  theme(legend.position = "bottom")

ggsave(file.path(path_output, "11_validacion_final.png"), p_final, width = 10, height = 6)

# --- [8] Informe de Resultados en Consola ---
cat("\n================================================\n")
cat("RESUMEN DE VALIDACIÓN DE MODELOS\n")
cat("================================================\n")
print(tabla_comparativa)
cat("\nEl mejor modelo seleccionado es:", mejor_modelo_nombre, "\n")
cat("P-value Test de Normalidad (Shapiro):", shapiro_res$p.value, "\n")
if(shapiro_res$p.value > 0.05) {
  cat("Conclusión: Los residuales siguen una distribución normal.\n")
} else {
  cat("Conclusión: Los residuales NO son normales (se sugiere revisar outliers).\n")
}

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
mensaje_texto <- paste0("feat (modelos): ", fecha_ejecucion, " | implementar pipeline end-to-end de series temporales.\n - docs: actualizar README con galería de resultados y descripción de logs
- feat: añadir validación competitiva de modelos (ARIMA vs HW vs SARIMA)
- perf: optimizar lectura de logs filtrando columnas innecesarias")
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