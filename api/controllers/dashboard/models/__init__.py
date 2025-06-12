from pydantic import BaseModel

from configs import dify_config


# Models for Pydantic validation
class FeatureCustomModel(BaseModel):
    members: int = 1
    apps: int = dify_config.user_account_max_of_apps
    vector_space: int = dify_config.user_account_max_vector_space
    knowledge_rate_limit: int = dify_config.user_account_knowledge_rate_limit
    annotation_quota_limit: int = dify_config.user_account_max_annotation_quota_limit
    documents_upload_quota: int = dify_config.user_account_max_documents_upload_quota

class PlanModel(BaseModel):
    id: str
    name: str
    description: str
    price: float
    plan_expiration: int   # number of days until expiration
    features: FeatureCustomModel

class PaymentSettingsModel(BaseModel):
    access_token: str = "123456"
    account_name: str = ""
    account_id: str = ""  # Corrected typo: acouunt_id -> account_id
    bank_id: str = ""

class PaymentSettingsModelPublic(BaseModel):
    account_name: str = ""
    account_id: str = ""
    bank_id: str = ""

class PaymentHistoryModel(BaseModel):
    id_account: str = ""
    id_plan: str = ""
    id: str
    type: str
    transactionID: str
    amount: float
    description: str
    date: str
    bank: str

class AliesPaymentsInfo(BaseModel):
    id_account: str
    id_plan: str

class PayRequestModel(BaseModel):
    id_account: str
    id_plan: str
