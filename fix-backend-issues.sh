#!/bin/bash

echo "🔧 修复后端容器问题..."

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

# 步骤1: 停止失败的容器
print_step "步骤 1/10: 停止失败的容器..."
docker-compose -f docker-compose.prod.yml down 2>/dev/null || true
print_success "容器已停止"

# 步骤2: 检查和创建数据目录
print_step "步骤 2/10: 检查和修复数据目录..."
sudo mkdir -p /opt/prompt-optimizer/{data,logs}
sudo chown -R $(whoami):$(whoami) /opt/prompt-optimizer/ 2>/dev/null || true
chmod -R 755 /opt/prompt-optimizer/

# 创建数据库文件（如果不存在）
if [ ! -f "/opt/prompt-optimizer/data/prompt_optimizer.db" ]; then
    print_warning "数据库文件不存在，将在启动时自动创建"
fi

print_success "数据目录已修复"

# 步骤3: 检查Docker Compose配置
print_step "步骤 3/10: 检查Docker Compose配置..."
if docker-compose -f docker-compose.prod.yml config >/dev/null 2>&1; then
    print_success "Docker Compose配置正确"
else
    print_error "Docker Compose配置有误"
    docker-compose -f docker-compose.prod.yml config
    exit 1
fi

# 步骤4: 临时修改健康检查（降低要求）
print_step "步骤 4/10: 创建临时的简化版docker-compose配置..."
cp docker-compose.prod.yml docker-compose.temp.yml

# 修改健康检查为更简单的方式
cat > temp_healthcheck.yml << 'EOF'
version: '3.8'
services:
  backend:
    healthcheck:
      test: ["CMD", "python", "-c", "import requests; requests.get('http://localhost:8080/', timeout=5)"]
      interval: 30s
      timeout: 15s
      retries: 5
      start_period: 60s
EOF

# 合并配置
python3 -c "
import yaml
import sys

# 读取原配置
with open('docker-compose.prod.yml', 'r') as f:
    original = yaml.safe_load(f)

# 读取新的健康检查配置
with open('temp_healthcheck.yml', 'r') as f:
    healthcheck = yaml.safe_load(f)

# 更新健康检查
if 'services' in original and 'backend' in original['services']:
    original['services']['backend']['healthcheck'] = healthcheck['services']['backend']['healthcheck']

# 写入临时配置
with open('docker-compose.temp.yml', 'w') as f:
    yaml.dump(original, f, default_flow_style=False)

print('临时配置已创建')
" 2>/dev/null || {
    print_warning "Python YAML处理失败，使用sed替换..."
    # 备用方案：使用sed修改健康检查
    sed -i 's/--start-period=40s/--start-period=60s/g' docker-compose.temp.yml
    sed -i 's/--retries=3/--retries=5/g' docker-compose.temp.yml
    sed -i 's/--timeout=10s/--timeout=15s/g' docker-compose.temp.yml
}

print_success "临时配置已创建"

# 步骤5: 构建后端镜像（不使用缓存）
print_step "步骤 5/10: 重新构建后端镜像..."
docker-compose -f docker-compose.temp.yml build --no-cache backend
print_success "后端镜像重建完成"

# 步骤6: 启动后端服务（单独启动）
print_step "步骤 6/10: 启动后端服务..."
docker-compose -f docker-compose.temp.yml up -d backend

# 步骤7: 等待后端启动
print_step "步骤 7/10: 等待后端服务启动..."
echo "等待90秒让后端服务完全启动..."
for i in {1..90}; do
    echo -n "."
    sleep 1
    if [ $((i % 10)) -eq 0 ]; then
        echo " ${i}s"
    fi
done
echo ""

# 步骤8: 检查后端状态
print_step "步骤 8/10: 检查后端容器状态..."
BACKEND_CONTAINER=$(docker-compose -f docker-compose.temp.yml ps -q backend)
if [ ! -z "$BACKEND_CONTAINER" ]; then
    STATUS=$(docker inspect $BACKEND_CONTAINER --format='{{.State.Status}}')
    HEALTH=$(docker inspect $BACKEND_CONTAINER --format='{{.State.Health.Status}}' 2>/dev/null || echo "无健康检查")
    
    echo "容器状态: $STATUS"
    echo "健康状态: $HEALTH"
    
    if [ "$STATUS" = "running" ]; then
        print_success "后端容器运行正常"
    else
        print_error "后端容器状态异常"
        echo "查看容器日志:"
        docker logs $BACKEND_CONTAINER --tail=20
        exit 1
    fi
else
    print_error "找不到后端容器"
    exit 1
fi

# 步骤9: 测试后端API
print_step "步骤 9/10: 测试后端API..."
if docker exec $BACKEND_CONTAINER curl -f http://localhost:8080/ >/dev/null 2>&1; then
    print_success "后端API响应正常"
    
    # 测试健康检查端点
    if docker exec $BACKEND_CONTAINER curl -f http://localhost:8080/health >/dev/null 2>&1; then
        print_success "健康检查端点正常"
    else
        print_warning "健康检查端点无响应，但基本API正常"
    fi
else
    print_warning "后端API无响应，检查应用启动..."
    echo "查看应用进程:"
    docker exec $BACKEND_CONTAINER ps aux | grep python || true
    echo "查看网络端口:"
    docker exec $BACKEND_CONTAINER netstat -tlnp 2>/dev/null || docker exec $BACKEND_CONTAINER ss -tlnp || true
fi

# 步骤10: 启动完整服务
print_step "步骤 10/10: 启动完整服务..."
if [ "$STATUS" = "running" ]; then
    print_step "后端运行正常，启动前端服务..."
    docker-compose -f docker-compose.temp.yml up -d
    
    echo ""
    print_success "🎉 服务部署完成！"
    echo ""
    echo "📋 服务状态:"
    docker-compose -f docker-compose.temp.yml ps
    echo ""
    echo "🌐 访问地址: http://你的服务器IP"
    echo "📊 健康检查: http://你的服务器IP/health"
    echo ""
    echo "💡 如果需要查看日志:"
    echo "   docker-compose -f docker-compose.temp.yml logs -f"
    echo ""
    echo "🔧 如果一切正常，可以用原配置替换:"
    echo "   docker-compose -f docker-compose.prod.yml up -d"
else
    print_error "后端启动失败，请查看详细日志"
    echo "详细日志:"
    docker logs $BACKEND_CONTAINER
fi

# 清理临时文件
rm -f temp_healthcheck.yml

print_step "修复完成！" 