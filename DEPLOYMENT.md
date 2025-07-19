# 生产环境部署指南

本文档详细介绍了如何在VPS服务器上部署LLM提示词优化平台的生产环境。

## 📋 部署前准备

### 服务器要求

**最低配置:**
- CPU: 1核心
- 内存: 2GB
- 存储: 20GB SSD
- 操作系统: Ubuntu 20.04+ / CentOS 8+ / Debian 11+

**推荐配置:**
- CPU: 2核心
- 内存: 4GB
- 存储: 40GB SSD
- 带宽: 5Mbps+

### 域名准备（可选）

如果您有域名，请提前配置DNS解析：
```
A记录: yourdomain.com -> YOUR_SERVER_IP
A记录: www.yourdomain.com -> YOUR_SERVER_IP
```

## 🚀 自动化部署

### 使用部署脚本（推荐）

我们提供了自动化部署脚本，支持一键部署：

```bash
# 基本部署
./remote-deploy.sh YOUR_SERVER_IP

# 带域名部署
./remote-deploy.sh -d yourdomain.com YOUR_SERVER_IP

# 带备份的部署
./remote-deploy.sh -b -d yourdomain.com YOUR_SERVER_IP

# 强制重新构建
./remote-deploy.sh -f YOUR_SERVER_IP
```

### 部署脚本选项

```bash
./remote-deploy.sh [选项] <服务器IP>

选项:
  -u, --user USER         SSH用户名 (默认: ubuntu)
  -p, --port PORT         SSH端口 (默认: 22)
  -d, --domain DOMAIN     域名 (用于SSL和CORS配置)
  -b, --backup            部署前备份现有数据
  -f, --force             强制重新构建镜像
  -h, --help              显示帮助信息
```

## 🔧 手动部署

如果您需要手动控制部署过程，请按照以下步骤操作：

### 1. 准备服务器环境

```bash
# 更新系统
sudo apt update && sudo apt upgrade -y

# 安装基础工具
sudo apt install -y curl wget git htop

# 安装Docker
curl -fsSL https://get.docker.com | sh
sudo usermod -aG docker $USER

# 安装Docker Compose
sudo curl -L "https://github.com/docker/compose/releases/latest/download/docker-compose-$(uname -s)-$(uname -m)" -o /usr/local/bin/docker-compose
sudo chmod +x /usr/local/bin/docker-compose

# 重新登录以获得Docker权限
```

### 2. 部署项目

```bash
# 创建项目目录
sudo mkdir -p /opt/prompt-optimizer
sudo chown $USER:$USER /opt/prompt-optimizer
cd /opt/prompt-optimizer

# 克隆项目（或上传文件）
git clone <your-repository-url> .

# 创建必要的目录
mkdir -p data logs backups ssl

# 设置权限
chmod 755 data logs backups
```

### 3. 配置环境变量

创建生产环境配置文件：

```bash
cat > .env.prod << 'EOF'
# 生产环境配置
ENVIRONMENT=production
DATABASE_URL=sqlite:///./data/prompt_optimizer.db
LOG_DIR=/app/logs

# CORS配置 - 根据您的域名修改
ALLOWED_ORIGINS=http://YOUR_SERVER_IP,https://yourdomain.com
ALLOWED_HOSTS=YOUR_SERVER_IP,yourdomain.com

# 性能配置
ENABLE_METRICS=false
ENABLE_DEBUG=false

# API配置
API_BASE_URL=http://YOUR_SERVER_IP/api/v1

# 客户端配置
CLIENT_MAX_BODY_SIZE=10m
EOF

# 设置安全权限
chmod 600 .env.prod
```

### 4. 启动服务

```bash
# 构建并启动服务
docker-compose -f docker-compose.prod.yml up --build -d

# 查看服务状态
docker-compose -f docker-compose.prod.yml ps

# 查看日志
docker-compose -f docker-compose.prod.yml logs -f
```

### 5. 验证部署

```bash
# 检查服务健康状态
curl http://YOUR_SERVER_IP/health
curl http://YOUR_SERVER_IP:8080/health

# 检查API访问
curl http://YOUR_SERVER_IP:8080/api/docs
```

## 🛡️ 安全配置

### 防火墙设置

