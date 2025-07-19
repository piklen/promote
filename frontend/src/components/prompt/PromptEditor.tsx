import { useState } from 'react'
import {
  Box,
  VStack,
  HStack,
  Heading,
  Textarea,
  Button,
  Select,
  FormControl,
  FormLabel,
  Card,
  CardBody,
  CardHeader,
  Text,
  Badge,
  Tabs,
  TabList,
  TabPanels,
  Tab,
  TabPanel,
  Code,
  Alert,
  AlertIcon,
  AlertTitle,
  AlertDescription,
} from '@chakra-ui/react'

// 提示词框架模板
const promptFrameworks = {
  COSTAR: {
    name: 'CO-STAR框架',
    description: '全面定义修辞和风格要素，适合内容创作、营销文案',
    category: 'structured',
    complexity: '中等',
    bestFor: ['内容创作', '市场营销', '沟通文案'],
    template: `[Context - 情境]
描述任务的背景信息和上下文，提供必要的背景知识

[Objective - 目标]
明确说明期望达到的具体目标，要清晰、可衡量

[Style - 风格]
指定写作或回应的风格（如正式、幽默、技术性、学术性等）

[Tone - 语气]
定义交流的语气（如友好、专业、鼓励性、权威性等）

[Audience - 受众]
描述目标受众的特征（专业水平、背景知识、需求等）

[Response - 响应格式]
明确期望的输出格式和结构（列表、段落、JSON、代码等）`,
  },
  RTF: {
    name: 'RTF框架',
    description: '简洁高效，适合执行明确指令、生成列表摘要',
    category: 'structured',
    complexity: '简单',
    bestFor: ['生成列表', '摘要', '执行简单指令'],
    template: `[Role - 角色]
你是一位具有丰富经验的[专业领域]专家...

[Task - 任务]
请完成以下任务：[具体任务描述]

[Format - 格式]
输出格式要求：[明确的格式规范，如列表、表格、JSON等]`,
  },
  TAG: {
    name: 'TAG框架',
    description: '目标导向，强调最终目的',
    template: `[Task - 任务]
具体需要完成的任务是...

[Action - 行动]
执行任务的具体步骤...

[Goal - 目标]
最终要达到的目标是...`,
  },
  CRISPE: {
    name: 'CRISPE框架',
    description: '全方位定义复杂任务',
    template: `[Capacity - 能力]
以...的身份/能力

[Role - 角色]
作为...

[Insight - 洞察]
了解到...

[Statement - 声明]
需要...

[Personality - 个性]
以...的风格

[Experiment - 实验]
尝试...`,
  },
}

// 提示词优化技巧
const optimizationTips = [
  {
    title: '使用清晰具体的语言',
    description: '避免模糊表达，提供明确的指令和约束条件',
    example: '❌ 写一篇关于气候变化的文章\n✅ 为高中生撰写一篇200字的文章，解释1950年以来气候变化的原因',
  },
  {
    title: '提供上下文信息',
    description: '背景信息帮助模型更好地理解任务意图',
    example: '在提示词中包含：任务背景、目标受众、使用场景等信息',
  },
  {
    title: '使用正面指令',
    description: '告诉模型"应该做什么"而不是"不要做什么"',
    example: '❌ 不要使用复杂的术语\n✅ 使用简单易懂的日常用语',
  },
  {
    title: '采用少样本学习',
    description: '提供1-3个输入输出示例，展示期望的格式',
    example: '示例输入：今天天气真好\n示例输出：积极\n\n现在请分析：这个产品质量太差了',
  },
  {
    title: '使用思维链提示',
    description: '对于复杂任务，引导模型逐步思考',
    example: '在提示词末尾添加："让我们一步一步地思考"',
  },
]

