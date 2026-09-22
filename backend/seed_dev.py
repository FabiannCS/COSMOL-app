import asyncio
import sys
import uuid
from sqlalchemy import select
from app.db.session import AsyncSessionLocal
from app.db.models import Usuario, Suministro
from app.core.security import get_password_hash

async def seed():
    async with AsyncSessionLocal() as db:
        pin_hash = get_password_hash("4455")
        
        test_users = [
            {
                "cod_socio": "540",
                "telefono": "+59171029384",
                "alias": "Mi Casa",
                "secundario": {"cod_socio": "556", "alias": "Alquiler Bolívar", "rol": "CONSULTA_PAGO"}
            },
            {
                "cod_socio": "104523",
                "telefono": "+59172019283",
                "alias": "Mi Suministro",
                "secundario": None
            },
            {
                "cod_socio": "556",
                "telefono": "+59173091827",
                "alias": "Casa Principal",
                "secundario": None
            },
        ]

        for udata in test_users:
            cod = udata["cod_socio"]
            # Check if supply already exists
            stmt = select(Suministro).where(Suministro.cod_socio == cod)
            res = await db.execute(stmt)
            existing_sum = res.scalars().first()
            if existing_sum:
                print(f"Socio {cod} ya existe en DB, salteando...")
                continue
            
            # Create Usuario
            user = Usuario(
                id=uuid.uuid4(),
                telefono=udata["telefono"],
                password_hash=pin_hash,
                esta_activo=True,
                intentos_fallidos=0
            )
            db.add(user)
            await db.flush()

            # Create Suministro Principal
            sum_p = Suministro(
                id=uuid.uuid4(),
                usuario_id=user.id,
                cod_socio=cod,
                alias=udata["alias"],
                rol="TITULAR",
                es_suministro_principal=True
            )
            db.add(sum_p)

            # Create Suministro Secundario if any
            if udata["secundario"]:
                sec = udata["secundario"]
                sum_s = Suministro(
                    id=uuid.uuid4(),
                    usuario_id=user.id,
                    cod_socio=sec["cod_socio"],
                    alias=sec["alias"],
                    rol=sec["rol"],
                    es_suministro_principal=False
                )
                db.add(sum_s)

            await db.commit()
            print(f"✅ Socio {cod} creado exitosamente con PIN '4455'")

if __name__ == "__main__":
    asyncio.run(seed())