```bash
# 安装UFW防火墙
sudo apt install ufw

# 配置防火墙规则
sudo ufw default deny incoming
sudo ufw default allow outgoing
sudo ufw allow ssh
sudo ufw allow 80/tcp
sudo ufw allow 443/tcp

# 启用防火墙
sudo ufw enable

# 查看状态
sudo ufw status
```

### SSL证书配置

#### 使用Let's Encrypt（推荐）

```bash
# 安装Certbot
sudo apt install certbot

# 获取SSL证书
sudo certbot certonly --standalone -d yourdomain.com

# 复制证书到项目目录
sudo cp /etc/letsencrypt/live/yourdomain.com/fullchain.pem ./ssl/cert.pem
sudo cp /etc/letsencrypt/live/yourdomain.com/privkey.pem ./ssl/key.pem
sudo chown $USER:$USER ./ssl/*.pem

# 设置自动续期
echo "0 12 * * * /usr/bin/certbot renew --quiet" | sudo crontab -
```

#### 使用自签名证书（测试环境）

```bash
# 生成自签名证书
openssl req -x509 -newkey rsa:4096 -keyout ./ssl/key.pem -out ./ssl/cert.pem -days 365 -nodes

# 设置权限
chmod 600 ./ssl/*.pem
```

### 反向代理配置

#### 安装Nginx

```bash
sudo apt install nginx

# 创建配置文件
sudo tee /etc/nginx/sites-available/prompt-optimizer << 'EOF'
server {
    listen 80;
    server_name yourdomain.com www.yourdomain.com;
    
    # 重定向HTTP到HTTPS
    return 301 https://$server_name$request_uri;
}

server {
    listen 443 ssl http2;
    server_name yourdomain.com www.yourdomain.com;
    
    # SSL配置
    ssl_certificate /opt/prompt-optimizer/ssl/cert.pem;
    ssl_certificate_key /opt/prompt-optimizer/ssl/key.pem;
    ssl_protocols TLSv1.2 TLSv1.3;
    ssl_ciphers ECDHE-RSA-AES256-GCM-SHA512:DHE-RSA-AES256-GCM-SHA512;
    ssl_prefer_server_ciphers off;
    
    # 安全头
    add_header X-Frame-Options DENY;
    add_header X-Content-Type-Options nosniff;
    add_header X-XSS-Protection "1; mode=block";
    add_header Strict-Transport-Security "max-age=63072000; includeSubDomains; preload";
    
    # 前端代理
    location / {
        proxy_pass http://localhost:80;
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto $scheme;
    }
    
    # API代理
    location /api/ {
        proxy_pass http://localhost:8080/api/;
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto $scheme;
    }
}
EOF

# 启用站点
sudo ln -s /etc/nginx/sites-available/prompt-optimizer /etc/nginx/sites-enabled/
sudo nginx -t
sudo systemctl reload nginx
```

## 📊 监控和维护

### 系统监控

#### 安装监控工具

```bash
# 安装系统监控工具
sudo apt install htop iotop nethogs

# 安装Docker监控
docker run -d \
  --name=portainer \
  --restart=always \
  -p 9000:9000 \
  -v /var/run/docker.sock:/var/run/docker.sock \
  -v portainer_data:/data \
  portainer/portainer-ce
```

#### 日志管理

```bash
# 查看应用日志
docker-compose -f docker-compose.prod.yml logs -f --tail=100

# 查看系统日志
journalctl -f

# 设置日志轮转
sudo tee /etc/logrotate.d/prompt-optimizer << 'EOF'
/opt/prompt-optimizer/logs/*.log {
    daily
    missingok
    rotate 30
    compress
    delaycompress
    notifempty
    create 644 root root
}
EOF
```

### 数据备份

#### 自动备份脚本

```bash
# 创建备份脚本
sudo tee /usr/local/bin/backup-prompt-optimizer.sh << 'EOF'
#!/bin/bash

BACKUP_DIR="/opt/prompt-optimizer/backups"
TIMESTAMP=$(date +%Y%m%d_%H%M%S)
PROJECT_DIR="/opt/prompt-optimizer"

# 创建备份目录
mkdir -p $BACKUP_DIR

# 备份数据库和配置
cd $PROJECT_DIR
tar -czf $BACKUP_DIR/backup_$TIMESTAMP.tar.gz \
    data/ \
    .env.prod \
    ssl/ \
    docker-compose.prod.yml

# 清理30天前的备份
find $BACKUP_DIR -name "backup_*.tar.gz" -mtime +30 -delete

echo "备份完成: backup_$TIMESTAMP.tar.gz"
EOF

# 设置执行权限
sudo chmod +x /usr/local/bin/backup-prompt-optimizer.sh

# 设置定时备份（每天凌晨2点）
echo "0 2 * * * /usr/local/bin/backup-prompt-optimizer.sh" | sudo crontab -
```

