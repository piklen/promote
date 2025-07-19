import os
from sqlalchemy import create_engine
from sqlalchemy.orm import sessionmaker, declarative_base
from dotenv import load_dotenv

# 加载环境变量
load_dotenv()

# SQLite数据库URL，支持环境变量配置
SQLALCHEMY_DATABASE_URL = os.getenv(
    "DATABASE_URL", 
    "sqlite:///./data/prompt_optimizer.db"
)

# 创建数据库引擎
# connect_args={"check_same_thread": False} 对SQLite很重要，允许多线程访问
engine = create_engine(
    SQLALCHEMY_DATABASE_URL, 
    connect_args={"check_same_thread": False},
    echo=False  # 设为True可以看到SQL语句
)

# 创建SessionLocal类，每个实例都是一个数据库会话
SessionLocal = sessionmaker(autocommit=False, autoflush=False, bind=engine)

# 创建Base类
Base = declarative_base()

# 依赖函数，用于获取数据库会话
def get_db():
    """
    获取数据库会话的生成器函数
    用于FastAPI的依赖注入系统
    确保数据库会话在使用后总是被关闭
    """
    db = SessionLocal()
    try:
        yield db
    finally:
        db.close()

# 创建所有表的函数
def create_tables():
    """
    创建所有数据库表
    在应用启动时调用
    """
    # 导入所有模型以确保它们被注册到Base.metadata中
    from .models import prompt
    Base.metadata.create_all(bind=engine) 