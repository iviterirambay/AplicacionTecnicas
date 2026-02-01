# ==============================================================================
# SCRIPT: 01_eda.R 
# PROYECTO: Análisis de Logs de Red
# ==============================================================================

# --- [0] Librerias ---
library(readr)
library(dplyr)

# 1. Definición de Rutas Globales
# > [!NOTE] Actualizado a la nueva ubicación del archivo comprimido .log.gz
path_base    <- "C:/Users/iavit/OneDrive/ESPOL/Maestria en Estadistica Aplicada/Clases Maestria en Estadistica Aplicada/Modulo 8/MODELOS DE PRONOSTICO/Tareas/Grupal/AplicacionTecnicas/"
path_data    <- paste0(path_base, "data/files.log.gz")
path_output  <- paste0(path_base, "output/")
path_scripts <- paste0(path_base, "scripts/")

# 2. Gestión de Librerías
if (!require("pacman")) install.packages("pacman")
pacman::p_load(tidyverse, lubridate, forecast, tseries, astsa, openxlsx)

# 3. Ingesta y Limpieza de Logs
# Nota: read_table detecta automáticamente la compresión .gz
col_names <- c("timestamp", "uid", "id_orig_h", "id_resp_h", "fuid", 
               "proto", "depth", "analyzers", "mime_type")


raw_data <- read_table(path_data, col_names = FALSE, na = "-", show_col_types = FALSE) %>%
  select(1:9) %>%
  set_names(col_names)


# Convertir el timestamp a numérico
raw_data <- raw_data %>% mutate(timestamp = as.numeric(timestamp))

# Transformación temporal: De Unix Epoch a Objetos de Tiempo
df_ts <- raw_data %>%
  mutate(fecha_hora = as.POSIXct(timestamp, origin = "1970-01-01", tz = "UTC"),
         segundo = floor_date(fecha_hora, "second")) %>%
  count(segundo, name = "peticiones") %>%
  # Aseguramos continuidad en la serie (segundos sin tráfico = 0)
  complete(segundo = seq(min(segundo), max(segundo), by = "1 sec"), fill = list(peticiones = 0))

# Creación de objeto Time Series
traffic_ts <- ts(df_ts$peticiones, frequency = 1)

# 4. Verificación de Supuestos (Estacionariedad)
sink(paste0(path_output, "test_resultados_eda.txt"))
print("--- PRUEBA DE DICKEY-FULLER AUMENTADA (ADF) ---")
# H0: La serie tiene raíz unitaria (no es estacionaria)
print(adf.test(traffic_ts, alternative = "stationary"))

print("--- TEST KPSS ---")
# H0: La serie es estacionaria
print(kpss.test(traffic_ts, null = "Level"))
sink()

# 5. Análisis de Medias Móviles (Suavización k=5)
v_ma <- stats::filter(traffic_ts, sides = 1, rep(1/5, 5))

# 6. Exportación de Visualizaciones
png(paste0(path_output, "EDA_Grafico_Peticiones.png"), width = 1200, height = 800)
par(mfrow=c(2,1))
plot(traffic_ts, main="Serie Original: Peticiones por Segundo", col="darkblue", ylab="Frecuencia")
plot(v_ma, main="Suavizado Medias Móviles (k=5)", col="darkred", lwd=2)
dev.off()

print(paste("Proceso EDA completado con éxito. Datos leídos desde .log.gz"))
print(paste("Archivos guardados en:", path_output))