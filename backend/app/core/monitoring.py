import time
import psutil
import threading
from typing import Dict, Any, Optional, List
from dataclasses import dataclass, asdict
from datetime import datetime, timedelta
import logging
from collections import defaultdict, deque
import json
import os

logger = logging.getLogger(__name__)

@dataclass
class SystemMetrics:
    """系统指标数据类"""
    timestamp: str
    cpu_percent: float
    memory_percent: float
    memory_used_mb: float
    memory_available_mb: float
    disk_usage_percent: float
    disk_free_gb: float
    active_connections: int
    
    def to_dict(self) -> Dict[str, Any]:
        return asdict(self)


@dataclass
class APIMetrics:
    """API指标数据类"""
    endpoint: str
    method: str
    status_code: int
    response_time: float
    timestamp: str
    user_agent: Optional[str] = None
    ip_address: Optional[str] = None
    
    def to_dict(self) -> Dict[str, Any]:
        return asdict(self)


class MetricsCollector:
    """指标收集器"""
    
    def __init__(self, max_metrics_count: int = 1000):
        self.max_metrics_count = max_metrics_count
        self.system_metrics: deque = deque(maxlen=max_metrics_count)
        self.api_metrics: deque = deque(maxlen=max_metrics_count)
        self.error_count = defaultdict(int)
        self.request_count = defaultdict(int)
        self.response_times = defaultdict(list)
        self._lock = threading.Lock()
        
        # 启动系统指标收集线程
        self._collection_thread = threading.Thread(target=self._collect_system_metrics, daemon=True)
        self._collection_thread.start()
        
        logger.info("指标收集器初始化完成")
    
    def _collect_system_metrics(self):
        """收集系统指标（后台线程）"""
        while True:
            try:
                # CPU使用率
                cpu_percent = psutil.cpu_percent(interval=1)
                
                # 内存信息
                memory = psutil.virtual_memory()
                
                # 磁盘信息
                disk = psutil.disk_usage('/')
                
                # 网络连接数（简化版）
                connections = len(psutil.net_connections())
                
                metrics = SystemMetrics(
                    timestamp=datetime.utcnow().isoformat(),
                    cpu_percent=cpu_percent,
                    memory_percent=memory.percent,
                    memory_used_mb=memory.used / 1024 / 1024,
                    memory_available_mb=memory.available / 1024 / 1024,
                    disk_usage_percent=disk.percent,
                    disk_free_gb=disk.free / 1024 / 1024 / 1024,
                    active_connections=connections
                )
                
                with self._lock:
                    self.system_metrics.append(metrics)
                
                # 每60秒收集一次
                time.sleep(60)
                
            except Exception as e:
                logger.error(f"收集系统指标失败: {e}")
                time.sleep(60)
    
    def record_api_request(self, endpoint: str, method: str, status_code: int, 
                          response_time: float, user_agent: Optional[str] = None,
                          ip_address: Optional[str] = None):
        """记录API请求指标"""
        try:
            metrics = APIMetrics(
                endpoint=endpoint,
                method=method,
                status_code=status_code,
                response_time=response_time,
                timestamp=datetime.utcnow().isoformat(),
                user_agent=user_agent,
                ip_address=ip_address
            )
            
            with self._lock:
                self.api_metrics.append(metrics)
                
                # 更新统计信息
                endpoint_key = f"{method} {endpoint}"
                self.request_count[endpoint_key] += 1
                
                if status_code >= 400:
                    self.error_count[endpoint_key] += 1
                
                # 保留最近100个响应时间用于计算平均值
                if len(self.response_times[endpoint_key]) >= 100:
                    self.response_times[endpoint_key].pop(0)
                self.response_times[endpoint_key].append(response_time)
            
        except Exception as e:
            logger.error(f"记录API指标失败: {e}")
    
    def get_system_metrics(self, limit: int = 100) -> List[Dict[str, Any]]:
        """获取系统指标"""
        with self._lock:
            return [metrics.to_dict() for metrics in list(self.system_metrics)[-limit:]]
    
    def get_api_metrics(self, limit: int = 100) -> List[Dict[str, Any]]:
        """获取API指标"""
        with self._lock:
            return [metrics.to_dict() for metrics in list(self.api_metrics)[-limit:]]
    
    def get_summary_stats(self) -> Dict[str, Any]:
        """获取汇总统计信息"""
        with self._lock:
            current_time = datetime.utcnow()
            
            # 最近一小时的API请求
            recent_apis = [
                m for m in self.api_metrics 
                if datetime.fromisoformat(m.timestamp.rstrip('Z')) > current_time - timedelta(hours=1)
            ]
            
            # 计算统计信息
            total_requests = len(recent_apis)
            error_requests = len([m for m in recent_apis if m.status_code >= 400])
            
            if recent_apis:
                avg_response_time = sum(m.response_time for m in recent_apis) / len(recent_apis)
                max_response_time = max(m.response_time for m in recent_apis)
            else:
                avg_response_time = 0
                max_response_time = 0
            
            # 最新的系统指标
            latest_system = self.system_metrics[-1] if self.system_metrics else None
            
            return {
                "timestamp": current_time.isoformat(),
                "api_stats": {
                    "total_requests_1h": total_requests,
                    "error_requests_1h": error_requests,
                    "error_rate_1h": error_requests / total_requests if total_requests > 0 else 0,
                    "avg_response_time_1h": avg_response_time,
                    "max_response_time_1h": max_response_time
                },
                "system_stats": latest_system.to_dict() if latest_system else None
            }
    
    def get_endpoint_stats(self) -> Dict[str, Any]:
        """获取端点统计信息"""
        with self._lock:
            stats = {}
            
            for endpoint, count in self.request_count.items():
                error_count = self.error_count.get(endpoint, 0)
                response_times = self.response_times.get(endpoint, [])
                
                avg_response_time = sum(response_times) / len(response_times) if response_times else 0
                
                stats[endpoint] = {
                    "total_requests": count,
                    "error_count": error_count,
                    "error_rate": error_count / count if count > 0 else 0,
                    "avg_response_time": avg_response_time,
                    "recent_requests": len(response_times)
                }
            
            return stats
    
    def export_metrics(self, file_path: str):
        """导出指标到文件"""
        try:
            data = {
                "export_time": datetime.utcnow().isoformat(),
                "system_metrics": self.get_system_metrics(),
                "api_metrics": self.get_api_metrics(),
                "summary_stats": self.get_summary_stats(),
                "endpoint_stats": self.get_endpoint_stats()
            }
            
            with open(file_path, 'w', encoding='utf-8') as f:
                json.dump(data, f, indent=2, ensure_ascii=False)
            
            logger.info(f"指标已导出到: {file_path}")
            
        except Exception as e:
            logger.error(f"导出指标失败: {e}")


