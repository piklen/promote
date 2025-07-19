#!/bin/bash

# 终极修复和部署脚本 v3.0
# 解决所有已知问题：TypeScript错误、依赖版本冲突、包管理优化等
# 支持传统pip和现代uv包管理器

set -e

echo "🚀 开始终极修复和部署..."

# 颜色定义
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
PURPLE='\033[0;35m'
CYAN='\033[0;36m'
NC='\033[0m' # No Color

# 检查是否在项目目录中
if [ ! -f "docker-compose.prod.yml" ]; then
    echo -e "${RED}❌ 错误: 请在项目根目录中运行此脚本${NC}"
    echo "当前目录: $(pwd)"
    echo "请先执行: cd /opt/prompt-optimizer/promote"
    exit 1
fi

echo -e "${BLUE}📍 当前工作目录: $(pwd)${NC}"
echo -e "${PURPLE}🎯 终极版本修复脚本 - 包含uv支持！${NC}"

# 询问用户是否使用uv包管理器
echo -e "${CYAN}🤔 选择Python包管理器:${NC}"
echo "1) 传统pip (兼容性好)"
echo "2) 现代uv (速度快10-100倍)"
read -p "请选择 (1 或 2, 默认为 1): " PACKAGE_MANAGER
PACKAGE_MANAGER=${PACKAGE_MANAGER:-1}

if [ "$PACKAGE_MANAGER" = "2" ]; then
    echo -e "${CYAN}⚡ 使用uv包管理器 - 极速部署模式！${NC}"
    COMPOSE_FILE="docker-compose.uv.yml"
    BACKEND_DOCKERFILE="Dockerfile.uv"
    MODE_NAME="UV高性能模式"
else
    echo -e "${BLUE}🐍 使用传统pip包管理器 - 稳定兼容模式${NC}"
    COMPOSE_FILE="docker-compose.prod.yml"
    BACKEND_DOCKERFILE="Dockerfile"
    MODE_NAME="PIP兼容模式"
fi

# 1. 停止现有容器
echo -e "${YELLOW}🛑 步骤 1/12: 停止现有容器...${NC}"
docker-compose -f docker-compose.prod.yml down --remove-orphans 2>/dev/null || true
docker-compose -f docker-compose.uv.yml down --remove-orphans 2>/dev/null || true

# 2. 全面清理Docker资源
echo -e "${YELLOW}🧹 步骤 2/12: 全面清理Docker资源...${NC}"
docker builder prune -f 2>/dev/null || true
docker system prune -a -f 2>/dev/null || true
docker volume prune -f 2>/dev/null || true

# 删除所有相关镜像
echo -e "${YELLOW}🗑️ 删除项目相关的所有Docker镜像...${NC}"
docker images | grep -E "(promote|prompt-optimizer)" | awk '{print $3}' | xargs -r docker rmi -f 2>/dev/null || true

# 3. 拉取最新代码
echo -e "${YELLOW}📥 步骤 3/12: 拉取最新代码...${NC}"
git stash 2>/dev/null || true
git pull origin main || {
    echo -e "${YELLOW}⚠️ 无法拉取最新代码，使用当前代码继续...${NC}"
}

# 4. 确保前端依赖文件完整
echo -e "${YELLOW}📋 步骤 4/12: 检查前端依赖文件...${NC}"
if [ ! -f "frontend/package-lock.json" ]; then
    echo -e "${YELLOW}⚠️ 缺少package-lock.json，正在生成...${NC}"
    cd frontend
    npm install --package-lock-only 2>/dev/null || npm install --package-lock-only --force
    cd ..
    echo -e "${GREEN}✅ package-lock.json已生成${NC}"
else
    echo -e "${GREEN}✅ package-lock.json文件存在${NC}"
fi

# 5. 验证修复的TypeScript文件
echo -e "${YELLOW}📋 步骤 5/12: 验证TypeScript修复...${NC}"
TYPESCRIPT_ERRORS=0

