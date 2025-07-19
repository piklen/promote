import os
import hashlib
import secrets
from typing import Optional, Dict, Any
from cryptography.fernet import Fernet
from cryptography.hazmat.primitives import hashes
from cryptography.hazmat.primitives.kdf.pbkdf2 import PBKDF2HMAC
import base64
import logging
import re
from functools import wraps
import time

logger = logging.getLogger(__name__)

class SecurityManager:
    """安全管理器 - 处理加密、解密、输入验证等安全相关功能"""
    
    def __init__(self):
        self._key = self._get_or_create_key()
        self._fernet = Fernet(self._key)
    
    def _get_or_create_key(self) -> bytes:
        """获取或创建加密密钥 - 优先从环境变量，其次使用默认密钥"""
        # 尝试从环境变量获取主密钥
        master_key = os.getenv("ENCRYPTION_MASTER_KEY")
        
        if not master_key:
            # 使用应用内置的默认密钥（对于零配置部署）
            app_secret = "prompt-optimizer-default-encryption-key-2024"
            logger.info("使用默认加密密钥（适用于零配置部署）")
        else:
            app_secret = master_key
            logger.info("使用环境变量提供的加密密钥")
        
        # 使用PBKDF2从主密钥派生加密密钥
        kdf = PBKDF2HMAC(
            algorithm=hashes.SHA256(),
            length=32,
            salt=b'prompt_optimizer_salt_2024',  # 固定salt，确保一致性
            iterations=100000,
        )
        key = base64.urlsafe_b64encode(kdf.derive(app_secret.encode()))
        return key
    
    def encrypt_api_key(self, api_key: str) -> str:
        """加密API密钥"""
        try:
            encrypted = self._fernet.encrypt(api_key.encode())
            return base64.urlsafe_b64encode(encrypted).decode()
        except Exception as e:
            logger.error(f"API密钥加密失败: {e}")
            # 在加密失败时，为了不阻止应用运行，返回原始值
            # 在生产环境中，这应该根据安全策略调整
            return api_key
    
    def decrypt_api_key(self, encrypted_api_key: str) -> str:
        """解密API密钥"""
        try:
            encrypted_bytes = base64.urlsafe_b64decode(encrypted_api_key.encode())
            decrypted = self._fernet.decrypt(encrypted_bytes)
            return decrypted.decode()
        except Exception as e:
            logger.error(f"API密钥解密失败: {e}")
            # 如果解密失败，可能是未加密的数据，直接返回
            return encrypted_api_key
    
    def generate_secure_token(self, length: int = 32) -> str:
        """生成安全的随机令牌"""
        return secrets.token_urlsafe(length)
    
    def hash_password(self, password: str) -> str:
        """哈希密码"""
        salt = secrets.token_bytes(32)
        pwdhash = hashlib.pbkdf2_hmac('sha256', password.encode('utf-8'), salt, 100000)
        return base64.b64encode(salt + pwdhash).decode('ascii')
    
    def verify_password(self, stored_password: str, provided_password: str) -> bool:
        """验证密码"""
        try:
            decoded = base64.b64decode(stored_password.encode('ascii'))
            salt = decoded[:32]
            stored_hash = decoded[32:]
            pwdhash = hashlib.pbkdf2_hmac('sha256', provided_password.encode('utf-8'), salt, 100000)
            return pwdhash == stored_hash
        except Exception:
            return False