class HealthChecker:
    """健康检查器"""
    
    def __init__(self):
        self.checks = {}
        logger.info("健康检查器初始化完成")
    
    def register_check(self, name: str, check_func):
        """注册健康检查函数"""
        self.checks[name] = check_func
        logger.info(f"注册健康检查: {name}")
    
    def run_checks(self) -> Dict[str, Any]:
        """运行所有健康检查"""
        results = {
            "timestamp": datetime.utcnow().isoformat(),
            "overall_status": "healthy",
            "checks": {}
        }
        
        for name, check_func in self.checks.items():
            try:
                start_time = time.time()
                result = check_func()
                duration = time.time() - start_time
                
                results["checks"][name] = {
                    "status": "healthy" if result else "unhealthy",
                    "duration": duration,
                    "details": result if isinstance(result, dict) else {}
                }
                
                if not result:
                    results["overall_status"] = "unhealthy"
                    
            except Exception as e:
                results["checks"][name] = {
                    "status": "error",
                    "error": str(e)
                }
                results["overall_status"] = "unhealthy"
                logger.error(f"健康检查失败 {name}: {e}")
        
        return results


# 全局实例
metrics_collector = MetricsCollector()
health_checker = HealthChecker()


# 注册默认的健康检查
def check_database():
    """检查数据库连接"""
    try:
        from ..database import engine
        with engine.connect() as conn:
            conn.execute("SELECT 1")
        return True
    except Exception:
        return False


def check_disk_space():
    """检查磁盘空间"""
    try:
        disk = psutil.disk_usage('/')
        free_percent = (disk.free / disk.total) * 100
        return {
            "free_percent": free_percent,
            "healthy": free_percent > 10  # 至少10%空闲空间
        }
    except Exception:
        return False


def check_memory():
    """检查内存使用率"""
    try:
        memory = psutil.virtual_memory()
        return {
            "used_percent": memory.percent,
            "healthy": memory.percent < 90  # 内存使用率低于90%
        }
    except Exception:
        return False


# 注册默认检查
health_checker.register_check("database", check_database)
health_checker.register_check("disk_space", check_disk_space)
health_checker.register_check("memory", check_memory) 