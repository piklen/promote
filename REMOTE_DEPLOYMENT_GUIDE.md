# 🚀 远程Ubuntu服务器Docker部署教程

本教程将指导您将LLM提示词优化平台部署到远程Ubuntu服务器上。

> **✨ 零配置部署特性**：本项目支持零配置部署 - 无需预先设置任何环境变量或API密钥。所有LLM API配置都通过前端界面管理，部署后即可使用。

## 📋 前置要求

### 本地环境
- macOS/Linux/Windows (支持SSH和rsync)
- Docker Desktop (用于测试)
- SSH客户端
- Git

### 远程服务器
- Ubuntu 18.04+ / Debian 9+
- 至少 2GB RAM
- 至少 10GB 可用磁盘空间
- Docker 和 Docker Compose 已安装
- SSH访问权限

## 🔧 第一步：准备远程服务器

### 1.1 连接到远程服务器

```bash
# 使用SSH连接到服务器
ssh ubuntu@YOUR_SERVER_IP

# 或指定端口和密钥
ssh -i ~/.ssh/your-key.pem -p 22 ubuntu@YOUR_SERVER_IP
```

### 1.2 更新系统包

```bash
# 更新包列表
sudo apt update

# 升级已安装的包
sudo apt upgrade -y

# 安装必要工具
sudo apt install -y curl wget git unzip
```

### 1.3 安装Docker

```bash
# 安装Docker
curl -fsSL https://get.docker.com | sh

# 将当前用户添加到docker组
sudo usermod -aG docker $USER

# 重新登录以生效
exit
ssh ubuntu@YOUR_SERVER_IP

# 验证Docker安装
docker --version
```

### 1.4 安装Docker Compose

```bash
# 下载Docker Compose
sudo curl -L "https://github.com/docker/compose/releases/download/v2.24.0/docker-compose-$(uname -s)-$(uname -m)" -o /usr/local/bin/docker-compose

# 添加执行权限
sudo chmod +x /usr/local/bin/docker-compose

# 验证安装
docker-compose --version
```

### 1.5 配置防火墙（如果需要）

```bash
# 允许SSH、HTTP和API端口
sudo ufw allow ssh
sudo ufw allow 80
sudo ufw allow 8080
sudo ufw enable
```

## 📦 第二步：准备项目文件

### 2.1 在本地准备项目

```bash
# 克隆或下载项目到本地
git clone <your-repo-url> promote
cd promote

# 确保远程部署脚本有执行权限
chmod +x remote-deploy.sh
```

### 2.2 零配置部署

本项目支持**零配置部署**，无需预先设置任何环境变量：

```bash
# 无需创建 .env 文件或配置API密钥
# 所有LLM API配置将在部署后通过前端界面管理

# 如需自定义配置，可选择性创建环境变量文件：
cat > .env << 'EOF'
# 服务器配置（可选）
SERVER_IP=YOUR_SERVER_IP
SERVER_USER=ubuntu
SSH_PORT=22
# 注意：LLM API密钥现在通过前端界面配置，无需在此设置
EOF
```

## 🚀 第三步：自动化部署

### 3.1 使用自动部署脚本

```bash
# 使用自动部署脚本（推荐）
./remote-deploy.sh YOUR_SERVER_IP ubuntu 22

# 示例
./remote-deploy.sh 192.168.1.100 ubuntu 22
```

脚本将自动执行以下操作：
1. ✅ 检查SSH连接
2. ✅ 验证远程Docker环境
3. ✅ 创建部署目录
4. ✅ 同步项目文件
5. ✅ 配置生产环境
6. ✅ 构建Docker镜像
7. ✅ 启动服务
8. ✅ 执行健康检查

### 3.2 手动部署（可选）

如果您希望手动控制每个步骤：

