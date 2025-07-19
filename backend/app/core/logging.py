import os
import sys
import logging
from logging.handlers import RotatingFileHandler, TimedRotatingFileHandler
import json
from datetime import datetime
from typing import Dict, Any, Optional
import traceback


class StructuredFormatter(logging.Formatter):
    """结构化日志格式器，输出JSON格式的日志"""
    
    def format(self, record: logging.LogRecord) -> str:
        log_entry = {
            "timestamp": datetime.utcnow().isoformat() + "Z",
            "level": record.levelname,
            "logger": record.name,
            "message": record.getMessage(),
            "module": record.module,
            "function": record.funcName,
            "line": record.lineno,
        }
        
        # 添加额外的字段
        if hasattr(record, 'user_id'):
            log_entry['user_id'] = record.user_id
            
        if hasattr(record, 'request_id'):
            log_entry['request_id'] = record.request_id
            
        if hasattr(record, 'duration'):
            log_entry['duration'] = record.duration
            
        if hasattr(record, 'status_code'):
            log_entry['status_code'] = record.status_code
            
        # 异常信息
        if record.exc_info:
            log_entry['exception'] = {
                "type": record.exc_info[0].__name__,
                "message": str(record.exc_info[1]),
                "traceback": traceback.format_exception(*record.exc_info)
            }
            
        # 环境信息
        log_entry['environment'] = os.getenv('ENVIRONMENT', 'development')
        
        return json.dumps(log_entry, ensure_ascii=False)


class RequestContextFilter(logging.Filter):
    """请求上下文过滤器，添加请求相关信息"""
    
    def filter(self, record: logging.LogRecord) -> bool:
        # 这里可以从上下文中获取请求信息
        # 在实际应用中，可以使用contextvars或其他方式
        return True


def setup_logging():
    """配置应用日志系统"""
    
    # 创建日志目录
    log_dir = os.getenv('LOG_DIR', './logs')
    
    # 尝试创建日志目录，如果失败则使用临时目录
    try:
        os.makedirs(log_dir, exist_ok=True)
        # 测试是否可以写入
        test_file = os.path.join(log_dir, '.write_test')
        with open(test_file, 'w') as f:
            f.write('test')
        os.remove(test_file)
    except (OSError, PermissionError) as e:
        # 如果无法创建或写入日志目录，降级到标准输出
        print(f"警告: 无法创建日志目录 {log_dir}: {e}")
        print("降级到仅使用控制台输出")
        log_dir = None
    
    # 根据环境确定日志级别
    environment = os.getenv('ENVIRONMENT', 'development')
    log_level = logging.DEBUG if environment == 'development' else logging.INFO
    
    # 配置根日志器
    root_logger = logging.getLogger()
    root_logger.setLevel(log_level)
    
    # 清除现有处理器
    for handler in root_logger.handlers[:]:
        root_logger.removeHandler(handler)
    
    # 控制台处理器
    console_handler = logging.StreamHandler(sys.stdout)
    if environment == 'development':
        # 开发环境使用简单格式
        console_formatter = logging.Formatter(
            '%(asctime)s - %(name)s - %(levelname)s - %(message)s'
        )
    else:
        # 生产环境使用结构化格式
        console_formatter = StructuredFormatter()
    
    console_handler.setFormatter(console_formatter)
    console_handler.setLevel(log_level)
    root_logger.addHandler(console_handler)
    
    # 只有在日志目录可用时才创建文件处理器
    if log_dir:
        try:
            # 文件处理器（应用日志）
            app_log_file = os.path.join(log_dir, 'app.log')
            file_handler = RotatingFileHandler(
                app_log_file,
                maxBytes=10 * 1024 * 1024,  # 10MB
                backupCount=5,
                encoding='utf-8'
            )
            file_handler.setFormatter(StructuredFormatter())
            file_handler.setLevel(logging.INFO)
            root_logger.addHandler(file_handler)
            
            # 错误日志处理器
            error_log_file = os.path.join(log_dir, 'error.log')
            error_handler = RotatingFileHandler(
                error_log_file,
                maxBytes=10 * 1024 * 1024,  # 10MB
                backupCount=5,
                encoding='utf-8'
            )
            error_handler.setFormatter(StructuredFormatter())
            error_handler.setLevel(logging.ERROR)
            root_logger.addHandler(error_handler)
            
            # 访问日志处理器
            access_log_file = os.path.join(log_dir, 'access.log')
            access_handler = TimedRotatingFileHandler(
                access_log_file,
                when='midnight',
                interval=1,
                backupCount=30,
                encoding='utf-8'
            )
            access_handler.setFormatter(StructuredFormatter())
            
            # 创建访问日志器
            access_logger = logging.getLogger('access')
            access_logger.setLevel(logging.INFO)
            access_logger.addHandler(access_handler)
            
        except Exception as e:
            print(f"警告: 创建文件日志处理器失败: {e}")
            print("继续使用控制台日志输出")
    
    # 第三方库日志级别调整
    logging.getLogger('sqlalchemy.engine').setLevel(logging.WARNING)
    logging.getLogger('uvicorn').setLevel(logging.INFO)
    logging.getLogger('fastapi').setLevel(logging.INFO)
    
    logging.info("日志系统初始化完成", extra={
        "log_level": logging.getLevelName(log_level),
        "log_dir": log_dir or "console-only",
        "environment": environment
    })


def get_logger(name: str) -> logging.Logger:
    """获取指定名称的日志器"""
    return logging.getLogger(name)


# 性能监控日志器
performance_logger = logging.getLogger('performance')

# 安全日志器
security_logger = logging.getLogger('security')

# 业务日志器
business_logger = logging.getLogger('business') 