#!/bin/bash

# LLM提示词优化平台 - 健康检查脚本

echo "🔍 检查服务健康状态..."

# 检查后端健康状态
echo "检查后端服务..."
BACKEND_STATUS=$(curl -s -o /dev/null -w "%{http_code}" http://localhost:8080/ 2>/dev/null || echo "000")

if [ "$BACKEND_STATUS" = "200" ]; then
    echo "✅ 后端服务正常 (HTTP $BACKEND_STATUS)"
else
    echo "❌ 后端服务异常 (HTTP $BACKEND_STATUS)"
fi

# 检查前端健康状态
echo "检查前端服务..."
FRONTEND_STATUS=$(curl -s -o /dev/null -w "%{http_code}" http://localhost/health 2>/dev/null || echo "000")

if [ "$FRONTEND_STATUS" = "200" ]; then
    echo "✅ 前端服务正常 (HTTP $FRONTEND_STATUS)"
else
    echo "❌ 前端服务异常 (HTTP $FRONTEND_STATUS)"
fi

# 检查Docker容器状态
echo "检查Docker容器状态..."
if command -v docker-compose &> /dev/null; then
    echo "Docker容器状态："
    docker-compose ps 2>/dev/null || docker ps --filter "name=prompt-optimizer"
else
    echo "Docker Compose未安装，跳过容器状态检查"
fi

echo ""
echo "健康检查完成！" 