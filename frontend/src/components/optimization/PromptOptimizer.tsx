import { useState, useEffect } from 'react'
import {
  Box,
  VStack,
  HStack,
  Grid,
  GridItem,
  Heading,
  Text,
  Textarea,
  Button,
  Card,
  CardBody,
  CardHeader,
  Select,
  FormControl,
  FormLabel,
  Slider,
  SliderTrack,
  SliderFilledTrack,
  SliderThumb,
  SliderMark,
  Badge,
  Divider,
  useToast,
  Tabs,
  TabList,
  TabPanels,
  Tab,
  TabPanel,
  Table,
  Thead,
  Tbody,
  Tr,
  Th,
  Td,
  IconButton,
  Spinner,
  Alert,
  AlertIcon,
} from '@chakra-ui/react'
import { StarIcon, RepeatIcon, CopyIcon } from '@chakra-ui/icons'
import { PromptAPI, VersionAPI, LLMAPI, Prompt, PromptVersion } from '../../services/api'
import QuickTemplates from './QuickTemplates'
import PromptQualityAnalyzer from './PromptQualityAnalyzer'

interface TestResult {
  id?: number;
  output: string;
  executionTime: number;
  rating?: number;
  usage?: Record<string, any>;
  provider?: string;
  model?: string;
  error?: string;
}

