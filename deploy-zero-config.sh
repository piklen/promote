#!/bin/bash

# 零配置部署脚本
# LLM 提示词优化平台 - 一键部署，所有配置通过前端界面完成

set -e  # 遇到错误立即退出

# 颜色定义
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

echo -e "${BLUE}========================================${NC}"
echo -e "${BLUE}   LLM 提示词优化平台 - 零配置部署      ${NC}"
echo -e "${BLUE}========================================${NC}"
echo -e "${GREEN}✨ 无需配置环境变量，开箱即用！${NC}"
echo -e "${GREEN}✨ 所有配置通过前端界面完成！${NC}"
echo ""

# 检查 Docker 和 Docker Compose
check_dependencies() {
    echo -e "${YELLOW}🔍 检查依赖...${NC}"
    
    if ! command -v docker &> /dev/null; then
        echo -e "${RED}❌ 错误: Docker 未安装${NC}"
        echo -e "${YELLOW}请安装 Docker: https://docs.docker.com/get-docker/${NC}"
        exit 1
    fi
    
    if ! command -v docker-compose &> /dev/null && ! docker compose version &> /dev/null; then
        echo -e "${RED}❌ 错误: Docker Compose 未安装${NC}"
        echo -e "${YELLOW}请安装 Docker Compose: https://docs.docker.com/compose/install/${NC}"
        exit 1
    fi
    
    echo -e "${GREEN}✅ 依赖检查通过${NC}"
}

# 创建必要的目录
create_directories() {
    echo -e "${YELLOW}📁 创建必要的目录...${NC}"
    
    mkdir -p ssl logs
    
    # 创建空的SSL证书目录（如果需要HTTPS）
    if [ ! -f ssl/README.txt ]; then
        cat > ssl/README.txt << EOF
SSL证书目录
===========

如需启用HTTPS，请将SSL证书文件放置在此目录：
- 证书文件: server.crt
- 私钥文件: server.key

注意：HTTP访问无需SSL证书
EOF
    fi
    
    echo -e "${GREEN}✅ 目录创建完成${NC}"
}

# 检查并停止现有容器
stop_existing_containers() {
    echo -e "${YELLOW}🛑 检查现有容器...${NC}"
    
    if docker ps -a --format "table {{.Names}}" | grep -q "prompt-optimizer"; then
        echo -e "${YELLOW}发现现有容器，正在停止...${NC}"
        docker-compose -f docker-compose.prod.yml down --remove-orphans 2>/dev/null || true
        echo -e "${GREEN}✅ 现有容器已停止${NC}"
    else
        echo -e "${GREEN}✅ 没有找到现有容器${NC}"
    fi
}

# 清理 Docker 缓存（可选）
cleanup_docker() {
    echo -e "${YELLOW}🧹 清理 Docker 缓存...${NC}"
    
    # 删除未使用的镜像
    docker image prune -f >/dev/null 2>&1 || true
    
    echo -e "${GREEN}✅ Docker 缓存清理完成${NC}"
}

# 构建并启动服务
build_and_start() {
    echo -e "${YELLOW}🔨 构建并启动服务...${NC}"
    echo -e "${BLUE}这可能需要几分钟时间，请耐心等待...${NC}"
    
    # 构建镜像
    echo -e "${BLUE}📦 构建镜像...${NC}"
    if docker-compose -f docker-compose.prod.yml build --no-cache; then
        echo -e "${GREEN}✅ 镜像构建成功${NC}"
    else
        echo -e "${RED}❌ 镜像构建失败${NC}"
        exit 1
    fi
    
    # 启动服务
    echo -e "${BLUE}🚀 启动服务...${NC}"
    if docker-compose -f docker-compose.prod.yml up -d; then
        echo -e "${GREEN}✅ 服务启动成功${NC}"
    else
        echo -e "${RED}❌ 服务启动失败${NC}"
        exit 1
    fi
    
    # 等待服务启动
    echo -e "${YELLOW}⏳ 等待服务完全启动（约60秒）...${NC}"
    sleep 60
    
    # 检查服务状态
    check_service_health
}