```bash
# 1. 同步文件到远程服务器
rsync -avz --progress \
    --exclude='.git' \
    --exclude='node_modules' \
    --exclude='__pycache__' \
    --exclude='*.pyc' \
    --exclude='.venv' \
    --exclude='frontend/dist' \
    --exclude='*.log' \
    ./ ubuntu@YOUR_SERVER_IP:/opt/prompt-optimizer/

# 2. 登录远程服务器
ssh ubuntu@YOUR_SERVER_IP

# 3. 进入项目目录
cd /opt/prompt-optimizer

# 4. 创建生产环境配置（可选）
cat > .env.prod << 'EOF'
ENVIRONMENT=production
DATABASE_URL=sqlite:///./data/prompt_optimizer.db
ALLOWED_ORIGINS=http://YOUR_SERVER_IP,https://yourdomain.com
# 注意：LLM API密钥现在通过前端界面配置，无需在此设置
EOF

# 5. 设置文件权限
chmod 600 .env.prod
mkdir -p ./data ./backups

# 6. 构建和启动服务
docker-compose -f docker-compose.prod.yml up --build -d

# 7. 查看服务状态
docker-compose -f docker-compose.prod.yml ps
```

## 🔍 第四步：验证部署

### 4.1 检查服务状态

```bash
# 查看容器状态
docker-compose -f docker-compose.prod.yml ps

# 查看服务日志
docker-compose -f docker-compose.prod.yml logs -f

# 检查健康状态
curl http://YOUR_SERVER_IP/health
curl http://YOUR_SERVER_IP:8080/health
```

### 4.2 访问应用

- **前端应用**: http://YOUR_SERVER_IP
- **后端API**: http://YOUR_SERVER_IP:8080
- **API文档**: http://YOUR_SERVER_IP:8080/api/docs

### 4.3 功能测试

1. 打开前端界面
2. 测试提示词管理功能
3. 验证API配置页面
4. **通过前端界面配置LLM API**（新特性）

## ⚙️ 第五步：配置LLM API

### 5.1 通过前端界面配置API（推荐）

1. **访问前端应用**: http://YOUR_SERVER_IP
2. **进入"API配置"标签页**
3. **点击"添加配置"按钮**
4. **选择提供商模板**：
   - OpenAI：GPT-4、GPT-3.5等
   - Anthropic：Claude-3系列
   - Google：Gemini（支持官方API和自定义地址）
   - 自定义API：任何兼容OpenAI格式的API
5. **填写配置信息**：
   - 输入API密钥
   - 配置API地址（如需要）
   - 设置超时时间
   - 选择支持的模型
6. **测试连接**：点击"测试"按钮验证配置
7. **保存并启用**：配置立即生效，无需重启服务

### 5.2 配置特性

- ✅ **即时生效**：修改配置后立即可用
- ✅ **安全存储**：API密钥加密存储在数据库
- ✅ **多提供商**：同时配置多个LLM提供商
- ✅ **连接测试**：实时验证API连接状态
- ✅ **灵活管理**：随时添加、编辑、删除配置

### 5.2 配置域名和CORS

```bash
# 编辑CORS配置
nano .env.prod

# 更新ALLOWED_ORIGINS
ALLOWED_ORIGINS=https://yourdomain.com,https://www.yourdomain.com

# 重启服务
docker-compose -f docker-compose.prod.yml restart
```

### 5.3 设置SSL证书（推荐）

```bash
# 安装Certbot
sudo apt install certbot python3-certbot-nginx

# 获取SSL证书
sudo certbot --nginx -d yourdomain.com

# 配置自动续期
sudo crontab -e
# 添加以下行：
# 0 12 * * * /usr/bin/certbot renew --quiet
```

## 🔧 第六步：管理和维护

### 6.1 常用管理命令

```bash
# 查看服务状态
docker-compose -f docker-compose.prod.yml ps

# 查看日志
docker-compose -f docker-compose.prod.yml logs -f [service_name]

# 重启服务
docker-compose -f docker-compose.prod.yml restart

# 停止服务
docker-compose -f docker-compose.prod.yml down

# 更新服务
docker-compose -f docker-compose.prod.yml pull
docker-compose -f docker-compose.prod.yml up --build -d

# 清理未使用的镜像
docker system prune -f
```

### 6.2 数据备份

