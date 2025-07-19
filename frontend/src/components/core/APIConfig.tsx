import { useState, useEffect } from 'react'
import {
  Box,
  VStack,
  HStack,
  Heading,
  Card,
  CardBody,
  CardHeader,
  Text,
  Badge,
  Button,
  Alert,
  AlertIcon,
  useToast,
  Table,
  Thead,
  Tbody,
  Tr,
  Th,
  Td,
  TableContainer,
  Spinner,
  Icon,
  Flex,
  Code,
  Divider,
  Modal,
  ModalOverlay,
  ModalContent,
  ModalHeader,
  ModalFooter,
  ModalBody,
  ModalCloseButton,
  FormControl,
  FormLabel,
  Input,
  Textarea,
  Select,
  Switch,
  NumberInput,
  NumberInputField,
  NumberInputStepper,
  NumberIncrementStepper,
  NumberDecrementStepper,
  IconButton,
  useDisclosure,
  AlertDialog,
  AlertDialogBody,
  AlertDialogFooter,
  AlertDialogHeader,
  AlertDialogContent,
  AlertDialogOverlay,
  Tag,
  TagLabel,
  TagCloseButton,
  List,
  ListItem,
  ListIcon,
} from '@chakra-ui/react'
import { 
  CheckIcon, 
  WarningIcon, 
  RepeatIcon, 
  AddIcon, 
  EditIcon, 
  DeleteIcon,
  ExternalLinkIcon 
} from '@chakra-ui/icons'
import { LLMAPI } from '../../services/api'
import { useRef } from 'react'

interface APIConfig {
  id: number
  provider: string
  display_name: string
  is_enabled: boolean
  api_key: string
  api_url?: string
  timeout: number
  extra_config: Record<string, any>
  supported_models: string[]
  default_model?: string
  description?: string
  created_at: string
  updated_at: string
  last_test_at?: string
  last_test_status?: 'success' | 'error' | 'pending'
  last_test_error?: string
}

interface ProviderTemplate {
  provider: string
  display_name: string
  description: string
  default_models: string[]
  required_fields: string[]
  optional_fields: string[]
  api_url_required: boolean
  setup_instructions: string[]
  example_config: Record<string, any>
}

interface ConfigFormData {
  provider: string
  display_name: string
  is_enabled: boolean
  api_key: string
  api_url: string
  timeout: number
  extra_config: Record<string, any>
  supported_models: string[]
  default_model: string
  description: string
}

