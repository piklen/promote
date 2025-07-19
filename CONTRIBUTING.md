# 贡献指南 Contributing Guide

欢迎为 LLM 提示词优化平台贡献代码！

## 如何贡献

### 报告问题 Bug Reports

如果发现问题，请通过 [GitHub Issues](../../issues) 报告：

1. 使用清晰描述性的标题
2. 提供详细的问题描述
3. 包含复现步骤
4. 说明期望行为和实际行为
5. 提供环境信息（操作系统、浏览器、Docker版本等）

### 功能请求 Feature Requests

我们欢迎新功能建议：

1. 在 Issues 中描述功能需求
2. 说明使用场景和预期收益
3. 提供可能的实现方案

### 代码贡献 Code Contributions

#### 开发环境设置

```bash
# 1. Fork 并克隆项目
git clone https://github.com/your-username/promote.git
cd promote

# 2. 创建虚拟环境（后端）
cd backend
python -m venv venv
source venv/bin/activate  # Windows: venv\Scripts\activate
pip install -r requirements.txt

# 3. 安装前端依赖
cd ../frontend
npm install

# 4. 运行开发环境
npm run dev
```

#### 开发流程

1. **创建分支**
   ```bash
   git checkout -b feature/your-feature-name
   ```

2. **代码规范**
   - 后端：遵循 PEP 8 规范
   - 前端：使用 ESLint 和 Prettier
   - 提交信息：使用语义化版本规范

3. **编写测试**
   - 为新功能添加单元测试
   - 确保所有测试通过
   ```bash
   # 后端测试
   cd backend && python -m pytest
   
   # 前端测试
   cd frontend && npm test
   ```

4. **提交代码**
   ```bash
   git add .
   git commit -m "feat: add new feature description"
   git push origin feature/your-feature-name
   ```

5. **创建 Pull Request**
   - 描述更改内容
   - 链接相关 Issues
   - 添加测试截图（如适用）

#### 代码规范 Code Standards

##### 后端 (Python/FastAPI)

```python
# 类型注解
from typing import List, Optional

def get_prompts(db: Session, skip: int = 0, limit: int = 100) -> List[Prompt]:
    """获取提示词列表，包含详细的文档字符串"""
    return db.query(Prompt).offset(skip).limit(limit).all()

# 异常处理
try:
    result = await llm_service.generate_text(prompt, model)
except LLMServiceError as e:
    raise HTTPException(status_code=500, detail=str(e))
```

##### 前端 (React/TypeScript)

```typescript
// 组件类型定义
interface PromptListProps {
  prompts: Prompt[];
  onSelect: (prompt: Prompt) => void;
}

// 错误边界和加载状态
const PromptList: React.FC<PromptListProps> = ({ prompts, onSelect }) => {
  const [loading, setLoading] = useState(false);
  const [error, setError] = useState<string | null>(null);
  
  // 实现组件逻辑
};
```

##### 提交信息规范

使用语义化版本格式：

```
feat: 添加新功能
fix: 修复问题
docs: 更新文档
style: 格式调整（不影响代码运行）
refactor: 重构（不是新功能，也不是修复问题）
test: 添加测试
chore: 构建过程或辅助工具的变动
```

#### Docker 开发

使用 Docker 进行开发和测试：

```bash
# 开发环境
docker-compose up --build

# 生产环境测试
docker-compose -f docker-compose.prod.yml up --build

# 查看日志
docker-compose logs -f backend
docker-compose logs -f frontend
```

## 项目结构

```
promote/
├── backend/                 # FastAPI 后端
│   ├── app/
│   │   ├── models/         # SQLAlchemy 数据模型
│   │   ├── schemas/        # Pydantic 模式
│   │   ├── routers/        # API 路由
│   │   ├── services/       # 业务逻辑
│   │   └── main.py         # 应用入口
│   ├── tests/              # 后端测试
│   └── requirements.txt    # Python 依赖
├── frontend/               # React 前端
│   ├── src/
│   │   ├── components/     # React 组件
│   │   ├── services/       # API 服务
│   │   └── utils/          # 工具函数
│   ├── tests/              # 前端测试
│   └── package.json        # Node.js 依赖
└── docs/                   # 项目文档
```

## 发布流程

1. 更新版本号
2. 更新 CHANGELOG.md
3. 创建 Git tag
4. 构建 Docker 镜像
5. 发布到 GitHub Releases

## 社区

- 讨论：[GitHub Discussions](../../discussions)
- 问题追踪：[GitHub Issues](../../issues)
- 邮件列表：[项目邮件列表]

## 许可证

本项目采用 MIT 许可证。详见 [LICENSE](LICENSE) 文件。

---

感谢您的贡献！每一个贡献都让这个项目变得更好。 