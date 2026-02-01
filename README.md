# Análisis de Series de Tiempo en Logs de Tráfico de Red

## 📋 Introducción
Este proyecto aplica modelos de pronóstico avanzados (ARIMA/VAR) sobre datos de tráfico de red para identificar patrones de comportamiento y anomalías temporales.

## 🎯 Objetivos
* Modelar la volatilidad del tráfico de red por segundo.
* Validar supuestos de estacionariedad (ADF, KPSS).
* Predecir picos de carga mediante modelos de transferencia lineal.

## 🛠️ Metodología
1. **Pre-procesamiento**: Conversión de timestamps Unix y manejo de valores nulos.
2. **Identificación**: Uso de funciones ACF/PACF para determinar órdenes (p, d, q).
3. **Estimación**: Comparación de modelos mediante criterios AIC/BIC.
4. **Validación**: Test de Ljung-Box para independencia de residuos y Shapiro-Wilk para normalidad.

