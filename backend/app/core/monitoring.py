import time
import logging
from typing import Dict, Any

logger = logging.getLogger(__name__)


class SimpleHealthChecker:
    """简化的健康检查器"""
    
    def __init__(self):
        self.start_time = time.time()
    
    def get_health_status(self) -> Dict[str, Any]:
        """获取健康状态"""
        uptime = time.time() - self.start_time
        return {
            "status": "healthy",
            "uptime_seconds": uptime,
            "uptime_human": self._format_uptime(uptime)
        }
    
    def _format_uptime(self, seconds: float) -> str:
        """格式化运行时间"""
        hours, remainder = divmod(int(seconds), 3600)
        minutes, seconds = divmod(remainder, 60)
        return f"{hours}h {minutes}m {seconds}s"


class SimpleMetricsCollector:
    """简化的指标收集器"""
    
    def __init__(self):
        self.request_count = 0
        self.error_count = 0
    
    def record_api_request(self, **kwargs):
        """记录API请求（简化版本）"""
        self.request_count += 1
        if kwargs.get('status_code', 200) >= 400:
            self.error_count += 1
    
    def get_summary_stats(self) -> Dict[str, Any]:
        """获取汇总统计"""
        return {
            "total_requests": self.request_count,
            "total_errors": self.error_count,
            "error_rate": self.error_count / max(self.request_count, 1)
        }
    
    def get_endpoint_stats(self) -> Dict[str, Any]:
        """获取端点统计（简化版本）"""
        return {}
    
    def get_system_metrics(self, limit: int = 10) -> list:
        """获取系统指标（简化版本）"""
        return []
    
    def export_metrics(self, filepath: str):
        """导出指标（简化版本）"""
        logger.info(f"Metrics export to {filepath} skipped in simplified version")


# 创建全局实例
health_checker = SimpleHealthChecker()
metrics_collector = SimpleMetricsCollector() 