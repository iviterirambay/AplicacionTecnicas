# ==============================================================================
# SCRIPT: 01_eda.R 
# PROYECTO: Análisis de Logs de Red
# ==============================================================================


# --- [1] Librerias ---
if (!require("pacman")) install.packages("pacman")
pacman::p_load(tidyverse, lubridate, forecast, tseries, astsa, ggplot2, readr)

# --- [2] Configuración de Entorno ---
path_base    <- "C:/Users/iavit/OneDrive/ESPOL/Maestria en Estadistica Aplicada/Clases Maestria en Estadistica Aplicada/Modulo 8/MODELOS DE PRONOSTICO/Tareas/Grupal/AplicacionTecnicas/"
path_data    <- file.path(path_base, "data/files.log.gz")
path_output  <- file.path(path_base, "output")
dir.create(path_output, showWarnings = FALSE)

# --- [3] Ingesta y Limpieza ---
col_names <- c("timestamp", "fuid", "id_orig_h", "id_resp_h", "conn_uids", "source", 
               "depth", "analyzers", "mime_type", "filename", "duration", 
               "local_orig", "is_orig", "seen_bytes", "total_bytes", "missing_bytes", 
               "overflow_bytes", "timedout", "parent_fuid", "md5", "sha1", "sha256", "extracted")

raw_data <- read_delim(path_data, delim = "\t", col_names = col_names, na = "-", quote = "", show_col_types = FALSE) %>%
  select(timestamp, id_orig_h, id_resp_h, source, mime_type)

df_clean <- raw_data %>%
  mutate(timestamp = as.numeric(timestamp),
         fecha_hora = as.POSIXct(timestamp, origin = "1970-01-01", tz = "UTC")) %>%
  filter(!is.na(fecha_hora))

# --- [4] Procesamiento de Series Temporales  ---
df_ts <- df_clean %>%
  mutate(segundo = floor_date(fecha_hora, "second")) %>%
  count(segundo, name = "peticiones") %>%
  complete(segundo = seq(min(segundo), max(segundo), by = "1 sec"), fill = list(peticiones = 0))

traffic_ts <- ts(df_ts$peticiones, frequency = 1)


# --- [4] Visualización y Guardado Automático ---

# A. Serie por Segundo
p1 <- autoplot(traffic_ts) + 
  labs(title = "Tráfico por Segundo", subtitle = "Serie Original", y = "Peticiones", x = "Tiempo") +
  theme_minimal()
print(p1) # Muestra en R
ggsave(file.path(path_output, "01_serie_segundo.png"), p1)

# B. Serie por Minuto
df_minuto <- df_ts %>%
  mutate(minuto = floor_date(segundo, "minute")) %>%
  group_by(minuto) %>%
  summarise(peticiones = sum(peticiones))
# Crear el objeto ts con frecuencia de 60 (ciclo horario)
traffic_min_ts <- ts(df_minuto$peticiones, frequency = 60)

p2 <- ggplot(df_minuto, aes(x = minuto, y = peticiones)) +
  geom_line(color = "#2c3e50") +
  labs(title = "Tráfico por Minuto", x = "Tiempo", y = "Total") +
  theme_light()
print(p2) # Muestra en R
ggsave(file.path(path_output, "02_serie_minuto.png"), p2)

# C. Serie por Hora
df_hora <- df_ts %>%
  mutate(hora = floor_date(segundo, "hour")) %>%
  group_by(hora) %>%
  summarise(peticiones = sum(peticiones))

p3 <- ggplot(df_hora, aes(x = hora, y = peticiones)) +
  geom_line(color = "#e67e22", size = 1) +  # Color naranja para diferenciar
  geom_point(color = "#d35400") +           # Puntos para resaltar los picos horarios
  labs(title = "Tráfico Agregado por Hora", 
       subtitle = paste("Desde", min(df_hora$hora), "hasta", max(df_hora$hora)),
       x = "Tiempo (Horas)", 
       y = "Total de Peticiones") +
  theme_minimal()

print(p3) # Muestra en R
ggsave(file.path(path_output, "03_serie_hora.png"), p3)

# D. Diagnóstico ACF/PACF
# Segundo
ggtsdisplay(traffic_ts, main = "Diagnóstico Temporal por segundo")
png(file.path(path_output, "04_diagnostico_seg_acf_pacf.png"), width = 1000, height = 800)
ggtsdisplay(traffic_ts, main = "Diagnóstico Temporal: Serie, ACF y PACF")
dev.off()

# Minuto
ggtsdisplay(traffic_min_ts, main = "Diagnóstico Temporal por minuto")
png(file.path(path_output, "05_diagnostico_min_acf_pacf.png"), width = 1000, height = 800)
ggtsdisplay(traffic_min_ts, main = "Diagnóstico Temporal: Serie, ACF y PACF")
dev.off()

# Objetos de Series Temporales
traffic_diff_min   <- diff(traffic_min_ts) # Diferenciación sugerida para estacionariedad
ggtsdisplay(traffic_diff_min, main = "Serie por Minuto con Diferenciación (d=1)")
png(file.path(path_output, "06_diagnostico_diff_min.png"), width = 1000, height = 800)
ggtsdisplay(traffic_diff_min, main = "Serie por Minuto con Diferenciación (d=1)")
dev.off()

# F. Boxplot Outliers
p4 <- ggplot(df_ts, aes(y = peticiones)) +
  geom_boxplot(fill = "orange", alpha = 0.5) + coord_flip() +
  labs(title = "Outliers Detectados") + theme_minimal()
print(p4) # Muestra en R
ggsave(file.path(path_output, "07_boxplot.png"), p4)

# --- [5] Pruebas Estadísticas ---
# Segundo
test_results_seg <- list(
  adf = tseries::adf.test(traffic_ts),
  kpss = tseries::kpss.test(traffic_ts)
)

# Minuto
test_results_min <- list(
  adf = tseries::adf.test(traffic_min_ts),
  kpss = tseries::kpss.test(traffic_min_ts)
)

# Mostrar en consola de R explícitamente
# Segundo
print(test_results_seg$adf)
print(test_results_seg$kpss)

# Segundo
print(test_results_min$adf)
print(test_results_min$kpss)

# --- Guardar en archivo TXT ---
# Creamos una lista maestra para guardar todo de una vez
resultados_totales <- list(
  segundos = test_results_seg,
  minutos = test_results_min
)

sink(file.path(path_output, "test_estacionariedad.txt"))
print(resultados_totales)
sink()



# 5. Análisis de Medias Móviles (Suavización k=5)
v_ma <- stats::filter(traffic_ts, sides = 1, rep(1/5, 5))


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
mensaje_texto <- paste0("feat(eda): ", fecha_ejecucion, " | capturar y persistir diagnósticos de estacionariedad.\n - Implementación de renderizado dual para ggtsdisplay (consola + PNG).
- Adición de serie diferenciada (d=1) al pipeline de salida automática.
- Incremento de resolución en gráficos de diagnóstico para mejor identificación de rezagos.")
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