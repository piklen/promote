# VPS一键部署指南

已经在VPS上拉取项目并有Docker环境？使用本指南一键部署！

## 🚀 快速部署

### 第一步：确认环境

在项目根目录运行以下命令确认环境：

```bash
# 检查当前目录是否为项目根目录
ls -la

# 应该看到这些文件：
# - docker-compose.prod.yml
# - backend/Dockerfile  
# - frontend/Dockerfile
# - deploy-local.sh

# 检查Docker环境
docker --version
docker-compose --version
```

### 第二步：一键部署

```bash
# 基本部署
./deploy-local.sh

# 带域名部署
./deploy-local.sh -d yourdomain.com

# 备份现有数据并强制重构
./deploy-local.sh -b -f

# 完全清理后重新部署
./deploy-local.sh -c
```

### 第三步：访问应用

部署完成后，打开浏览器访问：
- **前端应用**: `http://YOUR_SERVER_IP`
- **API文档**: `http://YOUR_SERVER_IP:8080/api/docs`

## 📋 部署选项说明

| 选项 | 说明 | 使用场景 |
|------|------|----------|
| `-d, --domain` | 指定域名 | 有域名需要配置SSL |
| `-b, --backup` | 备份现有数据 | 更新部署时保护数据 |
| `-f, --force` | 强制重新构建 | 代码有更新或镜像有问题 |
| `-c, --clean` | 清理所有Docker资源 | 彻底重新开始 |
| `-h, --help` | 显示帮助 | 查看所有选项 |

## 🔧 常用操作

### 查看服务状态
```bash
docker-compose -f docker-compose.prod.yml ps
```

### 查看日志
```bash
# 查看所有日志
docker-compose -f docker-compose.prod.yml logs -f

# 只看后端日志
docker-compose -f docker-compose.prod.yml logs -f backend

# 只看前端日志
docker-compose -f docker-compose.prod.yml logs -f frontend
```

### 重启服务
```bash
# 重启所有服务
docker-compose -f docker-compose.prod.yml restart

# 重启特定服务
docker-compose -f docker-compose.prod.yml restart backend
```

### 停止服务
```bash
docker-compose -f docker-compose.prod.yml down
```

### 更新应用
```bash
# 拉取最新代码并重新部署
git pull
./deploy-local.sh -f
```

## ⚙️ 配置API密钥

部署完成后，需要配置LLM提供商的API密钥：

1. 访问 `http://YOUR_SERVER_IP`
2. 点击 **"API配置"** 标签页
3. 点击 **"添加配置"** 按钮
4. 选择提供商（OpenAI、Anthropic、Google等）
5. 输入API密钥和相关配置
6. 点击 **"测试"** 验证连接
7. 保存配置

支持的提供商：
- **OpenAI**: GPT-3.5, GPT-4系列
- **Anthropic**: Claude系列  
- **Google**: Gemini系列
- **自定义API**: OpenAI兼容的API

## 🔍 故障排查

### 1. 脚本提示不在项目目录
**错误**: `当前目录不是项目根目录`

**解决**:
```bash
# 确保在正确的目录
cd /path/to/your/project
ls -la  # 检查是否有必要的文件
```

### 2. Docker权限问题
**错误**: `Docker服务未运行或当前用户无权限访问`

**解决**:
```bash
# 启动Docker服务
sudo systemctl start docker

# 将用户添加到docker组
sudo usermod -aG docker $USER

# 重新登录或重启终端
```

### 3. 端口占用
**错误**: 服务无法启动，端口被占用

**解决**:
```bash
# 检查端口占用
sudo netstat -tlnp | grep :80
sudo netstat -tlnp | grep :8080

# 停止占用端口的服务
sudo systemctl stop nginx  # 如果nginx占用80端口
```

### 4. 服务健康检查失败
**现象**: 部署完成但无法访问

**解决**:
```bash
# 检查服务状态
docker-compose -f docker-compose.prod.yml ps

# 查看详细日志
docker-compose -f docker-compose.prod.yml logs

# 等待更长时间（某些VPS启动较慢）
sleep 60
curl http://localhost/health
```

### 5. 内存不足
**现象**: 构建过程中服务器卡死

**解决**:
```bash
# 检查内存使用
free -h

# 如果内存不足，增加swap
sudo fallocate -l 2G /swapfile
sudo chmod 600 /swapfile
sudo mkswap /swapfile
sudo swapon /swapfile
```

## 🛡️ 安全建议

### 防火墙配置
```bash
# 安装并配置UFW
sudo apt install ufw
sudo ufw default deny incoming
sudo ufw default allow outgoing
sudo ufw allow ssh
sudo ufw allow 80/tcp
sudo ufw allow 443/tcp
sudo ufw enable
```

### SSL证书配置（有域名时）
```bash
# 安装Certbot
sudo apt install certbot python3-certbot-nginx

# 获取SSL证书
sudo certbot --nginx -d yourdomain.com

# 设置自动续期
sudo crontab -e
# 添加: 0 12 * * * /usr/bin/certbot renew --quiet
```

## 📊 性能监控

### 监控Docker容器
```bash
# 查看资源使用
docker stats

# 查看系统资源
htop
```

### 日志管理
```bash
# 查看磁盘使用
df -h

# 清理Docker日志（如果太大）
sudo sh -c 'truncate -s 0 /var/lib/docker/containers/*/*-json.log'
```

## 📞 获取帮助

- 查看部署脚本选项: `./deploy-local.sh --help`
- 查看完整文档: `README.md`
- 详细部署指南: `DEPLOYMENT.md`
- 安全最佳实践: `SECURITY.md`

---

🎉 **恭喜！您已成功部署LLM提示词优化平台！**

开始创建和优化您的提示词吧！ 🚀 