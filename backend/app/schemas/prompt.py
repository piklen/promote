from pydantic import BaseModel, Field, validator
from datetime import datetime
from typing import Optional, List, Dict, Any
from enum import Enum

# ===========================================
# 枚举定义
# ===========================================

class LLMProvider(str, Enum):
    """支持的LLM服务提供商"""
    OPENAI = "openai"
    ANTHROPIC = "anthropic"
    GOOGLE = "google"
    GOOGLE_CUSTOM = "google_custom"  # 通过自定义地址调用的Google模型
    CUSTOM = "custom"

class PromptCategory(str, Enum):
    """提示词分类"""
    CODE_GENERATION = "code_generation"
    CONTENT_CREATION = "content_creation"
    DATA_ANALYSIS = "data_analysis"
    REASONING = "reasoning"
    TRANSLATION = "translation"
    SUMMARIZATION = "summarization"
    QUESTION_ANSWERING = "question_answering"
    OTHER = "other"

class FrameworkType(str, Enum):
    """提示词框架类型"""
    COSTAR = "CO-STAR"
    RTF = "RTF"
    TAG = "TAG"
    CRISPE = "CRISPE"
    RACE = "RACE"
    CUSTOM = "custom"

class ComplexityLevel(str, Enum):
    """复杂度级别"""
    SIMPLE = "simple"
    MEDIUM = "medium"
    COMPLEX = "complex"

# ===========================================
# 提示词项目模式
# ===========================================

class PromptBase(BaseModel):
    title: str = Field(..., min_length=1, max_length=255, description="提示词项目标题")
    description: Optional[str] = Field(None, description="提示词项目描述")
    category: Optional[PromptCategory] = Field(None, description="提示词分类")
    tags: Optional[List[str]] = Field(default_factory=list, description="标签列表")
    is_public: bool = Field(False, description="是否公开分享")
    is_template: bool = Field(False, description="是否为模板")
    framework_type: Optional[FrameworkType] = Field(None, description="使用的提示词框架")

    @validator('tags')
    def validate_tags(cls, v):
        if v and len(v) > 10:
            raise ValueError('标签数量不能超过10个')
        return v

class PromptCreate(PromptBase):
    """创建提示词项目的请求模式"""
    pass

class PromptUpdate(BaseModel):
    """更新提示词项目的请求模式"""
    title: Optional[str] = Field(None, min_length=1, max_length=255)
    description: Optional[str] = None
    category: Optional[PromptCategory] = None
    tags: Optional[List[str]] = None
    is_public: Optional[bool] = None
    is_template: Optional[bool] = None
    framework_type: Optional[FrameworkType] = None

    @validator('tags')
    def validate_tags(cls, v):
        if v and len(v) > 10:
            raise ValueError('标签数量不能超过10个')
        return v

class PromptRead(PromptBase):
    """提示词项目的响应模式"""
    id: int
    created_at: datetime
    updated_at: datetime
    
    class Config:
        from_attributes = True

class PromptDetail(PromptRead):
    """包含版本信息的详细提示词模式"""
    versions: List["PromptVersionRead"] = []

class PromptReadWithVersions(PromptRead):
    """包含版本信息的提示词响应模式"""
    versions: List["PromptVersionRead"] = []

# ===========================================
# 提示词版本模式
# ===========================================

class LLMConfig(BaseModel):
    """LLM配置参数"""
    provider: LLMProvider = Field(..., description="LLM提供商")
    model: str = Field(..., description="模型名称")
    temperature: Optional[float] = Field(0.7, ge=0, le=2, description="温度参数")
    max_tokens: Optional[int] = Field(None, ge=1, le=8192, description="最大token数")
    top_p: Optional[float] = Field(1.0, ge=0, le=1, description="Top-p参数")
    frequency_penalty: Optional[float] = Field(0, ge=-2, le=2, description="频率惩罚")
    presence_penalty: Optional[float] = Field(0, ge=-2, le=2, description="存在惩罚")
    stop_sequences: Optional[List[str]] = Field(default_factory=list, description="停止序列")

