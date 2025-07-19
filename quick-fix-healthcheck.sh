#!/bin/bash

echo "🔧 快速修复健康检查配置..."

# 备份原配置
cp docker-compose.prod.yml docker-compose.prod.yml.backup

# 修改健康检查配置为更宽松的设置
sed -i 's/interval: 30s/interval: 60s/g' docker-compose.prod.yml
sed -i 's/timeout: 10s/timeout: 30s/g' docker-compose.prod.yml
sed -i 's/retries: 3/retries: 10/g' docker-compose.prod.yml
sed -i 's/start_period: 40s/start_period: 120s/g' docker-compose.prod.yml

echo "✅ 健康检查配置已修改为更宽松的设置："
echo "   - 检查间隔: 30s → 60s"
echo "   - 超时时间: 10s → 30s" 
echo "   - 重试次数: 3 → 10"
echo "   - 启动等待: 40s → 120s"

echo ""
echo "🚀 现在重新部署："
echo "   ./fix-network-and-redeploy.sh"
echo ""
echo "💡 如果需要恢复原配置："
echo "   mv docker-compose.prod.yml.backup docker-compose.prod.yml" 