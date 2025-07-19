#!/bin/bash

# VPS本地一键部署脚本
# 适用于已经在VPS上有项目文件和Docker环境的情况

set -e

echo "🚀 开始在VPS上一键部署LLM提示词优化平台..."

# 颜色定义
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# 显示帮助信息
show_help() {
    echo "用法: $0 [选项]"
    echo ""
    echo "选项:"
    echo "  -d, --domain DOMAIN     域名 (用于SSL和CORS配置)"
    echo "  -b, --backup            部署前备份现有数据"
    echo "  -f, --force             强制重新构建镜像"
    echo "  -c, --clean             清理所有Docker资源后重新部署"
    echo "  -h, --help              显示此帮助信息"
    echo ""
    echo "示例:"
    echo "  $0                      # 基本部署"
    echo "  $0 -d yourdomain.com    # 带域名部署"
    echo "  $0 -b -f               # 备份数据并强制重构"
    echo "  $0 -c                  # 清理重新部署"
    exit 0
}

# 解析命令行参数
DOMAIN=""
BACKUP_ENABLED=false
FORCE_REBUILD=false
CLEAN_DEPLOY=false

while [[ $# -gt 0 ]]; do
    case $1 in
        -d|--domain)
            DOMAIN="$2"
            shift 2
            ;;
        -b|--backup)
            BACKUP_ENABLED=true
            shift
            ;;
        -f|--force)
            FORCE_REBUILD=true
            shift
            ;;
        -c|--clean)
            CLEAN_DEPLOY=true
            shift
            ;;
        -h|--help)
            show_help
            ;;
        -*)
            echo -e "${RED}❌ 未知选项: $1${NC}"
            show_help
            ;;
        *)
            echo -e "${RED}❌ 多余参数: $1${NC}"
            show_help
            ;;
    esac
done

# 函数：记录日志
log() {
    echo -e "${BLUE}[$(date '+%Y-%m-%d %H:%M:%S')] $1${NC}"
}

# 函数：检查命令执行结果
check_result() {
    if [ $? -eq 0 ]; then
        echo -e "${GREEN}✅ $1${NC}"
    else
        echo -e "${RED}❌ $1失败${NC}"
        exit 1
    fi
}

# 检查是否在项目目录中
log "检查项目环境..."
if [ ! -f "docker-compose.prod.yml" ] || [ ! -f "backend/Dockerfile" ]; then
    echo -e "${RED}❌ 错误: 当前目录不是项目根目录${NC}"
    echo "请确保在项目根目录中运行此脚本，该目录应包含："
    echo "  - docker-compose.prod.yml"
    echo "  - backend/Dockerfile"
    echo "  - frontend/Dockerfile"
    exit 1
fi
echo -e "${GREEN}✅ 项目目录检查通过${NC}"

# 检查Docker环境
log "检查Docker环境..."
if ! command -v docker &> /dev/null; then
    echo -e "${RED}❌ Docker未安装或不可用${NC}"
    exit 1
fi

if ! command -v docker-compose &> /dev/null; then
    echo -e "${RED}❌ Docker Compose未安装或不可用${NC}"
    echo "安装Docker Compose："
    echo "sudo curl -L \"https://github.com/docker/compose/releases/latest/download/docker-compose-\$(uname -s)-\$(uname -m)\" -o /usr/local/bin/docker-compose"
    echo "sudo chmod +x /usr/local/bin/docker-compose"
    exit 1
fi

if ! docker info >/dev/null 2>&1; then
    echo -e "${RED}❌ Docker服务未运行或当前用户无权限访问${NC}"
    echo "请检查："
    echo "1. Docker服务是否运行: sudo systemctl start docker"
    echo "2. 当前用户是否在docker组: sudo usermod -aG docker \$USER"
    exit 1
fi
echo -e "${GREEN}✅ Docker环境检查通过${NC}"

# 获取服务器IP
SERVER_IP=$(curl -s ifconfig.me 2>/dev/null || curl -s ipinfo.io/ip 2>/dev/null || hostname -I | awk '{print $1}' || echo "localhost")

echo -e "${BLUE}📋 部署配置:${NC}"
echo "项目目录: $(pwd)"
echo "服务器IP: $SERVER_IP"
echo "域名: ${DOMAIN:-'未设置'}"
echo "备份数据: $(if $BACKUP_ENABLED; then echo '是'; else echo '否'; fi)"
echo "强制重构: $(if $FORCE_REBUILD; then echo '是'; else echo '否'; fi)"
echo "清理部署: $(if $CLEAN_DEPLOY; then echo '是'; else echo '否'; fi)"
echo ""

