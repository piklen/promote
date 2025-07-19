# 📚 API 文档

LLM提示词优化平台 RESTful API 文档

## 基础信息

- **基础URL**: `http://localhost:8080/api/v1`
- **认证方式**: 暂无（未来版本将支持）
- **数据格式**: JSON
- **API版本**: v1

## 目录

- [提示词管理](#-提示词管理)
- [版本控制](#-版本控制)
- [LLM服务](#-llm服务)
- [API配置](#-api配置)
- [错误处理](#-错误处理)

## 🎯 提示词管理

### 获取提示词列表

```http
GET /api/v1/prompts
```

**查询参数**：
- `skip` (int, 可选): 跳过的记录数，默认0
- `limit` (int, 可选): 返回的记录数，默认100

**响应示例**：
```json
[
  {
    "id": 1,
    "title": "代码生成助手",
    "description": "用于生成高质量代码的提示词",
    "category": "代码生成",
    "tags": ["programming", "code", "assistant"],
    "is_public": false,
    "is_template": false,
    "framework_type": "CO-STAR",
    "created_at": "2024-01-01T10:00:00Z",
    "updated_at": "2024-01-01T10:00:00Z"
  }
]
```

### 创建提示词

```http
POST /api/v1/prompts
```

**请求体**：
```json
{
  "title": "新提示词",
  "description": "提示词描述",
  "category": "分类名称",
  "tags": ["标签1", "标签2"],
  "is_public": false,
  "is_template": false,
  "framework_type": "CO-STAR"
}
```

**响应**: 201 Created，返回创建的提示词对象

### 获取单个提示词

```http
GET /api/v1/prompts/{id}
```

**路径参数**：
- `id` (int): 提示词ID

**响应**: 200 OK，返回提示词对象

### 更新提示词

```http
PUT /api/v1/prompts/{id}
```

**请求体**: 与创建提示词相同（所有字段可选）

**响应**: 200 OK，返回更新后的提示词对象

### 删除提示词

```http
DELETE /api/v1/prompts/{id}
```

**响应**: 204 No Content

## 📝 版本控制

### 获取提示词版本列表

```http
GET /api/v1/prompts/{prompt_id}/versions
```

**响应示例**：
```json
[
  {
    "id": 1,
    "prompt_id": 1,
    "version_number": 1,
    "version_name": "初始版本",
    "content": "你是一个专业的代码生成助手...",
    "llm_config": {
      "provider": "openai",
      "model": "gpt-4",
      "temperature": 0.7,
      "max_tokens": 1000
    },
    "change_notes": "创建初始版本",
    "is_baseline": true,
    "created_at": "2024-01-01T10:00:00Z"
  }
]
```

### 创建新版本

```http
POST /api/v1/prompts/{prompt_id}/versions
```

**请求体**：
```json
{
  "version_name": "优化版本",
  "content": "提示词内容",
  "llm_config": {
    "provider": "openai",
    "model": "gpt-4",
    "temperature": 0.7,
    "max_tokens": 1000
  },
  "change_notes": "优化了提示词结构"
}
```

### 获取版本详情

```http
GET /api/v1/versions/{version_id}
```

### 保存测试结果

```http
POST /api/v1/versions/{version_id}/results
```

**请求体**：
```json
{
  "test_input": "测试输入",
  "output_text": "LLM输出结果",
  "execution_time": 2.5,
  "input_tokens": 100,
  "output_tokens": 200,
  "total_tokens": 300,
  "cost": 0.002,
  "user_rating": 4,
  "quality_score": 8.5,
  "llm_provider": "openai",
  "llm_model": "gpt-4"
}
```

## 🤖 LLM服务

### 获取支持的提供商

```http
GET /api/v1/llm/providers
```

**响应示例**：
```json
{
  "providers": ["openai", "anthropic", "google"],
  "models": {
    "openai": ["gpt-4", "gpt-3.5-turbo"],
    "anthropic": ["claude-3-opus", "claude-3-sonnet"],
    "google": ["gemini-pro"]
  }
}
```

### 获取提供商模型

```http
GET /api/v1/llm/providers/{provider}/models
```

**响应示例**：
```json
{
  "provider": "openai",
  "models": ["gpt-4", "gpt-4-turbo", "gpt-3.5-turbo"]
}
```

### 生成文本

```http
POST /api/v1/llm/generate
```

**请求体**：
```json
{
  "provider": "openai",
  "model": "gpt-4",
  "prompt": "你好，请介绍一下人工智能",
  "temperature": 0.7,
  "max_tokens": 1000,
  "stream": false
}
```

**响应示例**：
```json
{
  "success": true,
  "response": "人工智能是计算机科学的一个分支...",
  "execution_time": 2.34,
  "tokens": {
    "input": 15,
    "output": 120,
    "total": 135
  },
  "cost": 0.0027,
  "provider": "openai",
  "model": "gpt-4"
}
```

## ⚙️ API配置

### 获取所有配置

```http
GET /api/v1/api-config/
```

### 获取启用的配置

```http
GET /api/v1/api-config/enabled
```

### 获取配置状态

```http
GET /api/v1/api-config/status
```

**响应示例**：
```json
{
  "total_configs": 3,
  "enabled_configs": 2,
  "working_configs": 1,
  "last_updated": "2024-01-01T12:00:00Z"
}
```

### 获取提供商模板

```http
GET /api/v1/api-config/templates
```

**响应示例**：
```json
[
  {
    "provider": "openai",
    "display_name": "OpenAI",
    "description": "OpenAI GPT模型，支持GPT-4、GPT-3.5等",
    "default_models": ["gpt-4", "gpt-3.5-turbo"],
    "required_fields": ["api_key"],
    "optional_fields": ["api_url", "timeout"],
    "api_url_required": false,
    "setup_instructions": [
      "访问 https://platform.openai.com/api-keys",
      "创建新的API密钥",
      "输入API密钥即可使用"
    ],
    "example_config": {
      "temperature": 0.7,
      "max_tokens": 1000
    }
  }
]
```

### 创建API配置

```http
POST /api/v1/api-config/
```

**请求体**：
```json
{
  "provider": "openai",
  "display_name": "OpenAI",
  "is_enabled": true,
  "api_key": "sk-your-api-key-here",
  "api_url": null,
  "timeout": 60,
  "extra_config": {},
  "supported_models": ["gpt-4", "gpt-3.5-turbo"],
  "default_model": "gpt-4",
  "description": "OpenAI配置"
}
```

### 更新API配置

```http
PUT /api/v1/api-config/{config_id}
```

### 测试API配置

```http
POST /api/v1/api-config/test/{config_id}
```

**请求体**：
```json
{
  "test_prompt": "Hello, this is a test."
}
```

**响应示例**：
```json
{
  "status": "success",
  "response": "Hello! I'm working correctly.",
  "execution_time": 1.23,
  "model_used": "gpt-4"
}
```

### 删除API配置

```http
DELETE /api/v1/api-config/{config_id}
```

## ❌ 错误处理

### 错误响应格式

```json
{
  "detail": "错误描述",
  "error_code": "ERROR_CODE",
  "timestamp": "2024-01-01T12:00:00Z"
}
```

### 常见错误码

| HTTP状态码 | 错误码 | 描述 |
|-----------|--------|------|
| 400 | `INVALID_INPUT` | 请求参数无效 |
| 401 | `UNAUTHORIZED` | 未授权访问 |
| 403 | `FORBIDDEN` | 禁止访问 |
| 404 | `NOT_FOUND` | 资源不存在 |
| 422 | `VALIDATION_ERROR` | 数据验证失败 |
| 429 | `RATE_LIMIT_EXCEEDED` | 超出速率限制 |
| 500 | `INTERNAL_ERROR` | 服务器内部错误 |
| 502 | `LLM_SERVICE_ERROR` | LLM服务错误 |
| 503 | `SERVICE_UNAVAILABLE` | 服务暂时不可用 |

### 验证错误示例

```json
{
  "detail": [
    {
      "loc": ["body", "title"],
      "msg": "field required",
      "type": "value_error.missing"
    },
    {
      "loc": ["body", "api_key"],
      "msg": "ensure this value has at least 10 characters",
      "type": "value_error.any_str.min_length",
      "ctx": {"limit_value": 10}
    }
  ]
}
```

## 🔐 安全性

### 速率限制

- API配置创建：10次/分钟
- API配置更新：20次/分钟
- LLM生成请求：60次/分钟
- 其他请求：100次/分钟

### 输入验证

所有用户输入都经过严格验证：
- SQL注入检测
- XSS攻击检测
- 输入长度限制
- 恶意字符过滤

### 数据加密

- API密钥使用AES-256加密存储
- 敏感配置信息加密传输
- 数据库连接使用SSL/TLS

## 📊 使用限制

- 单个提示词最大100个版本
- 单次请求最大token数：4000
- 文件上传最大大小：20MB
- 并发请求限制：根据配置动态调整

## 🔄 版本变更

### v1.1.0
- 添加API密钥加密存储
- 优化错误处理
- 增强安全性验证

### v1.0.0
- 初始API版本
- 基础CRUD操作
- LLM服务集成

## 📞 技术支持

- 📚 [完整文档](./README.md)
- 🐛 [问题报告](https://github.com/yourusername/promote/issues)
- 💬 [API讨论](https://github.com/yourusername/promote/discussions)
- 📧 技术支持：api-support@yourdomain.com 