function APIConfig() {
  const [configs, setConfigs] = useState<APIConfig[]>([])
  const [templates, setTemplates] = useState<ProviderTemplate[]>([])
  const [loading, setLoading] = useState(true)
  const [testing, setTesting] = useState<number | null>(null)
  const [selectedTemplate, setSelectedTemplate] = useState<ProviderTemplate | null>(null)
  const [configForm, setConfigForm] = useState<ConfigFormData>({
    provider: '',
    display_name: '',
    is_enabled: true,
    api_key: '',
    api_url: '',
    timeout: 60,
    extra_config: {},
    supported_models: [],
    default_model: '',
    description: ''
  })
  const [editingConfig, setEditingConfig] = useState<APIConfig | null>(null)
  const [modelInput, setModelInput] = useState('')
  
  const toast = useToast()
  const { isOpen: isConfigModalOpen, onOpen: onConfigModalOpen, onClose: onConfigModalClose } = useDisclosure()
  const { isOpen: isDeleteAlertOpen, onOpen: onDeleteAlertOpen, onClose: onDeleteAlertClose } = useDisclosure()
  const [configToDelete, setConfigToDelete] = useState<APIConfig | null>(null)
  const cancelRef = useRef<HTMLButtonElement>(null)

  useEffect(() => {
    loadData()
  }, [])

  const loadData = async () => {
    setLoading(true)
    try {
      const [configsData, templatesData] = await Promise.all([
        fetch('/api/v1/api-config/').then(res => res.json()),
        fetch('/api/v1/api-config/templates').then(res => res.json())
      ])
      
      setConfigs(configsData)
      setTemplates(templatesData)
    } catch (error: any) {
      toast({
        title: '加载失败',
        description: error.message,
        status: 'error',
        duration: 3000,
        isClosable: true,
      })
    }
    setLoading(false)
  }

  const handleCreateConfig = () => {
    setEditingConfig(null)
    setConfigForm({
      provider: '',
      display_name: '',
      is_enabled: true,
      api_key: '',
      api_url: '',
      timeout: 60,
      extra_config: {},
      supported_models: [],
      default_model: '',
      description: ''
    })
    setSelectedTemplate(null)
    onConfigModalOpen()
  }

  const handleEditConfig = (config: APIConfig) => {
    setEditingConfig(config)
    setConfigForm({
      provider: config.provider,
      display_name: config.display_name,
      is_enabled: config.is_enabled,
      api_key: config.api_key,
      api_url: config.api_url || '',
      timeout: config.timeout,
      extra_config: config.extra_config || {},
      supported_models: config.supported_models,
      default_model: config.default_model || '',
      description: config.description || ''
    })
    
    // 找到对应的模板
    const template = templates.find(t => t.provider === config.provider)
    setSelectedTemplate(template || null)
    
    onConfigModalOpen()
  }

  const handleDeleteConfig = (config: APIConfig) => {
    setConfigToDelete(config)
    onDeleteAlertOpen()
  }

  const confirmDeleteConfig = async () => {
    if (!configToDelete) return
    
    try {
      const response = await fetch(`/api/v1/api-config/${configToDelete.id}`, {
        method: 'DELETE'
      })
      
      if (!response.ok) {
        throw new Error('删除失败')
      }
      
      toast({
        title: '删除成功',
        description: `${configToDelete.display_name} 配置已删除`,
        status: 'success',
        duration: 3000,
        isClosable: true,
      })
      
      await loadData()
    } catch (error: any) {
      toast({
        title: '删除失败',
        description: error.message,
        status: 'error',
        duration: 3000,
        isClosable: true,
      })
    }
    
    onDeleteAlertClose()
    setConfigToDelete(null)
  }

  const handleTemplateSelect = (templateProvider: string) => {
    const template = templates.find(t => t.provider === templateProvider)
    if (template) {
      setSelectedTemplate(template)
      setConfigForm(prev => ({
        ...prev,
        provider: template.provider,
        display_name: template.display_name,
        supported_models: template.default_models,
        default_model: template.default_models[0] || '',
        description: template.description,
        extra_config: template.example_config
      }))
    }
  }

  const handleAddModel = () => {
    if (modelInput.trim() && !configForm.supported_models.includes(modelInput.trim())) {
      setConfigForm(prev => ({
        ...prev,
        supported_models: [...prev.supported_models, modelInput.trim()]
      }))
      setModelInput('')
    }
  }

  const handleRemoveModel = (model: string) => {
    setConfigForm(prev => ({
      ...prev,
      supported_models: prev.supported_models.filter(m => m !== model),
      default_model: prev.default_model === model ? '' : prev.default_model
    }))
  }

  const handleSaveConfig = async () => {
    try {
      const url = editingConfig 
        ? `/api/v1/api-config/${editingConfig.id}`
        : '/api/v1/api-config/'
      
      const method = editingConfig ? 'PUT' : 'POST'
      
      const response = await fetch(url, {
        method,
        headers: {
          'Content-Type': 'application/json'
        },
        body: JSON.stringify(configForm)
      })
      
      if (!response.ok) {
        const error = await response.json()
        throw new Error(error.detail || '保存失败')
      }
      
      toast({
        title: editingConfig ? '更新成功' : '创建成功',
        description: `${configForm.display_name} 配置已${editingConfig ? '更新' : '创建'}`,
        status: 'success',
        duration: 3000,
        isClosable: true,
      })
      
      onConfigModalClose()
      await loadData()
    } catch (error: any) {
      toast({
        title: editingConfig ? '更新失败' : '创建失败',
        description: error.message,
        status: 'error',
        duration: 3000,
        isClosable: true,
      })
    }
  }

  const handleTestConfig = async (config: APIConfig) => {
    setTesting(config.id)
    
    try {
      const response = await fetch(`/api/v1/api-config/test/${config.id}`, {
        method: 'POST',
        headers: {
          'Content-Type': 'application/json'
        },
        body: JSON.stringify({
          provider: config.provider,
          test_prompt: "Hello, this is a test."
        })
      })
      
      const result = await response.json()
      
      toast({
        title: `${config.display_name} 测试${result.status === 'success' ? '成功' : '失败'}`,
        description: result.status === 'success' 
          ? `响应时间: ${result.execution_time?.toFixed(2)}秒`
          : result.error,
        status: result.status === 'success' ? 'success' : 'error',
        duration: 5000,
        isClosable: true,
      })
      
      await loadData() // 重新加载以更新测试状态
    } catch (error: any) {
      toast({
        title: `${config.display_name} 测试失败`,
        description: error.message,
        status: 'error',
        duration: 3000,
        isClosable: true,
      })
    }
    
    setTesting(null)
  }

  const getStatusColor = (status?: string) => {
    switch (status) {
      case 'success': return 'green'
      case 'error': return 'red'
      case 'pending': return 'blue'
      default: return 'gray'
    }
  }

  const getStatusText = (status?: string) => {
    switch (status) {
      case 'success': return '测试通过'
      case 'error': return '测试失败'
      case 'pending': return '测试中...'
      default: return '未测试'
    }
  }

  if (loading) {
    return (
      <Box p={6}>
        <VStack spacing={4}>
          <Spinner size="lg" />
          <Text>加载API配置...</Text>
        </VStack>
      </Box>
    )
  }

  return (
    <Box p={6}>
      <VStack spacing={6} align="stretch">
        <Flex justify="space-between" align="center">
          <Box>
            <Heading size="lg" mb={2}>LLM API 配置管理</Heading>
            <Text color="gray.600">
              通过界面配置和管理LLM API连接，无需修改环境变量。
            </Text>
          </Box>
          <Button leftIcon={<AddIcon />} colorScheme="blue" onClick={handleCreateConfig}>
            添加配置
          </Button>
        </Flex>

        <Alert status="info">
          <AlertIcon />
          <Box>
            <Text fontWeight="bold">动态配置</Text>
            <Text>
              所有配置信息存储在数据库中，修改后立即生效，无需重启服务。
            </Text>
          </Box>
        </Alert>

        {configs.length === 0 ? (
          <Card>
            <CardBody>
              <VStack spacing={4} py={8}>
                <Text fontSize="lg" color="gray.500">还没有配置任何LLM提供商</Text>
                <Text color="gray.400">点击"添加配置"开始配置您的第一个LLM提供商</Text>
                <Button leftIcon={<AddIcon />} colorScheme="blue" onClick={handleCreateConfig}>
                  添加配置
                </Button>
              </VStack>
            </CardBody>
          </Card>
        ) : (
          <Card>
            <CardHeader>
              <HStack justify="space-between">
                <Heading size="md">已配置的提供商</Heading>
                <Button
                  leftIcon={<RepeatIcon />}
                  onClick={loadData}
                  size="sm"
                  variant="ghost"
                >
                  刷新
                </Button>
              </HStack>
            </CardHeader>
            <CardBody>
              <TableContainer>
                <Table variant="simple">
                  <Thead>
                    <Tr>
                      <Th>提供商</Th>
                      <Th>状态</Th>
                      <Th>模型数量</Th>
                      <Th>最近测试</Th>
                      <Th>操作</Th>
                    </Tr>
                  </Thead>
                  <Tbody>
                    {configs.map((config) => (
                      <Tr key={config.id}>
                        <Td>
                          <VStack align="start" spacing={1}>
                            <Text fontWeight="medium">{config.display_name}</Text>
                            <Text fontSize="sm" color="gray.500">{config.description}</Text>
                          </VStack>
                        </Td>
                        <Td>
                          <VStack align="start" spacing={1}>
                            <HStack>
                              <Badge colorScheme={config.is_enabled ? 'green' : 'gray'}>
                                {config.is_enabled ? '启用' : '禁用'}
                              </Badge>
                              <Badge colorScheme={getStatusColor(config.last_test_status)}>
                                {getStatusText(config.last_test_status)}
                              </Badge>
                            </HStack>
                            {config.last_test_error && (
                              <Text fontSize="xs" color="red.500" maxW="200px" isTruncated>
                                {config.last_test_error}
                              </Text>
                            )}
                          </VStack>
                        </Td>
                        <Td>
                          <Text>{config.supported_models.length} 个模型</Text>
                          {config.default_model && (
                            <Text fontSize="sm" color="gray.500">
                              默认: {config.default_model}
                            </Text>
                          )}
                        </Td>
                        <Td>
                          <Text fontSize="sm" color="gray.500">
                            {config.last_test_at 
                              ? new Date(config.last_test_at).toLocaleString()
                              : '从未测试'
                            }
                          </Text>
                        </Td>
                        <Td>
                          <HStack>
                            <Button
                              size="sm"
                              onClick={() => handleTestConfig(config)}
                              isLoading={testing === config.id}
                              isDisabled={!config.is_enabled}
                              colorScheme={config.last_test_status === 'success' ? 'green' : 'blue'}
                            >
                              测试
                            </Button>
                            <IconButton
                              aria-label="编辑"
                              icon={<EditIcon />}
                              size="sm"
                              onClick={() => handleEditConfig(config)}
                            />
                            <IconButton
                              aria-label="删除"
                              icon={<DeleteIcon />}
                              size="sm"
                              colorScheme="red"
                              variant="ghost"
                              onClick={() => handleDeleteConfig(config)}
                            />
                          </HStack>
                        </Td>
                      </Tr>
                    ))}
                  </Tbody>
                </Table>
              </TableContainer>
            </CardBody>
          </Card>
        )}

        {/* 配置模态框 */}
        <Modal isOpen={isConfigModalOpen} onClose={onConfigModalClose} size="xl">
          <ModalOverlay />
          <ModalContent>
            <ModalHeader>
              {editingConfig ? '编辑API配置' : '添加API配置'}
            </ModalHeader>
            <ModalCloseButton />
            <ModalBody>
              <VStack spacing={4} align="stretch">
                {!editingConfig && (
                  <FormControl>
                    <FormLabel>选择提供商模板</FormLabel>
                    <Select
                      placeholder="选择一个提供商"
                      value={selectedTemplate?.provider || ''}
                      onChange={(e) => handleTemplateSelect(e.target.value)}
                    >
                      {templates.map((template) => (
                        <option key={template.provider} value={template.provider}>
                          {template.display_name} - {template.description}
                        </option>
                      ))}
                    </Select>
                  </FormControl>
                )}

                {selectedTemplate && (
                  <Alert status="info" borderRadius="md">
                    <AlertIcon />
                    <Box>
                      <Text fontWeight="bold">{selectedTemplate.display_name}</Text>
                      <Text fontSize="sm">{selectedTemplate.description}</Text>
                      <List spacing={1} mt={2}>
                        {selectedTemplate.setup_instructions.map((instruction, index) => (
                          <ListItem key={index} fontSize="sm">
                            <ListIcon as={CheckIcon} color="green.500" />
                            {instruction}
                          </ListItem>
                        ))}
                      </List>
                    </Box>
                  </Alert>
                )}

                <FormControl isRequired>
                  <FormLabel>显示名称</FormLabel>
                  <Input
                    value={configForm.display_name}
                    onChange={(e) => setConfigForm(prev => ({ ...prev, display_name: e.target.value }))}
                    placeholder="如：OpenAI、Google自定义等"
                  />
                </FormControl>

                <FormControl isRequired>
                  <FormLabel>API密钥</FormLabel>
                  <Input
                    type="password"
                    value={configForm.api_key}
                    onChange={(e) => setConfigForm(prev => ({ ...prev, api_key: e.target.value }))}
                    placeholder="输入API密钥"
                  />
                </FormControl>

                {selectedTemplate?.api_url_required && (
                  <FormControl isRequired>
                    <FormLabel>API地址</FormLabel>
                    <Input
                      value={configForm.api_url}
                      onChange={(e) => setConfigForm(prev => ({ ...prev, api_url: e.target.value }))}
                      placeholder="https://api.example.com"
                    />
                  </FormControl>
                )}

                <FormControl>
                  <FormLabel>超时时间（秒）</FormLabel>
                  <NumberInput
                    value={configForm.timeout}
                    onChange={(valueString) => setConfigForm(prev => ({ 
                      ...prev, 
                      timeout: parseInt(valueString) || 60 
                    }))}
                    min={1}
                    max={300}
                  >
                    <NumberInputField />
                    <NumberInputStepper>
                      <NumberIncrementStepper />
                      <NumberDecrementStepper />
                    </NumberInputStepper>
                  </NumberInput>
                </FormControl>

                <FormControl>
                  <FormLabel>支持的模型</FormLabel>
                  <HStack>
                    <Input
                      value={modelInput}
                      onChange={(e) => setModelInput(e.target.value)}
                      placeholder="输入模型名称"
                      onKeyPress={(e) => e.key === 'Enter' && handleAddModel()}
                    />
                    <Button onClick={handleAddModel} size="sm">
                      添加
                    </Button>
                  </HStack>
                  <HStack mt={2} flexWrap="wrap">
                    {configForm.supported_models.map((model) => (
                      <Tag key={model} size="sm" colorScheme="blue">
                        <TagLabel>{model}</TagLabel>
                        <TagCloseButton onClick={() => handleRemoveModel(model)} />
                      </Tag>
                    ))}
                  </HStack>
                </FormControl>

                {configForm.supported_models.length > 0 && (
                  <FormControl>
                    <FormLabel>默认模型</FormLabel>
                    <Select
                      value={configForm.default_model}
                      onChange={(e) => setConfigForm(prev => ({ ...prev, default_model: e.target.value }))}
                    >
                      <option value="">无</option>
                      {configForm.supported_models.map((model) => (
                        <option key={model} value={model}>
                          {model}
                        </option>
                      ))}
                    </Select>
                  </FormControl>
                )}

                <FormControl>
                  <FormLabel>描述</FormLabel>
                  <Textarea
                    value={configForm.description}
                    onChange={(e) => setConfigForm(prev => ({ ...prev, description: e.target.value }))}
                    placeholder="简要描述此配置的用途"
                    rows={3}
                  />
                </FormControl>

                <FormControl display="flex" alignItems="center">
                  <FormLabel htmlFor="is-enabled" mb="0">
                    启用此配置
                  </FormLabel>
                  <Switch
                    id="is-enabled"
                    isChecked={configForm.is_enabled}
                    onChange={(e) => setConfigForm(prev => ({ ...prev, is_enabled: e.target.checked }))}
                  />
                </FormControl>
              </VStack>
            </ModalBody>
            <ModalFooter>
              <Button variant="ghost" mr={3} onClick={onConfigModalClose}>
                取消
              </Button>
              <Button
                colorScheme="blue"
                onClick={handleSaveConfig}
                isDisabled={!configForm.display_name || !configForm.api_key || configForm.supported_models.length === 0}
              >
                {editingConfig ? '更新' : '创建'}
              </Button>
            </ModalFooter>
          </ModalContent>
        </Modal>

        {/* 删除确认对话框 */}
        <AlertDialog
          isOpen={isDeleteAlertOpen}
          leastDestructiveRef={cancelRef}
          onClose={onDeleteAlertClose}
        >
          <AlertDialogOverlay>
            <AlertDialogContent>
              <AlertDialogHeader fontSize="lg" fontWeight="bold">
                删除API配置
              </AlertDialogHeader>
              <AlertDialogBody>
                确定要删除 <strong>{configToDelete?.display_name}</strong> 的配置吗？
                此操作无法撤销。
              </AlertDialogBody>
              <AlertDialogFooter>
                <Button ref={cancelRef} onClick={onDeleteAlertClose}>
                  取消
                </Button>
                <Button colorScheme="red" onClick={confirmDeleteConfig} ml={3}>
                  删除
                </Button>
              </AlertDialogFooter>
            </AlertDialogContent>
          </AlertDialogOverlay>
        </AlertDialog>
      </VStack>
    </Box>
  )
}

export default APIConfig 