class PromptVersionBase(BaseModel):
    version_name: Optional[str] = Field(None, max_length=100, description="版本名称")
    content: str = Field(..., min_length=1, description="提示词内容")
    llm_config: Optional[LLMConfig] = Field(None, description="LLM配置")
    change_notes: Optional[str] = Field(None, description="版本变更说明")
    is_baseline: bool = Field(False, description="是否为基准版本")

class PromptVersionCreate(BaseModel):
    """创建提示词版本的请求模式"""
    version_name: Optional[str] = Field(None, max_length=100)
    content: str = Field(..., min_length=1)
    llm_config: Optional[LLMConfig] = None
    change_notes: Optional[str] = None
    is_baseline: bool = False

class PromptVersionUpdate(BaseModel):
    """更新提示词版本的请求模式"""
    version_name: Optional[str] = Field(None, max_length=100)
    content: Optional[str] = Field(None, min_length=1)
    llm_config: Optional[LLMConfig] = None
    change_notes: Optional[str] = None
    is_baseline: Optional[bool] = None

class PromptVersionRead(PromptVersionBase):
    """提示词版本的响应模式"""
    id: int
    prompt_id: int
    version_number: int
    created_at: datetime
    
    class Config:
        from_attributes = True

class PromptVersionDetail(PromptVersionRead):
    """包含测试结果的详细版本模式"""
    optimization_results: List["OptimizationResultRead"] = []

class PromptVersionReadWithResults(PromptVersionRead):
    """包含测试结果的版本响应模式"""
    optimization_results: List["OptimizationResultRead"] = []

# ===========================================
# 优化结果模式
# ===========================================

class TokenUsage(BaseModel):
    """Token使用统计"""
    input_tokens: int = Field(..., ge=0, description="输入token数")
    output_tokens: int = Field(..., ge=0, description="输出token数")
    total_tokens: int = Field(..., ge=0, description="总token数")

class QualityMetrics(BaseModel):
    """质量评估指标"""
    clarity_score: float = Field(..., ge=0, le=100, description="清晰度评分")
    specificity_score: float = Field(..., ge=0, le=100, description="具体性评分")
    context_score: float = Field(..., ge=0, le=100, description="上下文评分")
    structure_score: float = Field(..., ge=0, le=100, description="结构性评分")
    completeness_score: float = Field(..., ge=0, le=100, description="完整性评分")
    overall_score: float = Field(..., ge=0, le=100, description="总体评分")

class OptimizationResultBase(BaseModel):
    test_input: Optional[str] = Field(None, description="测试输入内容")
    output_text: str = Field(..., description="LLM输出文本")
    execution_time: Optional[float] = Field(None, ge=0, description="执行时间（秒）")
    input_tokens: Optional[int] = Field(None, ge=0, description="输入token数")
    output_tokens: Optional[int] = Field(None, ge=0, description="输出token数")
    total_tokens: Optional[int] = Field(None, ge=0, description="总token数")
    cost: Optional[float] = Field(None, ge=0, description="调用成本")
    user_rating: Optional[int] = Field(None, ge=1, le=5, description="用户评分")
    quality_score: Optional[float] = Field(None, ge=0, le=100, description="自动质量评分")
    quality_analysis: Optional[QualityMetrics] = Field(None, description="详细质量分析")
    is_error: bool = Field(False, description="是否出错")
    error_message: Optional[str] = Field(None, description="错误消息")
    error_type: Optional[str] = Field(None, max_length=100, description="错误类型")
    llm_provider: Optional[LLMProvider] = Field(None, description="LLM提供商")
    llm_model: Optional[str] = Field(None, max_length=100, description="LLM模型")

class OptimizationResultCreate(BaseModel):
    """创建优化结果的请求模式"""
    test_input: Optional[str] = None
    output_text: str
    execution_time: Optional[float] = Field(None, ge=0)
    input_tokens: Optional[int] = Field(None, ge=0)
    output_tokens: Optional[int] = Field(None, ge=0)
    total_tokens: Optional[int] = Field(None, ge=0)
    cost: Optional[float] = Field(None, ge=0)
    user_rating: Optional[int] = Field(None, ge=1, le=5)
    quality_score: Optional[float] = Field(None, ge=0, le=100)
    quality_analysis: Optional[QualityMetrics] = None
    is_error: bool = False
    error_message: Optional[str] = None
    error_type: Optional[str] = Field(None, max_length=100)
    llm_provider: Optional[LLMProvider] = None
    llm_model: Optional[str] = Field(None, max_length=100)