#### 手动备份

```bash
# 停止服务
docker-compose -f docker-compose.prod.yml down

# 创建备份
tar -czf backup_$(date +%Y%m%d).tar.gz data/ .env.prod ssl/

# 启动服务
docker-compose -f docker-compose.prod.yml up -d
```

### 更新和维护

#### 应用更新

```bash
# 备份当前版本
./backup-prompt-optimizer.sh

# 拉取最新代码
git pull origin main

# 重新构建并部署
docker-compose -f docker-compose.prod.yml down
docker-compose -f docker-compose.prod.yml build --no-cache
docker-compose -f docker-compose.prod.yml up -d

# 验证更新
curl http://YOUR_SERVER_IP/health
```

#### 系统维护

```bash
# 清理Docker
docker system prune -f

# 更新系统
sudo apt update && sudo apt upgrade -y

# 重启服务器（如需要）
sudo reboot
```

## 🔍 故障排查

### 常见问题

#### 1. 容器无法启动

```bash
# 查看详细错误信息
docker-compose -f docker-compose.prod.yml logs

# 检查端口占用
sudo netstat -tlnp | grep :80
sudo netstat -tlnp | grep :443

# 检查磁盘空间
df -h

# 检查内存使用
free -h
```

#### 2. SSL证书问题

```bash
# 检查证书有效性
openssl x509 -in ./ssl/cert.pem -text -noout

# 测试SSL连接
openssl s_client -connect yourdomain.com:443

# 续期Let's Encrypt证书
sudo certbot renew --dry-run
```

#### 3. 网络连接问题

```bash
# 检查网络连通性
ping yourdomain.com

# 检查DNS解析
nslookup yourdomain.com

# 检查防火墙状态
sudo ufw status

# 检查Nginx状态
sudo systemctl status nginx
```

### 性能优化

#### 系统优化

```bash
# 优化系统文件描述符限制
echo "* soft nofile 65536" | sudo tee -a /etc/security/limits.conf
echo "* hard nofile 65536" | sudo tee -a /etc/security/limits.conf

# 优化网络参数
sudo tee -a /etc/sysctl.conf << 'EOF'
net.core.somaxconn = 1024
net.core.netdev_max_backlog = 5000
net.core.rmem_default = 262144
net.core.rmem_max = 16777216
net.core.wmem_default = 262144
net.core.wmem_max = 16777216
net.ipv4.tcp_wmem = 4096 12582912 16777216
net.ipv4.tcp_rmem = 4096 12582912 16777216
EOF

sudo sysctl -p
```

#### Docker优化

```bash
# 设置Docker日志限制
sudo tee /etc/docker/daemon.json << 'EOF'
{
  "log-driver": "json-file",
  "log-opts": {
    "max-size": "10m",
    "max-file": "3"
  }
}
EOF

sudo systemctl restart docker
```

## 📞 支持和联系

如果您在部署过程中遇到问题：

1. **查看文档**: 首先参考本部署指南和主README
2. **查看日志**: 检查应用日志和系统日志
3. **提交Issue**: 在GitHub上提交详细的问题报告
4. **社区讨论**: 参与GitHub Discussions

## 🎯 最佳实践总结

✅ **安全方面**
- 使用防火墙限制端口访问
- 配置SSL证书
- 定期更新系统和应用
- 使用强密码和密钥认证

✅ **性能方面**
- 选择合适的服务器配置
- 配置反向代理和缓存
- 监控资源使用情况
- 优化Docker配置

✅ **维护方面**
- 设置自动备份
- 配置监控告警
- 定期检查日志
- 制定更新计划

✅ **用户体验**
- 配置域名和SSL
- 优化加载速度
- 提供清晰的错误信息
- 定期测试功能 