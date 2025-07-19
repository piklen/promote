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
        """获取或创建加密密钥"""
        # 尝试从环境变量获取主密钥
        master_key = os.getenv("ENCRYPTION_MASTER_KEY")
        
        if not master_key:
            # 如果没有设置，生成一个基于应用密钥的固定密钥
            # 在生产环境中应该使用更安全的方式
            app_secret = os.getenv("SECRET_KEY", "default-secret-key-change-in-production")
            logger.warning("未设置ENCRYPTION_MASTER_KEY，使用默认密钥（生产环境请设置）")
        else:
            app_secret = master_key
        
        # 使用PBKDF2从主密钥派生加密密钥
        kdf = PBKDF2HMAC(
            algorithm=hashes.SHA256(),
            length=32,
            salt=b'prompt_optimizer_salt',  # 在生产环境中应该使用随机salt
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
            logger.error(f"加密API密钥失败: {e}")
            raise SecurityError("加密失败")
    
    def decrypt_api_key(self, encrypted_key: str) -> str:
        """解密API密钥"""
        try:
            encrypted_bytes = base64.urlsafe_b64decode(encrypted_key.encode())
            decrypted = self._fernet.decrypt(encrypted_bytes)
            return decrypted.decode()
        except Exception as e:
            logger.error(f"解密API密钥失败: {e}")
            raise SecurityError("解密失败")
    
    def hash_password(self, password: str) -> str:
        """密码哈希（如果需要用户认证）"""
        salt = secrets.token_hex(32)
        pwdhash = hashlib.pbkdf2_hmac('sha256', 
                                     password.encode('utf-8'), 
                                     salt.encode('utf-8'), 
                                     100000)
        return salt + pwdhash.hex()
    
    def verify_password(self, stored_password: str, provided_password: str) -> bool:
        """验证密码"""
        salt = stored_password[:64]
        stored_hash = stored_password[64:]
        pwdhash = hashlib.pbkdf2_hmac('sha256',
                                     provided_password.encode('utf-8'),
                                     salt.encode('utf-8'),
                                     100000)
        return pwdhash.hex() == stored_hash

class SecurityError(Exception):
    """安全相关异常"""
    pass

class InputValidator:
    """输入验证器"""
    
    # 常见的恶意模式
    SQL_INJECTION_PATTERNS = [
        r"('|(\\')|(;)|(\\;)|(\\x27)|(\\x2D\\x2D))",
        r"(\\x23)|(#)|(\\x2D\\x2D)|(\\x2F\\x2A)|(\\x2A\\x2F)",
        r"(union|select|insert|update|delete|drop|create|alter|exec|execute)",
    ]
    
    XSS_PATTERNS = [
        r"<script.*?>.*?</script>",
        r"javascript:",
        r"on\w+\s*=",
        r"<iframe.*?>.*?</iframe>",
    ]
    
    @classmethod
    def validate_api_key(cls, api_key: str) -> bool:
        """验证API密钥格式"""
        if not api_key or len(api_key.strip()) == 0:
            return False
        
        # 检查长度（大多数API密钥在10-100字符之间）
        if not (10 <= len(api_key) <= 200):
            return False
        
        # 检查是否包含危险字符
        if any(char in api_key for char in ['<', '>', '"', "'", '&']):
            return False
        
        return True
    
    @classmethod
    def validate_url(cls, url: str) -> bool:
        """验证URL格式"""
        if not url:
            return True  # URL是可选的
        
        # 简单的URL验证
        url_pattern = re.compile(
            r'^https?://'  # 只允许http和https
            r'(?:(?:[A-Z0-9](?:[A-Z0-9-]{0,61}[A-Z0-9])?\.)+[A-Z]{2,6}\.?|'  # 域名
            r'localhost|'  # localhost
            r'\d{1,3}\.\d{1,3}\.\d{1,3}\.\d{1,3})'  # IP地址
            r'(?::\d+)?'  # 可选端口
            r'(?:/?|[/?]\S+)$', re.IGNORECASE)
        
        return bool(url_pattern.match(url))
    
    @classmethod
    def validate_provider_name(cls, provider: str) -> bool:
        """验证提供商名称"""
        if not provider:
            return False
        
        # 只允许字母、数字、下划线、连字符
        pattern = re.compile(r'^[a-zA-Z0-9_-]+$')
        return bool(pattern.match(provider)) and 1 <= len(provider) <= 50
    
    @classmethod
    def sanitize_text(cls, text: str) -> str:
        """清理文本输入"""
        if not text:
            return ""
        
        # 移除潜在的危险字符
        text = re.sub(r'[<>&"\']', '', text)
        
        # 限制长度
        return text[:1000]
    
    @classmethod
    def detect_sql_injection(cls, text: str) -> bool:
        """检测SQL注入尝试"""
        text_lower = text.lower()
        
        for pattern in cls.SQL_INJECTION_PATTERNS:
            if re.search(pattern, text_lower, re.IGNORECASE):
                return True
        
        return False
    
    @classmethod
    def detect_xss(cls, text: str) -> bool:
        """检测XSS尝试"""
        text_lower = text.lower()
        
        for pattern in cls.XSS_PATTERNS:
            if re.search(pattern, text_lower, re.IGNORECASE):
                return True
        
        return False

def rate_limit(max_calls: int = 60, window: int = 60):
    """简单的速率限制装饰器"""
    calls = {}
    
    def decorator(func):
        @wraps(func)
        def wrapper(*args, **kwargs):
            now = time.time()
            # 简单的IP-based限制（在生产环境中应该使用更复杂的方式）
            client_id = "global"  # 可以根据需要改为IP或用户ID
            
            if client_id not in calls:
                calls[client_id] = []
            
            # 清理过期的调用记录
            calls[client_id] = [call_time for call_time in calls[client_id] 
                               if now - call_time < window]
            
            # 检查是否超过限制
            if len(calls[client_id]) >= max_calls:
                raise SecurityError("速率限制：请求过于频繁")
            
            calls[client_id].append(now)
            return func(*args, **kwargs)
        
        return wrapper
    return decorator

def get_security_headers() -> Dict[str, str]:
    """获取安全响应头"""
    return {
        "X-Content-Type-Options": "nosniff",
        "X-Frame-Options": "DENY",
        "X-XSS-Protection": "1; mode=block",
        "Strict-Transport-Security": "max-age=31536000; includeSubDomains",
        "Content-Security-Policy": "default-src 'self'; script-src 'self' 'unsafe-inline'; style-src 'self' 'unsafe-inline'",
        "Referrer-Policy": "strict-origin-when-cross-origin"
    }

# 全局安全管理器实例
security_manager = SecurityManager() 