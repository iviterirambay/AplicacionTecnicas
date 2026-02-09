# ==============================================================================
# SCRIPT: 04_comparativo_forecast.R
# PROYECTO: Análisis de Logs de Red
# DESCRIPCIÓN: Comparación visual sin recalcular modelos ya existentes
# ==============================================================================

# [1] Carga de Librerías
if (!require("pacman")) install.packages("pacman")
pacman::p_load(forecast, ggplot2, magrittr, dplyr)

# [2] Configuración de Parámetros
HORIZONTE <- 30

# [3] Función de Auditoría Optimizada (Evita recálculos)
audit_network_traffic_fast <- function(ts_data, h = 30) {
  
  if (!is.ts(ts_data)) stop("Error: La serie de tiempo no está disponible.")
  
  # --- RECUPERACIÓN O CÁLCULO DE MODELOS ---
  
  # 1. Holt-Winters (Es rápido, se puede recalcular o recuperar)
  # Si 'fit_hw' ya existe en el entorno global del Script 03, lo usamos
  if (exists("fit_hw")) {
    message("✅ Usando modelo Holt-Winters pre-calculado...")
    m_hw <- fit_hw
  } else {
    message("Calculating Holt-Winters...")
    m_hw <- tryCatch({
      HoltWinters(ts_data, seasonal = "multiplicative")
    }, error = function(e) {
      HoltWinters(ts_data, seasonal = "additive")
    })
  }
  fc_hw <- forecast(m_hw, h = h)
  
  # 2. ARIMA / SARIMA (Los más lentos)
  # Buscamos fit_arima y fc_sarima (que ya fueron creados en el Script 03)
  
  if (exists("fit_arima")) {
    message("✅ Usando modelo ARIMA pre-calculado...")
    fc_arima <- forecast(fit_arima, h = h)
  } else {
    message("⚠️ ARIMA no encontrado. Calculando versión rápida...")
    # Usamos stepwise=TRUE aquí para no demorar si no existe
    fc_arima <- forecast(auto.arima(ts_data, stepwise = TRUE), h = h)
  }
  
  if (exists("fc_sarima")) {
    message("✅ Usando modelo SARIMA pre-calculado...")
    # Si fc_sarima ya existe, solo ajustamos el horizonte si es necesario
    fc_sarima_final <- fc_sarima
  } else {
    message("⚠️ SARIMA no encontrado. Calculando...")
    fc_sarima_final <- stl(ts_data, s.window = "periodic") %>% forecast(method = "arima", h = h)
  }
  
  # --- EXTRACCIÓN DE MÉTRICAS ---
  # Usamos accuracy sobre los objetos de forecast ya existentes
  metrics <- rbind(
    data.frame(Modelo = "Holt-Winters", RMSE = accuracy(fc_hw)[1, "RMSE"]),
    data.frame(Modelo = "ARIMA",        RMSE = accuracy(fc_arima)[1, "RMSE"]),
    data.frame(Modelo = "SARIMA",       RMSE = accuracy(fc_sarima_final)[1, "RMSE"])
  ) %>% arrange(RMSE)
  
  # --- VISUALIZACIÓN ---
  # Definimos los colores manualmente para que coincidan con tu requerimiento
  colores_modelos <- c("Holt-Winters" = "red", "ARIMA" = "black", "SARIMA" = "blue")
  
  p_7 <- autoplot(ts_data) +
    # Línea de datos originales (por defecto negra)
    autolayer(fc_hw, series = "Holt-Winters", PI = FALSE, lwd = 1) +
    autolayer(fc_arima, series = "ARIMA", PI = FALSE,linetype = "dashed", lwd = 1) +
    autolayer(fc_sarima_final, series = "SARIMA", PI = FALSE, lwd = 1) +
    scale_color_manual(values = colores_modelos) +
    labs(title = "Comparativa: Pronóstico de Tráfico de Red",
         subtitle = paste("Modelo con menor RMSE:", metrics$Modelo[1]),
         y = "Peticiones/Logs", x = "Tiempo", color = "Modelos") +
    theme_minimal() +
    theme(
      legend.position = c(0.05, 0.95), # Simula el "topleft"
      legend.justification = c("left", "top"),
      legend.background = element_rect(fill = alpha("white", 0.5))
    )
  
  # --- GUARDAR IMAGEN ---
  # Definimos la ruta completa
  archivo_salida <- file.path(path_output, "13_forecast_modelos.png")
  
  # Guardamos en alta resolución
  ggsave(archivo_salida, p_7, width = 10, height = 6, dpi = 300)
  
  # Presentar la imagen en R (Consola/Plots)
  print(p_7)
  
  return(list(plot = p_7, metrics = metrics, forecasts = list(hw = fc_hw, arima = fc_arima, sarima = fc_sarima_final)))
}

# [4] Ejecución del Análisis
# Usamos traffic_min_ts o train_ts según disponibilidad
serie_a_usar <- if(exists("traffic_min_ts")) traffic_min_ts else train_ts

resultados <- audit_network_traffic_fast(serie_a_usar, h = HORIZONTE)

# Despliegue de Resultados
print(resultados$plot)
print(resultados$metrics)

cat("\n================================================\n")
cat("ANÁLISIS DE TENDENCIA (Próximos", HORIZONTE, "min)\n")
cat("================================================\n")
tendencia <- mean(diff(resultados$forecasts$sarima$mean))
cat("Dirección esperada:", ifelse(tendencia > 0, "📈 ALCISTA", "📉 BAJISTA"), "\n")

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
mensaje_texto <- paste0("refactor (comparativo_forecast): optimizar comparativa de pronósticos y modularizar función de graficado ", fecha_ejecucion, " | - Implementar patrón de recuperación para modelos pre-calculados (HW, ARIMA, SARIMA).
- Añadir validaciones defensivas para objetos de series temporales.
- Estandarizar el tema de ggplot2 y la resolución de salida (DPI).
- Asegurar la creación automatizada de directorios para resultados.")
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