from pydantic import BaseModel, Field, validator
from datetime import datetime
from typing import Optional, List, Dict, Any
from enum import Enum

class LLMProvider(str, Enum):
    """支持的LLM服务提供商"""
    OPENAI = "openai"
    ANTHROPIC = "anthropic"
    GOOGLE = "google"
    GOOGLE_CUSTOM = "google_custom"
    CUSTOM = "custom"

class TestStatus(str, Enum):
    """测试状态"""
    SUCCESS = "success"
    ERROR = "error"
    PENDING = "pending"

# ===========================================
# API配置基础模式
# ===========================================

class LLMAPIConfigBase(BaseModel):
    """API配置基础模式"""
    provider: LLMProvider = Field(..., description="LLM提供商")
    display_name: str = Field(..., min_length=1, max_length=100, description="显示名称")
    is_enabled: bool = Field(True, description="是否启用")
    api_key: str = Field(..., min_length=1, description="API密钥")
    api_url: Optional[str] = Field(None, description="API端点URL")
    timeout: int = Field(60, ge=1, le=300, description="超时时间（秒）")
    extra_config: Optional[Dict[str, Any]] = Field(default_factory=dict, description="额外配置参数")
    supported_models: List[str] = Field(..., min_items=1, description="支持的模型列表")
    default_model: Optional[str] = Field(None, description="默认模型")
    description: Optional[str] = Field(None, description="配置描述")

class LLMAPIConfigCreate(LLMAPIConfigBase):
    """创建API配置模式"""
    pass

class LLMAPIConfigUpdate(BaseModel):
    """更新API配置模式"""
    display_name: Optional[str] = Field(None, min_length=1, max_length=100, description="显示名称")
    is_enabled: Optional[bool] = Field(None, description="是否启用")
    api_key: Optional[str] = Field(None, min_length=1, description="API密钥")
    api_url: Optional[str] = Field(None, description="API端点URL")
    timeout: Optional[int] = Field(None, ge=1, le=300, description="超时时间（秒）")
    extra_config: Optional[Dict[str, Any]] = Field(None, description="额外配置参数")
    supported_models: Optional[List[str]] = Field(None, min_items=1, description="支持的模型列表")
    default_model: Optional[str] = Field(None, description="默认模型")
    description: Optional[str] = Field(None, description="配置描述")

class LLMAPIConfig(LLMAPIConfigBase):
    """API配置读取模式"""
    id: int
    created_at: datetime
    updated_at: datetime
    last_test_at: Optional[datetime] = None
    last_test_status: Optional[TestStatus] = None
    last_test_error: Optional[str] = None

    class Config:
        from_attributes = True

# ===========================================
# 测试和管理相关模式
# ===========================================

class APITestRequest(BaseModel):
    """API测试请求模式"""
    provider: str = Field(..., description="要测试的提供商")
    test_prompt: Optional[str] = Field("Hello, this is a test.", description="测试提示词")

class APITestResponse(BaseModel):
    """API测试响应模式"""
    status: TestStatus
    response: Optional[str] = None
    execution_time: Optional[float] = None
    error: Optional[str] = None
    model_used: Optional[str] = None

class ProvidersResponse(BaseModel):
    """提供商列表响应模式"""
    providers: List[str]
    configs: List[LLMAPIConfig]
    models: Dict[str, List[str]]

class ConfigStatusResponse(BaseModel):
    """配置状态响应模式"""
    total_configs: int
    enabled_configs: int
    working_configs: int
    last_updated: Optional[datetime] = None

# ===========================================
# 预设配置模板
# ===========================================

class ProviderTemplate(BaseModel):
    """提供商配置模板"""
    provider: LLMProvider
    display_name: str
    description: str
    default_models: List[str]
    required_fields: List[str]
    optional_fields: List[str]
    api_url_required: bool
    setup_instructions: List[str]
    example_config: Dict[str, Any] 