# 数据备份
if $BACKUP_ENABLED && [ -d "data" ]; then
    log "备份现有数据..."
    BACKUP_TIMESTAMP=$(date +%Y%m%d_%H%M%S)
    mkdir -p backups
    tar -czf "backups/data_backup_$BACKUP_TIMESTAMP.tar.gz" data/
    check_result "数据备份"
    echo "备份文件: backups/data_backup_$BACKUP_TIMESTAMP.tar.gz"
fi

# 清理Docker资源
if $CLEAN_DEPLOY; then
    log "清理Docker资源..."
    docker-compose -f docker-compose.prod.yml down --remove-orphans -v 2>/dev/null || true
    docker system prune -f
    docker volume prune -f
    echo -e "${GREEN}✅ Docker资源清理完成${NC}"
fi

# 创建必要的目录
log "准备部署环境..."
mkdir -p data logs backups ssl
chmod 755 data logs backups
check_result "目录创建"

# 创建生产环境配置
log "配置生产环境..."
CORS_ORIGINS="http://$SERVER_IP"
if [[ -n "$DOMAIN" ]]; then
    CORS_ORIGINS="http://$SERVER_IP,https://$DOMAIN,http://$DOMAIN"
fi

cat > .env.prod << EOF
# 生产环境配置
ENVIRONMENT=production
DATABASE_URL=sqlite:///./data/prompt_optimizer.db
LOG_DIR=/app/logs

# CORS配置
ALLOWED_ORIGINS=$CORS_ORIGINS
ALLOWED_HOSTS=$SERVER_IP$(if [[ -n "$DOMAIN" ]]; then echo ",$DOMAIN"; fi)

# 性能配置
ENABLE_METRICS=false
ENABLE_DEBUG=false

# API配置
API_BASE_URL=http://$SERVER_IP/api/v1

# 客户端配置
CLIENT_MAX_BODY_SIZE=10m

# SSL配置（如果有域名）$(if [[ -n "$DOMAIN" ]]; then echo "
SSL_CERT_PATH=./ssl"; fi)
EOF

# 设置安全权限
chmod 600 .env.prod
check_result "环境配置"

# 停止现有服务
log "停止现有服务..."
docker-compose -f docker-compose.prod.yml down --remove-orphans 2>/dev/null || true

# 构建和启动服务
log "构建Docker镜像..."
BUILD_ARGS=""
if $FORCE_REBUILD; then
    BUILD_ARGS="--no-cache"
fi

docker-compose -f docker-compose.prod.yml build $BUILD_ARGS
check_result "镜像构建"

log "启动服务..."
docker-compose -f docker-compose.prod.yml up -d
check_result "服务启动"

# 等待服务启动
log "等待服务启动完成..."
echo "等待45秒让服务完全启动..."
sleep 45

# 健康检查
log "执行服务健康检查..."
HEALTH_CHECK_TIMEOUT=90
HEALTH_CHECK_INTERVAL=5
elapsed=0

echo "检查前端服务..."
while [ $elapsed -lt $HEALTH_CHECK_TIMEOUT ]; do
    if curl -f http://localhost/health >/dev/null 2>&1; then
        echo -e "${GREEN}✅ 前端服务健康检查通过${NC}"
        FRONTEND_OK=true
        break
    fi
    echo -n "."
    sleep $HEALTH_CHECK_INTERVAL
    elapsed=$((elapsed + HEALTH_CHECK_INTERVAL))
done

if [[ "$FRONTEND_OK" != "true" ]]; then
    echo -e "${YELLOW}⚠️ 前端服务检查超时，但可能仍在启动中${NC}"
fi

elapsed=0
echo "检查后端服务..."
while [ $elapsed -lt $HEALTH_CHECK_TIMEOUT ]; do
    if curl -f http://localhost:8080/health >/dev/null 2>&1; then
        echo -e "${GREEN}✅ 后端服务健康检查通过${NC}"
        BACKEND_OK=true
        break
    fi
    echo -n "."
    sleep $HEALTH_CHECK_INTERVAL
    elapsed=$((elapsed + HEALTH_CHECK_INTERVAL))
