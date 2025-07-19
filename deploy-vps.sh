#!/bin/bash

# VPS部署脚本 - 修复Google自定义模型配置问题
# 使用方法: ./deploy-vps.sh

set -e

echo "🚀 开始VPS部署过程..."

# 检查是否在项目根目录
if [ ! -f "docker-compose.yml" ]; then
    echo "❌ 错误：请在项目根目录运行此脚本"
    exit 1
fi

echo "📦 1. 停止现有容器..."
docker-compose down

echo "🗑️  2. 清理Docker镜像缓存..."
# 删除旧的镜像（可选，确保使用最新代码）
docker image prune -f
docker-compose build --no-cache

echo "🔧 3. 验证关键文件是否存在..."
# 检查修复的文件是否存在
FILES=(
    "backend/app/core/security.py"
    "backend/app/routers/api_config.py"
    "frontend/src/components/core/APIConfig.tsx"
)

for file in "${FILES[@]}"; do
    if [ -f "$file" ]; then
        echo "✅ $file 存在"
    else
        echo "❌ $file 不存在，请检查代码更新"
        exit 1
    fi
done

echo "🏗️  4. 重新构建并启动服务..."
docker-compose up -d

echo "⏳ 5. 等待服务启动..."
sleep 10

echo "🔍 6. 检查服务状态..."
docker-compose ps

echo "📋 7. 检查容器日志..."
echo "=== 后端日志 ==="
docker-compose logs --tail=20 backend

echo "=== 前端日志 ==="
docker-compose logs --tail=20 frontend

echo "🧪 8. 测试API端点..."
# 测试健康检查
if curl -f -s http://localhost/health > /dev/null 2>&1; then
    echo "✅ 健康检查通过"
else
    echo "⚠️  健康检查失败，检查nginx配置"
fi

# 测试API配置模板端点
if curl -f -s http://localhost/api/v1/api-config/templates > /dev/null 2>&1; then
    echo "✅ API配置模板端点正常"
else
    echo "❌ API配置模板端点失败"
    echo "后端详细日志："
    docker-compose logs backend
    exit 1
fi

echo ""
echo "🎉 部署完成！"
echo ""
echo "📝 测试步骤："
echo "1. 访问您的网站"
echo "2. 进入 'API配置' 标签页"
echo "3. 如果已有配置，应该看到 '检测模型' 按钮"
echo "4. 点击 '添加配置' 试着创建Google自定义配置"
echo ""
echo "🔧 如果仍然有问题，运行以下命令检查："
echo "   docker-compose logs backend"
echo "   docker-compose logs frontend"
echo ""
echo "🌐 服务地址："
echo "   前端: http://localhost 或 http://your-vps-ip"
echo "   后端API: http://localhost/api 或 http://your-vps-ip/api"
echo "   API文档: http://localhost/api/docs 或 http://your-vps-ip/api/docs" 