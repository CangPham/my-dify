from pydantic import Field
from pydantic_settings import BaseSettings


class UserAccountDefaultConfig(BaseSettings):
    user_account_month_before_banned: int = Field(12, title="The number of months before the user account is banned")
    user_account_max_of_apps: int = Field(10, title="The maximum number of apps that a user can create")
    user_account_max_vector_space: int = Field(5, title="The maximum number of vector spaces that a user can create")
    user_account_knowledge_rate_limit: int = Field(10, title="The maximum number of knowledge rate limit that a user can create")
    user_account_max_annotation_quota_limit: int = Field(10, title="The maximum number of annotation quota limit that a user can create")
    user_account_max_documents_upload_quota: int = Field(50, title="The maximum number of documents upload quota that a user can create")