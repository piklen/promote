#!/bin/bash

# 生产环境部署脚本
# LLM 提示词优化平台

set -e  # 遇到错误立即退出

# 颜色定义
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

echo -e "${BLUE}========================================${NC}"
echo -e "${BLUE}    LLM 提示词优化平台 - 生产环境部署    ${NC}"
echo -e "${BLUE}========================================${NC}"

# 检查Docker是否安装
if ! command -v docker &> /dev/null; then
    echo -e "${RED}❌ 错误: Docker 未安装${NC}"
    echo -e "${YELLOW}请先安装 Docker: https://docs.docker.com/get-docker/${NC}"
    exit 1
fi

# 检查Docker Compose
if ! docker compose version &> /dev/null && ! docker-compose version &> /dev/null; then
    echo -e "${RED}❌ 错误: Docker Compose 未安装${NC}"
    exit 1
fi

# 设置docker-compose命令
if docker compose version &> /dev/null; then
    DOCKER_COMPOSE="docker compose"
else
    DOCKER_COMPOSE="docker-compose"
fi

echo -e "${YELLOW}🔍 检查项目文件...${NC}"
if [ ! -f "docker-compose.prod.yml" ]; then
    echo -e "${RED}❌ 错误: docker-compose.prod.yml 文件不存在${NC}"
    exit 1
fi

# 停止现有服务
echo -e "${YELLOW}📦 停止现有服务...${NC}"
$DOCKER_COMPOSE -f docker-compose.prod.yml down --remove-orphans

# 清理旧镜像
echo -e "${YELLOW}🧹 清理旧镜像...${NC}"
docker system prune -f

# 构建镜像
echo -e "${YELLOW}🔨 构建Docker镜像...${NC}"
$DOCKER_COMPOSE -f docker-compose.prod.yml build --no-cache

# 启动服务
echo -e "${YELLOW}🚀 启动服务...${NC}"
$DOCKER_COMPOSE -f docker-compose.prod.yml up -d

# 等待服务启动
echo -e "${YELLOW}⏳ 等待服务启动...${NC}"
sleep 30

# 检查服务状态
echo -e "${YELLOW}🔍 检查服务状态...${NC}"
$DOCKER_COMPOSE -f docker-compose.prod.yml ps

# 获取服务器IP
SERVER_IP=$(curl -s ifconfig.me 2>/dev/null || curl -s ipinfo.io/ip 2>/dev/null || hostname -I | awk '{print $1}' || echo "localhost")

echo ""
echo -e "${GREEN}✅ 部署完成！${NC}"
echo ""
echo -e "${BLUE}📍 访问地址:${NC}"
echo "前端应用: http://$SERVER_IP"
echo "后端API: http://$SERVER_IP:8080"
echo "API文档: http://$SERVER_IP:8080/api/docs"
echo ""
echo -e "${BLUE}🔧 常用命令:${NC}"
echo -e "查看日志: $DOCKER_COMPOSE -f docker-compose.prod.yml logs -f"
echo -e "停止服务: $DOCKER_COMPOSE -f docker-compose.prod.yml down"
echo -e "重启服务: $DOCKER_COMPOSE -f docker-compose.prod.yml restart"
echo "" 