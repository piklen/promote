# 后端容器问题排查和解决指南

## 问题描述
后端容器健康检查失败，导致前端容器无法启动：
```
✘ Container prompt-optimizer-backend-prod   Error
dependency failed to start: container prompt-optimizer-backend-prod is unhealthy
```

## 快速解决方案

### 方案1: 快速修复健康检查（推荐）
```bash
# 1. 修改健康检查为更宽松的设置
./quick-fix-healthcheck.sh

# 2. 重新部署
./fix-network-and-redeploy.sh
```

### 方案2: 全面修复后端问题
```bash
# 运行全面修复脚本
./fix-backend-issues.sh
```

### 方案3: 诊断问题
```bash
# 先诊断具体问题
./diagnose-backend-issues.sh

# 根据诊断结果选择合适的修复方案
```

## 常见问题和解决方案

### 1. 健康检查超时
**症状**: 容器启动但健康检查一直失败
**原因**: 健康检查配置过于严格
**解决**: 使用 `quick-fix-healthcheck.sh` 修改为更宽松的设置

### 2. 数据库连接问题
**症状**: 后端日志显示数据库连接错误
**原因**: 数据目录权限或SQLite文件不存在
**解决**:
```bash
# 修复数据目录权限
sudo mkdir -p /opt/prompt-optimizer/{data,logs}
sudo chown -R $(whoami):$(whoami) /opt/prompt-optimizer/
chmod -R 755 /opt/prompt-optimizer/

# 重新部署
docker-compose -f docker-compose.prod.yml down
docker-compose -f docker-compose.prod.yml up -d --build
```

### 3. 端口绑定问题
**症状**: 应用无法绑定到8080端口
**原因**: 端口被占用或权限问题
**解决**:
```bash
# 检查端口占用
sudo netstat -tlnp | grep 8080
sudo lsof -i :8080

# 杀死占用端口的进程
sudo kill -9 PID

# 或修改端口配置
```

### 4. Python依赖问题
**症状**: 应用启动时ImportError
**原因**: 依赖包安装失败或版本冲突
**解决**:
```bash
# 清理构建缓存重新构建
docker-compose -f docker-compose.prod.yml build --no-cache backend
docker-compose -f docker-compose.prod.yml up -d
```

### 5. 内存不足
**症状**: 容器被OOM Killer杀死
**原因**: 系统内存不足
**解决**:
```bash
# 检查内存使用
free -h
docker stats

# 清理Docker资源
docker system prune -f

# 增加交换空间（临时）
sudo fallocate -l 2G /swapfile
sudo chmod 600 /swapfile
sudo mkswap /swapfile
sudo swapon /swapfile
```

## 手动排查步骤

### 1. 检查容器状态
```bash
docker-compose -f docker-compose.prod.yml ps
docker-compose -f docker-compose.prod.yml logs backend
```

### 2. 进入容器调试
```bash
# 获取容器ID
CONTAINER_ID=$(docker-compose -f docker-compose.prod.yml ps -q backend)

# 进入容器
docker exec -it $CONTAINER_ID /bin/bash

# 在容器内测试
curl http://localhost:8080/
curl http://localhost:8080/health
python -c "from app.main import app; print('App imported successfully')"
```

### 3. 检查网络连接
```bash
# 检查容器网络
docker network ls
docker inspect promote_app_network

# 测试容器间通信
docker exec frontend_container ping backend_container
```

### 4. 检查环境变量
```bash
docker exec $CONTAINER_ID env | grep -E "(DATABASE|PYTHON|PORT)"
```

## 配置优化

### 健康检查优化
已通过 `quick-fix-healthcheck.sh` 修改：
```yaml
healthcheck:
  test: ["CMD", "curl", "-f", "http://localhost:8080/health"]
  interval: 60s      # 增加检查间隔
  timeout: 30s       # 增加超时时间
  retries: 10        # 增加重试次数
  start_period: 120s # 增加启动等待时间
```

### 资源限制调整
如果内存不足，可临时放宽限制：
```yaml
deploy:
  resources:
    limits:
      memory: 1G      # 从512M增加到1G
      cpus: '1.0'     # 从0.5增加到1.0
```

## 预防措施

1. **定期维护**
```bash
# 每周清理Docker资源
docker system prune -f

# 检查磁盘空间
df -h

# 检查内存使用
free -h
```

2. **监控日志**
```bash
# 实时监控应用日志
docker-compose -f docker-compose.prod.yml logs -f

# 定期检查错误日志
grep -i error /opt/prompt-optimizer/logs/*.log
```

3. **备份数据**
```bash
# 备份数据库
cp /opt/prompt-optimizer/data/prompt_optimizer.db /backup/

# 备份配置
tar -czf /backup/config-$(date +%Y%m%d).tar.gz docker-compose.prod.yml
```

## 成功指标

部署成功后应该看到：
```bash
# 容器状态
docker-compose -f docker-compose.prod.yml ps
# 应显示所有容器为 "Up" 状态

# 健康检查
curl http://localhost/health
# 应返回JSON格式的健康状态

# 前端访问
curl http://localhost/
# 应返回前端页面
```

## 获取帮助

如果问题仍然存在，请收集以下信息：

```bash
# 系统信息
uname -a
docker version
docker-compose version

# 容器信息
docker-compose -f docker-compose.prod.yml ps
docker-compose -f docker-compose.prod.yml logs --tail=100

# 系统资源
free -h
df -h
docker stats --no-stream

# 网络信息
docker network ls
netstat -tlnp | grep -E "(80|8080)"
```

将这些信息提供给技术支持以获得进一步帮助。 