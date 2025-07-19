import axios, { AxiosResponse, AxiosError, InternalAxiosRequestConfig } from 'axios';

// 创建axios实例，符合蓝图建议的API客户端设计
const api = axios.create({
  baseURL: import.meta.env.VITE_API_BASE_URL || '/api/v1',
  headers: {
    'Content-Type': 'application/json',
  },
  timeout: 10000, // 10秒超时
});

// 请求拦截器 - 添加错误处理
api.interceptors.request.use(
  (config: InternalAxiosRequestConfig) => {
    // 可以在这里添加认证头等
    return config;
  },
  (error: AxiosError) => {
    return Promise.reject(error);
  }
);

// 响应拦截器 - 统一错误处理
api.interceptors.response.use(
  (response: AxiosResponse) => response,
  (error: AxiosError) => {
    // 统一错误处理
    if (error.response?.status === 404) {
      console.error('资源未找到:', error.response.data?.detail || 'Unknown error');
    } else if (error.response?.status === 422) {
      console.error('数据验证错误:', error.response.data?.detail || 'Validation error');
    } else if (error.response?.status && error.response.status >= 500) {
      console.error('服务器错误:', error.response.data?.detail || 'Server error');
    }
    return Promise.reject(error);
  }
);

// TypeScript接口定义 - 基于后端Pydantic模式
export interface LLMConfig {
  provider: 'openai' | 'anthropic' | 'google' | 'google_custom' | 'custom';
  model: string;
  temperature?: number;
  max_tokens?: number;
  top_p?: number;
  frequency_penalty?: number;
  presence_penalty?: number;
  stop_sequences?: string[];
}

// 新增缺失的类型定义
export interface LLMRequest {
  prompt: string;
  config: LLMConfig;
}

export interface LLMResponse {
  content: string;
  usage?: {
    prompt_tokens?: number;
    completion_tokens?: number;
    total_tokens?: number;
  };
  model?: string;
  provider?: string;
  execution_time?: number;
  cost?: number;
}

export interface ProviderInfo {
  name: string;
  display_name: string;
  models: string[];
  available: boolean;
  configured: boolean;
}

export interface ProvidersResponse {
  providers: ProviderInfo[];
}

export interface Prompt {
  id: number;
  title: string;
  description?: string;
  category?: string;
  tags?: string[];
  is_public: boolean;
  is_template: boolean;
  framework_type?: string;
  created_at: string;
  updated_at: string;
}

export interface PromptCreate {
  title: string;
  description?: string;
  category?: string;
  tags?: string[];
  is_public?: boolean;
  is_template?: boolean;
  framework_type?: string;
}

export interface PromptUpdate {
  title?: string;
  description?: string;
  category?: string;
  tags?: string[];
  is_public?: boolean;
  is_template?: boolean;
  framework_type?: string;
}

export interface PromptVersion {
  id: number;
  prompt_id: number;
  version_number: number;
  version_name?: string;
  content: string;
  llm_config?: LLMConfig;
  change_notes?: string;
  is_baseline: boolean;
  created_at: string;
}

export interface PromptVersionCreate {
  version_name?: string;
  content: string;
  llm_config?: LLMConfig;
  change_notes?: string;
  is_baseline?: boolean;
}

export interface OptimizationResult {
  id: number;
  version_id: number;
  test_input?: string;
  output_text: string;
  execution_time?: number;
  input_tokens?: number;
  output_tokens?: number;
  total_tokens?: number;
  cost?: number;
  user_rating?: number;
  quality_score?: number;
  quality_analysis?: Record<string, any>;
  is_error: boolean;
  error_message?: string;
  error_type?: string;
  llm_provider?: string;
  llm_model?: string;
  created_at: string;
}

