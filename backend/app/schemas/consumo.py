"""
Esquemas Pydantic v2 para el módulo de Analítica e Historial de Consumo (COSMOL R.L.).
Estructura datos de consumo mensual en m3 e importes en Bs para gráficos (fl_chart)
y soporta la detección de anomalías o consumos atípicos (fugas >= +30%).
"""
from typing import List, Literal, Optional
from pydantic import BaseModel, Field, ConfigDict


class ConsumoPeriodoResponse(BaseModel):
    """
    Representa el consumo y lecturas de medidor de un periodo mensual específico.
    """
    model_config = ConfigDict(from_attributes=True)

    periodo: str = Field(..., description="Periodo de consumo en formato MM/YYYY (ej: '08/2026')")
    mes: int = Field(..., ge=1, le=12, description="Mes numérico del periodo (1-12)")
    mes_nombre: str = Field(..., description="Nombre del mes y año (ej: 'Agosto 2026')")
    anio: int = Field(..., description="Año de la medición (ej: 2026)")
    consumo_m3: float = Field(..., ge=0.0, description="Volumen consumido en metros cúbicos (m³)")
    monto_bs: float = Field(..., ge=0.0, description="Monto facturado en Bolivianos (Bs)")
    lectura_anterior: float = Field(..., ge=0.0, description="Lectura inicial del medidor al corte anterior")
    lectura_actual: float = Field(..., ge=0.0, description="Lectura final del medidor al corte actual")
    fecha_lectura: Optional[str] = Field(None, description="Fecha de toma de lectura (ej: '2026-08-20')")
    estado_lectura: str = Field("NORMAL", description="Estado de la toma (NORMAL, ESTIMADA, REMEDICION)")


class EstadisticasConsumoResponse(BaseModel):
    """
    Métricas analíticas calculadas sobre el historial de consumos del socio.
    """
    model_config = ConfigDict(from_attributes=True)

    promedio_m3: float = Field(..., description="Promedio mensual de consumo en metros cúbicos (m³)")
    consumo_maximo_m3: float = Field(..., description="Volumen del mes de mayor consumo registrado")
    mes_consumo_maximo: str = Field(..., description="Periodo del mes con mayor consumo (ej: '09/2026')")
    consumo_minimo_m3: float = Field(..., description="Volumen del mes de menor consumo registrado")
    mes_consumo_minimo: str = Field(..., description="Periodo del mes con menor consumo (ej: '02/2026')")
    consumo_ultimo_mes_m3: float = Field(..., description="Volumen consumido en el último periodo medido")
    consumo_atipico: bool = Field(
        False,
        description="Indica si el último consumo supera en 30% o más el promedio histórico (posible fuga)"
    )
    porcentaje_variacion_ultimo_mes: Optional[float] = Field(
        None,
        description="Porcentaje de variación del último mes frente al promedio histórico (ej: +77.8%)"
    )
    mensaje_alerta: Optional[str] = Field(
        None,
        description="Mensaje preventivo de recomendación técnica en caso de detectar consumo atípico"
    )
    tendencia: Literal["SUBIENDO", "BAJANDO", "ESTABLE"] = Field(
        "ESTABLE",
        description="Tendencia de consumo observada entre los últimos meses registrados"
    )


class HistorialConsumoResponse(BaseModel):
    """
    Respuesta integral con el historial mensual y métricas analíticas del suministro.
    Diseñado para el renderizado inmediato de gráficos en Flutter (fl_chart).
    """
    model_config = ConfigDict(from_attributes=True)

    cod_socio: str = Field(..., description="Código de suministro / socio consultado")
    alias: str = Field("Mi Suministro", description="Alias personalizado configurado por el usuario")
    rol_acceso: Literal["TITULAR", "CONSULTA_PAGO"] = Field(
        "TITULAR",
        description="Rol y nivel de permisos del usuario sobre este suministro"
    )
    nro_medidor: Optional[str] = Field(
        None,
        description="Número de serie del medidor instalado (enmascarado para inquilinos)"
    )
    total_periodos: int = Field(..., description="Cantidad total de meses retornados (6 a 12 meses)")
    periodos: List[ConsumoPeriodoResponse] = Field(
        default_factory=list,
        description="Listado de periodos mensuales ordenados cronológicamente"
    )
    estadisticas: EstadisticasConsumoResponse = Field(
        ...,
        description="Métricas analíticas calculadas (promedios, extremos y alertas de fuga)"
    )
