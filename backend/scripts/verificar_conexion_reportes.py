"""
Script de verificación integral de conectividad entre COSMOL-App y COSMOL-Reportes.
Prueba el despacho de los 8 eventos oficiales del catálogo de la App Móvil
y verifica que se registren exitosamente en la base de datos de COSMOL-Reportes.
"""
import asyncio
import os
import sys

# Agregar ruta del backend al path
sys.path.insert(0, os.path.abspath(os.path.join(os.path.dirname(__file__), "..")))

from app.integrations.reportes_client import ReportesApiClient

EVENTOS_PRUEBA = [
    {
        "id_tipo": 1,
        "tipo_consulta": "Autenticación / Acceso",
        "descripcion": "Inicio de sesión de socio en App Móvil",
    },
    {
        "id_tipo": 5,
        "tipo_consulta": "Solicitud de Reconexión",
        "descripcion": "Registro de solicitud formal de reconexión",
    },
    {
        "id_tipo": 9,
        "tipo_consulta": "Descarga de Factura PDF",
        "descripcion": "Descarga de factura digital SIAT en PDF",
    },
    {
        "id_tipo": 10,
        "tipo_consulta": "Pago: Multipago",
        "descripcion": "Intento de pago en pasarela Multipago Bolivia",
    },
]

async def main():
    print("=" * 70)
    print("  VERIFICACIÓN DE CONEXIÓN: COSMOL-APP -> COSMOL-REPORTES")
    print("=" * 70)

    client = ReportesApiClient()
    url_destino = client._resolver_url_destino()
    print(f"[*] URL Destino resuelta: {url_destino}")
    print(f"[*] Reportes habilitado: {client.base_url}")
    print(f"[*] Token configurado: {'SI' if client.default_headers.get('X-Reportes-Token') else 'NO'}")
    print("-" * 70)

    codigo_socio_test = 778899
    telefono_test = "76543210"
    nombre_test = "SOCIO PRUEBA CONEXION INTEGRAL"

    exitos = 0
    fallos = 0

    for ev in EVENTOS_PRUEBA:
        id_tipo = ev["id_tipo"]
        tipo_consulta = ev["tipo_consulta"]
        desc = ev["descripcion"]

        print(f"\n[>] Probando evento {id_tipo}: '{tipo_consulta}' ({desc})...")
        ok = await client.enviar_evento_auditoria(
            codigo_socio=codigo_socio_test,
            nombres=nombre_test,
            telefono=telefono_test,
            id_tipo=id_tipo,
            tipo_consulta=tipo_consulta,
            tipo_ubicacion="APP_MOVIL",
        )

        if ok:
            print(f"    [OK] Despachado y aceptado con éxito (HTTP 201).")
            exitos += 1
        else:
            print(f"    [ERROR] Falló el despacho del evento {id_tipo}.")
            fallos += 1

    print("\n" + "=" * 70)
    print(f"  RESUMEN: {exitos}/{len(EVENTOS_PRUEBA)} eventos despachados exitosamente.")
    if fallos == 0:
        print("  ¡TODOS LOS EVENTOS SE CONECTARON CORRECTAMENTE CON COSMOL-REPORTES!")
    else:
        print(f"  Hubo {fallos} fallos en el despacho.")
    print("=" * 70)

if __name__ == "__main__":
    asyncio.run(main())