export interface OptimizationResultCreate {
  test_input?: string;
  output_text: string;
  execution_time?: number;
  input_tokens?: number;
  output_tokens?: number;
  total_tokens?: number;
  cost?: number;
  user_rating?: number;
  quality_score?: number;
  quality_analysis?: Record<string, any>;
  is_error?: boolean;
  error_message?: string;
  error_type?: string;
  llm_provider?: string;
  llm_model?: string;
}

export interface PromptWithVersions extends Prompt {
  versions: PromptVersion[];
}

export interface VersionWithResults extends PromptVersion {
  optimization_results: OptimizationResult[];
}

// API客户端类 - 模块化设计
export class PromptAPI {
  // 获取所有提示词
  static async getPrompts(skip = 0, limit = 100): Promise<Prompt[]> {
    const response = await api.get('/prompts', { params: { skip, limit } });
    return response.data;
  }

  // 创建新提示词
  static async createPrompt(data: PromptCreate): Promise<Prompt> {
    const response = await api.post('/prompts', data);
    return response.data;
  }

  // 获取单个提示词（包含版本）
  static async getPromptById(id: number): Promise<PromptWithVersions> {
    const response = await api.get(`/prompts/${id}`);
    return response.data;
  }

  // 更新提示词
  static async updatePrompt(id: number, data: PromptUpdate): Promise<Prompt> {
    const response = await api.put(`/prompts/${id}`, data);
    return response.data;
  }

  // 删除提示词
  static async deletePrompt(id: number): Promise<void> {
    await api.delete(`/prompts/${id}`);
  }

  // 创建新版本
  static async createVersion(promptId: number, data: PromptVersionCreate): Promise<PromptVersion> {
    const response = await api.post(`/prompts/${promptId}/versions`, data);
    return response.data;
  }
}

export class VersionAPI {
  // 获取单个版本（包含结果）
  static async getVersionById(id: number): Promise<VersionWithResults> {
    const response = await api.get(`/versions/${id}`);
    return response.data;
  }

  // 创建优化结果
  static async createResult(versionId: number, data: OptimizationResultCreate): Promise<OptimizationResult> {
    const response = await api.post(`/versions/${versionId}/results`, data);
    return response.data;
  }

  // 获取版本的所有结果
  static async getVersionResults(versionId: number): Promise<OptimizationResult[]> {
    const response = await api.get(`/versions/${versionId}/results`);
    return response.data;
  }
}

export class LLMAPI {
  // 获取LLM提供商列表
  static async getProviders(): Promise<ProvidersResponse> {
    const response = await api.get('/llm/providers');
    return response.data;
  }

  // 测试LLM连接
  static async testConnection(provider: string): Promise<any> {
    const response = await api.post('/llm/test', { provider });
    return response.data;
  }

  // 获取模型列表
  static async getModels(provider: string): Promise<string[]> {
    const response = await api.get(`/llm/models/${provider}`);
    return response.data;
  }

  // 执行LLM请求
  static async generateCompletion(data: LLMRequest): Promise<LLMResponse> {
    const response = await api.post('/llm/generate', data);
    return response.data;
  }
}

// 向后兼容的导出
export const promptApi = {
  getPrompts: PromptAPI.getPrompts,
  createPrompt: PromptAPI.createPrompt,
  getPromptById: PromptAPI.getPromptById,
  updatePrompt: PromptAPI.updatePrompt,
  deletePrompt: PromptAPI.deletePrompt,
  createVersion: PromptAPI.createVersion,
};

export const versionApi = {
  getVersionById: VersionAPI.getVersionById,
  createResult: VersionAPI.createResult,
  getVersionResults: VersionAPI.getVersionResults,
};

export const llmApi = {
  getProviders: LLMAPI.getProviders,
  testConnection: LLMAPI.testConnection,
  getModels: LLMAPI.getModels,
  generateCompletion: LLMAPI.generateCompletion,
};

// 默认导出主要API实例
export default {
  prompt: PromptAPI,
  version: VersionAPI,
  llm: LLMAPI,
}; 