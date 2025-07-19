from fastapi import APIRouter, HTTPException, Depends, status
from sqlalchemy.orm import Session
from typing import List

from ..database import get_db
from ..models.api_config import LLMAPIConfig
from ..schemas.api_config import (
    LLMAPIConfigCreate, 
    LLMAPIConfigUpdate, 
    LLMAPIConfig as LLMAPIConfigSchema,
    APITestRequest,
    APITestResponse,
    ProvidersResponse,
    ConfigStatusResponse,
    ProviderTemplate,
    LLMProvider,
    TestStatus
)
from ..services.llm_service import DynamicLLMService
from ..core.security import security_manager, InputValidator, SecurityError, rate_limit
from datetime import datetime
import logging

logger = logging.getLogger(__name__)

router = APIRouter(
    prefix="/api/v1/api-config",
    tags=["api-config"]
)

# 预设的提供商模板
PROVIDER_TEMPLATES = {
    "openai": ProviderTemplate(
        provider=LLMProvider.OPENAI,
        display_name="OpenAI",
        description="OpenAI GPT模型，支持GPT-4、GPT-3.5等",
        default_models=["gpt-4", "gpt-4-turbo-preview", "gpt-3.5-turbo", "gpt-3.5-turbo-16k"],
        required_fields=["api_key"],
        optional_fields=["api_url", "timeout"],
        api_url_required=False,
        setup_instructions=[
            "访问 https://platform.openai.com/api-keys",
            "创建新的API密钥",
            "输入API密钥即可使用"
        ],
        example_config={"temperature": 0.7, "max_tokens": 1000}
    ),
    "anthropic": ProviderTemplate(
        provider=LLMProvider.ANTHROPIC,
        display_name="Anthropic Claude",
        description="Anthropic Claude模型，支持Claude-3等",
        default_models=["claude-3-opus-20240229", "claude-3-sonnet-20240229", "claude-3-haiku-20240307"],
        required_fields=["api_key"],
        optional_fields=["timeout"],
        api_url_required=False,
        setup_instructions=[
            "访问 https://console.anthropic.com/",
            "获取API密钥",
            "输入API密钥即可使用"
        ],
        example_config={"temperature": 0.7, "max_tokens": 1000}
    ),
    "google": ProviderTemplate(
        provider=LLMProvider.GOOGLE,
        display_name="Google (官方)",
        description="Google Gemini模型官方API",
        default_models=["gemini-pro", "gemini-pro-vision", "gemini-1.5-pro-latest"],
        required_fields=["api_key"],
        optional_fields=["timeout"],
        api_url_required=False,
        setup_instructions=[
            "访问 https://aistudio.google.com/app/apikey",
            "创建API密钥",
            "输入API密钥即可使用"
        ],
        example_config={"temperature": 0.7, "max_tokens": 1000}
    ),
    "google_custom": ProviderTemplate(
        provider=LLMProvider.GOOGLE_CUSTOM,
        display_name="Google (自定义地址)",
        description="通过自定义地址访问Google模型",
        default_models=["gemini-pro", "gemini-pro-vision", "gemini-1.5-pro-latest", "gemini-1.5-flash"],
        required_fields=["api_key", "api_url"],
        optional_fields=["timeout"],
        api_url_required=True,
        setup_instructions=[
            "获取Google API密钥",
            "设置自定义代理地址",
            "配置API格式 (openai/google/gemini)",
            "测试连接确保正常工作"
        ],
        example_config={"api_format": "openai", "model_prefix": "gemini"}
    ),
    "custom": ProviderTemplate(
        provider=LLMProvider.CUSTOM,
        display_name="自定义API",
        description="兼容OpenAI格式的自定义API",
        default_models=["custom-model"],
        required_fields=["api_key", "api_url"],
        optional_fields=["timeout"],
        api_url_required=True,
        setup_instructions=[
            "准备兼容OpenAI格式的API端点",
            "获取API密钥",
            "输入API端点地址和密钥"
        ],
        example_config={"temperature": 0.7, "max_tokens": 1000}
    )
}

@router.get("/templates", response_model=List[ProviderTemplate])
async def get_provider_templates():
    """获取所有提供商配置模板"""
    return list(PROVIDER_TEMPLATES.values())

@router.get("/templates/{provider}", response_model=ProviderTemplate)
async def get_provider_template(provider: str):
    """获取指定提供商的配置模板"""
    if provider not in PROVIDER_TEMPLATES:
        raise HTTPException(status_code=404, detail=f"Provider template '{provider}' not found")
    return PROVIDER_TEMPLATES[provider]

