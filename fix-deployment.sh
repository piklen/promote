#!/bin/bash

# 快速修复部署问题脚本

set -e

echo "🔧 开始修复部署问题..."

# 颜色定义
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

log() {
    echo -e "${BLUE}[$(date '+%Y-%m-%d %H:%M:%S')] $1${NC}"
}

log "停止所有容器..."
docker-compose -f docker-compose.prod.yml down --remove-orphans 2>/dev/null || true

log "清理Docker资源..."
docker system prune -f

log "重新生成环境配置..."
SERVER_IP=$(curl -s ifconfig.me 2>/dev/null || curl -s ipinfo.io/ip 2>/dev/null || hostname -I | awk '{print $1}' || echo "localhost")

cat > .env.prod << EOF
# 生产环境配置
ENVIRONMENT=production
DATABASE_URL=sqlite:///./data/prompt_optimizer.db
LOG_DIR=/app/logs

# 安全配置
ENCRYPTION_MASTER_KEY=$(openssl rand -hex 32)

# CORS配置
ALLOWED_ORIGINS=http://$SERVER_IP
ALLOWED_HOSTS=$SERVER_IP

# 性能配置
ENABLE_METRICS=false
ENABLE_DEBUG=false

# API配置
API_BASE_URL=http://$SERVER_IP/api/v1

# 客户端配置
CLIENT_MAX_BODY_SIZE=10m
EOF

chmod 600 .env.prod
echo -e "${GREEN}✅ 环境配置已更新${NC}"

log "重新构建镜像..."
docker-compose -f docker-compose.prod.yml build --no-cache

log "启动服务..."
docker-compose -f docker-compose.prod.yml up -d

log "等待服务启动..."
sleep 30

log "检查服务状态..."
docker-compose -f docker-compose.prod.yml ps

log "测试健康检查..."
if curl -f http://localhost:8080/health >/dev/null 2>&1; then
    echo -e "${GREEN}✅ 后端健康检查通过${NC}"
else
    echo -e "${YELLOW}⚠️ 后端健康检查失败，查看日志:${NC}"
    docker-compose -f docker-compose.prod.yml logs --tail=20 backend
fi

if curl -f http://localhost/health >/dev/null 2>&1; then
    echo -e "${GREEN}✅ 前端健康检查通过${NC}"
else
    echo -e "${YELLOW}⚠️ 前端健康检查失败，查看日志:${NC}"
    docker-compose -f docker-compose.prod.yml logs --tail=20 frontend
fi

echo ""
echo -e "${GREEN}🎉 修复完成！${NC}"
echo ""
echo -e "${BLUE}📍 访问地址:${NC}"
echo "前端应用: http://$SERVER_IP"
echo "后端API: http://$SERVER_IP:8080"
echo "API文档: http://$SERVER_IP:8080/api/docs"
echo ""
echo -e "${BLUE}🔧 如果仍有问题，请检查:${NC}"
echo "1. 查看详细日志: docker-compose -f docker-compose.prod.yml logs"
echo "2. 检查端口占用: sudo netstat -tlnp | grep :80"
echo "3. 检查防火墙: sudo ufw status"
echo "4. 重启Docker: sudo systemctl restart docker" 