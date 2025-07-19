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
try:
    create_tables()
    logger.info("数据库表创建成功")
except Exception as e:
    logger.error(f"数据库初始化失败: {e}")
    # 在零配置部署中，数据库初始化失败不应该阻止应用启动

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
    logger.info(f"请求开始: {request.method} {request.url.path}")
    
    try:
        # 处理请求
        response = await call_next(request)
        
        # 计算响应时间
        process_time = time.time() - start_time
        
        # 记录API指标（如果监控系统可用）
        try:
            metrics_collector.record_api_request(
                endpoint=request.url.path,
                method=request.method,
                status_code=response.status_code,
                response_time=process_time,
                user_agent=request.headers.get("user-agent"),
                ip_address=request.client.host if request.client else None
            )
        except Exception as e:
            logger.warning(f"记录指标失败: {e}")
        
        # 记录请求完成
        logger.info(f"请求完成: {request.method} {request.url.path} - {response.status_code} - {process_time:.3f}s")
        
        # 添加响应时间头
        response.headers["X-Process-Time"] = str(process_time)
        
        return response
    except Exception as e:
        logger.error(f"请求处理失败: {request.method} {request.url.path} - {e}")
        raise

# 添加安全中间件
@app.middleware("http")
async def security_headers_middleware(request: Request, call_next):
    """添加安全响应头"""
    try:
        response = await call_next(request)
        
        # 添加安全头
        try:
            security_headers = get_security_headers()
            for header, value in security_headers.items():
                response.headers[header] = value
        except Exception as e:
            logger.warning(f"添加安全头失败: {e}")
        
        return response
    except Exception as e:
        logger.error(f"安全中间件错误: {e}")
        raise

# 零配置CORS设置 - 允许所有来源（适用于内部部署）
def get_default_cors_origins() -> List[str]:
    """
    获取默认的CORS源配置 - 零配置部署友好
    """
    # 默认允许的源（适用于大多数部署场景）
    default_origins = [
        "http://localhost",
        "http://localhost:80",
        "http://localhost:3000",
        "http://localhost:5173",
        "http://127.0.0.1",
        "http://127.0.0.1:80",
        "http://127.0.0.1:3000", 
        "http://127.0.0.1:5173"
    ]
    
    # 从环境变量获取额外的源（可选）
    env_origins = os.getenv("ALLOWED_ORIGINS", "")
    if env_origins:
        additional_origins = [origin.strip() for origin in env_origins.split(",") if origin.strip()]
        default_origins.extend(additional_origins)
    
    logger.info(f"配置CORS源: {default_origins}")
    return default_origins

# 零配置受信任主机设置（仅在严格模式下启用）
if os.getenv("STRICT_HOST_CHECK", "false").lower() == "true":
    allowed_hosts = os.getenv("ALLOWED_HOSTS", "localhost,127.0.0.1").split(",")
    app.add_middleware(TrustedHostMiddleware, allowed_hosts=[host.strip() for host in allowed_hosts])
    logger.info(f"启用严格主机检查: {allowed_hosts}")

# 配置CORS中间件 - 零配置友好
try:
    origins = get_default_cors_origins()
    
    # 在零配置模式下，为了简化部署，允许更宽松的CORS策略
    app.add_middleware(
        CORSMiddleware,
        allow_origins=["*"],  # 允许所有源（适用于内部部署）
        allow_credentials=False,  # 由于允许所有源，禁用凭据
        allow_methods=["GET", "POST", "PUT", "DELETE", "OPTIONS"],
        allow_headers=["*"],
    )
    logger.info("CORS配置完成 - 零配置模式")
except Exception as e:
    logger.error(f"CORS配置失败: {e}")

# 包含路由
try:
    app.include_router(prompts.router)
    app.include_router(versions.router)
    app.include_router(llm.router)
    app.include_router(api_config.router)
    logger.info("所有路由加载成功")
except Exception as e:
    logger.error(f"路由加载失败: {e}")

# 根路径健康检查
@app.get("/")
def read_root():
    """根路径健康检查端点"""
    return {
        "status": "ok",
        "message": "LLM提示词优化平台API正在运行",
        "version": "1.1.0",
        "environment": os.getenv("ENVIRONMENT", "production"),
        "deployment_mode": "zero-config"
    }

@app.get("/health")
def health_check():
    """详细的健康检查端点"""
    try:
        health_data = {
            "status": "ok",
            "message": "API服务正常运行",
            "version": "1.1.0",
            "environment": os.getenv("ENVIRONMENT", "production"),
            "deployment_mode": "zero-config",
            "timestamp": time.time()
        }
        
        # 检查数据库连接
        try:
            from .database import engine
            with engine.connect() as conn:
                conn.execute("SELECT 1")
            health_data["database"] = "connected"
            logger.debug("数据库连接检查通过")
        except Exception as db_error:
            logger.warning(f"数据库连接检查失败: {db_error}")
            health_data["database"] = "disconnected"
            health_data["database_error"] = str(db_error)
        
        # 检查配置状态
        try:
            from .models.api_config import LLMAPIConfig
            from .database import SessionLocal
            
            db = SessionLocal()
            try:
                config_count = db.query(LLMAPIConfig).filter(LLMAPIConfig.is_enabled == True).count()
                health_data["llm_configs"] = config_count
            except Exception as config_error:
                health_data["llm_configs"] = "unknown"
                logger.warning(f"配置检查失败: {config_error}")
            finally:
                db.close()
        except Exception as e:
            logger.warning(f"配置状态检查失败: {e}")
        
        logger.info("健康检查通过")
        return health_data
        
    except Exception as e:
        logger.error(f"健康检查失败: {e}")
        return {
            "status": "error",
            "error": str(e),
            "version": "1.1.0",
            "timestamp": time.time()
        }

@app.get("/config/status")
def config_status():
    """配置状态检查端点 - 用于前端检查是否需要初始配置"""
    try:
        from .models.api_config import LLMAPIConfig
        from .database import SessionLocal
        
        db = SessionLocal()
        try:
            total_configs = db.query(LLMAPIConfig).count()
            enabled_configs = db.query(LLMAPIConfig).filter(LLMAPIConfig.is_enabled == True).count()
            
            return {
                "status": "ok",
                "total_configs": total_configs,
                "enabled_configs": enabled_configs,
                "needs_setup": total_configs == 0,
                "deployment_mode": "zero-config"
            }
        finally:
            db.close()
    except Exception as e:
        logger.error(f"配置状态检查失败: {e}")
        return {
            "status": "error",
            "error": str(e),
            "needs_setup": True,
            "deployment_mode": "zero-config"
        }

@app.get("/metrics")
def get_metrics():
    """获取性能指标端点（仅限调试模式）"""
    if os.getenv("ENABLE_METRICS", "false").lower() != "true":
        return {"error": "Metrics endpoint disabled"}
    
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
    logger.info("应用启动完成 - 零配置部署模式", extra={
        "version": "1.1.0",
        "environment": os.getenv("ENVIRONMENT", "production"),
        "deployment_mode": "zero-config"
    })

# 应用关闭事件
@app.on_event("shutdown")
async def shutdown_event():
    """应用关闭时执行"""
    logger.info("应用正在关闭")
    
    # 导出指标（如果启用）
    if os.getenv("ENABLE_METRICS", "false").lower() == "true":
        try:
            metrics_file = f"./logs/metrics_export_{int(time.time())}.json"
            metrics_collector.export_metrics(metrics_file)
            logger.info(f"指标已导出到: {metrics_file}")
        except Exception as e:
            logger.error(f"导出指标失败: {e}") 