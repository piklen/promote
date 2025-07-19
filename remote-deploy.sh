#!/bin/bash

# 远程Ubuntu服务器Docker部署脚本
# 适用于生产环境部署 - 优化版本

set -e

echo "🚀 开始部署LLM提示词优化平台到远程服务器..."

# 颜色定义
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# 默认配置
DEFAULT_PROJECT_NAME="prompt-optimizer"
DEFAULT_REMOTE_PATH="/opt/prompt-optimizer"

# 显示帮助信息
show_help() {
    echo "用法: $0 [选项] <服务器IP>"
    echo ""
    echo "选项:"
    echo "  -u, --user USER         SSH用户名 (默认: ubuntu)"
    echo "  -p, --port PORT         SSH端口 (默认: 22)"
    echo "  -d, --domain DOMAIN     域名 (用于SSL和CORS配置)"
    echo "  -b, --backup            部署前备份现有数据"
    echo "  -f, --force             强制重新构建镜像"
    echo "  -h, --help              显示此帮助信息"
    echo ""
    echo "示例:"
    echo "  $0 192.168.1.100"
    echo "  $0 -u ubuntu -p 22 -d yourdomain.com -b 192.168.1.100"
    exit 0
}

# 解析命令行参数
SERVER_IP=""
SERVER_USER="ubuntu"
SSH_PORT="22"
DOMAIN=""
BACKUP_ENABLED=false
FORCE_REBUILD=false

while [[ $# -gt 0 ]]; do
    case $1 in
        -u|--user)
            SERVER_USER="$2"
            shift 2
            ;;
        -p|--port)
            SSH_PORT="$2"
            shift 2
            ;;
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
        -h|--help)
            show_help
            ;;
        -*)
            echo -e "${RED}❌ 未知选项: $1${NC}"
            show_help
            ;;
        *)
            if [[ -z "$SERVER_IP" ]]; then
                SERVER_IP="$1"
            else
                echo -e "${RED}❌ 多余参数: $1${NC}"
                show_help
            fi
            shift
            ;;
    esac
done

# 检查必要参数
if [[ -z "$SERVER_IP" ]]; then
    echo -e "${RED}❌ 错误: 请提供服务器IP地址${NC}"
    show_help
fi

PROJECT_NAME="$DEFAULT_PROJECT_NAME"
REMOTE_PATH="$DEFAULT_REMOTE_PATH"

echo -e "${BLUE}📋 部署配置:${NC}"
echo "服务器IP: $SERVER_IP"
echo "用户名: $SERVER_USER"
echo "SSH端口: $SSH_PORT"
echo "远程路径: $REMOTE_PATH"
echo "域名: ${DOMAIN:-'未设置'}"
echo "备份数据: $(if $BACKUP_ENABLED; then echo '是'; else echo '否'; fi)"
echo "强制重构: $(if $FORCE_REBUILD; then echo '是'; else echo '否'; fi)"
echo ""

# 函数：记录日志
log() {
    echo -e "${BLUE}[$(date '+%Y-%m-%d %H:%M:%S')] $1${NC}"
}

