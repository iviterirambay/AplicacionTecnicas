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

He actualizado la sección de Resultados de Diagnóstico para incluir la comparación de granularidad.

Secciones modificadas:

Visualización de Diagnóstico: Se añadieron los hipervínculos a los nuevos gráficos de ACF/PACF.

Análisis Estadístico: Se incluyó la tabla comparativa de las pruebas ADF y KPSS para segundos y minutos.

### Diagnóstico Temporal
Se realizaron análisis en dos niveles de agregación para capturar dinámicas de red distintas:

* **Granularidad por Segundo:** [Ver Gráfico](https://github.com/iviterirambay/AplicacionTecnicas/blob/main/output/04_diagnostico_seg_acf_pacf.png)
* **Granularidad por Minuto:** [Ver Gráfico](https://github.com/iviterirambay/AplicacionTecnicas/blob/main/output/05_diagnostico_min__acf_pacf.png)

**Conclusión:** La serie presenta contradicción entre ADF y KPSS, sugiriendo la necesidad de aplicar una diferencia de primer orden antes de proceder con modelos ARIMA.

