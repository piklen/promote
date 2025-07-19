import os
import asyncio
from abc import ABC, abstractmethod
from typing import Dict, Any, Optional, List
from enum import Enum
import time

import openai
import anthropic
import google.generativeai as genai
from tenacity import retry, stop_after_attempt, wait_exponential
import httpx

class LLMProvider(str, Enum):
    """支持的LLM服务提供商"""
    OPENAI = "openai"
    ANTHROPIC = "anthropic"
    GOOGLE = "google"
    GOOGLE_CUSTOM = "google_custom"  # 通过自定义地址调用的Google模型
    CUSTOM = "custom"


class BaseLLMClient(ABC):
    """LLM客户端抽象基类"""
    
    def __init__(self, api_key: str, **kwargs):
        self.api_key = api_key
        self.config = kwargs
    
    @abstractmethod
    async def generate_text(
        self, 
        prompt: str, 
        model: str,
        temperature: float = 0.7,
        max_tokens: int = 1000,
        **kwargs
    ) -> Dict[str, Any]:
        """生成文本"""
        pass
    
    @abstractmethod
    def get_available_models(self) -> List[str]:
        """获取可用模型列表"""
        pass


class OpenAIClient(BaseLLMClient):
    """OpenAI API客户端"""
    
    def __init__(self, api_key: str, **kwargs):
        super().__init__(api_key, **kwargs)
        self.client = openai.AsyncOpenAI(
            api_key=api_key,
            base_url=kwargs.get('base_url'),  # 支持自定义API地址
            timeout=kwargs.get('timeout', 60)
        )
    
    @retry(stop=stop_after_attempt(3), wait=wait_exponential(multiplier=1, min=4, max=10))
    async def generate_text(
        self, 
        prompt: str, 
        model: str = "gpt-3.5-turbo",
        temperature: float = 0.7,
        max_tokens: int = 1000,
        **kwargs
    ) -> Dict[str, Any]:
        """使用OpenAI API生成文本"""
        start_time = time.time()
        
        try:
            response = await self.client.chat.completions.create(
                model=model,
                messages=[{"role": "user", "content": prompt}],
                temperature=temperature,
                max_tokens=max_tokens,
                **kwargs
            )
            
            execution_time = time.time() - start_time
            
            return {
                "text": response.choices[0].message.content,
                "model": model,
                "provider": "openai",
                "execution_time": execution_time,
                "usage": {
                    "prompt_tokens": response.usage.prompt_tokens,
                    "completion_tokens": response.usage.completion_tokens,
                    "total_tokens": response.usage.total_tokens
                },
                "finish_reason": response.choices[0].finish_reason
            }
        except Exception as e:
            execution_time = time.time() - start_time
            return {
                "error": str(e),
                "model": model,
                "provider": "openai",
                "execution_time": execution_time
            }
    
    def get_available_models(self) -> List[str]:
        """获取OpenAI可用模型"""
        return [
            "gpt-4",
            "gpt-4-turbo-preview",
            "gpt-3.5-turbo",
            "gpt-3.5-turbo-16k"
        ]