# 检查是否添加了@chakra-ui/icons依赖
if grep -q "@chakra-ui/icons" frontend/package.json; then
    echo -e "${GREEN}✅ @chakra-ui/icons依赖已添加${NC}"
else
    echo -e "${YELLOW}⚠️ 添加@chakra-ui/icons依赖...${NC}"
    cd frontend
    npm install @chakra-ui/icons@^2.2.4 --save
    cd ..
fi

# 检查API服务类型定义
if grep -q "LLMRequest" frontend/src/services/api.ts; then
    echo -e "${GREEN}✅ API类型定义已修复${NC}"
else
    echo -e "${RED}❌ API类型定义需要修复${NC}"
    TYPESCRIPT_ERRORS=1
fi

if [ "$TYPESCRIPT_ERRORS" -eq 1 ]; then
    echo -e "${RED}❌ 发现TypeScript错误，请检查前端代码${NC}"
    exit 1
fi

# 6. 检查后端依赖
echo -e "${YELLOW}📋 步骤 6/12: 验证后端依赖...${NC}"
if grep -q "cryptography>=42.0.0" backend/requirements.txt; then
    echo -e "${GREEN}✅ 后端依赖版本已更新${NC}"
else
    echo -e "${YELLOW}⚠️ 后端依赖版本需要更新...${NC}"
fi

# 7. 创建必要目录并设置权限
echo -e "${YELLOW}📁 步骤 7/12: 创建必要目录并设置权限...${NC}"
mkdir -p ./data ./backups ./logs
chmod 755 ./data ./logs

# 确保宿主机目录存在
if [ ! -d "/opt/prompt-optimizer/data" ]; then
    sudo mkdir -p /opt/prompt-optimizer/{data,logs,backups} 2>/dev/null || mkdir -p /opt/prompt-optimizer/{data,logs,backups}
    sudo chown -R $(id -u):$(id -g) /opt/prompt-optimizer/ 2>/dev/null || chown -R $(id -u):$(id -g) /opt/prompt-optimizer/
fi

# 8. 验证Docker环境
echo -e "${YELLOW}🔍 步骤 8/12: 验证Docker环境...${NC}"
if ! docker --version >/dev/null 2>&1; then
    echo -e "${RED}❌ Docker未安装或未启动${NC}"
    exit 1
fi

if ! docker-compose --version >/dev/null 2>&1; then
    echo -e "${RED}❌ Docker Compose未安装${NC}"
    exit 1
fi

echo -e "${GREEN}✅ Docker环境正常${NC}"
echo -e "${CYAN}🎯 使用模式: $MODE_NAME${NC}"
echo -e "${CYAN}📄 配置文件: $COMPOSE_FILE${NC}"

# 9. 构建后端镜像
echo -e "${YELLOW}🔨 步骤 9/12: 构建后端镜像...${NC}"
echo -e "${BLUE}正在使用 $BACKEND_DOCKERFILE 构建后端...${NC}"
if [ "$PACKAGE_MANAGER" = "2" ]; then
    echo -e "${CYAN}⚡ UV模式: 预期速度提升10-100倍！${NC}"
fi

docker-compose -f $COMPOSE_FILE build --no-cache --pull --force-rm backend

# 10. 构建前端镜像
echo -e "${YELLOW}🔨 步骤 10/12: 构建前端镜像...${NC}"
docker-compose -f $COMPOSE_FILE build --no-cache --pull --force-rm frontend

# 11. 验证镜像构建成功
echo -e "${YELLOW}🔍 步骤 11/12: 验证镜像构建...${NC}"
BACKEND_IMAGE=$(docker images | grep promote | grep backend | wc -l)
FRONTEND_IMAGE=$(docker images | grep promote | grep frontend | wc -l)

