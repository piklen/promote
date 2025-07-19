# LLM 提示词优化平台 - 零配置部署指南

## 🚀 概述

这是一个支持零配置部署的 LLM 提示词优化平台。无需复杂的环境变量配置，一键部署即可使用！

### ✨ 特性

- **零配置部署**：无需设置任何环境变量
- **开箱即用**：部署后立即可用
- **前端配置**：所有设置通过 Web 界面完成
- **安全存储**：API 密钥自动加密存储
- **多模型支持**：支持 OpenAI、Claude、Google Gemini 等
- **Docker 部署**：基于 Docker 的可靠部署

## 🔧 系统要求

- Docker（20.x 或更高版本）
- Docker Compose（2.x 或更高版本）
- 可用端口：80（前端）、8080（API）

## 📦 一键部署

### 方法一：使用零配置脚本（推荐）

```bash
# 1. 克隆项目
git clone <项目地址>
cd promote

# 2. 执行零配置部署脚本
./deploy-zero-config.sh
```

### 方法二：手动 Docker Compose

```bash
# 1. 创建必要目录
mkdir -p ssl logs

# 2. 启动服务
docker-compose -f docker-compose.prod.yml up -d --build

# 3. 等待服务启动（约2分钟）
docker-compose -f docker-compose.prod.yml logs -f
```

## 🌐 访问应用

部署完成后，可以通过以下地址访问：

- **主页**：http://localhost
- **API 文档**：http://localhost:8080/api/docs  
- **健康检查**：http://localhost:8080/health

## ⚙️ 首次配置

### 1. 访问配置页面

打开浏览器访问 http://localhost，进入 **API 配置** 页面。

### 2. 添加 LLM 提供商

点击 **添加配置** 按钮，填写以下信息：

#### OpenAI 配置示例
- **提供商**: openai
- **API 密钥**: sk-xxxxxxxxxxxxxxxx
- **基础 URL**: https://api.openai.com/v1
- **默认模型**: gpt-3.5-turbo
- **支持的模型**: gpt-3.5-turbo, gpt-4, gpt-4-turbo

#### Claude 配置示例
- **提供商**: anthropic
- **API 密钥**: sk-ant-api03-xxxxxxxxxxxxxxxx
- **基础 URL**: https://api.anthropic.com
- **默认模型**: claude-3-sonnet-20240229
- **支持的模型**: claude-3-haiku-20240307, claude-3-sonnet-20240229

#### Google Gemini 配置示例
- **提供商**: google
- **API 密钥**: AIzaSyxxxxxxxxxxxxxxxxxx
- **基础 URL**: https://generativelanguage.googleapis.com/v1
- **默认模型**: gemini-pro
- **支持的模型**: gemini-pro, gemini-pro-vision

### 3. 测试配置

添加配置后，点击 **测试** 按钮验证 API 连接是否正常。

### 4. 开始使用

配置完成后，就可以在 **提示词管理** 页面开始创建和优化提示词了！

## 🔒 安全特性

### API 密钥保护
- 所有 API 密钥使用 AES-256 加密存储
- 前端界面只显示密钥的部分字符
- 支持密钥的安全更新和删除

### 网络安全
- 容器间通信使用内部网络
- 支持 HTTPS（需要 SSL 证书）
- 实施 CORS 策略和安全头

### 数据安全
- 数据存储在 Docker 卷中
- 支持数据备份和恢复
- 日志记录访问和操作

## 📊 监控和维护

### 查看服务状态
```bash
# 查看容器状态
docker-compose -f docker-compose.prod.yml ps

# 查看服务日志
docker-compose -f docker-compose.prod.yml logs -f

# 查看特定服务日志
docker logs prompt-optimizer-backend-prod
docker logs prompt-optimizer-frontend-prod
```

### 重启服务
```bash
# 重启所有服务
docker-compose -f docker-compose.prod.yml restart

# 重启特定服务
docker-compose -f docker-compose.prod.yml restart backend
docker-compose -f docker-compose.prod.yml restart frontend
```

### 停止服务
```bash
# 停止服务（保留数据）
docker-compose -f docker-compose.prod.yml down

# 停止服务并删除卷（清除所有数据）
docker-compose -f docker-compose.prod.yml down -v
```

## 💾 数据管理

### 数据位置
- **数据库**: Docker 卷 `prompt-optimizer-data-prod`
- **日志**: Docker 卷 `prompt-optimizer-logs-prod`
- **配置**: 存储在 SQLite 数据库中

### 备份数据
```bash
# 备份数据库
docker run --rm -v prompt-optimizer-data-prod:/data -v $(pwd):/backup alpine tar czf /backup/data-backup-$(date +%Y%m%d-%H%M%S).tar.gz -C /data .

# 备份日志
docker run --rm -v prompt-optimizer-logs-prod:/logs -v $(pwd):/backup alpine tar czf /backup/logs-backup-$(date +%Y%m%d-%H%M%S).tar.gz -C /logs .
```

### 恢复数据
```bash
# 恢复数据库（替换 backup-file.tar.gz 为实际备份文件）
docker run --rm -v prompt-optimizer-data-prod:/data -v $(pwd):/backup alpine tar xzf /backup/backup-file.tar.gz -C /data
```

## 🔧 高级配置

### 启用 HTTPS

1. 将 SSL 证书文件放入 `ssl` 目录：
   - `server.crt`（证书文件）
   - `server.key`（私钥文件）

2. 重启服务：
   ```bash
   docker-compose -f docker-compose.prod.yml restart frontend
   ```

### 自定义端口

如果需要更改端口，编辑 `docker-compose.prod.yml`：

```yaml
ports:
  - "8080:80"    # 将前端端口改为 8080
  - "8081:8080"  # 将 API 端口改为 8081
```

### 外网访问

如果需要从外网访问，请：

1. 配置防火墙开放相应端口
2. 设置反向代理（如 Nginx）
3. 配置域名解析
4. 建议启用 HTTPS

## 🚨 故障排除

### 常见问题

#### 1. 端口占用
错误：`bind: address already in use`

解决：检查端口占用并释放端口
```bash
# 检查端口占用
lsof -i :80
lsof -i :8080

# 停止占用端口的进程
sudo kill -9 <PID>
```

#### 2. 权限问题
错误：`permission denied`

解决：确保当前用户可以访问 Docker
```bash
# 将用户添加到 docker 组
sudo usermod -aG docker $USER

# 重新登录或执行
newgrp docker
```

#### 3. 构建失败
错误：`build failed`

解决：清理 Docker 缓存并重新构建
```bash
# 清理缓存
docker system prune -a

# 重新构建
docker-compose -f docker-compose.prod.yml build --no-cache
```

#### 4. 数据库连接失败
检查后端日志：
```bash
docker logs prompt-optimizer-backend-prod
```

通常原因：
- 数据库目录权限问题
- 磁盘空间不足

### 获取帮助

如遇到问题，请：

1. 检查日志输出
2. 确认系统要求满足
3. 查看 GitHub Issues
4. 提交详细的错误报告

## 📝 更新日志

### v1.1.0
- ✨ 新增零配置部署支持
- 🔒 增强安全性配置
- 🚀 优化部署流程
- 📚 完善文档说明

## 📄 许可证

本项目采用 MIT 许可证。详见 LICENSE 文件。

---

🎉 **享受 LLM 提示词优化之旅！** 