class AnthropicClient(BaseLLMClient):
    """Anthropic Claude API客户端"""
    
    def __init__(self, api_key: str, **kwargs):
        super().__init__(api_key, **kwargs)
        self.client = anthropic.AsyncAnthropic(
            api_key=api_key,
            timeout=kwargs.get('timeout', 60)
        )
    
    @retry(stop=stop_after_attempt(3), wait=wait_exponential(multiplier=1, min=4, max=10))
    async def generate_text(
        self, 
        prompt: str, 
        model: str = "claude-3-sonnet-20240229",
        temperature: float = 0.7,
        max_tokens: int = 1000,
        **kwargs
    ) -> Dict[str, Any]:
        """使用Anthropic API生成文本"""
        start_time = time.time()
        
        try:
            response = await self.client.messages.create(
                model=model,
                max_tokens=max_tokens,
                temperature=temperature,
                messages=[{"role": "user", "content": prompt}],
                **kwargs
            )
            
            execution_time = time.time() - start_time
            
            return {
                "text": response.content[0].text,
                "model": model,
                "provider": "anthropic",
                "execution_time": execution_time,
                "usage": {
                    "input_tokens": response.usage.input_tokens,
                    "output_tokens": response.usage.output_tokens
                },
                "stop_reason": response.stop_reason
            }
        except Exception as e:
            execution_time = time.time() - start_time
            return {
                "error": str(e),
                "model": model,
                "provider": "anthropic",
                "execution_time": execution_time
            }
    
    def get_available_models(self) -> List[str]:
        """获取Anthropic可用模型"""
        return [
            "claude-3-opus-20240229",
            "claude-3-sonnet-20240229",
            "claude-3-haiku-20240307",
            "claude-2.1",
            "claude-2.0",
            "claude-instant-1.2"
        ]


class GoogleClient(BaseLLMClient):
    """Google Gemini API客户端"""
    
    def __init__(self, api_key: str, **kwargs):
        super().__init__(api_key, **kwargs)
        genai.configure(api_key=api_key)
    
    @retry(stop=stop_after_attempt(3), wait=wait_exponential(multiplier=1, min=4, max=10))
    async def generate_text(
        self, 
        prompt: str, 
        model: str = "gemini-pro",
        temperature: float = 0.7,
        max_tokens: int = 1000,
        **kwargs
    ) -> Dict[str, Any]:
        """使用Google Gemini API生成文本"""
        start_time = time.time()
        
        try:
            model_instance = genai.GenerativeModel(model)
            
            generation_config = genai.types.GenerationConfig(
                temperature=temperature,
                max_output_tokens=max_tokens,
                **kwargs
            )
            
            response = await asyncio.to_thread(
                model_instance.generate_content,
                prompt,
                generation_config=generation_config
            )
            
            execution_time = time.time() - start_time
            
            return {
                "text": response.text,
                "model": model,
                "provider": "google",
                "execution_time": execution_time,
                "usage": {
                    "prompt_token_count": response.usage_metadata.prompt_token_count if hasattr(response, 'usage_metadata') else None,
                    "candidates_token_count": response.usage_metadata.candidates_token_count if hasattr(response, 'usage_metadata') else None,
                    "total_token_count": response.usage_metadata.total_token_count if hasattr(response, 'usage_metadata') else None
                },
                "finish_reason": response.candidates[0].finish_reason if response.candidates else None
            }
        except Exception as e:
            execution_time = time.time() - start_time
            return {
                "error": str(e),
                "model": model,
                "provider": "google",
                "execution_time": execution_time
            }
    
    def get_available_models(self) -> List[str]:
        """获取Google可用模型"""
        return [
            "gemini-pro",
            "gemini-pro-vision",
            "gemini-1.5-pro-latest"
        ]