class InputValidator:
    """输入验证器"""
    
    @staticmethod
    def validate_url(url: str) -> bool:
        """验证URL格式"""
        if not url:
            return False
        
        # 基本URL模式验证
        url_pattern = re.compile(
            r'^https?://'  # http:// 或 https://
            r'(?:(?:[A-Z0-9](?:[A-Z0-9-]{0,61}[A-Z0-9])?\.)+[A-Z]{2,6}\.?|'  # 域名
            r'localhost|'  # localhost
            r'\d{1,3}\.\d{1,3}\.\d{1,3}\.\d{1,3})'  # IP地址
            r'(?::\d+)?'  # 端口号
            r'(?:/?|[/?]\S+)$', re.IGNORECASE)
        
        return bool(url_pattern.match(url))
    
    @staticmethod
    def validate_api_key(api_key: str, provider: str) -> bool:
        """验证API密钥格式"""
        if not api_key or not isinstance(api_key, str):
            return False
        
        # 不同提供商的API密钥格式验证
        patterns = {
            'openai': r'^sk-[A-Za-z0-9]{32,}$',
            'anthropic': r'^sk-ant-api03-[A-Za-z0-9_-]{95}$',
            'google': r'^[A-Za-z0-9_-]{39}$',
        }
        
        pattern = patterns.get(provider.lower())
        if pattern:
            return bool(re.match(pattern, api_key))
        
        # 对于未知提供商，进行基本验证
        return len(api_key) >= 10
    
    @staticmethod
    def sanitize_input(input_str: str, max_length: int = 1000) -> str:
        """清理输入字符串"""
        if not input_str:
            return ""
        
        # 移除危险字符
        sanitized = re.sub(r'[<>"\']', '', str(input_str))
        
        # 限制长度
        return sanitized[:max_length]


# 安全相关的异常类
class SecurityError(Exception):
    """安全相关错误"""
    pass


class RateLimitError(SecurityError):
    """请求频率限制错误"""
    pass


# 全局安全管理器实例
security_manager = SecurityManager()


def get_security_headers() -> Dict[str, str]:
    """获取安全响应头"""
    return {
        "X-Content-Type-Options": "nosniff",
        "X-Frame-Options": "DENY",
        "X-XSS-Protection": "1; mode=block",
        "Strict-Transport-Security": "max-age=31536000; includeSubDomains",
        "Content-Security-Policy": "default-src 'self'; script-src 'self' 'unsafe-inline' 'unsafe-eval'; style-src 'self' 'unsafe-inline'; img-src 'self' data: https:; font-src 'self' data:; connect-src 'self' https:",
        "Referrer-Policy": "strict-origin-when-cross-origin",
        "Permissions-Policy": "geolocation=(), microphone=(), camera=()"
    }


# 简单的内存速率限制器
class SimpleRateLimiter:
    """简单的内存速率限制器"""
    
    def __init__(self):
        self.requests = {}
        self.cleanup_interval = 60  # 每60秒清理一次过期记录
        self.last_cleanup = time.time()
    
    def is_allowed(self, key: str, max_requests: int = 60, window: int = 60) -> bool:
        """检查是否允许请求"""
        now = time.time()
        
        # 定期清理过期记录
        if now - self.last_cleanup > self.cleanup_interval:
            self._cleanup_expired(now, window)
            self.last_cleanup = now
        
        # 获取当前窗口内的请求
        if key not in self.requests:
            self.requests[key] = []
        
        # 过滤窗口内的请求
        self.requests[key] = [req_time for req_time in self.requests[key] if now - req_time < window]
        
        # 检查是否超过限制
        if len(self.requests[key]) >= max_requests:
            return False
        
        # 记录当前请求
        self.requests[key].append(now)
        return True
    
    def _cleanup_expired(self, now: float, window: int):
        """清理过期的请求记录"""
        keys_to_remove = []
        for key, requests in self.requests.items():
            # 过滤过期请求
            valid_requests = [req_time for req_time in requests if now - req_time < window]
            if not valid_requests:
                keys_to_remove.append(key)
            else:
                self.requests[key] = valid_requests
        
        # 移除空的记录
        for key in keys_to_remove:
            del self.requests[key]


# 全局速率限制器
rate_limiter = SimpleRateLimiter()


def rate_limit(max_requests: int = 60, window: int = 60):
    """速率限制装饰器"""
    def decorator(func):
        @wraps(func)
        async def wrapper(*args, **kwargs):
            # 从请求中获取客户端IP
            request = None
            for arg in args:
                if hasattr(arg, 'client'):
                    request = arg
                    break
            
            if request and hasattr(request, 'client') and request.client:
                client_ip = request.client.host
                key = f"rate_limit:{client_ip}:{func.__name__}"
                
                if not rate_limiter.is_allowed(key, max_requests, window):
                    raise RateLimitError(f"请求过于频繁，请稍后再试")
            
            return await func(*args, **kwargs)
        return wrapper
    return decorator 