#!/bin/bash

echo "🔧 修复Docker网络问题并重新部署..."

# 设置错误处理
set -e

# 颜色定义
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

print_step() {
    echo -e "${BLUE}🔧 $1${NC}"
}

print_success() {
    echo -e "${GREEN}✅ $1${NC}"
}

print_warning() {
    echo -e "${YELLOW}⚠️  $1${NC}"
}

print_error() {
    echo -e "${RED}❌ $1${NC}"
}

# 步骤1: 停止所有服务
print_step "步骤 1/8: 停止所有相关服务..."
docker-compose -f docker-compose.prod.yml down --remove-orphans 2>/dev/null || true
print_success "服务已停止"

# 步骤2: 清理Docker网络
print_step "步骤 2/8: 清理Docker网络..."
docker network prune -f
docker network rm promote_app_network 2>/dev/null || true
docker network rm promote-app-network 2>/dev/null || true
docker network rm app_network 2>/dev/null || true
print_success "网络已清理"

# 步骤3: 清理Docker资源
print_step "步骤 3/8: 清理未使用的Docker资源..."
docker system prune -f
print_success "资源已清理"

# 步骤4: 重启Docker服务
print_step "步骤 4/8: 重启Docker服务..."
if command -v systemctl &> /dev/null; then
    sudo systemctl restart docker
    print_success "Docker服务已重启 (systemctl)"
elif command -v service &> /dev/null; then
    sudo service docker restart
    print_success "Docker服务已重启 (service)"
else
    print_warning "请手动重启Docker服务: sudo systemctl restart docker"
    read -p "Docker服务已重启后按Enter继续..."
fi

# 步骤5: 等待Docker启动完成
print_step "步骤 5/8: 等待Docker服务完全启动..."
sleep 15

# 步骤6: 验证Docker状态
print_step "步骤 6/8: 验证Docker状态..."
if docker version > /dev/null 2>&1; then
    print_success "Docker服务运行正常"
else
    print_error "Docker服务异常，请检查"
    exit 1
fi

# 步骤7: 创建必要目录
print_step "步骤 7/8: 创建必要目录..."
sudo mkdir -p /opt/prompt-optimizer/{data,logs}
sudo chown -R $(whoami):$(whoami) /opt/prompt-optimizer/ 2>/dev/null || true
print_success "目录已创建"

# 步骤8: 重新部署
print_step "步骤 8/8: 重新部署应用..."
docker-compose -f docker-compose.prod.yml up -d --build

# 验证部署状态
print_step "验证部署状态..."
sleep 10

if docker-compose -f docker-compose.prod.yml ps | grep -q "Up"; then
    print_success "应用部署成功！"
    echo ""
    echo "📋 部署信息:"
    docker-compose -f docker-compose.prod.yml ps
    echo ""
    echo "🌐 访问地址: http://你的服务器IP"
    echo "📊 健康检查: http://你的服务器IP/health"
else
    print_error "部署失败，请检查日志:"
    docker-compose -f docker-compose.prod.yml logs --tail=50
    exit 1
fi

print_success "🎉 网络修复和重新部署完成！" 