class GoogleCustomClient(BaseLLMClient):
    """通过自定义地址调用Google模型的客户端"""
    
    def __init__(self, api_key: str, **kwargs):
        super().__init__(api_key, **kwargs)
        self.base_url = kwargs.get('base_url', 'http://localhost:8080')
        self.timeout = kwargs.get('timeout', 60)
        # Google特有的配置
        self.model_prefix = kwargs.get('model_prefix', 'gemini')
    
    @retry(stop=stop_after_attempt(3), wait=wait_exponential(multiplier=1, min=4, max=10))
    async def generate_text(
        self, 
        prompt: str, 
        model: str = "gemini-pro",
        temperature: float = 0.7,
        max_tokens: int = 1000,
        **kwargs
    ) -> Dict[str, Any]:
        """使用自定义地址的Google API生成文本"""
        start_time = time.time()
        
        try:
            # 支持多种API格式
            api_format = kwargs.get('api_format', 'openai')  # openai, google, gemini
            
            if api_format == 'google' or api_format == 'gemini':
                # 使用Google Gemini原生API格式
                payload = {
                    "contents": [
                        {
                            "parts": [{"text": prompt}]
                        }
                    ],
                    "generationConfig": {
                        "temperature": temperature,
                        "maxOutputTokens": max_tokens,
                        **{k: v for k, v in kwargs.items() if k not in ['api_format']}
                    }
                }
                endpoint = f"/v1/models/{model}:generateContent"
            else:
                # 使用OpenAI兼容格式（默认）
                payload = {
                    "model": model,
                    "messages": [{"role": "user", "content": prompt}],
                    "temperature": temperature,
                    "max_tokens": max_tokens,
                    **{k: v for k, v in kwargs.items() if k not in ['api_format']}
                }
                endpoint = "/v1/chat/completions"
            
            async with httpx.AsyncClient(timeout=self.timeout) as client:
                response = await client.post(
                    f"{self.base_url}{endpoint}",
                    headers={
                        "Authorization": f"Bearer {self.api_key}",
                        "Content-Type": "application/json",
                        "User-Agent": "LLM-Optimizer/1.0"
                    },
                    json=payload
                )
                response.raise_for_status()
                data = response.json()
                
                execution_time = time.time() - start_time
                
                # 解析不同格式的响应
                if api_format == 'google' or api_format == 'gemini':
                    # Google原生格式响应
                    text = data.get("candidates", [{}])[0].get("content", {}).get("parts", [{}])[0].get("text", "")
                    usage = data.get("usageMetadata", {})
                    finish_reason = data.get("candidates", [{}])[0].get("finishReason", "")
                    
                    return {
                        "text": text,
                        "model": model,
                        "provider": "google_custom",
                        "execution_time": execution_time,
                        "usage": {
                            "prompt_token_count": usage.get("promptTokenCount"),
                            "candidates_token_count": usage.get("candidatesTokenCount"),
                            "total_token_count": usage.get("totalTokenCount")
                        },
                        "finish_reason": finish_reason
                    }
                else:
                    # OpenAI兼容格式响应
                    return {
                        "text": data["choices"][0]["message"]["content"],
                        "model": model,
                        "provider": "google_custom",
                        "execution_time": execution_time,
                        "usage": data.get("usage", {}),
                        "finish_reason": data["choices"][0].get("finish_reason")
                    }
                    
        except Exception as e:
            execution_time = time.time() - start_time
            return {
                "error": str(e),
                "model": model,
                "provider": "google_custom",
                "execution_time": execution_time
            }
    
    def get_available_models(self) -> List[str]:
        """获取Google自定义API可用模型"""
        return [
            "gemini-pro",
            "gemini-pro-vision",
            "gemini-1.5-pro-latest",
            "gemini-1.5-flash",
            "gemini-1.0-pro"
        ]


class CustomClient(BaseLLMClient):
    """自定义API客户端（兼容OpenAI格式）"""
    
    def __init__(self, api_key: str, **kwargs):
        super().__init__(api_key, **kwargs)
        self.base_url = kwargs.get('base_url', 'http://localhost:8080')
        self.timeout = kwargs.get('timeout', 60)
    
    @retry(stop=stop_after_attempt(3), wait=wait_exponential(multiplier=1, min=4, max=10))
    async def generate_text(
        self, 
        prompt: str, 
        model: str = "custom-model",
        temperature: float = 0.7,
        max_tokens: int = 1000,
        **kwargs
    ) -> Dict[str, Any]:
        """使用自定义API生成文本"""
        start_time = time.time()
        
        try:
            async with httpx.AsyncClient(timeout=self.timeout) as client:
                response = await client.post(
                    f"{self.base_url}/v1/chat/completions",
                    headers={
                        "Authorization": f"Bearer {self.api_key}",
                        "Content-Type": "application/json"
                    },
                    json={
                        "model": model,
                        "messages": [{"role": "user", "content": prompt}],
                        "temperature": temperature,
                        "max_tokens": max_tokens,
                        **kwargs
                    }
                )
                response.raise_for_status()
                data = response.json()
                
                execution_time = time.time() - start_time
                
                return {
                    "text": data["choices"][0]["message"]["content"],
                    "model": model,
                    "provider": "custom",
                    "execution_time": execution_time,
                    "usage": data.get("usage", {}),
                    "finish_reason": data["choices"][0].get("finish_reason")
                }
        except Exception as e:
            execution_time = time.time() - start_time
            return {
                "error": str(e),
                "model": model,
                "provider": "custom",
                "execution_time": execution_time
            }
    
    def get_available_models(self) -> List[str]:
        """获取自定义API可用模型"""
        return ["custom-model"]  # 可通过配置文件扩展


