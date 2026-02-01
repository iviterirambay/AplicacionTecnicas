# Análisis de Series de Tiempo en Logs de Tráfico de Red

## Introducción
Este proyecto aplica modelos de pronóstico avanzados (ARIMA/VAR) sobre datos de tráfico de red para identificar patrones de comportamiento y anomalías temporales.

## Objetivos
* Modelar la volatilidad del tráfico de red por segundo.
* Validar supuestos de estacionariedad (ADF, KPSS).
* Predecir picos de carga mediante modelos de transferencia lineal.

##  Metodología
1. **Pre-procesamiento**: Conversión de timestamps Unix y manejo de valores nulos.
2. **Identificación**: Uso de funciones ACF/PACF para determinar órdenes (p, d, q).
3. **Estimación**: Comparación de modelos mediante criterios AIC/BIC.
4. **Validación**: Test de Ljung-Box para independencia de residuos y Shapiro-Wilk para normalidad.

## Análisis Exploratorio de Datos (EDA)

Se ha implementado un pipeline de procesamiento de logs con los siguientes componentes:

### 1. Visualización de Series Temporales
* **Multiescala:** Análisis de tráfico por segundo, minuto y hora para identificar patrones de ráfagas.
* **Suavizado (Moving Average):** Se incorporó una media móvil ($k=5$) para filtrar el ruido blanco y visualizar la tendencia subyacente.

### 2. Diagnóstico Estadístico
Se generan diagnósticos automáticos de estacionariedad en la carpeta `/output`:
* **ACF/PACF:** Evaluación de autocorrelación para la selección de órdenes en modelos ARMA/ARIMA.
* **Pruebas de Raíz Unitaria:** Resultados de los tests ADF y KPSS exportados en `test_estacionariedad.txt`.

###  Galería de Resultados
| Descripción | Visualización |
| :--- | :--- |
| **Tráfico por Segundo** | ![Serie Segundo](output/01_serie_segundo.png) |
| **Tráfico por Minuto** | ![Serie Minuto](output/02_serie_minuto.png) |
| **Análisis ACF/PACF** | ![Diagnóstico](output/04_diagnostico_seg_acf_pacf.png) |
| **Diferenciación (d=1)** | ![Diff](output/06_diagnostico_diff_min.png) |