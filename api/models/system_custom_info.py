from sqlalchemy.dialects.postgresql import JSONB

from models.base import Base

from .engine import db
from .types import StringUUID


# This model is used to store custom information about the system.
class SystemCustomInfo(Base):
    __tablename__ = "system_custom_info"
    __table_args__ = (
        db.PrimaryKeyConstraint("id", name="pk_system_custom_info_id"),
        db.UniqueConstraint("name", name="uq_system_custom_info_name"),
    )

    id = db.Column(StringUUID, server_default=db.text("uuid_generate_v4()"))
    name = db.Column(db.String(255), nullable=False)
    value = db.Column(JSONB, nullable=True)