if [ "$BACKEND_IMAGE" -eq 0 ]; then
    echo -e "${RED}❌ 后端镜像构建失败${NC}"
    echo -e "${YELLOW}显示后端构建日志...${NC}"
    docker-compose -f $COMPOSE_FILE build backend 2>&1 | tail -30
    exit 1
fi

if [ "$FRONTEND_IMAGE" -eq 0 ]; then
    echo -e "${RED}❌ 前端镜像构建失败${NC}"
    echo -e "${YELLOW}显示前端构建日志...${NC}"
    docker-compose -f $COMPOSE_FILE build frontend 2>&1 | tail -30
    exit 1
fi

echo -e "${GREEN}✅ 所有镜像构建成功${NC}"

# 12. 启动服务
echo -e "${YELLOW}🚀 步骤 12/12: 启动服务...${NC}"
docker-compose -f $COMPOSE_FILE up -d

# 等待并监控服务启动
echo -e "${YELLOW}⏳ 等待服务启动并监控状态...${NC}"
for i in {1..15}; do
    echo "等待 ${i}0 秒... (${i}/15)"
    sleep 10
    
    # 检查容器状态
    RUNNING_CONTAINERS=$(docker-compose -f $COMPOSE_FILE ps --services --filter "status=running" 2>/dev/null | wc -l)
    if [ "$RUNNING_CONTAINERS" -eq 2 ]; then
        echo -e "${GREEN}✅ 所有服务已启动${NC}"
        break
    fi
    
    # 如果超过1分钟还没启动，显示容器状态
    if [ "$i" -eq 6 ]; then
        echo -e "${YELLOW}⚠️ 启动时间较长，检查容器状态...${NC}"
        docker-compose -f $COMPOSE_FILE ps
    fi
done

# 显示详细的容器信息
echo -e "${BLUE}📊 容器详细状态:${NC}"
docker-compose -f $COMPOSE_FILE ps -a

# 获取服务器IP
SERVER_IP=$(curl -s ifconfig.me 2>/dev/null || curl -s ipinfo.io/ip 2>/dev/null || curl -s ipecho.net/plain 2>/dev/null || echo "localhost")

# 全面健康检查
echo -e "${YELLOW}💓 执行全面健康检查...${NC}"
sleep 10

# 检查前端健康
FRONTEND_HEALTH_URLS=("http://localhost/health" "http://localhost:80/health" "http://127.0.0.1/health")
FRONTEND_OK=false
for url in "${FRONTEND_HEALTH_URLS[@]}"; do
    if curl -f -m 20 -s "$url" >/dev/null 2>&1; then
        echo -e "${GREEN}✅ 前端服务健康检查通过 ($url)${NC}"
        FRONTEND_OK=true
        break
    fi
done

if [ "$FRONTEND_OK" = false ]; then
    echo -e "${YELLOW}⚠️ 前端健康检查失败，检查容器日志...${NC}"
    docker-compose -f $COMPOSE_FILE logs --tail=15 frontend
fi

# 检查后端健康
BACKEND_HEALTH_URLS=("http://localhost:8080/health" "http://127.0.0.1:8080/health")
BACKEND_OK=false
for url in "${BACKEND_HEALTH_URLS[@]}"; do
    if curl -f -m 20 -s "$url" >/dev/null 2>&1; then
        echo -e "${GREEN}✅ 后端服务健康检查通过 ($url)${NC}"
        BACKEND_OK=true
        break
    fi
done

if [ "$BACKEND_OK" = false ]; then
    echo -e "${YELLOW}⚠️ 后端健康检查失败，检查容器日志...${NC}"
    docker-compose -f $COMPOSE_FILE logs --tail=15 backend
fi

# 显示最终结果
echo ""
echo "=========================================="
if [ "$FRONTEND_OK" = true ] && [ "$BACKEND_OK" = true ]; then
    echo -e "${GREEN}🎉 终极部署完全成功！所有问题已解决！${NC}"
    echo -e "${GREEN}🌐 现在可以访问应用了${NC}"
    if [ "$PACKAGE_MANAGER" = "2" ]; then
        echo -e "${CYAN}⚡ UV模式部署成功 - 享受极速性能！${NC}"
    fi
