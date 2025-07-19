#!/bin/bash

# 修复依赖问题并重新部署脚本
# 适用于解决 cryptography 版本冲突等问题

set -e

echo "🔧 开始修复并重新部署..."

# 颜色定义
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# 检查是否在项目目录中
if [ ! -f "docker-compose.prod.yml" ]; then
    echo -e "${RED}❌ 错误: 请在项目根目录中运行此脚本${NC}"
    echo "当前目录: $(pwd)"
    echo "请先执行: cd /opt/prompt-optimizer/promote"
    exit 1
fi

echo -e "${BLUE}📍 当前工作目录: $(pwd)${NC}"

# 停止现有容器
echo -e "${YELLOW}🛑 停止现有容器...${NC}"
docker-compose -f docker-compose.prod.yml down --remove-orphans 2>/dev/null || true

# 清理Docker缓存
echo -e "${YELLOW}🧹 清理Docker构建缓存...${NC}"
docker builder prune -f 2>/dev/null || true
docker system prune -f 2>/dev/null || true

# 删除旧镜像
echo -e "${YELLOW}🗑️ 删除旧的Docker镜像...${NC}"
docker rmi $(docker images | grep prompt-optimizer | awk '{print $3}') 2>/dev/null || true

# 拉取最新代码
echo -e "${YELLOW}📥 拉取最新代码...${NC}"
git stash 2>/dev/null || true
git pull origin main || {
    echo -e "${YELLOW}⚠️ 无法拉取最新代码，使用当前代码继续...${NC}"
}

# 确保数据目录存在
echo -e "${YELLOW}📁 创建必要目录...${NC}"
mkdir -p ./data ./backups ./logs
chmod 755 ./data ./logs

# 构建并启动服务（使用新的依赖）
echo -e "${YELLOW}🔨 重新构建并启动服务...${NC}"
docker-compose -f docker-compose.prod.yml build --no-cache --pull

echo -e "${YELLOW}🚀 启动服务...${NC}"
docker-compose -f docker-compose.prod.yml up -d

# 等待服务启动
echo -e "${YELLOW}⏳ 等待服务启动...${NC}"
sleep 30

# 检查服务状态
echo -e "${YELLOW}🔍 检查服务状态...${NC}"
docker-compose -f docker-compose.prod.yml ps

# 健康检查
echo -e "${YELLOW}💓 执行健康检查...${NC}"
sleep 10

# 获取服务器IP
SERVER_IP=$(curl -s ifconfig.me 2>/dev/null || echo "localhost")

# 检查前端
if curl -f http://localhost/health >/dev/null 2>&1; then
    echo -e "${GREEN}✅ 前端服务健康检查通过${NC}"
    FRONTEND_OK=true
else
    echo -e "${YELLOW}⚠️ 前端服务健康检查失败，可能还在启动中${NC}"
    FRONTEND_OK=false
fi

# 检查后端
if curl -f http://localhost:8080/health >/dev/null 2>&1; then
    echo -e "${GREEN}✅ 后端服务健康检查通过${NC}"
    BACKEND_OK=true
else
    echo -e "${YELLOW}⚠️ 后端服务健康检查失败，可能还在启动中${NC}"
    BACKEND_OK=false
fi

# 显示服务日志（如果有问题）
if [ "$FRONTEND_OK" = false ] || [ "$BACKEND_OK" = false ]; then
    echo -e "${YELLOW}📋 显示最近的服务日志:${NC}"
    echo -e "${BLUE}--- 后端日志 ---${NC}"
    docker-compose -f docker-compose.prod.yml logs --tail=20 backend
    echo -e "${BLUE}--- 前端日志 ---${NC}"
    docker-compose -f docker-compose.prod.yml logs --tail=20 frontend
fi

echo ""
echo -e "${GREEN}🎉 修复和重新部署完成！${NC}"
echo ""
echo -e "${BLUE}📍 访问地址:${NC}"
echo "前端应用: http://$SERVER_IP"
echo "后端API: http://$SERVER_IP:8080"
echo "API文档: http://$SERVER_IP:8080/docs"
echo ""
echo -e "${BLUE}🔧 管理命令:${NC}"
echo "查看服务状态: docker-compose -f docker-compose.prod.yml ps"
echo "查看日志: docker-compose -f docker-compose.prod.yml logs -f"
echo "重启服务: docker-compose -f docker-compose.prod.yml restart"
echo "停止服务: docker-compose -f docker-compose.prod.yml down"
echo ""

# 如果服务启动有问题，提供故障排除信息
if [ "$FRONTEND_OK" = false ] || [ "$BACKEND_OK" = false ]; then
    echo -e "${YELLOW}🔧 故障排除建议:${NC}"
    echo "1. 等待2-3分钟后再次检查健康状态"
    echo "2. 查看详细日志: docker-compose -f docker-compose.prod.yml logs -f"
    echo "3. 检查端口占用: netstat -tlnp | grep :80 和 netstat -tlnp | grep :8080"
    echo "4. 重启Docker服务: systemctl restart docker"
    echo "5. 如果问题持续，请联系技术支持"
fi 