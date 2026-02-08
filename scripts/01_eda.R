# ==============================================================================
# SCRIPT: 01_eda.R 
# PROYECTO: Análisis de Logs de Red
# DESCRIPCIÓN: Ingesta, limpieza y análisis exploratorio (EDA) de tráfico.
# ==============================================================================

# --- [1] Librerías ---
if (!require("pacman")) install.packages("pacman")
pacman::p_load(tidyverse, lubridate, forecast, tseries, astsa, scales)

# --- [2] Configuración de Entorno ---
path_base   <- "C:/Users/iavit/OneDrive/ESPOL/Maestria en Estadistica Aplicada/Clases Maestria en Estadistica Aplicada/Modulo 8/MODELOS DE PRONOSTICO/Tareas/Grupal/AplicacionTecnicas/"
path_data   <- file.path(path_base, "data/files.log.gz")
path_output <- file.path(path_base, "output")

if (!dir.exists(path_output)) dir.create(path_output, recursive = TRUE)

# --- [3] Ingesta y Limpieza ---
col_names <- c("timestamp", "fuid", "id_orig_h", "id_resp_h", "conn_uids", "source", 
               "depth", "analyzers", "mime_type", "filename", "duration", 
               "local_orig", "is_orig", "seen_bytes", "total_bytes", "missing_bytes", 
               "overflow_bytes", "timedout", "parent_fuid", "md5", "sha1", "sha256", "extracted")

raw_data <- read_delim(path_data, delim = "\t", col_names = col_names, 
                       na = "-", quote = "", show_col_types = FALSE) %>%
  select(timestamp, id_orig_h, id_resp_h, source, mime_type)

df_clean <- raw_data %>%
  mutate(timestamp = as.numeric(timestamp),
         fecha_hora = as.POSIXct(timestamp, origin = "1970-01-01", tz = "UTC")) %>%
  filter(!is.na(fecha_hora))

# --- [4] Procesamiento de Series Temporales ---

# Agregación por Segundo
df_ts <- df_clean %>%
  mutate(segundo = floor_date(fecha_hora, "second")) %>%
  count(segundo, name = "peticiones") %>%
  complete(segundo = seq(min(segundo), max(segundo), by = "1 sec"), 
           fill = list(peticiones = 0))

traffic_ts <- ts(df_ts$peticiones, frequency = 1)

# Agregación por Minuto
df_minuto <- df_ts %>%
  mutate(minuto = floor_date(segundo, "minute")) %>%
  group_by(minuto) %>%
  summarise(peticiones = sum(peticiones), .groups = 'drop')

traffic_min_ts <- ts(df_minuto$peticiones, frequency = 60)

# Agregación por Hora
df_hora <- df_ts %>%
  mutate(hora = floor_date(segundo, "hour")) %>%
  group_by(hora) %>%
  summarise(peticiones = sum(peticiones), .groups = 'drop')

# --- [5] Visualización de Resultados ---

# 01. Serie por Segundo
p1 <- autoplot(traffic_ts) + 
  labs(title = "01. Tráfico de Red por Segundo", subtitle = "Serie temporal original", 
       y = "Peticiones", x = "Tiempo (Segundos)") +
  theme_minimal()
ggsave(file.path(path_output, "01_serie_segundo.png"), p1, width = 10, height = 6)

# 02. Serie por Minuto
p2 <- ggplot(df_minuto, aes(x = minuto, y = peticiones)) +
  geom_line(color = "#2c3e50") +
  labs(title = "02. Tráfico de Red por Minuto", x = "Tiempo", y = "Total Peticiones") +
  theme_light()
ggsave(file.path(path_output, "02_serie_minuto.png"), p2, width = 10, height = 6)

# 03. Serie por Hora
p3 <- ggplot(df_hora, aes(x = hora, y = peticiones)) +
  geom_line(color = "#e67e22", size = 1) + 
  geom_point(color = "#d35400") +
  labs(title = "03. Tráfico Agregado por Hora", 
       subtitle = paste("Rango:", min(df_hora$hora), "-", max(df_hora$hora)),
       x = "Tiempo (Horas)", y = "Total de Peticiones") +
  theme_minimal()
ggsave(file.path(path_output, "03_serie_hora.png"), p3, width = 10, height = 6)

# 04. Diagnóstico ACF/PACF (Segundo)
png(file.path(path_output, "04_diagnostico_seg_acf_pacf.png"), width = 1000, height = 800, res = 120)
ggtsdisplay(traffic_ts, main = "04. Diagnóstico Temporal (Segundo)")
dev.off()

# 05. Diagnóstico ACF/PACF (Minuto)
png(file.path(path_output, "05_diagnostico_min_acf_pacf.png"), width = 1000, height = 800, res = 120)
ggtsdisplay(traffic_min_ts, main = "05. Diagnóstico Temporal (Minuto)")
dev.off()

# 06. Diferenciación (Estacionariedad)
traffic_diff_min <- diff(traffic_min_ts)
png(file.path(path_output, "06_diagnostico_diff_min.png"), width = 1000, height = 800, res = 120)
ggtsdisplay(traffic_diff_min, main = "06. Serie por Minuto con Diferenciación (d=1)")
dev.off()

# 07. Boxplot de Outliers
p4 <- ggplot(df_ts, aes(x = "", y = peticiones)) +
  geom_boxplot(fill = "#3498db", alpha = 0.6, outlier.color = "red") + 
  coord_flip() +
  labs(title = "07. Identificación de Outliers", subtitle = "Distribución de peticiones por segundo",
       x = "", y = "Peticiones") + 
  theme_minimal()
ggsave(file.path(path_output, "07_boxplot.png"), p4, width = 10, height = 4)

# --- [6] Pruebas Estadísticas y Exportación ---

test_results <- list(
  segundo = list(adf = adf.test(traffic_ts), kpss = kpss.test(traffic_ts)),
  minuto  = list(adf = adf.test(traffic_min_ts), kpss = kpss.test(traffic_min_ts))
)

# Guardar resultados en texto
sink(file.path(path_output, "test_estacionariedad.txt"))
cat("========================================\n")
cat("PRUEBAS DE ESTACIONARIEDAD\n")
cat("========================================\n\n")
print(test_results)
sink()

# --- [7] Análisis de Medias Móviles ---
# Suavización simple para identificar tendencia
df_ts <- df_ts %>%
  mutate(ma_5 = as.numeric(stats::filter(peticiones, rep(1/5, 5), sides = 1)))

p5 <- ggplot(df_ts, aes(x = segundo)) +
  geom_line(aes(y = peticiones), alpha = 0.3) +
  geom_line(aes(y = ma_5), color = "red", size = 1) +
  labs(title = "08. Suavizado de la Serie (Media Móvil k=5)", 
       subtitle = "Rojo: Tendencia suavizada | Gris: Original",
       x = "Tiempo", y = "Peticiones") +
  theme_minimal()
ggsave(file.path(path_output, "08_suavizado_ma.png"), p5, width = 10, height = 6)


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
mensaje_texto <- paste0("refactor(eda): ", fecha_ejecucion, " | optimizar pipeline de visualización y diagnóstico estadístico.\n - Se añade parámetro .groups='drop' en agregaciones para evitar fugas de memoria.
- Estandarización de resolución (120 dpi) y dimensiones en exportación de PNG.
- Implementación de media móvil (k=5) para análisis de tendencia.
- Mejora en la nomenclatura de títulos de gráficos para trazabilidad con archivos de salida.
- Limpieza de lógica de Git interna para favorecer ejecución modular.")
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