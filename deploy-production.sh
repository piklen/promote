#!/bin/bash

# 生产环境部署脚本
# 用于自动配置和部署 LLM 提示词优化平台

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

# 检查 Docker 和 Docker Compose
check_dependencies() {
    echo -e "${YELLOW}检查依赖...${NC}"
    
    if ! command -v docker &> /dev/null; then
        echo -e "${RED}错误: Docker 未安装${NC}"
        exit 1
    fi
    
    if ! command -v docker-compose &> /dev/null && ! docker compose version &> /dev/null; then
        echo -e "${RED}错误: Docker Compose 未安装${NC}"
        exit 1
    fi
    
    echo -e "${GREEN}依赖检查通过${NC}"
}

# 生成强密码
generate_password() {
    openssl rand -base64 32 | tr -d "=+/" | cut -c1-32
}

# 创建生产环境配置文件
create_env_file() {
    echo -e "${YELLOW}创建生产环境配置文件...${NC}"
    
    # 生成安全密钥
    ENCRYPTION_KEY=$(generate_password)
    SECRET_KEY=$(generate_password)
    
    # 获取用户输入的域名
    read -p "请输入你的域名 (例如: yourdomain.com, 留空默认为 localhost): " DOMAIN
    DOMAIN=${DOMAIN:-localhost}
    
    # 创建 .env.prod 文件
    cat > .env.prod << EOF
# 生产环境配置文件
# 由部署脚本自动生成于 $(date)

# 安全配置
ENCRYPTION_MASTER_KEY=${ENCRYPTION_KEY}
SECRET_KEY=${SECRET_KEY}

# 数据库配置
DATABASE_URL=sqlite:///./data/prompt_optimizer.db

# 环境标识
ENVIRONMENT=production

# CORS配置
ALLOWED_ORIGINS=http://${DOMAIN},https://${DOMAIN},http://www.${DOMAIN},https://www.${DOMAIN},http://localhost
ALLOWED_HOSTS=${DOMAIN},www.${DOMAIN},localhost

# API配置
API_BASE_URL=http://${DOMAIN}/api/v1

# 可选配置
ENABLE_METRICS=false
ENABLE_DEBUG=false
CLIENT_MAX_BODY_SIZE=10m

# 日志配置
LOG_LEVEL=INFO
LOG_DIR=/app/logs
EOF

    echo -e "${GREEN}配置文件创建成功: .env.prod${NC}"
    echo -e "${YELLOW}重要提示: 请妥善保管以下安全密钥${NC}"
    echo -e "ENCRYPTION_MASTER_KEY: ${ENCRYPTION_KEY}"
    echo -e "SECRET_KEY: ${SECRET_KEY}"
}

# 创建必要的目录
create_directories() {
    echo -e "${YELLOW}创建必要的目录...${NC}"
    
    mkdir -p ssl
    mkdir -p logs
    
    echo -e "${GREEN}目录创建完成${NC}"
}

# 检查并停止现有容器
stop_existing_containers() {
    echo -e "${YELLOW}停止现有容器...${NC}"
    
    if docker ps -a --format "table {{.Names}}" | grep -q "prompt-optimizer"; then
        docker-compose -f docker-compose.prod.yml down --remove-orphans
        echo -e "${GREEN}现有容器已停止${NC}"
    else
        echo -e "${GREEN}没有找到现有容器${NC}"
    fi
}

# 清理 Docker 缓存
cleanup_docker() {
    echo -e "${YELLOW}清理 Docker 缓存...${NC}"
    
    # 删除未使用的镜像
    docker image prune -f
    
    # 删除未使用的卷
    docker volume prune -f
    
    echo -e "${GREEN}Docker 缓存清理完成${NC}"
}

# 构建并启动服务
build_and_start() {
    echo -e "${YELLOW}构建并启动服务...${NC}"
    
    # 构建镜像
    echo -e "${BLUE}构建镜像...${NC}"
    docker-compose -f docker-compose.prod.yml build --no-cache
    
    # 启动服务
    echo -e "${BLUE}启动服务...${NC}"
    docker-compose -f docker-compose.prod.yml up -d
    
    # 等待服务启动
    echo -e "${YELLOW}等待服务启动...${NC}"
    sleep 30
    
    # 检查服务状态
    check_service_health
}

# 检查服务健康状态
check_service_health() {
    echo -e "${YELLOW}检查服务健康状态...${NC}"
    
    # 检查后端健康状态
    BACKEND_HEALTH=$(curl -s -o /dev/null -w "%{http_code}" http://localhost:8080/health || echo "000")
    
    if [ "$BACKEND_HEALTH" = "200" ]; then
        echo -e "${GREEN}✓ 后端服务健康${NC}"
    else
        echo -e "${RED}✗ 后端服务不健康 (HTTP $BACKEND_HEALTH)${NC}"
        echo -e "${YELLOW}查看后端日志:${NC}"
        docker logs prompt-optimizer-backend-prod --tail 20
    fi
    
    # 检查前端健康状态
    FRONTEND_HEALTH=$(curl -s -o /dev/null -w "%{http_code}" http://localhost/ || echo "000")
    
    if [ "$FRONTEND_HEALTH" = "200" ]; then
        echo -e "${GREEN}✓ 前端服务健康${NC}"
    else
        echo -e "${RED}✗ 前端服务不健康 (HTTP $FRONTEND_HEALTH)${NC}"
        echo -e "${YELLOW}查看前端日志:${NC}"
        docker logs prompt-optimizer-frontend-prod --tail 20
    fi
    
    # 显示容器状态
    echo -e "${YELLOW}容器状态:${NC}"
    docker-compose -f docker-compose.prod.yml ps
}

# 显示部署后信息
show_deployment_info() {
    echo -e "${BLUE}========================================${NC}"
    echo -e "${GREEN}部署完成！${NC}"
    echo -e "${BLUE}========================================${NC}"
    echo -e "应用访问地址: http://localhost"
    echo -e "API 文档: http://localhost/api/docs"
    echo -e "健康检查: http://localhost/health"
    echo -e ""
    echo -e "${YELLOW}常用命令:${NC}"
    echo -e "查看日志: docker-compose -f docker-compose.prod.yml logs -f"
    echo -e "停止服务: docker-compose -f docker-compose.prod.yml down"
    echo -e "重启服务: docker-compose -f docker-compose.prod.yml restart"
    echo -e ""
    echo -e "${YELLOW}配置文件:${NC}"
    echo -e "环境变量: .env.prod"
    echo -e "数据存储: 容器卷 prompt-optimizer-data-prod"
    echo -e ""
    echo -e "${RED}注意: 请妥善保管 .env.prod 文件中的安全密钥${NC}"
}

# 主执行流程
main() {
    check_dependencies
    create_env_file
    create_directories
    stop_existing_containers
    cleanup_docker
    build_and_start
    show_deployment_info
}

# 执行主函数
main "$@" 