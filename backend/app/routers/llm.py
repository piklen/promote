from fastapi import APIRouter, HTTPException, Depends
from sqlalchemy.orm import Session
from typing import Dict, List

from ..database import get_db
from ..schemas.prompt import LLMRequest, LLMResponse, ProvidersResponse, ModelInfo
from ..services.llm_service import llm_service, DynamicLLMService

router = APIRouter(
    prefix="/api/v1/llm",
    tags=["llm"]
)


@router.get("/providers", response_model=ProvidersResponse)
async def get_providers(db: Session = Depends(get_db)):
    """获取可用的LLM服务提供商和模型（从数据库动态加载）"""
    try:
        # 使用动态服务从数据库加载配置
        dynamic_service = DynamicLLMService(db)
        providers = dynamic_service.get_available_providers()
        models = dynamic_service.get_all_models()
        
        return ProvidersResponse(
            providers=providers,
            models=models
        )
    except Exception as e:
        raise HTTPException(status_code=500, detail=f"获取提供商信息失败: {str(e)}")


@router.get("/providers/{provider}/models", response_model=ModelInfo)
async def get_provider_models(provider: str):
    """获取指定提供商的可用模型"""
    try:
        models = llm_service.get_available_models(provider)
        if not models:
            raise HTTPException(
                status_code=404, 
                detail=f"提供商 '{provider}' 未配置或不可用"
            )
        
        return ModelInfo(
            provider=provider,
            models=models
        )
    except HTTPException:
        raise
    except Exception as e:
        raise HTTPException(status_code=500, detail=f"获取模型信息失败: {str(e)}")


@router.post("/generate", response_model=LLMResponse)
async def generate_text(
    request: LLMRequest,
    db: Session = Depends(get_db)
):
    """使用指定的LLM生成文本（使用数据库配置）"""
    try:
        # 使用动态服务从数据库加载配置
        dynamic_service = DynamicLLMService(db)
        
        # 调用LLM服务生成文本
        result = await dynamic_service.generate_text(
            provider=request.provider.value,
            prompt=request.prompt,
            model=request.model,
            temperature=request.temperature,
            max_tokens=request.max_tokens,
            **request.parameters
        )
        
        # 构造响应
        response = LLMResponse(
            text=result.get("text"),
            model=result["model"],
            provider=result["provider"],
            execution_time=result["execution_time"],
            usage=result.get("usage", {}),
            error=result.get("error"),
            finish_reason=result.get("finish_reason") or result.get("stop_reason")
        )
        
        return response
        
    except Exception as e:
        raise HTTPException(
            status_code=500, 
            detail=f"文本生成失败: {str(e)}"
        )


@router.post("/test/{provider}")
async def test_provider(provider: str, db: Session = Depends(get_db)):
    """测试指定提供商的连接（使用数据库配置）"""
    try:
        # 使用动态服务从数据库加载配置
        dynamic_service = DynamicLLMService(db)
        
        # 使用简单提示词测试连接
        test_prompt = "请回答：1+1等于几？"
        
        models = dynamic_service.get_available_models(provider)
        if not models:
            raise HTTPException(
                status_code=404,
                detail=f"提供商 '{provider}' 未配置或不可用"
            )
        
        # 使用第一个可用模型进行测试
        default_model = models[0]
        
        result = await dynamic_service.generate_text(
            provider=provider,
            prompt=test_prompt,
            model=default_model,
            temperature=0.1,
            max_tokens=50
        )
        
        if "error" in result:
            return {
                "status": "error",
                "provider": provider,
                "model": default_model,
                "error": result["error"],
                "execution_time": result["execution_time"]
            }
        else:
            return {
                "status": "success",
                "provider": provider,
                "model": default_model,
                "response": result["text"][:100] + "..." if len(result["text"]) > 100 else result["text"],
                "execution_time": result["execution_time"]
            }
            
    except HTTPException:
        raise
    except Exception as e:
        raise HTTPException(
            status_code=500,
            detail=f"测试提供商失败: {str(e)}"
        ) 