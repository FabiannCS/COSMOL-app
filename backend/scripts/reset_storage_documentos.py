"""
Script de mantenimiento y reseteo (Clean-Slate) del repositorio de documentos (COSMOL R.L.).
Permite purgar de forma controlada y segura:
1. Bucket de MinIO S3 ('cosmol-docs'): elimina todos los PDFs generados previamente para reconstruir
   la estructura con la nueva jerarquía modular (facturas/pagadas/, facturas/impagas/, avisos_cobranza/).
2. Tabla 'documentos' en PostgreSQL: limpia metadatos para permitir sincronización fresca on-demand.
3. Claves de caché en Redis: invalida 'factura:detalle:*' y consultas cacheadas.

Uso:
    python scripts/reset_storage_documentos.py --confirm
    python scripts/reset_storage_documentos.py --solo-minio
    python scripts/reset_storage_documentos.py --solo-db
"""
import argparse
import asyncio
import logging
import sys

from sqlalchemy import delete, text

from pathlib import Path

# Asegurar path base del backend para imports
BASE_DIR = Path(__file__).resolve().parent.parent
sys.path.insert(0, str(BASE_DIR))

from app.core.config import settings
from app.core.redis import get_redis
from app.db.models.documento import Documento
from app.db.session import async_session_factory
from app.integrations.minio_client import minio_client

logging.basicConfig(level=logging.INFO, format="%(asctime)s [%(levelname)s] %(message)s")
logger = logging.getLogger("reset_storage")


def resetear_minio(bucket_name: str = "cosmol-docs") -> int:
    """
    Purga todos los objetos del bucket en MinIO S3.
    """
    logger.info(f"[MINIO] Iniciando purga de bucket '{bucket_name}'...")
    try:
        objetos = minio_client.listar_objetos(prefix="", recursive=True, bucket_name=bucket_name)
        total = len(objetos)
        if total == 0:
            logger.info(f"[MINIO] El bucket '{bucket_name}' ya se encuentra vacío.")
            return 0

        logger.info(f"[MINIO] Encontrados {total} objetos para eliminar.")
        eliminados = minio_client.purgar_bucket(bucket_name=bucket_name)
        logger.info(f"[MINIO] Purga completada exitosamente. Total eliminados: {eliminados}.")
        return eliminados
    except Exception as exc:
        logger.error(f"[MINIO] Error durante la purga de MinIO: {exc}")
        return 0


async def resetear_base_de_datos() -> int:
    """
    Elimina los registros indexados en la tabla 'documentos' de PostgreSQL.
    """
    logger.info("[DB] Limpiando tabla 'documentos' en PostgreSQL...")
    try:
        async with async_session_factory() as session:
            stmt = delete(Documento)
            result = await session.execute(stmt)
            await session.commit()
            total_eliminados = result.rowcount
            logger.info(f"[DB] Tabla 'documentos' reseteada exitosamente. Filas eliminadas: {total_eliminados}.")
            return total_eliminados
    except Exception as exc:
        logger.error(f"[DB] Error al resetear tabla 'documentos': {exc}")
        return 0


async def resetear_cache_redis() -> int:
    """
    Invalida las claves cacheadas en Redis relacionadas a facturas y documentos.
    """
    logger.info("[REDIS] Limpiando claves de facturas y documentos en Redis...")
    try:
        redis = get_redis()
        if not redis:
            logger.warning("[REDIS] Cliente Redis no disponible.")
            return 0

        patrones = ["factura:*", "deuda:*", "documentos:*"]
        total_purgados = 0
        for pat in patrones:
            keys = await redis.keys(pat)
            if keys:
                await redis.delete(*keys)
                total_purgados += len(keys)

        logger.info(f"[REDIS] Total de claves cacheadas invalidadas: {total_purgados}.")
        return total_purgados
    except Exception as exc:
        logger.warning(f"[REDIS] Error al limpiar caché de Redis: {exc}")
        return 0


async def main():
    parser = argparse.ArgumentParser(description="Herramienta de reseteo para el almacenamiento de PDFs de COSMOL.")
    parser.add_argument("--confirm", action="store_true", help="Confirma la ejecución sin confirmación interactiva.")
    parser.add_argument("--solo-minio", action="store_true", help="Solo purgar objetos de MinIO.")
    parser.add_argument("--solo-db", action="store_true", help="Solo limpiar registros en PostgreSQL.")
    args = parser.parse_args()

    print("=================================================================")
    print("  COSMOL R.L. - RESET DE ALMACENAMIENTO DE DOCUMENTOS DIGITALES  ")
    print("=================================================================")
    print(f"Bucket MinIO objetivo: {settings.MINIO_BUCKET_NAME}")
    print(f"Base de datos:         {settings.POSTGRES_DB}")
    print("-----------------------------------------------------------------")

    if not args.confirm:
        print("\nADVERTENCIA: Esta operacion eliminara los PDFs previos en MinIO")
        print("y los registros de la tabla 'documentos'. Toda la informacion se")
        print("regenerara limpiamente en la nueva estructura modular al consultar.")
        resp = input("\n¿Desea continuar con el reseteo? [s/N]: ").strip().lower()
        if resp not in ["s", "si", "y", "yes"]:
            print("Operación cancelada por el usuario.")
            return

    # Ejecutar reseteos solicitados
    if args.solo_minio:
        resetear_minio(settings.MINIO_BUCKET_NAME)
    elif args.solo_db:
        await resetear_base_de_datos()
    else:
        # Full Clean-Slate
        resetear_minio(settings.MINIO_BUCKET_NAME)
        await resetear_base_de_datos()
        await resetear_cache_redis()

    print("\n[OK] Reseteo finalizado. El sistema comenzara a guardar los nuevos PDFs")
    print("bajo la jerarquia modular:")
    print("  - facturas/impagas/{cod_socio}/{anio}/FAC_*.pdf")
    print("  - facturas/pagadas/{cod_socio}/{anio}/FAC_*.pdf")
    print("  - avisos_cobranza/{cod_socio}/{anio}/AVISO_*.pdf")


if __name__ == "__main__":
    asyncio.run(main())
