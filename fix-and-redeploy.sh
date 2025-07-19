#!/bin/bash

# 修复依赖问题并重新部署脚本
# 适用于解决 cryptography 版本冲突和nginx用户冲突等问题

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

# 清理Docker缓存和镜像
echo -e "${YELLOW}🧹 清理Docker构建缓存和镜像...${NC}"
docker builder prune -f 2>/dev/null || true
docker system prune -f 2>/dev/null || true

# 删除旧镜像（更安全的方式）
echo -e "${YELLOW}🗑️ 删除旧的Docker镜像...${NC}"
docker images | grep -E "(promote|prompt-optimizer)" | awk '{print $3}' | xargs -r docker rmi -f 2>/dev/null || true

# 清理未使用的卷
echo -e "${YELLOW}📦 清理未使用的Docker卷...${NC}"
docker volume prune -f 2>/dev/null || true

# 拉取最新代码
echo -e "${YELLOW}📥 拉取最新代码...${NC}"
git stash 2>/dev/null || true
git pull origin main || {
    echo -e "${YELLOW}⚠️ 无法拉取最新代码，使用当前代码继续...${NC}"
}

# 确保数据目录存在并设置正确权限
echo -e "${YELLOW}📁 创建必要目录并设置权限...${NC}"
mkdir -p ./data ./backups ./logs
chmod 755 ./data ./logs

# 检查并修复docker-compose文件中的版本警告
echo -e "${YELLOW}🔧 检查配置文件...${NC}"
if grep -q "version:" docker-compose.prod.yml 2>/dev/null; then
    echo -e "${YELLOW}ℹ️ 注意: docker-compose版本字段已弃用，但不影响运行${NC}"
fi

# 强制重新构建所有镜像
echo -e "${YELLOW}🔨 强制重新构建Docker镜像...${NC}"
docker-compose -f docker-compose.prod.yml build --no-cache --pull --force-rm

# 验证镜像构建成功
echo -e "${YELLOW}🔍 验证镜像构建...${NC}"
BACKEND_IMAGE=$(docker images | grep promote | grep backend | wc -l)
FRONTEND_IMAGE=$(docker images | grep promote | grep frontend | wc -l)

if [ "$BACKEND_IMAGE" -eq 0 ] || [ "$FRONTEND_IMAGE" -eq 0 ]; then
    echo -e "${RED}❌ 镜像构建失败，显示构建日志...${NC}"
    docker-compose -f docker-compose.prod.yml build --no-cache 2>&1 | tail -50
    exit 1
fi

echo -e "${GREEN}✅ 镜像构建成功${NC}"

# 启动服务
echo -e "${YELLOW}🚀 启动服务...${NC}"
docker-compose -f docker-compose.prod.yml up -d

# 等待服务启动
echo -e "${YELLOW}⏳ 等待服务启动...${NC}"
for i in {1..6}; do
    echo "等待 ${i}0 秒..."
    sleep 10
    
    # 检查容器状态
    RUNNING_CONTAINERS=$(docker-compose -f docker-compose.prod.yml ps --services --filter "status=running" | wc -l)
    if [ "$RUNNING_CONTAINERS" -eq 2 ]; then
        echo -e "${GREEN}✅ 所有服务已启动${NC}"
        break
    fi
done

# 检查服务状态
echo -e "${YELLOW}🔍 检查服务状态...${NC}"
docker-compose -f docker-compose.prod.yml ps

# 获取服务器IP
SERVER_IP=$(curl -s ifconfig.me 2>/dev/null || curl -s ipinfo.io/ip 2>/dev/null || echo "localhost")

# 健康检查
echo -e "${YELLOW}💓 执行健康检查...${NC}"
sleep 10

# 检查前端
FRONTEND_HEALTH_URLS=("http://localhost/health" "http://localhost:80/health")
FRONTEND_OK=false
for url in "${FRONTEND_HEALTH_URLS[@]}"; do
    if curl -f -m 10 "$url" >/dev/null 2>&1; then
        echo -e "${GREEN}✅ 前端服务健康检查通过 ($url)${NC}"
        FRONTEND_OK=true
        break
    fi
