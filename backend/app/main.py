import os
import time
from typing import List

from fastapi import FastAPI, Request, Response
from fastapi.middleware.cors import CORSMiddleware
from fastapi.middleware.trustedhost import TrustedHostMiddleware
from .routers import prompts, versions, llm, api_config
from .database import engine, create_tables
from .models import prompt as models
from .core.security import get_security_headers, SecurityError
from .core.logging import setup_logging, get_logger
from .core.monitoring import metrics_collector, health_checker

# 初始化日志系统
setup_logging()
logger = get_logger(__name__)

# 在应用启动时创建数据库表
create_tables()

# 创建FastAPI应用实例
app = FastAPI(
    title="LLM提示词优化平台",
    description="一个用于创建、版本化和优化LLM提示词的Web应用",
    version="1.1.0",
    docs_url="/api/docs",
    redoc_url="/api/redoc"
)

# 添加性能监控中间件
@app.middleware("http")
async def performance_monitoring_middleware(request: Request, call_next):
    """性能监控中间件"""
    start_time = time.time()
    
    # 记录请求开始
    logger.info(f"请求开始: {request.method} {request.url.path}", extra={
        "method": request.method,
        "path": request.url.path,
        "client_ip": request.client.host if request.client else None,
        "user_agent": request.headers.get("user-agent")
    })
    
    # 处理请求
    response = await call_next(request)
    
    # 计算响应时间
    process_time = time.time() - start_time
    
    # 记录API指标
    metrics_collector.record_api_request(
        endpoint=request.url.path,
        method=request.method,
        status_code=response.status_code,
        response_time=process_time,
        user_agent=request.headers.get("user-agent"),
        ip_address=request.client.host if request.client else None
    )
    
    # 记录请求完成
    logger.info(f"请求完成: {request.method} {request.url.path}", extra={
        "method": request.method,
        "path": request.url.path,
        "status_code": response.status_code,
        "duration": process_time,
        "client_ip": request.client.host if request.client else None
    })
    
    # 添加响应时间头
    response.headers["X-Process-Time"] = str(process_time)
    
    return response

# 添加安全中间件
@app.middleware("http")
async def security_headers_middleware(request: Request, call_next):
    """添加安全响应头"""
    response = await call_next(request)
    
    # 添加安全头
    security_headers = get_security_headers()
    for header, value in security_headers.items():
        response.headers[header] = value
    
    return response

# 添加受信任主机中间件（生产环境）
if os.getenv("ENVIRONMENT") == "production":
    allowed_hosts = os.getenv("ALLOWED_HOSTS", "localhost").split(",")
    app.add_middleware(TrustedHostMiddleware, allowed_hosts=allowed_hosts)

# 配置CORS中间件
# 严格的CORS配置，符合AI辅助开发蓝图的安全建议
def get_cors_origins() -> List[str]:
    """
    获取CORS允许的源，支持开发和生产环境
    """
    # 从环境变量获取生产环境的允许源
    env_origins = os.getenv("ALLOWED_ORIGINS", "")
    production_origins = [origin.strip() for origin in env_origins.split(",") if origin.strip()]
    
    # 开发环境默认源
    development_origins = [
        "http://localhost:5173",  # Vite默认开发服务器端口
        "http://localhost:3000",  # 备用前端端口
        "http://127.0.0.1:5173",
        "http://127.0.0.1:3000",
    ]
    
    # 根据环境变量决定使用哪些源
    environment = os.getenv("ENVIRONMENT", "development")
    
    if environment == "production":
        # 生产环境只允许配置的源
        if not production_origins:
            raise ValueError("生产环境必须设置ALLOWED_ORIGINS环境变量")
        return production_origins
    else:
        # 开发环境允许开发源加上配置的源
        return development_origins + production_origins

origins = get_cors_origins()

app.add_middleware(
    CORSMiddleware,
    allow_origins=origins,
    allow_credentials=True,
    allow_methods=["GET", "POST", "PUT", "DELETE", "OPTIONS"],
    allow_headers=["*"],
)

# 包含路由
app.include_router(prompts.router)
app.include_router(versions.router)
app.include_router(llm.router)
app.include_router(api_config.router)

# 根路径健康检查
@app.get("/")
def read_root():
    """健康检查端点"""
    return {
        "status": "ok",
        "message": "LLM提示词优化平台API正在运行",
        "version": "1.1.0",
        "environment": os.getenv("ENVIRONMENT", "development")
    }

@app.get("/health")
def health_check():
    """详细的健康检查端点"""
    try:
        health_results = health_checker.run_checks()
        return health_results
    except Exception as e:
        logger.error(f"健康检查失败: {e}")
        return {
            "status": "error",
            "error": str(e),
            "version": "1.1.0"
        }

@app.get("/metrics")
def get_metrics():
    """获取性能指标端点（仅限开发/调试）"""
    if os.getenv("ENVIRONMENT") == "production":
        return {"error": "Metrics endpoint disabled in production"}
    
    try:
        return {
            "summary": metrics_collector.get_summary_stats(),
            "endpoints": metrics_collector.get_endpoint_stats(),
            "system": metrics_collector.get_system_metrics(limit=10)
        }
    except Exception as e:
        logger.error(f"获取指标失败: {e}")
        return {"error": str(e)}

# 应用启动事件
@app.on_event("startup")
async def startup_event():
    """应用启动时执行"""
    logger.info("应用启动完成", extra={
        "version": "1.1.0",
        "environment": os.getenv("ENVIRONMENT", "development")
    })

# 应用关闭事件
@app.on_event("shutdown")
async def shutdown_event():
    """应用关闭时执行"""
    logger.info("应用正在关闭")
    
    # 导出指标
    try:
        metrics_file = f"./logs/metrics_export_{int(time.time())}.json"
        metrics_collector.export_metrics(metrics_file)
    except Exception as e:
        logger.error(f"导出指标失败: {e}") 