#!/bin/bash

# 远程Ubuntu服务器Docker部署脚本
# 适用于生产环境部署

set -e

echo "🚀 开始部署LLM提示词优化平台到远程服务器..."

# 颜色定义
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# 检查必要参数
if [ -z "$1" ]; then
    echo -e "${RED}❌ 错误: 请提供服务器IP地址${NC}"
    echo "用法: ./remote-deploy.sh <服务器IP> [用户名] [端口]"
    echo "示例: ./remote-deploy.sh 192.168.1.100 ubuntu 22"
    exit 1
fi

SERVER_IP=$1
SERVER_USER=${2:-ubuntu}
SSH_PORT=${3:-22}
PROJECT_NAME="prompt-optimizer"
REMOTE_PATH="/opt/$PROJECT_NAME"

echo -e "${BLUE}📋 部署配置:${NC}"
echo "服务器IP: $SERVER_IP"
echo "用户名: $SERVER_USER"
echo "SSH端口: $SSH_PORT"
echo "远程路径: $REMOTE_PATH"
echo ""

# 检查本地Docker是否运行
if ! docker info >/dev/null 2>&1; then
    echo -e "${RED}❌ Docker未运行，请先启动Docker${NC}"
    exit 1
fi

# 检查SSH连接
echo -e "${YELLOW}🔍 检查SSH连接...${NC}"
if ! ssh -p $SSH_PORT -o ConnectTimeout=10 $SERVER_USER@$SERVER_IP "echo 'SSH连接成功'" >/dev/null 2>&1; then
    echo -e "${RED}❌ 无法连接到服务器 $SERVER_USER@$SERVER_IP:$SSH_PORT${NC}"
    echo "请检查:"
    echo "1. 服务器IP地址是否正确"
    echo "2. SSH服务是否运行"
    echo "3. 防火墙是否允许SSH连接"
    echo "4. SSH密钥是否配置正确"
    exit 1
fi
echo -e "${GREEN}✅ SSH连接正常${NC}"

# 检查远程Docker
echo -e "${YELLOW}🔍 检查远程Docker环境...${NC}"
if ! ssh -p $SSH_PORT $SERVER_USER@$SERVER_IP "docker --version && docker-compose --version" >/dev/null 2>&1; then
    echo -e "${RED}❌ 远程服务器Docker环境未准备就绪${NC}"
    echo "请在远程服务器上安装Docker和Docker Compose:"
    echo "curl -fsSL https://get.docker.com | sh"
    echo "sudo usermod -aG docker $SERVER_USER"
    exit 1
fi
echo -e "${GREEN}✅ 远程Docker环境正常${NC}"

# 创建远程目录
echo -e "${YELLOW}📁 创建远程部署目录...${NC}"
ssh -p $SSH_PORT $SERVER_USER@$SERVER_IP "
    sudo mkdir -p $REMOTE_PATH
    sudo chown -R $SERVER_USER:$SERVER_USER $REMOTE_PATH
    mkdir -p $REMOTE_PATH/data
    chmod 755 $REMOTE_PATH/data
"

# 同步项目文件
echo -e "${YELLOW}📤 同步项目文件到远程服务器...${NC}"
rsync -avz --progress \
    --exclude='.git' \
    --exclude='node_modules' \
    --exclude='__pycache__' \
    --exclude='*.pyc' \
    --exclude='.venv' \
    --exclude='frontend/dist' \
    --exclude='frontend/node_modules' \
    --exclude='*.log' \
    --exclude='.env' \
    -e "ssh -p $SSH_PORT" \
    ./ $SERVER_USER@$SERVER_IP:$REMOTE_PATH/

echo -e "${GREEN}✅ 文件同步完成${NC}"

# 创建生产环境配置
echo -e "${YELLOW}⚙️ 配置生产环境...${NC}"
ssh -p $SSH_PORT $SERVER_USER@$SERVER_IP "
    cd $REMOTE_PATH
    
    # 创建生产环境变量文件
    cat > .env.prod << 'EOF'