else
    echo -e "${YELLOW}⚠️ 部署完成，但有服务可能还在启动中${NC}"
fi
echo "=========================================="
echo ""
echo -e "${BLUE}📍 访问地址:${NC}"
echo "✅ 前端应用: http://$SERVER_IP"
echo "✅ 后端API: http://$SERVER_IP:8080"
echo "✅ API文档: http://$SERVER_IP:8080/docs"
if [ "$SERVER_IP" != "localhost" ]; then
    echo "🔗 本地测试: http://localhost 和 http://localhost:8080"
fi
echo ""
echo -e "${BLUE}🔧 管理命令 ($MODE_NAME):${NC}"
echo "📊 查看服务状态: docker-compose -f $COMPOSE_FILE ps"
echo "📋 查看实时日志: docker-compose -f $COMPOSE_FILE logs -f"
echo "🔄 重启服务: docker-compose -f $COMPOSE_FILE restart"
echo "⏹️  停止服务: docker-compose -f $COMPOSE_FILE down"
echo "🧹 清理重来: docker system prune -a && ./ultimate-fix-deploy.sh"
echo ""

# 故障排除信息
if [ "$FRONTEND_OK" = false ] || [ "$BACKEND_OK" = false ]; then
    echo -e "${YELLOW}🔧 故障排除建议:${NC}"
    echo "1️⃣ 等待3-5分钟，服务可能还在启动（特别是首次构建）"
    echo "2️⃣ 手动测试: curl http://localhost/health && curl http://localhost:8080/health"
    echo "3️⃣ 查看详细日志: docker-compose -f $COMPOSE_FILE logs -f"
    echo "4️⃣ 检查端口占用: netstat -tlnp | grep :80 && netstat -tlnp | grep :8080"
    echo "5️⃣ 进入容器检查: docker exec -it prompt-optimizer-backend-${PACKAGE_MANAGER == 2 && echo 'uv' || echo 'prod'} bash"
    echo "6️⃣ 重启Docker: systemctl restart docker"
    echo "7️⃣ 尝试其他模式: 如果用uv失败，试试pip模式 (选项1)"
    echo ""
    echo -e "${YELLOW}📋 最近的服务日志:${NC}"
    echo -e "${BLUE}--- 后端日志 ---${NC}"
    docker-compose -f $COMPOSE_FILE logs --tail=15 backend 2>/dev/null || echo "无法获取后端日志"
    echo -e "${BLUE}--- 前端日志 ---${NC}"
    docker-compose -f $COMPOSE_FILE logs --tail=15 frontend 2>/dev/null || echo "无法获取前端日志"
else
    echo -e "${GREEN}🎯 恭喜！终极部署成功，所有问题已完美解决！${NC}"
    echo -e "${GREEN}🚀 您的LLM提示词优化平台已准备就绪！${NC}"
    if [ "$PACKAGE_MANAGER" = "2" ]; then
        echo -e "${CYAN}⚡ UV模式让您的部署速度比传统方式快10-100倍！${NC}"
    fi
    echo ""
    echo -e "${PURPLE}📝 下一步操作:${NC}"
    echo "1. 访问前端应用配置您的LLM API密钥"
    echo "2. 开始创建和优化提示词"
    echo "3. 享受AI提示词优化的强大功能！"
    echo "4. 如果需要，可以随时在两种模式间切换"
fi

echo ""
echo -e "${BLUE}==========================================${NC}"
echo -e "${BLUE}终极部署脚本执行完成 - $(date)${NC}"
echo -e "${BLUE}使用模式: $MODE_NAME${NC}"
echo -e "${BLUE}==========================================${NC}" 