@router.get("/", response_model=List[LLMAPIConfigSchema])
async def get_all_configs(db: Session = Depends(get_db)):
    """获取所有API配置"""
    configs = db.query(LLMAPIConfig).all()
    return configs

@router.get("/enabled", response_model=List[LLMAPIConfigSchema])
async def get_enabled_configs(db: Session = Depends(get_db)):
    """获取所有启用的API配置"""
    configs = db.query(LLMAPIConfig).filter(LLMAPIConfig.is_enabled == True).all()
    return configs

@router.get("/status", response_model=ConfigStatusResponse)
async def get_config_status(db: Session = Depends(get_db)):
    """获取配置状态统计"""
    total_configs = db.query(LLMAPIConfig).count()
    enabled_configs = db.query(LLMAPIConfig).filter(LLMAPIConfig.is_enabled == True).count()
    working_configs = db.query(LLMAPIConfig).filter(
        LLMAPIConfig.is_enabled == True,
        LLMAPIConfig.last_test_status == "success"
    ).count()
    
    last_updated = db.query(LLMAPIConfig.updated_at).order_by(LLMAPIConfig.updated_at.desc()).first()
    
    return ConfigStatusResponse(
        total_configs=total_configs,
        enabled_configs=enabled_configs,
        working_configs=working_configs,
        last_updated=last_updated[0] if last_updated else None
    )

@router.get("/{config_id}", response_model=LLMAPIConfigSchema)
async def get_config(config_id: int, db: Session = Depends(get_db)):
    """获取指定API配置"""
    config = db.query(LLMAPIConfig).filter(LLMAPIConfig.id == config_id).first()
    if not config:
        raise HTTPException(status_code=404, detail="API配置不存在")
    return config

@router.post("/", response_model=LLMAPIConfigSchema)
@rate_limit(max_requests=10, window=60)  # 限制API配置创建频率
async def create_config(config: LLMAPIConfigCreate, db: Session = Depends(get_db)):
    """创建新的API配置"""
    try:
        # 输入验证
        if not InputValidator.validate_provider_name(config.provider):
            raise HTTPException(status_code=400, detail="无效的提供商名称")
        
        if not InputValidator.validate_api_key(config.api_key):
            raise HTTPException(status_code=400, detail="无效的API密钥格式")
        
        if config.api_url and not InputValidator.validate_url(config.api_url):
            raise HTTPException(status_code=400, detail="无效的API URL格式")
        
        # 检查恶意输入
        if InputValidator.detect_sql_injection(config.display_name or ""):
            raise HTTPException(status_code=400, detail="检测到恶意输入")
        
        if InputValidator.detect_xss(config.description or ""):
            raise HTTPException(status_code=400, detail="检测到恶意输入")
        
        # 检查提供商是否已存在
        existing = db.query(LLMAPIConfig).filter(LLMAPIConfig.provider == config.provider).first()
        if existing:
            raise HTTPException(status_code=400, detail=f"提供商 '{config.provider}' 的配置已存在")
        
        # 加密API密钥
        encrypted_api_key = security_manager.encrypt_api_key(config.api_key)
        
        # 创建配置对象
        config_dict = config.dict()
        config_dict["api_key"] = encrypted_api_key
        
        # 清理文本字段
        if config_dict.get("display_name"):
            config_dict["display_name"] = InputValidator.sanitize_text(config_dict["display_name"])
        if config_dict.get("description"):
            config_dict["description"] = InputValidator.sanitize_text(config_dict["description"])
        
        db_config = LLMAPIConfig(**config_dict)
        db.add(db_config)
        db.commit()
        db.refresh(db_config)
        
        logger.info(f"Created API config for provider: {config.provider}")
        return db_config
        
    except SecurityError as e:
        logger.warning(f"Security error in create_config: {e}")
        raise HTTPException(status_code=429, detail=str(e))
    except Exception as e:
        logger.error(f"Error creating API config: {e}")
        db.rollback()
        raise HTTPException(status_code=500, detail="创建配置失败")

