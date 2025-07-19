#!/bin/bash

echo "🔧 修复Docker网络问题..."

# 停止所有相关容器
echo "1. 停止所有相关容器..."
docker-compose -f docker-compose.prod.yml down --remove-orphans 2>/dev/null || true

# 清理所有未使用的网络
echo "2. 清理Docker网络..."
docker network prune -f

# 删除特定网络（如果存在）
echo "3. 删除冲突的网络..."
docker network rm promote_app_network 2>/dev/null || true
docker network rm promote-app-network 2>/dev/null || true
docker network rm app_network 2>/dev/null || true

# 清理所有未使用的资源
echo "4. 清理Docker资源..."
docker system prune -f

# 重启Docker daemon（需要root权限）
echo "5. 重启Docker服务..."
if command -v systemctl &> /dev/null; then
    sudo systemctl restart docker
elif command -v service &> /dev/null; then
    sudo service docker restart
else
    echo "⚠️  请手动重启Docker服务"
fi

# 等待Docker重启完成
echo "6. 等待Docker服务启动..."
sleep 10

# 验证Docker状态
echo "7. 验证Docker状态..."
docker version --format 'Docker version: {{.Server.Version}}'

echo "✅ Docker网络修复完成！"
echo "💡 现在可以重新部署应用了" 