# 函数：执行远程命令
remote_exec() {
    ssh -p $SSH_PORT $SERVER_USER@$SERVER_IP "$1"
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

# 检查本地Docker是否运行
log "检查本地Docker环境..."
if ! docker info >/dev/null 2>&1; then
    echo -e "${RED}❌ Docker未运行，请先启动Docker${NC}"
    exit 1
fi
check_result "本地Docker环境检查"

# 检查SSH连接
log "检查SSH连接..."
if ! ssh -p $SSH_PORT -o ConnectTimeout=10 -o BatchMode=yes $SERVER_USER@$SERVER_IP "echo 'SSH连接成功'" >/dev/null 2>&1; then
    echo -e "${RED}❌ 无法连接到服务器 $SERVER_USER@$SERVER_IP:$SSH_PORT${NC}"
    echo "请检查:"
    echo "1. 服务器IP地址是否正确"
    echo "2. SSH服务是否运行"
    echo "3. 防火墙是否允许SSH连接"
    echo "4. SSH密钥是否配置正确"
    exit 1
fi
check_result "SSH连接"

# 检查远程Docker环境
log "检查远程Docker环境..."
if ! remote_exec "docker --version && docker-compose --version" >/dev/null 2>&1; then
    echo -e "${RED}❌ 远程服务器Docker环境未准备就绪${NC}"
    echo "自动安装Docker? (y/N)"
    read -r response
    if [[ "$response" =~ ^([yY][eE][sS]|[yY])$ ]]; then
        log "安装Docker..."
        remote_exec "
            curl -fsSL https://get.docker.com | sh &&
            sudo usermod -aG docker $SERVER_USER &&
            sudo systemctl enable docker &&
            sudo systemctl start docker
        "
        check_result "Docker安装"
        echo -e "${YELLOW}⚠️ 请重新登录SSH会话以使Docker组权限生效${NC}"
        exit 1
    else
        exit 1
    fi
fi
check_result "远程Docker环境"

# 数据备份
if $BACKUP_ENABLED; then
    log "备份现有数据..."
    BACKUP_TIMESTAMP=$(date +%Y%m%d_%H%M%S)
    remote_exec "
        if [ -d '$REMOTE_PATH/data' ]; then
            sudo mkdir -p '$REMOTE_PATH/backups'
            sudo tar -czf '$REMOTE_PATH/backups/data_backup_$BACKUP_TIMESTAMP.tar.gz' -C '$REMOTE_PATH' data/
            echo '数据备份完成: data_backup_$BACKUP_TIMESTAMP.tar.gz'
        else
            echo '没有发现现有数据，跳过备份'
        fi
    "
    check_result "数据备份"
fi

# 创建远程目录
log "准备远程部署环境..."
remote_exec "
    sudo mkdir -p $REMOTE_PATH
    sudo chown -R $SERVER_USER:$SERVER_USER $REMOTE_PATH
    mkdir -p $REMOTE_PATH/{data,logs,backups,ssl}
    chmod 755 $REMOTE_PATH/{data,logs,backups}
"
check_result "远程目录创建"

# 同步项目文件
log "同步项目文件到远程服务器..."
rsync -avz --progress \
    --exclude='.git' \
    --exclude='node_modules' \
    --exclude='__pycache__' \
    --exclude='*.pyc' \
    --exclude='.venv' \
    --exclude='frontend/dist' \
    --exclude='frontend/node_modules' \
    --exclude='*.log' \
    --exclude='.env*' \
    --exclude='data/' \
    --exclude='logs/' \
    --exclude='backups/' \
    -e "ssh -p $SSH_PORT" \
    ./ $SERVER_USER@$SERVER_IP:$REMOTE_PATH/ >/dev/null
check_result "文件同步"

# 创建生产环境配置
log "配置生产环境..."
CORS_ORIGINS="http://$SERVER_IP"
if [[ -n "$DOMAIN" ]]; then
    CORS_ORIGINS="http://$SERVER_IP,https://$DOMAIN,http://$DOMAIN"
fi

remote_exec "
    cd $REMOTE_PATH
    
    # 创建生产环境变量文件
    cat > .env.prod << 'EOF'
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

# API配置基础URL
API_BASE_URL=http://$SERVER_IP/api/v1

# 客户端配置
CLIENT_MAX_BODY_SIZE=10m

# SSL配置（如果有域名）$(if [[ -n "$DOMAIN" ]]; then echo "
SSL_CERT_PATH=./ssl"; fi)
EOF

    # 设置文件权限
    chmod 600 .env.prod
    
    echo '生产环境配置完成'
"
check_result "环境配置"

# 构建和启动服务
log "构建并启动Docker服务..."
BUILD_ARGS=""
if $FORCE_REBUILD; then
    BUILD_ARGS="--no-cache"
fi

remote_exec "
    cd $REMOTE_PATH
    
    # 停止现有容器
    docker-compose -f docker-compose.prod.yml down --remove-orphans 2>/dev/null || true
    
    # 清理未使用的镜像（如果强制重构）
    $(if $FORCE_REBUILD; then echo "docker system prune -f"; fi)
    
    # 构建镜像
    echo '开始构建Docker镜像...'
    docker-compose -f docker-compose.prod.yml build $BUILD_ARGS
    
    # 启动服务
    echo '启动服务...'
    docker-compose -f docker-compose.prod.yml up -d
    
    # 等待服务启动
    echo '等待服务启动完成...'
    sleep 45
"
check_result "Docker服务启动"

# 健康检查
log "执行服务健康检查..."
HEALTH_CHECK_TIMEOUT=60
HEALTH_CHECK_INTERVAL=5
elapsed=0

while [ $elapsed -lt $HEALTH_CHECK_TIMEOUT ]; do
    if curl -f http://$SERVER_IP/health >/dev/null 2>&1; then
        echo -e "${GREEN}✅ 前端服务健康检查通过${NC}"
        FRONTEND_OK=true
        break
    fi
    sleep $HEALTH_CHECK_INTERVAL
    elapsed=$((elapsed + HEALTH_CHECK_INTERVAL))
done

elapsed=0
while [ $elapsed -lt $HEALTH_CHECK_TIMEOUT ]; do
    if curl -f http://$SERVER_IP:8080/health >/dev/null 2>&1; then
        echo -e "${GREEN}✅ 后端服务健康检查通过${NC}"
        BACKEND_OK=true
        break
    fi
    sleep $HEALTH_CHECK_INTERVAL
    elapsed=$((elapsed + HEALTH_CHECK_INTERVAL))
done

if [[ "$FRONTEND_OK" != "true" ]] || [[ "$BACKEND_OK" != "true" ]]; then
    echo -e "${YELLOW}⚠️ 部分服务健康检查失败，查看服务状态:${NC}"
    remote_exec "cd $REMOTE_PATH && docker-compose -f docker-compose.prod.yml ps"
    echo -e "${YELLOW}查看日志:${NC}"
    remote_exec "cd $REMOTE_PATH && docker-compose -f docker-compose.prod.yml logs --tail=50"
fi

echo ""
echo -e "${GREEN}🎉 部署完成！${NC}"
echo ""
echo -e "${BLUE}📍 访问地址:${NC}"
echo "前端应用: http://$SERVER_IP"
if [[ -n "$DOMAIN" ]]; then
    echo "域名访问: https://$DOMAIN (需配置SSL)"
fi
echo "后端API: http://$SERVER_IP:8080"
echo "API文档: http://$SERVER_IP:8080/api/docs"
echo ""
echo -e "${BLUE}🔧 管理命令:${NC}"
echo "查看服务状态: ssh -p $SSH_PORT $SERVER_USER@$SERVER_IP 'cd $REMOTE_PATH && docker-compose -f docker-compose.prod.yml ps'"
echo "查看日志: ssh -p $SSH_PORT $SERVER_USER@$SERVER_IP 'cd $REMOTE_PATH && docker-compose -f docker-compose.prod.yml logs -f'"
echo "重启服务: ssh -p $SSH_PORT $SERVER_USER@$SERVER_IP 'cd $REMOTE_PATH && docker-compose -f docker-compose.prod.yml restart'"
echo "停止服务: ssh -p $SSH_PORT $SERVER_USER@$SERVER_IP 'cd $REMOTE_PATH && docker-compose -f docker-compose.prod.yml down'"
echo ""
echo -e "${YELLOW}📝 下一步操作:${NC}"
echo "1. 访问前端界面，在设置页面配置您的LLM API密钥"
echo "2. 如果有域名，请配置反向代理和SSL证书"
echo "3. 建议设置定期数据备份计划"
if $BACKUP_ENABLED; then
    echo "4. 数据备份保存在: $REMOTE_PATH/backups/"
fi
echo ""
echo -e "${GREEN}🔐 安全提醒:${NC}"
echo "• 所有API密钥都通过前端界面管理，未存储在配置文件中"
echo "• 建议配置防火墙，只开放必要端口 (80, 443, SSH)"
echo "• 定期更新系统和Docker镜像" 