function PromptOptimizer() {
  const [prompts, setPrompts] = useState<Prompt[]>([])
  const [selectedPrompt, setSelectedPrompt] = useState<number | null>(null)
  const [currentVersion, setCurrentVersion] = useState<PromptVersion | null>(null)
  const [promptContent, setPromptContent] = useState('')
  const [temperature, setTemperature] = useState(0.7)
  const [maxTokens, setMaxTokens] = useState(500)
  const [testResults, setTestResults] = useState<TestResult[]>([])
  const [loading, setLoading] = useState(false)
  const [comparing, setComparing] = useState(false)
  
  // LLM相关状态
  const [providers, setProviders] = useState<ProvidersResponse | null>(null)
  const [selectedProvider, setSelectedProvider] = useState<string>('')
  const [selectedModel, setSelectedModel] = useState<string>('')
  const [availableModels, setAvailableModels] = useState<string[]>([])
  
  const toast = useToast()

  // 获取提供商显示名称
  const getProviderDisplayName = (provider: string) => {
    switch (provider) {
      case 'openai': return 'OpenAI'
      case 'anthropic': return 'Anthropic'
      case 'google': return 'Google (官方)'
      case 'google_custom': return 'Google (自定义地址)'
      case 'custom': return '自定义API'
      default: return provider.toUpperCase()
    }
  }

  useEffect(() => {
    loadPrompts()
    loadProviders()
  }, [])

  useEffect(() => {
    if (selectedProvider && providers) {
      const models = providers.models[selectedProvider] || []
      setAvailableModels(models)
      setSelectedModel(models[0] || '')
    }
  }, [selectedProvider, providers])

  const loadPrompts = async () => {
    try {
      const data = await promptApi.getPrompts()
      setPrompts(data)
    } catch (error) {
      toast({
        title: '加载失败',
        status: 'error',
        duration: 3000,
        isClosable: true,
      })
    }
  }

  const loadProviders = async () => {
    try {
      const data = await llmApi.getProviders()
      setProviders(data)
      
      // 选择第一个可用的提供商
      if (data.providers.length > 0) {
        const firstProvider = data.providers[0]
        setSelectedProvider(firstProvider)
      }
    } catch (error) {
      toast({
        title: '无法加载LLM提供商',
        description: '请检查API密钥配置',
        status: 'warning',
        duration: 5000,
        isClosable: true,
      })
    }
  }

  const handlePromptSelect = async (promptId: number) => {
    setSelectedPrompt(promptId)
    try {
      const promptData = await promptApi.getPromptById(promptId)
      if (promptData.versions.length > 0) {
        const latestVersion = promptData.versions[promptData.versions.length - 1]
        setCurrentVersion(latestVersion)
        setPromptContent(latestVersion.content)
        
        // 加载参数
        if (latestVersion.parameters) {
          setTemperature(latestVersion.parameters.temperature || 0.7)
          setMaxTokens(latestVersion.parameters.max_tokens || 500)
        }
      }
    } catch (error) {
      toast({
        title: '加载版本失败',
        status: 'error',
        duration: 3000,
        isClosable: true,
      })
    }
  }

  const handleSaveVersion = async () => {
    if (!selectedPrompt) {
      toast({
        title: '请先选择一个提示词项目',
        status: 'warning',
        duration: 2000,
        isClosable: true,
      })
      return
    }

    try {
      const newVersion = await promptApi.createVersion(selectedPrompt, {
        content: promptContent,
        parameters: {
          temperature,
          max_tokens: maxTokens,
          model: 'gpt-3.5-turbo',
        },
      })
      setCurrentVersion(newVersion)
      toast({
        title: '版本保存成功',
        description: `版本号：${newVersion.version_number}`,
        status: 'success',
        duration: 2000,
        isClosable: true,
      })
    } catch (error) {
      toast({
        title: '保存失败',
        status: 'error',
        duration: 3000,
        isClosable: true,
      })
    }
  }

  const handleTestPrompt = async () => {
    if (!promptContent.trim()) {
      toast({
        title: '请输入提示词内容',
        status: 'warning',
        duration: 2000,
        isClosable: true,
      })
      return
    }

    if (!selectedProvider || !selectedModel) {
      toast({
        title: '请选择LLM提供商和模型',
        status: 'warning',
        duration: 2000,
        isClosable: true,
      })
      return
    }

    setLoading(true)
    
    try {
      const request: LLMRequest = {
        provider: selectedProvider,
        model: selectedModel,
        prompt: promptContent,
        temperature: temperature,
        max_tokens: maxTokens,
        parameters: {}
      }
      
      const response: LLMResponse = await llmApi.generateText(request)
      
      const result: TestResult = {
        output: response.error ? 
          `错误: ${response.error}` : 
          (response.text || '无返回内容'),
        executionTime: response.execution_time,
        rating: undefined,
        id: Date.now(),
        usage: response.usage,
        provider: response.provider,
        model: response.model,
        error: response.error
      }
      
      setTestResults([result, ...testResults.slice(0, 4)])
      
      toast({
        title: response.error ? '测试失败' : '测试完成',
        description: response.error ? response.error : `执行时间: ${response.execution_time.toFixed(2)}秒`,
        status: response.error ? 'error' : 'success',
        duration: 3000,
        isClosable: true,
      })
      
    } catch (error: any) {
      const errorResult: TestResult = {
        output: `网络错误: ${error.message || '未知错误'}`,
        executionTime: 0,
        rating: undefined,
        id: Date.now(),
        error: error.message
      }
      
      setTestResults([errorResult, ...testResults.slice(0, 4)])
      
      toast({
        title: '请求失败',
        description: error.message || '网络错误',
        status: 'error',
        duration: 3000,
        isClosable: true,
      })
    } finally {
      setLoading(false)
    }
  }

  const handleRateResult = (index: number, rating: number) => {
    const updatedResults = [...testResults]
    updatedResults[index].rating = rating
    setTestResults(updatedResults)
  }

  return (
    <Grid templateColumns="1fr 2fr" gap={6} height="calc(100vh - 200px)">
      {/* 左侧面板 - 提示词编辑 */}
      <GridItem>
        <Card height="100%">
          <CardHeader>
            <Heading size="md">提示词编辑器</Heading>
          </CardHeader>
          <CardBody>
            <VStack spacing={4} align="stretch">
              <FormControl>
                <FormLabel>选择提示词项目</FormLabel>
                <Select
                  placeholder="选择一个项目"
                  value={selectedPrompt || ''}
                  onChange={(e) => handlePromptSelect(Number(e.target.value))}
                >
                  {prompts.map((prompt) => (
                    <option key={prompt.id} value={prompt.id}>
                      {prompt.title}
                    </option>
                  ))}
                </Select>
              </FormControl>

              {currentVersion && (
                <Badge colorScheme="blue">当前版本：v{currentVersion.version_number}</Badge>
              )}

              <QuickTemplates onSelectTemplate={(template) => setPromptContent(template)} />
              
              <Divider />

              <FormControl>
                <FormLabel>提示词内容</FormLabel>
                <Textarea
                  value={promptContent}
                  onChange={(e) => setPromptContent(e.target.value)}
                  placeholder="输入您的提示词，或从上方快速模板中选择..."
                  height="250px"
                  fontSize="sm"
                />
              </FormControl>

              <Divider />

              <FormControl>
                <FormLabel>LLM提供商</FormLabel>
                <Select
                  value={selectedProvider}
                  onChange={(e) => setSelectedProvider(e.target.value)}
                  placeholder="选择提供商"
                >
                  {providers?.providers.map((provider) => (
                    <option key={provider} value={provider}>
                      {getProviderDisplayName(provider)}
                    </option>
                  ))}
                </Select>
              </FormControl>

              <FormControl>
                <FormLabel>模型</FormLabel>
                <Select
                  value={selectedModel}
                  onChange={(e) => setSelectedModel(e.target.value)}
                  placeholder="选择模型"
                  isDisabled={!selectedProvider}
                >
                  {availableModels.map((model) => (
                    <option key={model} value={model}>
                      {model}
                    </option>
                  ))}
                </Select>
              </FormControl>

              <FormControl>
                <FormLabel>
                  温度 (Temperature): {temperature}
                </FormLabel>
                <Slider
                  value={temperature}
                  onChange={(val) => setTemperature(val)}
                  min={0}
                  max={2}
                  step={0.1}
                >
                  <SliderMark value={0} mt="1" fontSize="xs">0</SliderMark>
                  <SliderMark value={1} mt="1" fontSize="xs">1</SliderMark>
                  <SliderMark value={2} mt="1" fontSize="xs">2</SliderMark>
                  <SliderTrack bg="gray.200">
                    <SliderFilledTrack bg="blue.500" />
                  </SliderTrack>
                  <SliderThumb boxSize={4} />
                </Slider>
              </FormControl>

              <FormControl>
                <FormLabel>
                  最大令牌数 (Max Tokens): {maxTokens}
                </FormLabel>
                <Slider
                  value={maxTokens}
                  onChange={(val) => setMaxTokens(val)}
                  min={50}
                  max={2000}
                  step={50}
                >
                  <SliderMark value={50} mt="1" fontSize="xs">50</SliderMark>
                  <SliderMark value={1000} mt="1" fontSize="xs">1K</SliderMark>
                  <SliderMark value={2000} mt="1" fontSize="xs">2K</SliderMark>
                  <SliderTrack bg="gray.200">
                    <SliderFilledTrack bg="blue.500" />
                  </SliderTrack>
                  <SliderThumb boxSize={4} />
                </Slider>
              </FormControl>

              <HStack spacing={3}>
                <Button
                  colorScheme="blue"
                  onClick={handleTestPrompt}
                  isLoading={loading}
                  loadingText="测试中"
                  width="full"
                >
                  测试提示词
                </Button>
                <Button
                  variant="outline"
                  onClick={handleSaveVersion}
                  width="full"
                >
                  保存版本
                </Button>
              </HStack>
            </VStack>
          </CardBody>
        </Card>
      </GridItem>

      {/* 右侧面板 - 测试结果与质量分析 */}
      <GridItem>
        <VStack spacing={4} align="stretch">
          {/* 质量分析器 */}
          <PromptQualityAnalyzer prompt={promptContent} />
          
          {/* 测试结果 */}
          <Card>
            <CardHeader>
              <HStack justify="space-between">
                <Heading size="md">测试结果</Heading>
              <Button
                size="sm"
                variant="ghost"
                leftIcon={<RepeatIcon />}
                onClick={() => setTestResults([])}
              >
                清空结果
              </Button>
            </HStack>
          </CardHeader>
          <CardBody overflowY="auto">
            {testResults.length === 0 ? (
              <Alert status="info">
                <AlertIcon />
                <Text>还没有测试结果。点击"测试提示词"开始测试。</Text>
              </Alert>
            ) : (
              <VStack spacing={4} align="stretch">
                {testResults.map((result, index) => (
                  <Card key={result.id || index} variant="outline">
                    <CardBody>
                      <VStack align="stretch" spacing={3}>
                        <HStack justify="space-between" wrap="wrap">
                          <HStack spacing={2}>
                            <Badge colorScheme="purple">测试 #{testResults.length - index}</Badge>
                            {result.provider && (
                              <Badge colorScheme="blue" variant="outline">
                                {result.provider.toUpperCase()}
                              </Badge>
                            )}
                            {result.model && (
                              <Badge colorScheme="green" variant="outline">
                                {result.model}
                              </Badge>
                            )}
                            {result.error && (
                              <Badge colorScheme="red">
                                错误
                              </Badge>
                            )}
                          </HStack>
                          <HStack>
                            <Text fontSize="sm" color="gray.500">
                              {result.executionTime.toFixed(2)}s
                            </Text>
                            <IconButton
                              aria-label="复制"
                              icon={<CopyIcon />}
                              size="sm"
                              variant="ghost"
                              onClick={() => {
                                navigator.clipboard.writeText(result.output)
                                toast({
                                  title: '已复制到剪贴板',
                                  status: 'success',
                                  duration: 1000,
                                })
                              }}
                            />
                          </HStack>
                        </HStack>
                        
                        <Box 
                          bg={result.error ? "red.50" : "gray.50"} 
                          p={3} 
                          borderRadius="md"
                          borderLeft={result.error ? "4px" : "none"}
                          borderColor={result.error ? "red.400" : "transparent"}
                        >
                          <Text 
                            fontSize="sm" 
                            whiteSpace="pre-wrap"
                            color={result.error ? "red.800" : "inherit"}
                          >
                            {result.output}
                          </Text>
                        </Box>

                        {result.usage && !result.error && (
                          <Box fontSize="xs" color="gray.600" bg="blue.50" p={2} borderRadius="md">
                            <Text fontWeight="medium" mb={1}>Token 使用情况:</Text>
                            <Text>
                              {result.usage.total_tokens ? (
                                `总计: ${result.usage.total_tokens} tokens`
                              ) : (
                                Object.entries(result.usage)
                                  .filter(([_, value]) => typeof value === 'number' && value > 0)
                                  .map(([key, value]) => `${key}: ${value}`)
                                  .join(', ')
                              )}
                            </Text>
                          </Box>
                        )}

                        <HStack justify="space-between">
                          <HStack>
                            <Text fontSize="sm">评分：</Text>
                            {[1, 2, 3, 4, 5].map((star) => (
                              <IconButton
                                key={star}
                                aria-label={`评分 ${star}`}
                                icon={<StarIcon />}
                                size="sm"
                                variant="ghost"
                                color={result.rating && result.rating >= star ? 'yellow.400' : 'gray.300'}
                                onClick={() => handleRateResult(index, star)}
                              />
                            ))}
                          </HStack>
                        </HStack>
                      </VStack>
                    </CardBody>
                  </Card>
                ))}
              </VStack>
            )}
          </CardBody>
        </Card>
        </VStack>
      </GridItem>
    </Grid>
  )
}

export default PromptOptimizer 