class LLMService:
    """LLM服务管理器"""
    
    def __init__(self):
        self.clients: Dict[str, BaseLLMClient] = {}
        self._load_clients()
    
    def _load_clients(self):
        """加载配置的API客户端"""
        # OpenAI
        openai_key = os.getenv('OPENAI_API_KEY')
        if openai_key:
            self.clients['openai'] = OpenAIClient(
                api_key=openai_key,
                base_url=os.getenv('OPENAI_BASE_URL'),
                timeout=int(os.getenv('OPENAI_TIMEOUT', '60'))
            )
        
        # Anthropic
        anthropic_key = os.getenv('ANTHROPIC_API_KEY')
        if anthropic_key:
            self.clients['anthropic'] = AnthropicClient(
                api_key=anthropic_key,
                timeout=int(os.getenv('ANTHROPIC_TIMEOUT', '60'))
            )
        
        # Google (官方)
        google_key = os.getenv('GOOGLE_API_KEY')
        if google_key:
            self.clients['google'] = GoogleClient(
                api_key=google_key,
                timeout=int(os.getenv('GOOGLE_TIMEOUT', '60'))
            )
        
        # Google (自定义地址)
        google_custom_key = os.getenv('GOOGLE_CUSTOM_API_KEY')
        google_custom_url = os.getenv('GOOGLE_CUSTOM_API_URL')
        if google_custom_key and google_custom_url:
            self.clients['google_custom'] = GoogleCustomClient(
                api_key=google_custom_key,
                base_url=google_custom_url,
                timeout=int(os.getenv('GOOGLE_CUSTOM_TIMEOUT', '60')),
                api_format=os.getenv('GOOGLE_CUSTOM_API_FORMAT', 'openai'),  # openai, google, gemini
                model_prefix=os.getenv('GOOGLE_CUSTOM_MODEL_PREFIX', 'gemini')
            )
        
        # Custom API (通用自定义)
        custom_key = os.getenv('CUSTOM_API_KEY')
        custom_url = os.getenv('CUSTOM_API_URL')
        if custom_key and custom_url:
            self.clients['custom'] = CustomClient(
                api_key=custom_key,
                base_url=custom_url,
                timeout=int(os.getenv('CUSTOM_TIMEOUT', '60'))
            )
    
    async def generate_text(
        self,
        provider: str,
        prompt: str,
        model: str,
        temperature: float = 0.7,
        max_tokens: int = 1000,
        **kwargs
    ) -> Dict[str, Any]:
        """生成文本"""
        if provider not in self.clients:
            return {
                "error": f"Provider '{provider}' not configured or not available",
                "provider": provider,
                "model": model,
                "execution_time": 0
            }
        
        client = self.clients[provider]
        return await client.generate_text(
            prompt=prompt,
            model=model,
            temperature=temperature,
            max_tokens=max_tokens,
            **kwargs
        )
    
    def get_available_providers(self) -> List[str]:
        """获取可用的提供商"""
        return list(self.clients.keys())
    
    def get_available_models(self, provider: str) -> List[str]:
        """获取指定提供商的可用模型"""
        if provider not in self.clients:
            return []
        return self.clients[provider].get_available_models()
    
    def get_all_models(self) -> Dict[str, List[str]]:
        """获取所有提供商的模型"""
        return {
            provider: client.get_available_models()
            for provider, client in self.clients.items()
        }


