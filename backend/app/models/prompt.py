from sqlalchemy import Column, Integer, String, DateTime, Text, ForeignKey, Float, JSON, Boolean
from sqlalchemy.orm import relationship
from sqlalchemy.sql import func
from .base import Base

class Prompt(Base):
    """提示词项目主体 - 管理提示词的基本信息和元数据"""
    __tablename__ = "prompts"

    id = Column(Integer, primary_key=True, index=True)
    title = Column(String(255), nullable=False, index=True)
    description = Column(Text, nullable=True)
    category = Column(String(100), nullable=True, index=True)  # 如：代码生成、内容创作、数据分析
    tags = Column(JSON, nullable=True)  # 标签数组
    is_public = Column(Boolean, default=False)  # 是否公开分享
    is_template = Column(Boolean, default=False)  # 是否为模板
    framework_type = Column(String(50), nullable=True)  # 使用的框架：CO-STAR, RTF, TAG等
    created_at = Column(DateTime(timezone=True), server_default=func.now())
    updated_at = Column(DateTime(timezone=True), server_default=func.now(), onupdate=func.now())
    
    # 关系
    versions = relationship("PromptVersion", back_populates="prompt", cascade="all, delete-orphan")
    
    def __repr__(self):
        return f"<Prompt(id={self.id}, title='{self.title}')>"


class PromptVersion(Base):
    """提示词版本 - 管理提示词的具体版本实现"""
    __tablename__ = "prompt_versions"

    id = Column(Integer, primary_key=True, index=True)
    prompt_id = Column(Integer, ForeignKey("prompts.id"), nullable=False, index=True)
    version_number = Column(Integer, nullable=False)  # 版本号：1, 2, 3...
    version_name = Column(String(100), nullable=True)  # 版本名称：如 "优化后的版本"
    content = Column(Text, nullable=False)  # 提示词内容
    
    # LLM参数配置
    llm_config = Column(JSON, nullable=True)  # LLM配置：provider, model, temperature等
    
    # 元数据
    change_notes = Column(Text, nullable=True)  # 版本变更说明
    is_baseline = Column(Boolean, default=False)  # 是否为基准版本
    created_at = Column(DateTime(timezone=True), server_default=func.now())
    
    # 关系
    prompt = relationship("Prompt", back_populates="versions")
    optimization_results = relationship("OptimizationResult", back_populates="version", cascade="all, delete-orphan")
    
    def __repr__(self):
        return f"<PromptVersion(id={self.id}, prompt_id={self.prompt_id}, version={self.version_number})>"


class OptimizationResult(Base):
    """优化测试结果 - 存储提示词版本的测试结果和性能指标"""
    __tablename__ = "optimization_results"

    id = Column(Integer, primary_key=True, index=True)
    version_id = Column(Integer, ForeignKey("prompt_versions.id"), nullable=False, index=True)
    
    # 输入输出数据
    test_input = Column(Text, nullable=True)  # 测试输入（如果有）
    output_text = Column(Text, nullable=False)  # LLM输出文本
    
    # 性能指标
    execution_time = Column(Float, nullable=True)  # 执行时间（秒）
    input_tokens = Column(Integer, nullable=True)  # 输入token数
    output_tokens = Column(Integer, nullable=True)  # 输出token数
    total_tokens = Column(Integer, nullable=True)  # 总token数
    cost = Column(Float, nullable=True)  # 调用成本
    
    # 质量评估
    user_rating = Column(Integer, nullable=True)  # 用户评分 1-5
    quality_score = Column(Float, nullable=True)  # 自动质量评分
    quality_analysis = Column(JSON, nullable=True)  # 详细质量分析结果
    
    # 错误处理
    is_error = Column(Boolean, default=False)
    error_message = Column(Text, nullable=True)
    error_type = Column(String(100), nullable=True)
    
    # 元数据
    llm_provider = Column(String(50), nullable=True)  # 使用的LLM提供商
    llm_model = Column(String(100), nullable=True)  # 使用的模型
    created_at = Column(DateTime(timezone=True), server_default=func.now())
    
    # 关系
    version = relationship("PromptVersion", back_populates="optimization_results")
    
    def __repr__(self):
        return f"<OptimizationResult(id={self.id}, version_id={self.version_id}, rating={self.user_rating})>"


class PromptTemplate(Base):
    """提示词模板 - 管理预制的高质量提示词模板"""
    __tablename__ = "prompt_templates"

    id = Column(Integer, primary_key=True, index=True)
    name = Column(String(255), nullable=False, index=True)
    description = Column(Text, nullable=False)
    category = Column(String(100), nullable=False, index=True)  # reasoning, learning, structured等
    complexity = Column(String(20), nullable=False)  # simple, medium, complex
    framework_type = Column(String(50), nullable=True)  # CO-STAR, RTF等
    
    # 模板内容
    template_content = Column(Text, nullable=False)
    variables = Column(JSON, nullable=True)  # 模板变量定义
    example_use_case = Column(Text, nullable=True)  # 使用示例
    best_practices = Column(JSON, nullable=True)  # 最佳实践建议
    
    # 使用统计
    usage_count = Column(Integer, default=0)  # 使用次数
    average_rating = Column(Float, nullable=True)  # 平均评分
    
    # 元数据
    is_official = Column(Boolean, default=True)  # 是否为官方模板
    created_at = Column(DateTime(timezone=True), server_default=func.now())
    updated_at = Column(DateTime(timezone=True), server_default=func.now(), onupdate=func.now())
    
    def __repr__(self):
        return f"<PromptTemplate(id={self.id}, name='{self.name}', category='{self.category}')>" 