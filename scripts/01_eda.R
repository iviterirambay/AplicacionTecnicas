# ==============================================================================
# SCRIPT: 01_eda.R 
# PROYECTO: Análisis de Logs de Red
# ==============================================================================

# --- [0] Librerias ---
library(readr)
library(dplyr)
library(lubridate)


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
col_names <- c(
  "timestamp", "fuid", "id_orig_h", "id_resp_h", "conn_uids", 
  "source", "depth", "analyzers", "mime_type", "filename", 
  "duration", "local_orig", "is_orig", "seen_bytes", "total_bytes", 
  "missing_bytes", "overflow_bytes", "timedout", "parent_fuid", 
  "md5", "sha1", "sha256", "extracted"
)


raw_data <- read_delim(
  path_data, 
  delim = "\t", 
  col_names = col_names,
  na = "-", 
  quote = "", # Importante: evita errores con caracteres especiales en nombres de archivos
  show_col_types = FALSE
) %>%
  # Seleccion para el analisis temporal
  select(timestamp, id_orig_h, id_resp_h, source, mime_type)


# Transformación temporal: De Unix Epoch a Objetos de Tiempo
df_clean <- raw_data %>%
  # 1. Convertir timestamp con precisión decimal
  mutate(timestamp = as.numeric(timestamp)) %>%
  # 2. Transformar a objeto de tiempo real (POSIXct)
  mutate(fecha_hora = as.POSIXct(timestamp, origin = "1970-01-01", tz = "UTC")) %>%
  # 3. Eliminar posibles NAs en el tiempo que rompan la serie
  filter(!is.na(fecha_hora))

# 3. Preparación para la Serie Temporal (Peticiones por segundo)
df_ts <- df_clean %>%
  mutate(segundo = floor_date(fecha_hora, "second")) %>%
  count(segundo, name = "peticiones") %>%
  # Asegurar que los segundos sin actividad tengan valor 0
  complete(segundo = seq(min(segundo), max(segundo), by = "1 sec"), 
           fill = list(peticiones = 0))

# Crear el objeto TS
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


# ==============================================================================
# 7. Sincronización Automática con GitHub
# ==============================================================================

# Cambiar el directorio de trabajo a la raíz del proyecto para que Git funcione
nombre_repo <- "AplicacionTecnicas" 
nombre_user <- "iviterirambay"
remote_url <- paste0("https://github.com/", nombre_user, "/", nombre_repo, ".git")
setwd(path_base)

# 2. Preparar el mensaje del commit
# Usamos shQuote para que los espacios y caracteres especiales no rompan el comando
fecha_ejecucion <- format(Sys.time(), "%Y-%m-%d %H:%M:%S")
mensaje_texto <- paste0("Auto-update DATOS: ", fecha_ejecucion, " | Corrección de formato y truncamiento de datos")
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