done

if [[ "$BACKEND_OK" != "true" ]]; then
    echo -e "${YELLOW}⚠️ 后端服务检查超时，但可能仍在启动中${NC}"
fi

# 显示服务状态
echo ""
log "检查服务状态..."
docker-compose -f docker-compose.prod.yml ps

# 如果健康检查失败，显示日志
if [[ "$FRONTEND_OK" != "true" ]] || [[ "$BACKEND_OK" != "true" ]]; then
    echo ""
    echo -e "${YELLOW}⚠️ 部分服务健康检查失败，显示最近日志:${NC}"
    echo "=== 后端日志 ==="
    docker-compose -f docker-compose.prod.yml logs --tail=20 backend
    echo ""
    echo "=== 前端日志 ==="
    docker-compose -f docker-compose.prod.yml logs --tail=20 frontend
    echo ""
fi

# 部署完成
echo ""
echo -e "${GREEN}🎉 部署完成！${NC}"
echo ""
echo -e "${BLUE}📍 访问地址:${NC}"
echo "┌─────────────────────────────────────────────┐"
echo "│  前端应用: http://$SERVER_IP                │"
if [[ -n "$DOMAIN" ]]; then
echo "│  域名访问: https://$DOMAIN (需配置SSL)     │"
fi
echo "│  后端API:  http://$SERVER_IP:8080          │"
echo "│  API文档:  http://$SERVER_IP:8080/api/docs │"
echo "└─────────────────────────────────────────────┘"
echo ""
echo -e "${BLUE}🔧 常用管理命令:${NC}"
echo "查看服务状态: docker-compose -f docker-compose.prod.yml ps"
echo "查看实时日志: docker-compose -f docker-compose.prod.yml logs -f"
echo "查看后端日志: docker-compose -f docker-compose.prod.yml logs -f backend"
echo "查看前端日志: docker-compose -f docker-compose.prod.yml logs -f frontend"
echo "重启服务:     docker-compose -f docker-compose.prod.yml restart"
echo "停止服务:     docker-compose -f docker-compose.prod.yml down"
echo "更新重部署:   git pull && $0 -f"
echo ""
echo -e "${YELLOW}📝 下一步操作:${NC}"
echo "1. 🌐 访问 http://$SERVER_IP 打开应用"
echo "2. ⚙️  点击'API配置'标签页"
echo "3. 🔑 添加您的LLM提供商API密钥（OpenAI、Anthropic等）"
echo "4. ✨开始创建和优化您的提示词！"
echo ""
if [[ -n "$DOMAIN" ]]; then
    echo -e "${BLUE}🔒 SSL配置提示:${NC}"
    echo "配置域名SSL证书，请参考 DEPLOYMENT.md 文档"
    echo "或运行: sudo certbot --nginx -d $DOMAIN"
    echo ""
fi
echo -e "${GREEN}🔐 安全提醒:${NC}"
echo "• 所有API密钥都通过前端界面管理，安全存储在数据库中"
echo "• 建议配置防火墙，只开放必要端口 (80, 443, SSH)"
echo "• 定期备份数据: $0 -b"
if $BACKUP_ENABLED; then
    echo "• 数据备份已保存在: $(pwd)/backups/"
fi
echo ""
echo -e "${BLUE}📊 监控服务:${NC}"
echo "• 查看资源使用: docker stats"
echo "• 系统监控: htop"
echo "• 磁盘使用: df -h"

# 最终检查并给出状态总结
echo ""
echo -e "${BLUE}📋 部署状态总结:${NC}"
if [[ "$FRONTEND_OK" == "true" ]] && [[ "$BACKEND_OK" == "true" ]]; then
    echo -e "${GREEN}✅ 所有服务运行正常，部署成功！${NC}"
    echo -e "${GREEN}🎯 立即访问: http://$SERVER_IP${NC}"
elif [[ "$FRONTEND_OK" == "true" ]] || [[ "$BACKEND_OK" == "true" ]]; then
    echo -e "${YELLOW}⚠️ 部分服务正常，可能仍在启动中${NC}"
    echo "请稍等片刻或查看日志排查问题"
else
    echo -e "${YELLOW}⚠️ 服务可能仍在启动中，请稍等几分钟后访问${NC}"
    echo "如有问题，请查看日志: docker-compose -f docker-compose.prod.yml logs"
fi 