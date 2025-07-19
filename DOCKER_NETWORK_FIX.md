# Docker网络问题修复指南

## 问题描述
在VPS上部署时遇到以下错误：
```
failed to create network promote_app_network: Error response from daemon: failed to check bridge interface existence: numerical result out of range
```

## 解决方案

### 方法1: 快速修复和重新部署（推荐）
运行完整的修复脚本：
```bash
./fix-network-and-redeploy.sh
```

这个脚本会自动：
1. 停止所有容器
2. 清理Docker网络
3. 重启Docker服务
4. 重新构建和部署应用

### 方法2: 仅修复网络问题
如果只想修复网络问题而不重新部署：
```bash
./fix-docker-network.sh
```

然后手动重新部署：
```bash
docker-compose -f docker-compose.prod.yml up -d --build
```

## 主要修复内容

### 1. 简化了网络配置
修改 `docker-compose.prod.yml` 中的网络设置：
```yaml
# 修改前（可能导致冲突）
networks:
  app_network:
    driver: bridge
    driver_opts:
      com.docker.network.bridge.name: prompt-optimizer-br
    ipam:
      config:
        - subnet: 172.20.0.0/16

# 修改后（使用默认配置）
networks:
  app_network:
    driver: bridge
```

### 2. 网络清理脚本
脚本会自动清理：
- 停止所有相关容器
- 删除冲突的网络
- 清理未使用的Docker资源
- 重启Docker服务

## 常见原因
这个错误通常由以下原因引起：
1. **网络子网冲突**: 指定的子网范围与现有网络冲突
2. **网桥接口问题**: 自定义网桥名称可能与系统配置冲突
3. **Docker daemon状态**: Docker服务可能需要重启
4. **资源清理**: 累积的网络资源需要清理

## 验证修复
修复完成后，可以通过以下命令验证：

1. 检查Docker网络：
```bash
docker network ls
```

2. 检查容器状态：
```bash
docker-compose -f docker-compose.prod.yml ps
```

3. 检查应用健康状态：
```bash
curl http://localhost/health
```

## 预防措施
为避免类似问题：
1. 定期清理Docker资源：`docker system prune -f`
2. 使用默认网络配置而不是自定义子网
3. 定期重启Docker服务
4. 监控系统资源使用情况

## 故障排除
如果修复脚本执行失败：

1. 手动停止容器：
```bash
docker stop $(docker ps -aq)
docker rm $(docker ps -aq)
```

2. 手动清理网络：
```bash
docker network prune -f
docker system prune -f
```

3. 重启Docker：
```bash
sudo systemctl restart docker
```

4. 重新部署：
```bash
docker-compose -f docker-compose.prod.yml up -d --build
```

## 联系支持
如果问题仍然存在，请提供以下信息：
- Docker版本：`docker version`
- 系统信息：`uname -a`
- 网络状态：`docker network ls`
- 错误日志：`docker-compose logs` 