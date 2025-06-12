from sqlalchemy.dialects.postgresql import JSONB

from models.base import Base

from .engine import db
from .types import StringUUID


# This model is used to store custom information about the system.
class AliesPaymentsCustom(Base):
    __tablename__ = "alies_payments_custom"
    __table_args__ = (
        db.PrimaryKeyConstraint("id", name="pk_alies_payments_custom_id"),
        db.ForeignKeyConstraint(
            ["id_account"],
            ["accounts.id"],
            name="fk_alies_payments_custom_id_account",
            ondelete="CASCADE",
        ),
        db.UniqueConstraint("alies", name="uq_alies_payments_custom_alies"),
    )

    id = db.Column(StringUUID, server_default=db.text("uuid_generate_v4()"))
    id_account = db.Column(StringUUID, nullable=False)
    alies = db.Column(db.String(255), nullable=False)
    value = db.Column(JSONB, nullable=True)