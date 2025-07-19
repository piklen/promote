# 从database.py导入Base，保持向后兼容性
from ..database import Base

# 保持对原有代码的兼容性
__all__ = ['Base'] 