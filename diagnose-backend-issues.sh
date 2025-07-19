#!/bin/bash

echo "🔍 诊断后端容器问题..."

# 颜色定义
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

print_step() {
    echo -e "${BLUE}🔍 $1${NC}"
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

print_step "步骤 1: 检查容器状态..."
docker-compose -f docker-compose.prod.yml ps

echo ""
print_step "步骤 2: 查看后端容器日志（最近50行）..."
docker-compose -f docker-compose.prod.yml logs --tail=50 backend

echo ""
print_step "步骤 3: 检查后端容器详细信息..."
BACKEND_CONTAINER=$(docker-compose -f docker-compose.prod.yml ps -q backend)
if [ ! -z "$BACKEND_CONTAINER" ]; then
    docker inspect $BACKEND_CONTAINER | jq '.[0].State'
else
    print_error "后端容器未找到"
fi

echo ""
print_step "步骤 4: 测试后端健康检查端点..."
BACKEND_CONTAINER=$(docker-compose -f docker-compose.prod.yml ps -q backend)
if [ ! -z "$BACKEND_CONTAINER" ]; then
    echo "尝试在容器内执行健康检查..."
    docker exec $BACKEND_CONTAINER curl -f http://localhost:8080/health 2>/dev/null || {
        print_warning "健康检查失败，尝试其他端口..."
        docker exec $BACKEND_CONTAINER curl -f http://localhost:8000/health 2>/dev/null || {
            print_error "健康检查端点无法访问"
        }
    }
else
    print_error "无法找到运行中的后端容器"
fi

echo ""
print_step "步骤 5: 检查端口绑定..."
docker-compose -f docker-compose.prod.yml ps | grep backend

echo ""
print_step "步骤 6: 检查数据目录权限..."
ls -la /opt/prompt-optimizer/data/ 2>/dev/null || print_warning "数据目录不存在"

echo ""
print_step "步骤 7: 检查环境变量..."
BACKEND_CONTAINER=$(docker-compose -f docker-compose.prod.yml ps -q backend)
if [ ! -z "$BACKEND_CONTAINER" ]; then
    echo "DATABASE_URL:"
    docker exec $BACKEND_CONTAINER env | grep DATABASE_URL || print_warning "DATABASE_URL未设置"
    echo "PYTHONPATH:"
    docker exec $BACKEND_CONTAINER env | grep PYTHONPATH || print_warning "PYTHONPATH未设置"
fi

echo ""
print_step "步骤 8: 尝试手动启动后端应用..."
BACKEND_CONTAINER=$(docker-compose -f docker-compose.prod.yml ps -q backend)
if [ ! -z "$BACKEND_CONTAINER" ]; then
    echo "检查Python应用启动..."
    docker exec $BACKEND_CONTAINER python -c "
import sys
sys.path.append('/app')
try:
    from app.main import app
    print('✅ 应用模块导入成功')
except Exception as e:
    print(f'❌ 应用模块导入失败: {e}')
"
fi

echo ""
print_warning "如果需要进入容器调试，请运行："
echo "docker exec -it $BACKEND_CONTAINER /bin/bash"

echo ""
print_step "诊断完成！请根据上述信息排查问题。" 