class DynamicLLMService:
    """动态LLM服务管理器 - 从数据库加载配置"""
    
    def __init__(self, db_session):
        self.db = db_session
        self.clients: Dict[str, BaseLLMClient] = {}
        self._load_clients_from_db()
        # 导入安全管理器
        from ..core.security import security_manager
        self.security_manager = security_manager
    
    def _load_clients_from_db(self):
        """从数据库加载配置的API客户端"""
        from ..models.api_config import LLMAPIConfig
        
        self.clients.clear()
        
        # 查询所有启用的配置
        configs = self.db.query(LLMAPIConfig).filter(LLMAPIConfig.is_enabled == True).all()
        
        for config in configs:
            try:
                client = self._create_client_from_config(config)
                if client:
                    self.clients[config.provider] = client
            except Exception as e:
                # 记录错误但继续加载其他客户端
                print(f"Failed to load client for {config.provider}: {str(e)}")
    
    def _create_client_from_config(self, config) -> Optional[BaseLLMClient]:
        """根据配置创建客户端实例"""
        try:
            # 解密API密钥
            try:
                decrypted_api_key = self.security_manager.decrypt_api_key(config.api_key)
            except Exception as e:
                print(f"Failed to decrypt API key for {config.provider}: {str(e)}")
                return None
            
            if config.provider == "openai":
                return OpenAIClient(
                    api_key=decrypted_api_key,
                    base_url=config.api_url,
                    timeout=config.timeout
                )
            elif config.provider == "anthropic":
                return AnthropicClient(
                    api_key=decrypted_api_key,
                    timeout=config.timeout
                )
            elif config.provider == "google":
                return GoogleClient(
                    api_key=decrypted_api_key,
                    timeout=config.timeout
                )
            elif config.provider == "google_custom":
                extra_config = config.extra_config or {}
                return GoogleCustomClient(
                    api_key=decrypted_api_key,
                    base_url=config.api_url,
                    timeout=config.timeout,
                    api_format=extra_config.get('api_format', 'openai'),
                    model_prefix=extra_config.get('model_prefix', 'gemini')
                )
            elif config.provider == "custom":
                return CustomClient(
                    api_key=decrypted_api_key,
                    base_url=config.api_url,
                    timeout=config.timeout
                )
        except Exception as e:
            print(f"Error creating client for {config.provider}: {str(e)}")
            return None
    
    def reload_clients(self):
        """重新加载客户端配置"""
        self._load_clients_from_db()
    
    async def generate_text(
        self,
        provider: str,
        prompt: str,
        model: str,
        temperature: float = 0.7,
        max_tokens: int = 1000,
        **kwargs
    ) -> Dict[str, Any]:
        """生成文本"""
        if provider not in self.clients:
            # 尝试重新加载配置
            self.reload_clients()
            
            if provider not in self.clients:
                return {
                    "error": f"Provider '{provider}' not configured or not available",
                    "provider": provider,
                    "model": model,
                    "execution_time": 0
                }
        
        client = self.clients[provider]
        return await client.generate_text(
            prompt=prompt,
            model=model,
            temperature=temperature,
            max_tokens=max_tokens,
            **kwargs
        )
    
    def get_available_providers(self) -> List[str]:
        """获取可用的提供商"""
        return list(self.clients.keys())
    
    def get_available_models(self, provider: str) -> List[str]:
        """获取指定提供商的可用模型"""
        if provider not in self.clients:
            return []
        return self.clients[provider].get_available_models()
    
    def get_all_models(self) -> Dict[str, List[str]]:
        """获取所有提供商的模型"""
        return {
            provider: client.get_available_models()
            for provider, client in self.clients.items()
        }


# 向后兼容的全局LLM服务实例（基于环境变量）
llm_service = LLMService() 