class OptimizationResultRead(OptimizationResultBase):
    """优化结果的响应模式"""
    id: int
    version_id: int
    created_at: datetime
    
    class Config:
        from_attributes = True

# ===========================================
# 提示词模板模式
# ===========================================

class PromptTemplateBase(BaseModel):
    name: str = Field(..., min_length=1, max_length=255, description="模板名称")
    description: str = Field(..., min_length=1, description="模板描述")
    category: PromptCategory = Field(..., description="模板分类")
    complexity: ComplexityLevel = Field(..., description="复杂度级别")
    framework_type: Optional[FrameworkType] = Field(None, description="使用的框架")
    template_content: str = Field(..., min_length=1, description="模板内容")
    variables: Optional[Dict[str, str]] = Field(default_factory=dict, description="模板变量定义")
    example_use_case: Optional[str] = Field(None, description="使用示例")
    best_practices: Optional[List[str]] = Field(default_factory=list, description="最佳实践建议")

class PromptTemplateCreate(PromptTemplateBase):
    """创建提示词模板的请求模式"""
    is_official: bool = True

class PromptTemplateRead(PromptTemplateBase):
    """提示词模板的响应模式"""
    id: int
    usage_count: int
    average_rating: Optional[float]
    is_official: bool
    created_at: datetime
    updated_at: datetime
    
    class Config:
        from_attributes = True

# ===========================================
# 复合模式和特殊用例
# ===========================================

class VersionComparisonRequest(BaseModel):
    """版本比较请求模式"""
    version_ids: List[int] = Field(..., min_items=2, max_items=5, description="要比较的版本ID列表")
    test_input: Optional[str] = Field(None, description="测试输入")

class VersionComparisonResult(BaseModel):
    """版本比较结果模式"""
    versions: List[PromptVersionRead]
    results: List[OptimizationResultRead]
    comparison_metrics: Dict[str, Any]

class QualityAnalysisRequest(BaseModel):
    """质量分析请求模式"""
    content: str = Field(..., min_length=1, description="要分析的提示词内容")
    framework_type: Optional[FrameworkType] = Field(None, description="使用的框架类型")

class QualityAnalysisResult(BaseModel):
    """质量分析结果模式"""
    total_score: float = Field(..., ge=0, le=100, description="总体评分")
    category_scores: Dict[str, float] = Field(..., description="各维度评分")
    issues: List[Dict[str, str]] = Field(..., description="发现的问题")
    strengths: List[str] = Field(..., description="优势方面")
    recommendations: List[str] = Field(..., description="改进建议")

class BatchOptimizationRequest(BaseModel):
    """批量优化请求模式"""
    version_ids: List[int] = Field(..., min_items=1, max_items=10, description="版本ID列表")
    test_inputs: List[str] = Field(..., min_items=1, description="测试输入列表")
    llm_config: Optional[LLMConfig] = Field(None, description="LLM配置")

class OptimizationStats(BaseModel):
    """优化统计信息"""
    total_results: int
    average_rating: Optional[float]
    average_execution_time: Optional[float]
    total_tokens_used: Optional[int]
    total_cost: Optional[float]
    success_rate: float

# ===========================================
# API响应封装
# ===========================================

class ApiResponse(BaseModel):
    """标准API响应格式"""
    success: bool = True
    message: str = "操作成功"
    data: Optional[Any] = None
    errors: Optional[List[str]] = None

class PaginatedResponse(BaseModel):
    """分页响应格式"""
    items: List[Any]
    total: int
    page: int
    size: int
    pages: int

# 前向引用解决
PromptDetail.model_rebuild()
PromptReadWithVersions.model_rebuild()
PromptVersionDetail.model_rebuild()
PromptVersionReadWithResults.model_rebuild() 