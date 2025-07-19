from sqlalchemy import Column, Integer, String, DateTime, Text, Boolean, JSON
from sqlalchemy.sql import func
from .base import Base

class LLMAPIConfig(Base):
    """LLM API配置模型 - 存储各个LLM提供商的API配置信息"""
    __tablename__ = "llm_api_configs"

    id = Column(Integer, primary_key=True, index=True)
    provider = Column(String(50), nullable=False, unique=True, index=True)  # openai, anthropic, google, etc.
    display_name = Column(String(100), nullable=False)  # 显示名称，如 "OpenAI", "Google (自定义地址)"
    is_enabled = Column(Boolean, default=True)  # 是否启用
    
    # API连接配置
    api_key = Column(Text, nullable=False)  # API密钥（加密存储）
    api_url = Column(String(500), nullable=True)  # API端点URL（可选，用于自定义地址）
    timeout = Column(Integer, default=60)  # 超时时间（秒）
    
    # 扩展配置（JSON格式存储）
    extra_config = Column(JSON, nullable=True)  # 额外配置参数
    
    # 支持的模型列表
    supported_models = Column(JSON, nullable=False)  # 支持的模型列表
    default_model = Column(String(100), nullable=True)  # 默认模型
    
    # 元数据
    description = Column(Text, nullable=True)  # 配置描述
    created_at = Column(DateTime(timezone=True), server_default=func.now())
    updated_at = Column(DateTime(timezone=True), server_default=func.now(), onupdate=func.now())
    
    # 连接状态
    last_test_at = Column(DateTime(timezone=True), nullable=True)  # 最后测试时间
    last_test_status = Column(String(20), nullable=True)  # 最后测试状态：success, error
    last_test_error = Column(Text, nullable=True)  # 最后测试错误信息
    
    def __repr__(self):
        return f"<LLMAPIConfig(id={self.id}, provider='{self.provider}', enabled={self.is_enabled})>" 