@router.put("/{config_id}", response_model=LLMAPIConfigSchema)
@rate_limit(max_requests=20, window=60)  # 限制API配置更新频率
async def update_config(config_id: int, config: LLMAPIConfigUpdate, db: Session = Depends(get_db)):
    """更新API配置"""
    try:
        # 验证配置ID
        if config_id <= 0:
            raise HTTPException(status_code=400, detail="无效的配置ID")
        
        db_config = db.query(LLMAPIConfig).filter(LLMAPIConfig.id == config_id).first()
        if not db_config:
            raise HTTPException(status_code=404, detail="API配置不存在")
        
        update_data = config.dict(exclude_unset=True)
        
        # 输入验证
        if "api_key" in update_data and update_data["api_key"]:
            if not InputValidator.validate_api_key(update_data["api_key"]):
                raise HTTPException(status_code=400, detail="无效的API密钥格式")
            # 加密新的API密钥
            update_data["api_key"] = security_manager.encrypt_api_key(update_data["api_key"])
        
        if "api_url" in update_data and update_data["api_url"]:
            if not InputValidator.validate_url(update_data["api_url"]):
                raise HTTPException(status_code=400, detail="无效的API URL格式")
        
        # 检查恶意输入
        if "display_name" in update_data and update_data["display_name"]:
            if InputValidator.detect_sql_injection(update_data["display_name"]):
                raise HTTPException(status_code=400, detail="检测到恶意输入")
            update_data["display_name"] = InputValidator.sanitize_text(update_data["display_name"])
        
        if "description" in update_data and update_data["description"]:
            if InputValidator.detect_xss(update_data["description"]):
                raise HTTPException(status_code=400, detail="检测到恶意输入")
            update_data["description"] = InputValidator.sanitize_text(update_data["description"])
        
        # 更新字段
        for field, value in update_data.items():
            setattr(db_config, field, value)
        
        db_config.updated_at = datetime.utcnow()
        db.commit()
        db.refresh(db_config)
        
        logger.info(f"Updated API config for provider: {db_config.provider}")
        return db_config
        
    except SecurityError as e:
        logger.warning(f"Security error in update_config: {e}")
        raise HTTPException(status_code=429, detail=str(e))
    except Exception as e:
        logger.error(f"Error updating API config: {e}")
        db.rollback()
        raise HTTPException(status_code=500, detail="更新配置失败")

@router.delete("/{config_id}")
async def delete_config(config_id: int, db: Session = Depends(get_db)):
    """删除API配置"""
    db_config = db.query(LLMAPIConfig).filter(LLMAPIConfig.id == config_id).first()
    if not db_config:
        raise HTTPException(status_code=404, detail="API配置不存在")
    
    provider = db_config.provider
    db.delete(db_config)
    db.commit()
    
    logger.info(f"Deleted API config for provider: {provider}")
    return {"message": f"API配置 '{provider}' 已删除"}

@router.post("/test/{config_id}", response_model=APITestResponse)
async def test_config(config_id: int, test_request: APITestRequest = None, db: Session = Depends(get_db)):
    """测试API配置连接"""
    db_config = db.query(LLMAPIConfig).filter(LLMAPIConfig.id == config_id).first()
    if not db_config:
        raise HTTPException(status_code=404, detail="API配置不存在")
    
    if not db_config.is_enabled:
        raise HTTPException(status_code=400, detail="API配置已禁用")
    
    # 创建动态LLM服务实例进行测试
    llm_service = DynamicLLMService(db)
    
    try:
        # 更新测试状态
        db_config.last_test_at = datetime.utcnow()
        db_config.last_test_status = "pending"
        db.commit()
        
        # 执行测试
        test_prompt = test_request.test_prompt if test_request else "Hello, this is a test."
        result = await llm_service.generate_text(
            provider=db_config.provider,
            prompt=test_prompt,
            model=db_config.default_model or db_config.supported_models[0],
            temperature=0.7,
            max_tokens=100
        )
        
        if "error" in result:
            # 测试失败
            db_config.last_test_status = "error"
            db_config.last_test_error = result["error"]
            db.commit()
            
            return APITestResponse(
                status=TestStatus.ERROR,
                error=result["error"],
                execution_time=result.get("execution_time", 0)
            )
        else:
            # 测试成功
            db_config.last_test_status = "success"
            db_config.last_test_error = None
            db.commit()
            
            return APITestResponse(
                status=TestStatus.SUCCESS,
                response=result["text"][:200] + "..." if len(result["text"]) > 200 else result["text"],
                execution_time=result["execution_time"],
                model_used=result["model"]
            )
            
    except Exception as e:
        # 异常处理
        db_config.last_test_status = "error"
        db_config.last_test_error = str(e)
        db.commit()
        
        logger.error(f"Test failed for provider {db_config.provider}: {str(e)}")
        return APITestResponse(
            status=TestStatus.ERROR,
            error=str(e),
            execution_time=0
        )

@router.get("/providers/available", response_model=ProvidersResponse)
async def get_available_providers(db: Session = Depends(get_db)):
    """获取可用的提供商和模型信息"""
    configs = db.query(LLMAPIConfig).filter(LLMAPIConfig.is_enabled == True).all()
    
    providers = [config.provider for config in configs]
    models = {config.provider: config.supported_models for config in configs}
    
    return ProvidersResponse(
        providers=providers,
        configs=configs,
        models=models
    ) 