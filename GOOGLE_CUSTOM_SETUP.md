# Google 自定义API配置指南

## 概述

本指南详细说明如何在项目中配置通过自定义地址调用Google模型（如Gemini）的功能。这对于需要通过代理服务器、自定义网关或企业内部服务访问Google AI模型的场景特别有用。

## 配置方式

### 1. 环境变量配置

在后端的 `.env` 文件中添加以下配置：

```bash
# Google自定义配置（通过自定义地址调用）
GOOGLE_CUSTOM_API_KEY=your_google_api_key_here
GOOGLE_CUSTOM_API_URL=https://your-custom-google-proxy.com
GOOGLE_CUSTOM_TIMEOUT=60
GOOGLE_CUSTOM_API_FORMAT=openai  # openai, google, gemini
GOOGLE_CUSTOM_MODEL_PREFIX=gemini
```

### 2. 配置参数说明

| 参数 | 说明 | 示例值 |
|------|------|--------|
| `GOOGLE_CUSTOM_API_KEY` | Google API密钥 | `AIza...` |
| `GOOGLE_CUSTOM_API_URL` | 自定义代理地址 | `https://api.proxy.com` |
| `GOOGLE_CUSTOM_TIMEOUT` | 请求超时时间（秒） | `60` |
| `GOOGLE_CUSTOM_API_FORMAT` | API格式类型 | `openai`/`google`/`gemini` |
| `GOOGLE_CUSTOM_MODEL_PREFIX` | 模型名称前缀 | `gemini` |

### 3. API格式说明

#### OpenAI兼容格式 (推荐)
```json
{
  "model": "gemini-pro",
  "messages": [{"role": "user", "content": "Hello"}],
  "temperature": 0.7,
  "max_tokens": 1000
}
```

#### Google原生格式
```json
{
  "contents": [{"parts": [{"text": "Hello"}]}],
  "generationConfig": {
    "temperature": 0.7,
    "maxOutputTokens": 1000
  }
}
```

## 使用场景

### 1. 代理服务器
如果您需要通过代理服务器访问Google API：
```bash
GOOGLE_CUSTOM_API_URL=https://your-proxy.com/google-api
GOOGLE_CUSTOM_API_FORMAT=openai
```

### 2. 企业网关
通过企业内部API网关访问：
```bash
GOOGLE_CUSTOM_API_URL=https://enterprise-gateway.company.com/ai/google
GOOGLE_CUSTOM_API_FORMAT=google
```

### 3. 第三方集成平台
通过第三方AI平台访问Google模型：
```bash
GOOGLE_CUSTOM_API_URL=https://platform.ai-service.com/v1
GOOGLE_CUSTOM_API_FORMAT=openai
```

## 模型支持

系统支持以下Google模型：
- `gemini-pro`
- `gemini-pro-vision`
- `gemini-1.5-pro-latest`
- `gemini-1.5-flash`
- `gemini-1.0-pro`

## 测试配置

### 1. 通过API配置页面测试
1. 启动应用后，访问"API配置"标签页
2. 找到"Google (自定义地址)"提供商
3. 点击"测试连接"按钮
4. 查看连接状态和响应时间

### 2. 通过命令行测试
```bash
curl -X POST "http://localhost:8080/api/v1/llm/generate" \
  -H "Content-Type: application/json" \
  -d '{
    "provider": "google_custom",
    "model": "gemini-pro",
    "prompt": "Hello, how are you?",
    "temperature": 0.7,
    "max_tokens": 100
  }'
```

## 故障排除

### 常见问题

#### 1. 连接超时
**错误**: `Request timeout`
**解决方案**: 
- 增加 `GOOGLE_CUSTOM_TIMEOUT` 值
- 检查网络连接和代理服务器状态

#### 2. 认证失败
**错误**: `Authentication failed`
**解决方案**:
- 验证 `GOOGLE_CUSTOM_API_KEY` 是否正确
- 检查API密钥是否有权限访问所需的模型

#### 3. API格式不匹配
**错误**: `Invalid request format`
**解决方案**:
- 确认代理服务支持的API格式
- 调整 `GOOGLE_CUSTOM_API_FORMAT` 参数

#### 4. 模型不支持
**错误**: `Model not found`
**解决方案**:
- 检查模型名称是否正确
- 确认代理服务支持指定的模型

### 调试技巧

1. **启用详细日志**：
   在 `.env` 中添加：
   ```bash
   LOG_LEVEL=DEBUG
   ```

2. **检查请求响应**：
   查看应用日志中的API请求和响应详情

3. **测试代理连通性**：
   ```bash
   curl -v https://your-custom-google-proxy.com/health
   ```

## 安全注意事项

1. **API密钥保护**：
   - 不要在代码中硬编码API密钥
   - 使用环境变量管理敏感信息
   - 定期轮换API密钥

2. **网络安全**：
   - 使用HTTPS进行所有API通信
   - 验证代理服务器的SSL证书
   - 考虑使用VPN或专用网络连接

3. **访问控制**：
   - 限制API密钥的权限范围
   - 监控API使用情况和异常访问

## 示例配置

### 配置示例1：通过Cloudflare Worker代理
```bash
GOOGLE_CUSTOM_API_KEY=AIzaSy...
GOOGLE_CUSTOM_API_URL=https://google-ai-proxy.your-domain.workers.dev
GOOGLE_CUSTOM_API_FORMAT=openai
GOOGLE_CUSTOM_TIMEOUT=30
```

### 配置示例2：通过Nginx反向代理
```bash
GOOGLE_CUSTOM_API_KEY=AIzaSy...
GOOGLE_CUSTOM_API_URL=https://api-gateway.company.com/google
GOOGLE_CUSTOM_API_FORMAT=google
GOOGLE_CUSTOM_TIMEOUT=60
```

### 配置示例3：直接访问但使用自定义域名
```bash
GOOGLE_CUSTOM_API_KEY=AIzaSy...
GOOGLE_CUSTOM_API_URL=https://ai.your-domain.com/google-api
GOOGLE_CUSTOM_API_FORMAT=gemini
GOOGLE_CUSTOM_TIMEOUT=45
```

## 支持

如果您在配置过程中遇到问题，请：

1. 检查配置是否正确
2. 查看应用日志获取详细错误信息
3. 验证网络连接和代理服务状态
4. 参考本指南的故障排除部分

更多技术支持，请参考项目的主要文档或提交issue。 