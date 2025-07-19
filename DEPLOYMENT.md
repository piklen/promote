# 🚀 部署指南

这份指南将帮助您在不同环境中部署LLM提示词优化平台。

## 目录

- [快速部署](#-快速部署)
- [生产环境部署](#-生产环境部署)
- [云平台部署](#️-云平台部署)
- [环境配置](#-环境配置)
- [故障排除](#-故障排除)

## 🚀 快速部署

### Docker 一键部署

适用于快速体验和本地开发：

```bash
# 1. 克隆项目
git clone https://github.com/yourusername/promote.git
cd promote

# 2. 运行部署脚本
chmod +x deploy.sh
./deploy.sh

# 3. 等待部署完成，然后访问
# 前端：http://localhost
# API：http://localhost:8080/docs
```

### 手动Docker部署

```bash
# 开发环境
docker-compose up --build -d

# 生产环境
docker-compose -f docker-compose.prod.yml up --build -d
```

## 🏭 生产环境部署

### 系统要求

- **操作系统**：Ubuntu 20.04+ / CentOS 7+ / Debian 10+
- **内存**：最小 2GB，推荐 4GB+
- **CPU**：最小 2核，推荐 4核+
- **存储**：最小 10GB，推荐 50GB+
- **Docker**：20.10+
- **Docker Compose**：2.0+

### 1. 准备服务器

```bash
# 更新系统
sudo apt update && sudo apt upgrade -y

# 安装Docker
curl -fsSL https://get.docker.com | sh
sudo usermod -aG docker $USER

# 安装Docker Compose
sudo curl -L "https://github.com/docker/compose/releases/latest/download/docker-compose-$(uname -s)-$(uname -m)" -o /usr/local/bin/docker-compose
sudo chmod +x /usr/local/bin/docker-compose

# 重新登录以应用用户组变更
exit
```

### 2. 配置生产环境

```bash
# 克隆项目
git clone https://github.com/yourusername/promote.git
cd promote

# 创建生产环境配置
cp backend/env.example backend/.env
cp frontend/env.example frontend/.env

# 编辑环境变量
nano backend/.env
```

**生产环境变量配置**：

```bash
# backend/.env
ENVIRONMENT=production
SECRET_KEY=your-super-secret-key-here
ENCRYPTION_MASTER_KEY=your-encryption-master-key
ALLOWED_ORIGINS=https://yourdomain.com,https://www.yourdomain.com
ALLOWED_HOSTS=yourdomain.com,www.yourdomain.com
DATABASE_URL=sqlite:///./data/prompt_optimizer.db

# 性能配置
WORKERS=2
MAX_WORKERS=4
WEB_CONCURRENCY=2
```

```bash
# frontend/.env
VITE_API_BASE_URL=https://yourdomain.com/api/v1
NODE_ENV=production
```

### 3. 创建必要目录

```bash
# 创建数据目录
sudo mkdir -p /opt/prompt-optimizer/{data,logs,backups}
sudo chown -R $(id -u):$(id -g) /opt/prompt-optimizer/

# 设置权限
chmod 755 /opt/prompt-optimizer/
chmod 750 /opt/prompt-optimizer/data
```

### 4. 部署应用

```bash
# 构建并启动生产环境
docker-compose -f docker-compose.prod.yml up --build -d

# 检查服务状态
docker-compose -f docker-compose.prod.yml ps

# 查看日志
docker-compose -f docker-compose.prod.yml logs -f
```

### 5. 配置反向代理（可选）

如果需要HTTPS和更好的性能，建议在前面加一层Nginx：

```nginx
# /etc/nginx/sites-available/prompt-optimizer
server {
    listen 80;
    server_name yourdomain.com www.yourdomain.com;
    return 301 https://$server_name$request_uri;
}

server {
    listen 443 ssl http2;
    server_name yourdomain.com www.yourdomain.com;

    ssl_certificate /path/to/ssl/cert.pem;
    ssl_certificate_key /path/to/ssl/private.key;

    location / {
        proxy_pass http://localhost:80;
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto $scheme;
    }
}
```

## ☁️ 云平台部署

### AWS EC2

1. **启动实例**：
   - AMI：Ubuntu 20.04 LTS
   - 实例类型：t3.medium 或更高
   - 安全组：开放80, 443, 22端口

2. **部署步骤**：
```bash
# 连接到实例
ssh -i your-key.pem ubuntu@your-ec2-ip

# 安装依赖
sudo apt update
curl -fsSL https://get.docker.com | sh
sudo usermod -aG docker ubuntu

# 部署应用
git clone https://github.com/yourusername/promote.git
cd promote
./deploy.sh
```

### Google Cloud Platform

```bash
# 创建VM实例
gcloud compute instances create prompt-optimizer \
    --image-family=ubuntu-2004-lts \
    --image-project=ubuntu-os-cloud \
    --machine-type=n1-standard-2 \
    --tags=http-server,https-server

# SSH连接并部署
gcloud compute ssh prompt-optimizer
# 然后按照标准部署流程操作
```

### DigitalOcean

1. 创建Droplet（Ubuntu 20.04，2GB内存）
2. 通过SSH连接
3. 按照标准部署流程操作

### Railway

```bash
# 安装Railway CLI
npm install -g @railway/cli

# 登录并部署
railway login
railway init
railway up
```

## 🔧 环境配置

### 环境变量说明

#### 后端环境变量

| 变量名 | 描述 | 默认值 | 必需 |
|--------|------|--------|------|
| `ENVIRONMENT` | 运行环境 | `development` | 否 |
| `SECRET_KEY` | 应用密钥 | 自动生成 | 生产环境必需 |
| `ENCRYPTION_MASTER_KEY` | 加密密钥 | 自动生成 | 生产环境必需 |
| `DATABASE_URL` | 数据库连接 | `sqlite:///./data/prompt_optimizer.db` | 否 |
| `ALLOWED_ORIGINS` | CORS允许源 | `http://localhost:5173` | 生产环境必需 |
| `ALLOWED_HOSTS` | 受信任主机 | `localhost` | 生产环境必需 |
| `WORKERS` | 工作进程数 | `1` | 否 |

#### 前端环境变量

| 变量名 | 描述 | 默认值 | 必需 |
|--------|------|--------|------|
| `VITE_API_BASE_URL` | API基础URL | `http://localhost:8080/api/v1` | 否 |
| `NODE_ENV` | Node环境 | `development` | 否 |

### 性能调优

#### 内存使用优化

```bash
# 对于1GB内存的服务器
WORKERS=1
WEB_CONCURRENCY=1

# 对于2GB内存的服务器
WORKERS=1
WEB_CONCURRENCY=2

# 对于4GB内存的服务器
WORKERS=2
WEB_CONCURRENCY=2
```

#### 数据库优化

```bash
# 定期备份数据库
docker-compose exec backend python -c "
import shutil
shutil.copy('/app/data/prompt_optimizer.db', '/app/data/backup_$(date +%Y%m%d_%H%M%S).db')
"

# 清理旧备份（保留最近7天）
find /opt/prompt-optimizer/data -name "backup_*.db" -mtime +7 -delete
```

## 🔍 故障排除

### 常见问题

#### 1. 容器无法启动

```bash
# 检查Docker状态
sudo systemctl status docker

# 查看容器日志
docker-compose logs backend
docker-compose logs frontend

# 重新构建镜像
docker-compose build --no-cache
```

#### 2. API连接失败

```bash
# 检查后端健康状态
curl http://localhost:8080/health

# 检查端口是否被占用
sudo netstat -tlnp | grep :8080

# 检查防火墙设置
sudo ufw status
```

#### 3. 前端页面无法加载

```bash
# 检查nginx配置
docker-compose exec frontend nginx -t

# 重新加载nginx配置
docker-compose exec frontend nginx -s reload

# 检查静态文件
docker-compose exec frontend ls -la /usr/share/nginx/html/
```

#### 4. 数据库权限问题

```bash
# 检查数据目录权限
ls -la /opt/prompt-optimizer/data/

# 修复权限
sudo chown -R $(id -u):$(id -g) /opt/prompt-optimizer/data/
chmod 755 /opt/prompt-optimizer/data/
```

### 日志分析

```bash
# 查看实时日志
docker-compose -f docker-compose.prod.yml logs -f

# 查看特定服务日志
docker-compose -f docker-compose.prod.yml logs backend
docker-compose -f docker-compose.prod.yml logs frontend

# 查看错误日志
docker-compose -f docker-compose.prod.yml logs | grep ERROR
```

### 性能监控

```bash
# 查看容器资源使用
docker stats

# 查看系统资源
htop
df -h
free -h

# 查看网络连接
ss -tulpn
```

## 🔄 更新部署

```bash
# 1. 备份数据
cp -r /opt/prompt-optimizer/data /opt/prompt-optimizer/backups/data_$(date +%Y%m%d_%H%M%S)

# 2. 拉取最新代码
git pull origin main

# 3. 重新构建并部署
docker-compose -f docker-compose.prod.yml down
docker-compose -f docker-compose.prod.yml up --build -d

# 4. 验证部署
curl -f http://localhost/health
```

## 📞 获取帮助

- 📚 [文档](./README.md)
- 🐛 [问题报告](https://github.com/yourusername/promote/issues)
- 💬 [讨论区](https://github.com/yourusername/promote/discussions)
- 📧 [邮件支持](mailto:support@yourdomain.com) 