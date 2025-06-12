from sqlalchemy.dialects.postgresql import JSONB

from models.base import Base

from .engine import db
from .types import StringUUID


# This model is used to store custom information about the system.
class PaymentsHistoryCustom(Base):
    __tablename__ = "payments_history_custom"
    __table_args__ = (
        db.PrimaryKeyConstraint("id", name="pk_payments_history_custom_id"),
    )

    id = db.Column(StringUUID, server_default=db.text("uuid_generate_v4()"))
    value = db.Column(JSONB, nullable=True)
