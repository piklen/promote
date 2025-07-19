# 🚀 LLM提示词优化平台

<div align="center">

[![License](https://img.shields.io/badge/license-MIT-blue.svg)](LICENSE)
[![Docker](https://img.shields.io/badge/docker-ready-green.svg)](https://hub.docker.com)
[![Python](https://img.shields.io/badge/python-3.11-blue.svg)](https://python.org)
[![React](https://img.shields.io/badge/react-18-blue.svg)](https://reactjs.org)
[![FastAPI](https://img.shields.io/badge/fastapi-latest-green.svg)](https://fastapi.tiangolo.com)

一个专业的大型语言模型(LLM)提示词优化平台，帮助用户创建、测试、版本化和优化与AI交互的提示词。

[🎯 快速开始](#-快速开始) • [📚 文档](#-文档) • [🐛 问题报告](https://github.com/yourusername/promote/issues) • [💬 讨论](https://github.com/yourusername/promote/discussions)

</div>

## 功能特点

### 核心功能
- **提示词管理**：创建和管理多个提示词项目
- **版本控制**：为每个提示词保存多个版本，追踪优化历史
- **多厂商LLM集成**：支持OpenAI、Anthropic、Google等主流API
- **实时测试**：使用真实LLM API测试提示词效果
- **参数调优**：调整温度(Temperature)、最大令牌数(Max Tokens)等参数
- **智能分析**：显示执行时间、Token消耗、错误信息等详细指标
- **结果评分**：对每次测试结果进行评分，量化优化效果
- **多模型比较**：支持不同模型和提供商的结果对比
- **最佳实践**：内置提示词工程框架和优化技巧

### 提示词框架
- **CO-STAR框架**：全面定义修辞和风格要素
- **RTF框架**：简洁高效的角色-任务-格式模式
- **TAG框架**：目标导向的任务设计
- **CRISPE框架**：处理复杂任务的全方位框架

## 技术栈

### 后端
- **Python 3.8+**
- **FastAPI** - 现代高性能Web框架
- **SQLAlchemy** - ORM数据库工具
- **SQLite** - 轻量级数据库
- **Pydantic** - 数据验证

### 前端
- **React 18** - UI框架
- **TypeScript** - 类型安全
- **Vite** - 构建工具
- **Chakra UI** - 组件库
- **Axios** - HTTP客户端

## 🎯 快速开始

### 方式一：Docker 一键部署（推荐）

```bash
# 克隆项目
git clone https://github.com/yourusername/promote.git
cd promote

# 一键部署
./deploy.sh
```

访问 http://localhost 开始使用！

### 方式二：开发环境搭建

#### 环境要求
- Python 3.11+
- Node.js 18+
- Docker & Docker Compose（可选）

#### 安装步骤

1. **克隆项目**
```bash
git clone https://github.com/yourusername/promote.git
cd promote
```

2. **后端设置**
```bash
cd backend
python -m venv venv
source venv/bin/activate  # Windows: venv\Scripts\activate
pip install -r requirements.txt
uvicorn app.main:app --reload --host 0.0.0.0 --port 8080
```

3. **前端设置**
```bash
cd frontend
npm install
npm run dev
```

4. **访问应用**
- 前端：http://localhost:5173
- API文档：http://localhost:8080/docs

## 🔧 API配置管理

### 动态配置系统

本项目采用全新的**动态配置系统**，无需修改代码或环境变量即可管理LLM API：

1. **启动应用后，访问"API配置"标签页**
2. **点击"添加配置"按钮**
3. **选择提供商模板（OpenAI、Anthropic、Google等）**
4. **填写API密钥和相关信息**
5. **点击"测试"验证连接**
6. **保存配置即可使用**

### 支持的提供商

- **OpenAI**: GPT-4、GPT-3.5-turbo等
- **Anthropic**: Claude-3系列模型
- **Google**: Gemini Pro等（支持官方API和自定义地址）
- **自定义API**: 兼容OpenAI格式的任何API

### 配置特性

- ✅ **零配置部署** - 无需预先设置环境变量
- ✅ **动态更新** - 修改配置立即生效，无需重启
- ✅ **安全存储** - 配置信息加密存储在数据库
- ✅ **多提供商** - 同时使用多个LLM提供商
- ✅ **连接测试** - 一键测试API连接状态
- ✅ **模型管理** - 灵活配置支持的模型列表

### 🎯 提示词工程技术

平台集成了最新的提示词工程理论和最佳实践：

- **结构化框架**: CO-STAR、RTF、TAG、CRISPE、RACE框架
- **高级技术**: 思维链(CoT)、自洽性检验、生成知识提示、思维树等
- **质量分析**: 智能评估提示词的清晰度、具体性、上下文等维度
- **快速模板**: 8种预制模板，覆盖推理、学习、结构化等场景
- **最佳实践指导**: 常见陷阱避免、质量原则提醒

### 🤖 支持的LLM提供商

- **OpenAI**: GPT-4, GPT-3.5 等模型
- **Anthropic**: Claude-3 系列模型
- **Google**: Gemini Pro 系列模型  
- **自定义API**: 兼容OpenAI格式的其他服务

## 部署指南

### 🚀 远程Ubuntu服务器部署（推荐）

#### 一键自动部署
```bash
# 使用自动部署脚本
./remote-deploy.sh YOUR_SERVER_IP ubuntu 22

# 示例
./remote-deploy.sh 192.168.1.100 ubuntu 22
```

#### 详细部署教程
查看完整的远程部署指南：[REMOTE_DEPLOYMENT_GUIDE.md](./REMOTE_DEPLOYMENT_GUIDE.md)

### 使用Docker本地部署

项目已配置完整的Docker支持，可以一键部署到Linux服务器。

#### 快速部署

1. **确保已安装Docker和Docker Compose**
```bash
# 安装Docker
curl -fsSL https://get.docker.com | sh

# 安装Docker Compose (如果需要)
sudo curl -L "https://github.com/docker/compose/releases/download/v2.21.0/docker-compose-$(uname -s)-$(uname -m)" -o /usr/local/bin/docker-compose
sudo chmod +x /usr/local/bin/docker-compose
```

2. **克隆项目并运行部署脚本**
```bash
git clone <repository-url>
cd promote
./deploy.sh
```

部署脚本会自动：
- 检查Docker环境
- 选择部署模式（开发/生产）
- 构建并启动所有服务
- 显示访问地址和管理命令

#### 手动Docker部署

**开发环境：**
```bash
# 启动开发环境
docker-compose up --build -d

# 查看日志
docker-compose logs -f

# 停止服务
docker-compose down
```

**生产环境：**
```bash
# 创建数据目录
sudo mkdir -p /var/lib/prompt-optimizer/data

# 启动生产环境
docker-compose -f docker-compose.prod.yml up --build -d

# 查看服务状态
docker-compose -f docker-compose.prod.yml ps
```

### 环境变量配置

#### 后端环境变量
```bash
# 数据库配置
DATABASE_URL=sqlite:///./data/prompt_optimizer.db

# CORS配置（生产环境）
ALLOWED_ORIGINS=https://yourdomain.com,https://www.yourdomain.com

# 环境标识
ENVIRONMENT=production
```

#### 前端环境变量
```bash
# API基础URL
VITE_API_BASE_URL=https://your-api-domain.com/api/v1
```

### 生产环境优化

#### 性能优化
- 启用了nginx gzip压缩
- 配置了静态文件缓存
- 使用多阶段Docker构建减小镜像大小
- 实现了健康检查机制

#### 安全配置
- 通过环境变量配置CORS源
- 数据持久化到主机目录
- 容器运行时权限最小化

#### 监控和日志
- 配置了Docker日志轮转
- 提供了健康检查端点
- 支持服务状态监控

### 部署到云平台

#### 使用Docker的云平台
- **阿里云ECS**：支持Docker部署
- **腾讯云CVM**：支持Docker部署  
- **AWS EC2**：支持Docker部署
- **DigitalOcean Droplets**：支持Docker部署

#### PaaS平台部署

**Render部署（不使用Docker）：**
1. **后端部署**
   - 创建新的Web Service
   - 连接GitHub仓库
   - 构建命令：`pip install -r requirements.txt`
   - 启动命令：`uvicorn app.main:app --host 0.0.0.0 --port $PORT`

2. **前端部署**
   - 创建新的Static Site
   - 构建命令：`npm install && npm run build`
   - 发布目录：`dist`
   - 环境变量：`VITE_API_BASE_URL=<后端URL>`

#### 其他云平台
- **Vercel**：适合前端部署
- **Railway**：支持Docker全栈部署
- **Heroku**：支持容器化部署

## 项目结构

```
promote/
├── backend/
│   ├── app/
│   │   ├── models/          # 数据库模型
│   │   ├── schemas/         # Pydantic模式
│   │   ├── routers/         # API路由
│   │   ├── core/           # 核心配置
│   │   ├── database.py     # 数据库配置
│   │   └── main.py         # 应用入口
│   └── requirements.txt
│
├── frontend/
│   ├── src/
│   │   ├── components/     # React组件
│   │   ├── services/       # API服务
│   │   ├── hooks/         # 自定义Hooks
│   │   ├── utils/         # 工具函数
│   │   └── App.tsx        # 主应用
│   ├── package.json
│   └── vite.config.ts
│
└── README.md
```

## API文档

### 主要端点

- `GET /api/v1/prompts` - 获取所有提示词项目
- `POST /api/v1/prompts` - 创建新提示词项目
- `GET /api/v1/prompts/{id}` - 获取单个提示词详情
- `POST /api/v1/prompts/{id}/versions` - 创建新版本
- `GET /api/v1/versions/{id}` - 获取版本详情
- `POST /api/v1/versions/{id}/results` - 保存测试结果

完整API文档请访问：http://localhost:8080/docs

## 开发指南

### 添加新功能
1. 后端：在`routers`中添加新路由
2. 前端：在`components`中创建新组件
3. 更新API服务和类型定义

### 代码规范
- 后端：遵循PEP 8
- 前端：使用ESLint和Prettier
- 提交信息：使用语义化版本

## 贡献指南

欢迎贡献代码！请遵循以下步骤：
1. Fork项目
2. 创建功能分支
3. 提交更改
4. 推送到分支
5. 创建Pull Request

## 许可证

MIT License

## 联系方式

如有问题或建议，请提交Issue或联系维护者。 