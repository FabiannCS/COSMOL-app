"""
Modelos ORM de SQLAlchemy para PostgreSQL:
- BaseModel: Clase base abstracta con UUID v4, created_at y updated_at.
- Entidades futuras de negocio: User, UserAccount, UserDevice, OtpLog.
"""
from app.db.models.base import BaseModel

__all__ = ["BaseModel"]