```bash
# 创建备份脚本
cat > /opt/prompt-optimizer/backup.sh << 'EOF'
#!/bin/bash
DATE=$(date +%Y%m%d_%H%M%S)
BACKUP_DIR="/opt/prompt-optimizer/backups"
DATA_DIR="/opt/prompt-optimizer/data"

# 创建备份目录
mkdir -p $BACKUP_DIR

# 备份数据库
cp $DATA_DIR/prompt_optimizer.db $BACKUP_DIR/prompt_optimizer_$DATE.db

# 保留最近7天的备份
find $BACKUP_DIR -name "prompt_optimizer_*.db" -mtime +7 -delete

echo "备份完成: prompt_optimizer_$DATE.db"
EOF

# 添加执行权限
chmod +x /opt/prompt-optimizer/backup.sh

# 设置定时备份
crontab -e
# 添加以下行（每天凌晨2点备份）：
# 0 2 * * * /opt/prompt-optimizer/backup.sh
```

### 6.3 监控和日志

```bash
# 查看系统资源使用
docker stats

# 查看容器日志
docker logs prompt-optimizer-backend-prod
docker logs prompt-optimizer-frontend-prod

# 监控磁盘使用
df -h
du -sh /opt/prompt-optimizer/
```

## 🔄 第七步：更新和升级

### 7.1 应用更新

```bash
# 本地拉取最新代码
git pull origin main

# 重新部署
./remote-deploy.sh YOUR_SERVER_IP ubuntu 22
```

### 7.2 手动更新

```bash
# 在服务器上
cd /opt/prompt-optimizer

# 备份当前数据
./backup.sh

# 拉取新代码
git pull origin main

# 重新构建和启动
docker-compose -f docker-compose.prod.yml down
docker-compose -f docker-compose.prod.yml up --build -d
```

## 🛠️ 故障排除

### 常见问题及解决方案

#### 问题1: 无法连接到服务器
```bash
# 检查SSH连接
ssh -v ubuntu@YOUR_SERVER_IP

# 检查防火墙
sudo ufw status
```

#### 问题2: Docker服务启动失败
```bash
# 查看详细日志
docker-compose -f docker-compose.prod.yml logs

# 检查端口占用
sudo netstat -tlnp | grep :80
sudo netstat -tlnp | grep :8080
```

#### 问题3: 前端无法访问后端API
```bash
# 检查网络连接
docker network ls
docker network inspect prompt-optimizer_app_network

# 检查服务间通信
docker exec prompt-optimizer-frontend-prod curl http://backend:8080/health
```

#### 问题4: 数据库权限问题
```bash
# 检查数据目录权限
ls -la /opt/prompt-optimizer/data/

# 修复权限
sudo chown -R 1000:1000 /opt/prompt-optimizer/data/
```

## 📈 性能优化

### 服务器优化

```bash
# 增加文件描述符限制
echo "* soft nofile 65536" | sudo tee -a /etc/security/limits.conf
echo "* hard nofile 65536" | sudo tee -a /etc/security/limits.conf

# 优化内核参数
echo "net.core.somaxconn = 65536" | sudo tee -a /etc/sysctl.conf
sudo sysctl -p
```

### Docker优化

```bash
# 配置Docker日志轮转
cat > /etc/docker/daemon.json << 'EOF'
{
  "log-driver": "json-file",
  "log-opts": {
    "max-size": "10m",
    "max-file": "3"
  }
}
EOF

# 重启Docker
sudo systemctl restart docker
```

## 📞 支持和帮助

如果您在部署过程中遇到问题：

1. 检查服务器日志：`docker-compose -f docker-compose.prod.yml logs`
2. 验证网络连接：`curl http://YOUR_SERVER_IP/health`
3. 检查防火墙设置：`sudo ufw status`
4. 查看系统资源：`htop` 或 `docker stats`

---

🎉 **恭喜！** 您已成功将LLM提示词优化平台部署到远程Ubuntu服务器。现在您可以通过 http://YOUR_SERVER_IP 访问应用了！ 