done

if [ "$FRONTEND_OK" = false ]; then
    echo -e "${YELLOW}⚠️ 前端服务健康检查失败，检查容器状态...${NC}"
    docker-compose -f docker-compose.prod.yml logs --tail=10 frontend
fi

# 检查后端
BACKEND_HEALTH_URLS=("http://localhost:8080/health" "http://127.0.0.1:8080/health")
BACKEND_OK=false
for url in "${BACKEND_HEALTH_URLS[@]}"; do
    if curl -f -m 10 "$url" >/dev/null 2>&1; then
        echo -e "${GREEN}✅ 后端服务健康检查通过 ($url)${NC}"
        BACKEND_OK=true
        break
    fi
done

if [ "$BACKEND_OK" = false ]; then
    echo -e "${YELLOW}⚠️ 后端服务健康检查失败，检查容器状态...${NC}"
    docker-compose -f docker-compose.prod.yml logs --tail=10 backend
fi

# 显示详细的容器信息
echo -e "${BLUE}📊 容器详细状态:${NC}"
docker-compose -f docker-compose.prod.yml ps -a

# 显示服务日志（如果有问题）
if [ "$FRONTEND_OK" = false ] || [ "$BACKEND_OK" = false ]; then
    echo -e "${YELLOW}📋 显示最近的服务日志:${NC}"
    echo -e "${BLUE}--- 后端日志（最近20行）---${NC}"
    docker-compose -f docker-compose.prod.yml logs --tail=20 backend 2>/dev/null || echo "无法获取后端日志"
    echo -e "${BLUE}--- 前端日志（最近20行）---${NC}"
    docker-compose -f docker-compose.prod.yml logs --tail=20 frontend 2>/dev/null || echo "无法获取前端日志"
fi

echo ""
echo -e "${GREEN}🎉 修复和重新部署完成！${NC}"
echo ""
echo -e "${BLUE}📍 访问地址:${NC}"
echo "前端应用: http://$SERVER_IP"
echo "后端API: http://$SERVER_IP:8080"
echo "API文档: http://$SERVER_IP:8080/docs"
if [ "$SERVER_IP" != "localhost" ]; then
    echo "本地测试: http://localhost 和 http://localhost:8080"
fi
echo ""
echo -e "${BLUE}🔧 管理命令:${NC}"
echo "查看服务状态: docker-compose -f docker-compose.prod.yml ps"
echo "查看实时日志: docker-compose -f docker-compose.prod.yml logs -f"
echo "查看后端日志: docker-compose -f docker-compose.prod.yml logs -f backend"
echo "查看前端日志: docker-compose -f docker-compose.prod.yml logs -f frontend"
echo "重启服务: docker-compose -f docker-compose.prod.yml restart"
echo "停止服务: docker-compose -f docker-compose.prod.yml down"
echo ""

# 如果服务启动有问题，提供故障排除信息
if [ "$FRONTEND_OK" = false ] || [ "$BACKEND_OK" = false ]; then
    echo -e "${YELLOW}🔧 故障排除建议:${NC}"
    echo "1. 等待2-3分钟后再次检查健康状态"
    echo "2. 手动测试: curl http://localhost/health 和 curl http://localhost:8080/health"
    echo "3. 查看详细日志: docker-compose -f docker-compose.prod.yml logs -f"
    echo "4. 检查端口占用: netstat -tlnp | grep :80 和 netstat -tlnp | grep :8080"
    echo "5. 重启Docker服务: systemctl restart docker"
    echo "6. 如果问题持续，手动进入容器检查: docker exec -it prompt-optimizer-backend-prod bash"
else
    echo -e "${GREEN}🎯 部署成功！所有服务都已正常运行${NC}"
    echo -e "${GREEN}🌐 现在可以访问应用了：http://$SERVER_IP${NC}"
fi 