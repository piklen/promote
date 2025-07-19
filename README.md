# LLM提示词优化平台

🚀 一个现代化的大语言模型提示词创建、管理和优化的Web应用平台。支持多种LLM提供商，提供可视化的提示词编辑和优化功能。

## ✨ 功能特性

### 🎯 核心功能
- **动态API配置**: 通过Web界面配置和管理多个LLM提供商的API密钥
- **提示词管理**: 创建、编辑、版本控制和组织提示词
- **智能优化**: 基于最佳实践自动优化提示词性能
- **实时测试**: 在线测试提示词效果，支持多模型对比
- **模板系统**: 内置丰富的提示词模板库

### 🔌 支持的LLM提供商
- **OpenAI**: GPT-3.5, GPT-4系列
- **Anthropic**: Claude系列
- **Google**: PaLM, Gemini系列
- **自定义API**: 支持OpenAI兼容的API端点

### 🛡️ 安全特性
- API密钥加密存储
- 动态配置管理，无需重启服务
- 完整的访问控制和日志记录
- 生产级别的安全头配置

## 🏗️ 技术架构

### 后端技术栈
- **FastAPI**: 高性能Python Web框架
- **SQLAlchemy**: ORM和数据库管理
- **Pydantic**: 数据验证和序列化
- **Docker**: 容器化部署

### 前端技术栈
- **React 18**: 现代化用户界面
- **TypeScript**: 类型安全的JavaScript
- **Chakra UI**: 组件库和设计系统
- **Vite**: 快速构建工具

### 部署架构
- **Docker Compose**: 多容器编排
- **Nginx**: 反向代理和静态文件服务
- **SQLite**: 轻量级数据库（可扩展到PostgreSQL）

## 🚀 快速开始

### 前置要求
- Docker 20.10+
- Docker Compose 2.0+
- 2GB+ 可用内存

### 开发环境部署

1. **克隆项目**
```bash
git clone https://github.com/yourusername/llm-prompt-optimizer.git
cd llm-prompt-optimizer
```

2. **启动开发环境**
```bash
docker-compose up -d
```

3. **访问应用**
- 前端应用: http://localhost:5173
- 后端API: http://localhost:8080
- API文档: http://localhost:8080/api/docs

### 生产环境部署

1. **准备VPS服务器**
```bash
# 更新系统
sudo apt update && sudo apt upgrade -y

# 安装Docker（如果未安装）
curl -fsSL https://get.docker.com | sh
sudo usermod -aG docker $USER
```

2. **上传项目并部署**
```bash
# 基本部署
./remote-deploy.sh YOUR_SERVER_IP

# 带域名和备份的部署
./remote-deploy.sh -d yourdomain.com -b YOUR_SERVER_IP

# 查看所有选项
./remote-deploy.sh --help
```

3. **配置API密钥**
访问 `http://YOUR_SERVER_IP`，在"API配置"页面添加您的LLM提供商API密钥。

## ⚙️ 配置指南

### 环境变量说明

**开发环境** (docker-compose.yml)
```env
ENVIRONMENT=development
DATABASE_URL=sqlite:///./data/prompt_optimizer.db
VITE_API_BASE_URL=http://localhost:8080/api/v1
```

**生产环境** (.env.prod)
```env
ENVIRONMENT=production
DATABASE_URL=sqlite:///./data/prompt_optimizer.db
ALLOWED_ORIGINS=https://yourdomain.com
ALLOWED_HOSTS=yourdomain.com
LOG_DIR=/app/logs
```

### API配置管理

**无需环境变量** - 所有LLM API配置都通过Web界面管理：

1. 访问"API配置"页面
2. 点击"添加配置"
3. 选择提供商模板
4. 输入API密钥和相关配置
5. 测试连接并保存

支持的配置项：
- API密钥
- 自定义API端点
- 超时设置
- 支持模型列表
- 默认模型选择

## 📚 使用指南

