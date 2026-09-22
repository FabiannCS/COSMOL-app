import os
from typing import List
from pydantic_settings import BaseSettings, SettingsConfigDict


class Settings(BaseSettings):
    """
    Configuración central de la aplicación cargada desde variables de entorno.
    """
    # Entorno y Depuración
    PROJECT_NAME: str = "COSMOL R.L. - Backend API"
    VERSION: str = "1.0.0"
    API_V1_STR: str = "/api/v1"
    ENVIRONMENT: str = "development"
    DEBUG: bool = True

    # Seguridad y JWT
    SECRET_KEY: str = "cosmol_dev_secret_key_change_in_production_3849102834"
    ALGORITHM: str = "HS256"
    ACCESS_TOKEN_EXPIRE_MINUTES: int = 15
    REFRESH_TOKEN_EXPIRE_DAYS: int = 7

    # CORS
    BACKEND_CORS_ORIGINS: List[str] = ["*"]

    # Base de Datos (PostgreSQL)
    POSTGRES_SERVER: str = "db-postgres"
    POSTGRES_PORT: int = 5432
    POSTGRES_USER: str = "cosmol_user"
    POSTGRES_PASSWORD: str = "cosmol_secret_pass"
    POSTGRES_DB: str = "cosmol_db"
    DATABASE_URL: str = "postgresql+asyncpg://cosmol_user:cosmol_secret_pass@db-postgres:5432/cosmol_db"

    # Caché y Redis
    REDIS_HOST: str = "cache-redis"
    REDIS_PORT: int = 6379
    REDIS_URL: str = "redis://cache-redis:6379/0"

    # Almacenamiento de Documentos (MinIO)
    MINIO_ENDPOINT: str = "storage-minio:9000"
    MINIO_ROOT_USER: str = "cosmol_minio_admin"
    MINIO_ROOT_PASSWORD: str = "cosmol_minio_secret_pass"
    MINIO_BUCKET_NAME: str = "cosmol-docs"

    # Mensajería y OTP (WhatsApp Cloud API y Gateway SMS)
    MOCK_MESSAGING: bool = True
    OTP_EXPIRE_SECONDS: int = 300  # 5 minutos
    OTP_MAX_REQUESTS_PER_HOUR: int = 3
    OTP_CODE_LENGTH: int = 6

    # Meta WhatsApp Cloud API
    WHATSAPP_API_URL: str = "https://graph.facebook.com/v21.0"
    WHATSAPP_PHONE_NUMBER_ID: str = ""
    WHATSAPP_ACCESS_TOKEN: str = ""
    WHATSAPP_OTP_TEMPLATE_NAME: str = "codigo_autenticacion_cosmol"

    # Gateway SMS (Canal alternativo de respaldo)
    SMS_GATEWAY_URL: str = ""
    SMS_GATEWAY_API_KEY: str = ""

    # Integración con Sistema Comercial Legado de COSMOL
    COSMOL_LEGACY_URL: str = "http://api.cosmol.com.bo/api-consultas"
    COSMOL_LEGACY_TIMEOUT_SECONDS: float = 4.0
    MOCK_COSMOL_LEGACY: bool = False
    MOCK_COSMOL_CONSUMO: bool = False
    DEBT_CACHE_TTL_SECONDS: int = 600  # 10 minutos (600 segundos)
    CONSUMO_CACHE_TTL_SECONDS: int = 900  # 15 minutos (900 segundos)

    # Pasarelas de Pago Externas (Hosted Checkout)
    URL_MULTIPAGO_COSMOL: str = "https://multipago.com/service/cosmol_payment/first"
    URL_PAGO_AL_PASO_COSMOL: str = "https://red.pagoalpaso247.net/servicio/cosmol"
    VENTANA_VERIFICACION_PAGO_SEGUNDOS: int = 900  # 15 minutos (900 segundos)
    COOLDOWN_VERIFICACION_PAGO_SEGUNDOS: int = 30  # Micro-TTL anti-saturación Informix (30 segundos)

    model_config = SettingsConfigDict(
        env_file=".env",
        env_file_encoding="utf-8",
        extra="ignore"
    )


settings = Settings()
