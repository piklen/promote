#!/bin/bash

# 部署验证脚本
# 使用方法: ./check-deployment.sh [your-vps-ip]

VPS_IP=${1:-localhost}

echo "🔍 检查部署状态 (服务器: $VPS_IP)"
echo "========================================"

# 1. 检查Docker容器状态
echo "📦 1. Docker容器状态："
if command -v docker-compose &> /dev/null; then
    docker-compose ps
else
    echo "❌ docker-compose 未安装"
fi

echo ""

# 2. 检查服务健康状态
echo "🏥 2. 服务健康检查："

# 检查前端
if curl -f -s "http://$VPS_IP" > /dev/null 2>&1; then
    echo "✅ 前端服务正常"
else
    echo "❌ 前端服务异常"
fi

# 检查后端健康端点
if curl -f -s "http://$VPS_IP/health" > /dev/null 2>&1; then
    echo "✅ 后端健康检查通过"
else
    echo "❌ 后端健康检查失败"
fi

# 检查API文档
if curl -f -s "http://$VPS_IP/api/docs" > /dev/null 2>&1; then
    echo "✅ API文档可访问"
else
    echo "❌ API文档不可访问"
fi

echo ""

# 3. 检查关键API端点
echo "🔌 3. 关键API端点检查："

# 检查模板端点
TEMPLATES_RESPONSE=$(curl -s "http://$VPS_IP/api/v1/api-config/templates" 2>/dev/null)
if echo "$TEMPLATES_RESPONSE" | grep -q "google_custom"; then
    echo "✅ API配置模板端点正常 (包含google_custom)"
else
    echo "❌ API配置模板端点异常"
    echo "响应: $TEMPLATES_RESPONSE"
fi

# 检查提供商端点
PROVIDERS_RESPONSE=$(curl -s "http://$VPS_IP/api/v1/llm/providers" 2>/dev/null)
if [ $? -eq 0 ]; then
    echo "✅ LLM提供商端点正常"
else
    echo "❌ LLM提供商端点异常"
fi

echo ""

# 4. 检查前端文件
echo "📁 4. 前端关键文件检查："
if [ -f "frontend/src/components/core/APIConfig.tsx" ]; then
    if grep -q "handleDetectModels" "frontend/src/components/core/APIConfig.tsx"; then
        echo "✅ 前端包含模型检测功能"
    else
        echo "❌ 前端缺少模型检测功能"
    fi
    
    if grep -q "检测模型" "frontend/src/components/core/APIConfig.tsx"; then
        echo "✅ 前端包含检测模型按钮"
    else
        echo "❌ 前端缺少检测模型按钮"
    fi
else
    echo "❌ 前端APIConfig.tsx文件不存在"
fi

echo ""

# 5. 检查后端文件
echo "🔧 5. 后端关键文件检查："
if [ -f "backend/app/routers/api_config.py" ]; then
    if grep -q "detect-models" "backend/app/routers/api_config.py"; then
        echo "✅ 后端包含模型检测API"
    else
        echo "❌ 后端缺少模型检测API"
    fi
else
    echo "❌ 后端api_config.py文件不存在"
fi

if [ -f "backend/app/core/security.py" ]; then
    if grep -q "validate_provider_name" "backend/app/core/security.py"; then
        echo "✅ 后端包含提供商验证功能"
    else
        echo "❌ 后端缺少提供商验证功能"
    fi
else
    echo "❌ 后端security.py文件不存在"
fi

echo ""

# 6. 浏览器缓存清理提示
echo "🌐 6. 浏览器访问建议："
echo "访问: http://$VPS_IP"
echo ""
echo "⚠️  如果看不到新功能，请："
echo "1. 清除浏览器缓存 (Ctrl+Shift+Delete)"
echo "2. 硬刷新页面 (Ctrl+Shift+R 或 Ctrl+F5)"
echo "3. 或使用无痕模式访问"

echo ""

# 7. 故障排除命令
echo "🔧 7. 如果仍有问题，运行以下命令："
echo "查看后端日志: docker-compose logs backend"
echo "查看前端日志: docker-compose logs frontend"
echo "重新构建: docker-compose build --no-cache"
echo "强制重启: docker-compose down && docker-compose up -d"

echo ""
echo "✅ 检查完成！" 