# 生产环境配置
ENVIRONMENT=production
DATABASE_URL=sqlite:///./data/prompt_optimizer.db

# CORS配置 - 请根据实际域名修改
ALLOWED_ORIGINS=http://$SERVER_IP,https://yourdomain.com

# LLM API配置 - 请添加您的API密钥
# OPENAI_API_KEY=your_openai_api_key_here
# ANTHROPIC_API_KEY=your_anthropic_api_key_here
# GOOGLE_API_KEY=your_google_api_key_here

# 日志配置
LOG_LEVEL=INFO
EOF

    # 设置文件权限
    chmod 600 .env.prod
    
    # 创建数据备份目录
    mkdir -p ./backups
    
    echo '生产环境配置完成'
"

# 构建和启动服务
echo -e "${YELLOW}🔨 构建并启动Docker服务...${NC}"
ssh -p $SSH_PORT $SERVER_USER@$SERVER_IP "
    cd $REMOTE_PATH
    
    # 停止现有容器
    docker-compose -f docker-compose.prod.yml down --remove-orphans 2>/dev/null || true
    
    # 构建镜像
    echo '开始构建Docker镜像...'
    docker-compose -f docker-compose.prod.yml build --no-cache
    
    # 启动服务
    echo '启动服务...'
    docker-compose -f docker-compose.prod.yml up -d
    
    # 等待服务启动
    echo '等待服务启动...'
    sleep 30
    
    # 检查服务状态
    docker-compose -f docker-compose.prod.yml ps
"

# 健康检查
echo -e "${YELLOW}🔍 执行健康检查...${NC}"
sleep 10

if curl -f http://$SERVER_IP/health >/dev/null 2>&1; then
    echo -e "${GREEN}✅ 前端服务健康检查通过${NC}"
else
    echo -e "${YELLOW}⚠️ 前端服务健康检查失败，可能还在启动中${NC}"
fi

if curl -f http://$SERVER_IP:8080/health >/dev/null 2>&1; then
    echo -e "${GREEN}✅ 后端服务健康检查通过${NC}"
else
    echo -e "${YELLOW}⚠️ 后端服务健康检查失败，可能还在启动中${NC}"
fi

echo ""
echo -e "${GREEN}🎉 部署完成！${NC}"
echo ""
echo -e "${BLUE}📍 访问地址:${NC}"
echo "前端应用: http://$SERVER_IP"
echo "后端API: http://$SERVER_IP:8080"
echo "API文档: http://$SERVER_IP:8080/api/docs"
echo ""
echo -e "${BLUE}🔧 管理命令:${NC}"
echo "查看服务状态: ssh -p $SSH_PORT $SERVER_USER@$SERVER_IP 'cd $REMOTE_PATH && docker-compose -f docker-compose.prod.yml ps'"
echo "查看日志: ssh -p $SSH_PORT $SERVER_USER@$SERVER_IP 'cd $REMOTE_PATH && docker-compose -f docker-compose.prod.yml logs -f'"
echo "重启服务: ssh -p $SSH_PORT $SERVER_USER@$SERVER_IP 'cd $REMOTE_PATH && docker-compose -f docker-compose.prod.yml restart'"
echo "停止服务: ssh -p $SSH_PORT $SERVER_USER@$SERVER_IP 'cd $REMOTE_PATH && docker-compose -f docker-compose.prod.yml down'"
echo ""
echo -e "${YELLOW}📝 重要提醒:${NC}"
echo "1. 请在远程服务器上编辑 $REMOTE_PATH/.env.prod 文件，添加您的LLM API密钥"
echo "2. 请根据实际域名修改 ALLOWED_ORIGINS 配置"
echo "3. 建议配置反向代理和SSL证书"
echo "4. 建议设置定期数据备份" 