# 检查服务健康状态
check_service_health() {
    echo -e "${YELLOW}🏥 检查服务健康状态...${NC}"
    
    # 检查后端健康状态
    for i in {1..10}; do
        BACKEND_HEALTH=$(curl -s -o /dev/null -w "%{http_code}" http://localhost:8080/health 2>/dev/null || echo "000")
        
        if [ "$BACKEND_HEALTH" = "200" ]; then
            echo -e "${GREEN}✅ 后端服务健康${NC}"
            break
        else
            if [ $i -eq 10 ]; then
                echo -e "${RED}❌ 后端服务不健康 (HTTP $BACKEND_HEALTH)${NC}"
                echo -e "${YELLOW}查看后端日志:${NC}"
                docker logs prompt-optimizer-backend-prod --tail 20
                return 1
            else
                echo -e "${YELLOW}⏳ 等待后端服务启动... ($i/10)${NC}"
                sleep 10
            fi
        fi
    done
    
    # 检查前端健康状态
    for i in {1..5}; do
        FRONTEND_HEALTH=$(curl -s -o /dev/null -w "%{http_code}" http://localhost/ 2>/dev/null || echo "000")
        
        if [ "$FRONTEND_HEALTH" = "200" ]; then
            echo -e "${GREEN}✅ 前端服务健康${NC}"
            break
        else
            if [ $i -eq 5 ]; then
                echo -e "${RED}❌ 前端服务不健康 (HTTP $FRONTEND_HEALTH)${NC}"
                echo -e "${YELLOW}查看前端日志:${NC}"
                docker logs prompt-optimizer-frontend-prod --tail 20
                return 1
            else
                echo -e "${YELLOW}⏳ 等待前端服务启动... ($i/5)${NC}"
                sleep 5
            fi
        fi
    done
    
    # 显示容器状态
    echo -e "${YELLOW}📊 容器状态:${NC}"
    docker-compose -f docker-compose.prod.yml ps
}

# 显示部署后信息
show_deployment_info() {
    echo ""
    echo -e "${BLUE}========================================${NC}"
    echo -e "${GREEN}🎉 部署完成！${NC}"
    echo -e "${BLUE}========================================${NC}"
    echo ""
    echo -e "${GREEN}📱 应用访问地址:${NC}"
    echo -e "   🌐 主页: ${YELLOW}http://localhost${NC}"
    echo -e "   📚 API文档: ${YELLOW}http://localhost:8080/api/docs${NC}"
    echo -e "   🏥 健康检查: ${YELLOW}http://localhost:8080/health${NC}"
    echo ""
    echo -e "${GREEN}🔧 首次使用指南:${NC}"
    echo -e "   1. 打开浏览器访问 ${YELLOW}http://localhost${NC}"
    echo -e "   2. 进入 ${YELLOW}API配置${NC} 页面"
    echo -e "   3. 添加你的 LLM API 配置（OpenAI、Claude等）"
    echo -e "   4. 开始使用提示词优化功能！"
    echo ""
    echo -e "${GREEN}🛠️ 常用管理命令:${NC}"
    echo -e "   查看日志: ${YELLOW}docker-compose -f docker-compose.prod.yml logs -f${NC}"
    echo -e "   停止服务: ${YELLOW}docker-compose -f docker-compose.prod.yml down${NC}"
    echo -e "   重启服务: ${YELLOW}docker-compose -f docker-compose.prod.yml restart${NC}"
    echo -e "   查看状态: ${YELLOW}docker-compose -f docker-compose.prod.yml ps${NC}"
    echo ""
    echo -e "${GREEN}💾 数据存储:${NC}"
    echo -e "   数据库: Docker卷 ${YELLOW}prompt-optimizer-data-prod${NC}"
    echo -e "   日志: Docker卷 ${YELLOW}prompt-optimizer-logs-prod${NC}"
    echo ""
    echo -e "${YELLOW}⚠️  注意事项:${NC}"
    echo -e "   • 首次使用需要在前端配置 LLM API"
    echo -e "   • 数据存储在 Docker 卷中，删除卷会丢失数据"
    echo -e "   • 如需外网访问，请配置防火墙和反向代理"
    echo ""
    echo -e "${GREEN}🔒 安全提示:${NC}"
    echo -e "   • API密钥将被安全加密存储"
    echo -e "   • 建议在生产环境配置HTTPS"
    echo -e "   • 定期备份数据库文件"
    echo ""
    echo -e "${BLUE}========================================${NC}"
    echo -e "${GREEN}✨ 享受 LLM 提示词优化之旅！${NC}"
    echo -e "${BLUE}========================================${NC}"
}

# 错误处理
handle_error() {
    echo ""
    echo -e "${RED}❌ 部署过程中出现错误${NC}"
    echo -e "${YELLOW}请检查以下内容:${NC}"
    echo -e "   • Docker 是否正常运行"
    echo -e "   • 端口 80 和 8080 是否被占用"
    echo -e "   • 是否有足够的磁盘空间"
    echo ""
    echo -e "${YELLOW}获取帮助:${NC}"
    echo -e "   • 查看日志: docker-compose -f docker-compose.prod.yml logs"
    echo -e "   • 检查容器: docker ps -a"
    echo ""
    exit 1
}

# 设置错误处理
trap handle_error ERR

# 主执行流程
main() {
    echo -e "${BLUE}开始零配置部署流程...${NC}"
    
    check_dependencies
    create_directories
    stop_existing_containers
    cleanup_docker
    build_and_start
    show_deployment_info
}

# 执行主函数
main "$@" 