### 1. 配置LLM提供商

首次使用需要配置至少一个LLM提供商：

1. 转到"API配置"标签页
2. 点击"添加配置"
3. 选择提供商（如OpenAI）
4. 输入API密钥
5. 测试连接
6. 保存配置

### 2. 创建提示词

1. 转到"提示词管理"标签页
2. 点击"新建提示词"
3. 编写提示词内容
4. 添加描述和标签
5. 保存提示词

### 3. 优化提示词

1. 转到"提示词优化"标签页
2. 输入或选择要优化的提示词
3. 选择目标LLM模型
4. 点击"开始优化"
5. 查看优化建议和对比结果

### 4. 使用模板

1. 转到"最佳实践"标签页
2. 浏览内置模板库
3. 选择合适的模板
4. 自定义模板内容
5. 另存为新提示词

## 🔧 高级配置

### SSL证书配置

```bash
# 创建SSL证书目录
mkdir -p ./ssl

# 使用Let's Encrypt（推荐）
certbot certonly --standalone -d yourdomain.com
cp /etc/letsencrypt/live/yourdomain.com/*.pem ./ssl/

# 或使用自签名证书（开发环境）
openssl req -x509 -newkey rsa:4096 -keyout ./ssl/key.pem -out ./ssl/cert.pem -days 365 -nodes
```

### 反向代理配置

```nginx
server {
    listen 80;
    server_name yourdomain.com;
    
    location / {
        proxy_pass http://localhost:80;
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
    }
    
    location /api/ {
        proxy_pass http://localhost:8080/api/;
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
    }
}
```

### 数据备份

```bash
# 手动备份
docker exec prompt-optimizer-backend-prod tar -czf /tmp/backup.tar.gz -C /app data/

# 定时备份（crontab）
0 2 * * * docker exec prompt-optimizer-backend-prod tar -czf /opt/prompt-optimizer/backups/backup_$(date +\%Y\%m\%d).tar.gz -C /app data/
```

## 🐛 故障排查

### 常见问题

**1. 容器启动失败**
```bash
# 查看日志
docker-compose logs -f

# 检查权限
sudo chown -R $USER:$USER ./data ./logs
```

**2. API连接失败**
- 检查API密钥是否正确
- 确认网络连接正常
- 查看API配置中的端点URL

**3. 前端无法访问后端**
- 确认CORS配置正确
- 检查防火墙设置
- 验证API_BASE_URL配置

### 日志查看

```bash
# 查看所有服务日志
docker-compose -f docker-compose.prod.yml logs -f

# 查看特定服务日志
docker-compose -f docker-compose.prod.yml logs -f backend
docker-compose -f docker-compose.prod.yml logs -f frontend
```

### 性能监控

```bash
# 查看资源使用情况
docker stats

# 查看服务状态
docker-compose -f docker-compose.prod.yml ps
```

## 🤝 贡献指南

我们欢迎任何形式的贡献！

### 开发流程

1. Fork项目
2. 创建功能分支
3. 提交变更
4. 创建Pull Request

### 代码规范

- **Python**: 遵循PEP 8规范
- **TypeScript**: 使用ESLint和Prettier
- **提交信息**: 使用约定式提交格式

## 📄 许可证

本项目采用 [MIT 许可证](LICENSE)。

## 🙋‍♂️ 支持

- **文档**: 查看本README和API文档
- **问题**: 提交GitHub Issue
- **讨论**: 参与GitHub Discussions

## 🗺️ 开发路线图

### v1.2.0 (计划中)
- [ ] 支持更多LLM提供商
- [ ] 高级提示词分析功能
- [ ] 团队协作功能
- [ ] 提示词性能分析

### v1.3.0 (计划中)
- [ ] 多租户支持
- [ ] API使用统计
- [ ] 自动化测试套件
- [ ] 移动端适配

---

⭐ 如果这个项目对您有帮助，请给我们一个星标！ 