function PromptEditor() {
  const [selectedFramework, setSelectedFramework] = useState('COSTAR')
  const [promptContent, setPromptContent] = useState(promptFrameworks.COSTAR.template)
  const [customPrompt, setCustomPrompt] = useState('')

  const handleFrameworkChange = (framework: string) => {
    setSelectedFramework(framework)
    setPromptContent(promptFrameworks[framework as keyof typeof promptFrameworks].template)
  }

  const handleTestPrompt = () => {
    // 这里可以添加测试提示词的逻辑
    alert('提示词测试功能即将推出！')
  }

  return (
    <Box>
      <VStack spacing={6} align="stretch">
        <Card>
          <CardHeader>
            <Heading size="md">提示词工程最佳实践</Heading>
          </CardHeader>
          <CardBody>
            <Alert status="info" mb={4}>
              <AlertIcon />
              <Box>
                <AlertTitle>什么是提示词工程？</AlertTitle>
                <AlertDescription>
                  提示词工程是设计、构建和优化指令的系统性学科，旨在引导AI模型产生最精确、最相关、最高质量的输出。
                </AlertDescription>
              </Box>
            </Alert>

            <Tabs variant="enclosed" colorScheme="blue">
              <TabList>
                <Tab>结构化框架</Tab>
                <Tab>优化技巧</Tab>
                <Tab>自定义编辑</Tab>
              </TabList>

              <TabPanels>
                {/* 结构化框架标签页 */}
                <TabPanel>
                  <VStack spacing={4} align="stretch">
                    <FormControl>
                      <FormLabel>选择提示词框架</FormLabel>
                      <Select value={selectedFramework} onChange={(e) => handleFrameworkChange(e.target.value)}>
                        {Object.entries(promptFrameworks).map(([key, framework]) => (
                          <option key={key} value={key}>
                            {framework.name} - {framework.description}
                          </option>
                        ))}
                      </Select>
                    </FormControl>

                    <Box>
                      <Text fontWeight="bold" mb={2}>框架模板：</Text>
                      <Textarea
                        value={promptContent}
                        onChange={(e) => setPromptContent(e.target.value)}
                        height="400px"
                        fontFamily="monospace"
                        fontSize="sm"
                      />
                    </Box>

                    <HStack justify="flex-end">
                      <Button colorScheme="blue" onClick={handleTestPrompt}>
                        测试提示词
                      </Button>
                    </HStack>
                  </VStack>
                </TabPanel>

                {/* 优化技巧标签页 */}
                <TabPanel>
                  <VStack spacing={4} align="stretch">
                    {optimizationTips.map((tip, index) => (
                      <Card key={index} variant="outline">
                        <CardBody>
                          <HStack justify="space-between" mb={2}>
                            <Heading size="sm">{tip.title}</Heading>
                            <Badge colorScheme="green">技巧 {index + 1}</Badge>
                          </HStack>
                          <Text fontSize="sm" color="gray.600" mb={3}>
                            {tip.description}
                          </Text>
                          <Box bg="gray.50" p={3} borderRadius="md">
                            <Code whiteSpace="pre-wrap" fontSize="xs">
                              {tip.example}
                            </Code>
                          </Box>
                        </CardBody>
                      </Card>
                    ))}
                  </VStack>
                </TabPanel>

                {/* 自定义编辑标签页 */}
                <TabPanel>
                  <VStack spacing={4} align="stretch">
                    <Alert status="warning">
                      <AlertIcon />
                      <AlertDescription>
                        基于您的需求自由编写提示词，充分利用您学到的技巧和框架。
                      </AlertDescription>
                    </Alert>

                    <Textarea
                      value={customPrompt}
                      onChange={(e) => setCustomPrompt(e.target.value)}
                      placeholder="在这里编写您的提示词..."
                      height="400px"
                      fontSize="sm"
                    />

                    <HStack justify="space-between">
                      <Text fontSize="sm" color="gray.500">
                        字符数：{customPrompt.length}
                      </Text>
                      <Button colorScheme="blue" onClick={handleTestPrompt}>
                        测试提示词
                      </Button>
                    </HStack>
                  </VStack>
                </TabPanel>
              </TabPanels>
            </Tabs>
          </CardBody>
        </Card>
      </VStack>
    </Box>
  )
}

export default PromptEditor 