# 导入所有数据库模型
from .base import Base
from .prompt import Prompt, PromptVersion, OptimizationResult, PromptTemplate
from .api_config import LLMAPIConfig

# 导出所有模型，确保它们被SQLAlchemy识别
__all__ = ["Base", "Prompt", "PromptVersion", "OptimizationResult", "PromptTemplate", "LLMAPIConfig"] 