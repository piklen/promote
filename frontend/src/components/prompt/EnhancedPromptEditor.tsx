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
  SimpleGrid,
  Accordion,
  AccordionItem,
  AccordionButton,
  AccordionPanel,
  AccordionIcon,
  List,
  ListItem,
  ListIcon,
  Tooltip,
  Switch,
  IconButton,
} from '@chakra-ui/react'
import { CheckIcon, CopyIcon, InfoIcon } from '@chakra-ui/icons'

// 提示词框架模板
const promptFrameworks = {
  COSTAR: {
    name: 'CO-STAR框架',
    description: '全面定义修辞和风格要素，适合内容创作、营销文案',
    category: 'structured',
    complexity: '中等',
    bestFor: ['内容创作', '市场营销', '沟通文案'],
    example: '为新产品写宣传文案',
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
明确期望的输出格式和结构（列表、段落、JSON、代码等）`
  },
  RTF: {
    name: 'RTF框架',
    description: '简洁高效，适合执行明确指令、生成列表摘要',
    category: 'structured',
    complexity: '简单',
    bestFor: ['生成列表', '摘要', '执行简单指令'],
    example: '生成产品功能列表',
    template: `[Role - 角色]
你是一位具有丰富经验的[专业领域]专家

[Task - 任务]
请完成以下任务：[具体任务描述]

[Format - 格式]
输出格式要求：[明确的格式规范，如列表、表格、JSON等]`
  },
  TAG: {
    name: 'TAG框架',
    description: '目标导向，强调最终目的，确保输出与战略目标对齐',
    category: 'structured',
    complexity: '简单',
    bestFor: ['目标驱动型任务', '内容迭代优化'],
    example: '制定学习计划',
    template: `[Task - 任务]
具体需要完成的任务是：[详细任务描述]

[Action - 行动]
执行任务的具体步骤：[明确的行动方案]

[Goal - 目标]
最终要达到的目标是：[具体的成功标准]`
  },
  CRISPE: {
    name: 'CRISPE框架',
    description: '全方位、多维度地定义复杂任务，适合战略规划',
    category: 'structured',
    complexity: '复杂',
    bestFor: ['战略规划', 'UX设计', '复杂问题分析'],
    example: '设计用户体验流程',
    template: `[Capacity - 能力]
作为[专业角色]，你具备[具体能力和专业知识]

[Role - 角色]
你扮演[具体角色]的身份

[Insight - 洞察]
基于你的专业经验，重要的洞察是：[关键洞察]

[Statement - 声明]
问题声明：[明确的问题定义]

[Personality - 个性]
以[特定个性特征]的方式回应

[Experiment - 实验]
采用[具体方法论]来解决问题`
  },
  RACE: {
    name: 'RACE框架',
    description: '结合角色扮演和明确期望，适合专业内容生成',
    category: 'structured',
    complexity: '中等',
    bestFor: ['战略咨询', '复杂分析', '专业内容生成'],
    example: '市场分析报告',
    template: `[Role - 角色]
你是[具体专业角色]，拥有[相关经验和资质]

[Action - 行动]
需要执行的具体行动：[详细行动计划]

[Context - 情境]
背景信息：[相关上下文和约束条件]

[Expectation - 期望]
期望的结果：[具体的输出要求和成功标准]`
  }
}

// 高级提示词技术
const advancedTechniques = {
  COT: {
    name: '思维链 (Chain of Thought)',
    description: '引导模型生成逐步推理过程，适合复杂推理任务',
    category: 'reasoning',
    complexity: '中等',
    bestFor: ['数学问题', '逻辑推理', '问题分析'],
    template: `请一步一步地思考这个问题：

[问题描述]

让我们分步骤解决：
1. 首先，[第一步分析]
2. 然后，[第二步分析]
3. 接下来，[第三步分析]
4. 最后，[总结结论]

请详细展示你的思考过程。`
  },
  ZEROSHOT_COT: {
    name: '零样本思维链',
    description: '简单有效的推理提示，无需提供示例',
    category: 'reasoning', 
    complexity: '简单',
    bestFor: ['快速推理', '问题分析', '决策制定'],
    template: `[问题或任务描述]

让我们一步一步地思考这个问题。`
  },
  SELF_CONSISTENCY: {
    name: '自洽性检验',
    description: '生成多个推理路径并选择最一致的答案',
    category: 'reasoning',
    complexity: '高',
    bestFor: ['提高准确性', '复杂推理', '关键决策'],
    template: `请用3种不同的方法来解决这个问题：

[问题描述]

方法1：[第一种解决思路]
方法2：[第二种解决思路] 
方法3：[第三种解决思路]

比较这些方法的结果，选择最合理的答案并说明理由。`
  },
  GENERATED_KNOWLEDGE: {
    name: '生成知识提示',
    description: '先生成相关知识，再基于知识回答问题',
    category: 'reasoning',
    complexity: '中等',
    bestFor: ['常识推理', '知识密集型任务', '教育场景'],
    template: `关于[主题]，请先生成一些相关的背景知识和事实：

[生成相关知识的指令]

现在，基于上述知识回答以下问题：
[具体问题]`
  },
  TREE_OF_THOUGHTS: {
    name: '思维树 (Tree of Thoughts)',
    description: '探索多个思维分支，支持回溯和深度搜索',
    category: 'reasoning',
    complexity: '非常高',
    bestFor: ['复杂规划', '创意生成', '策略制定'],
    template: `让我们用思维树的方法来解决这个问题：

[问题描述]

第一层思考：
选项A：[思路A]
选项B：[思路B]
选项C：[思路C]

对每个选项进行评估：
- 选项A的优缺点：
- 选项B的优缺点：
- 选项C的优缺点：

选择最佳选项并继续深入思考...`
  },
  PROMPT_CHAINING: {
    name: '提示链 (Prompt Chaining)',
    description: '将复杂任务分解为多个简单步骤',
    category: 'workflow',
    complexity: '中等',
    bestFor: ['复杂工作流', '数据处理', '多步分析'],
    template: `这是一个多步骤任务，我们将分步完成：

步骤1：[第一个子任务]
输入：[步骤1的输入]
期望输出：[步骤1的输出格式]

[继续添加后续步骤...]

请先完成步骤1，我会根据结果继续后续步骤。`
  },
  FEW_SHOT: {
    name: '少样本学习 (Few-Shot)',
    description: '提供2-5个示例来指导模型行为',
    category: 'learning',
    complexity: '简单',
    bestFor: ['格式指定', '风格模仿', '模式识别'],
    template: `以下是一些示例：

示例1：
输入：[示例输入1]
输出：[示例输出1]

示例2：
输入：[示例输入2]
输出：[示例输出2]

示例3：
输入：[示例输入3]
输出：[示例输出3]

现在请处理：
输入：[实际输入]
输出：`
  },
  SELF_CORRECTION: {
    name: '自我纠正 (Self-Correction)',
    description: '模型生成答案后进行自我评估和改进',
    category: 'quality',
    complexity: '中等',
    bestFor: ['提高质量', '错误检查', '内容优化'],
    template: `请完成以下任务：
[任务描述]

完成后，请检查你的答案：
1. 是否回答了所有问题？
2. 是否有逻辑错误？
3. 是否符合要求的格式？
4. 是否可以改进表达？

如发现问题，请提供改进版本。`
  }
}

// 提示词质量检查原则
const qualityPrinciples = [
  {
    name: '清晰性 (Clarity)',
    description: '提示词必须清晰、简洁、无歧义',
    tips: ['使用直接明了的语言', '避免复杂或含糊的表述', '一个句子表达一个观点']
  },
  {
    name: '具体性 (Specificity)', 
    description: '提供详细信息，不留解释空间',
    tips: ['明确定义期望结果', '指定格式、风格、长度', '提供具体的约束条件']
  },
  {
    name: '上下文 (Context)',
    description: '提供必要的背景信息',
    tips: ['包含相关背景知识', '说明任务的重要性', '提供必要的环境信息']
  },
  {
    name: '正面指令',
    description: '告诉模型应该做什么，而不是不应该做什么',
    tips: ['使用"请做X"而不是"不要做Y"', '提供明确的行动指导', '给出具体的期望行为']
  },
  {
    name: '结构化',
    description: '使用清晰的结构组织提示词',
    tips: ['使用标题和分隔符', '逻辑清晰的层次结构', '重要信息放在显眼位置']
  }
]

// 常见陷阱和解决方案
const commonPitfalls = [
  {
    problem: '模糊与歧义',
    impact: '产生不相关、泛泛或错误的输出',
    solution: '提供清晰、具体的参数和约束',
    example: {
      bad: '解释气候变化',
      good: '为高中生撰写一篇200字的文章，解释1950年以来气候变化的主要原因'
    }
  },
  {
    problem: '指令过载',
    impact: '模型困惑，只关注开头和结尾，忽略中间指令',
    solution: '分解为更小步骤，使用清晰的分隔符',
    example: {
      bad: '一个包含10个不同指令的长段落',
      good: '将10个指令分解为3-4个顺序执行的提示'
    }
  },
  {
    problem: '无效的角色扮演',
    impact: '仅改变语气，未调用相关领域知识',
    solution: '除了分配角色，还需提供利用专业知识的具体任务',
    example: {
      bad: '你是个世界级的文案。写个广告',
      good: '你是为苹果和耐克工作的世界级文案。为新健身App撰写广告，强调社区功能'
    }
  },
  {
    problem: '高估模型能力',
    impact: '导致"幻觉"，编造事实或无法完成任务',
    solution: '核查知识截止日期，引导生成代码而非直接计算',
    example: {
      bad: '计算12345 × 67890',
      good: '写一段Python代码来计算12345 × 67890'
    }
  }
]

function EnhancedPromptEditor() {
  const [selectedFramework, setSelectedFramework] = useState('')
  const [selectedTechnique, setSelectedTechnique] = useState('')
  const [promptContent, setPromptContent] = useState('')
  const [showAdvanced, setShowAdvanced] = useState(false)

  const handleFrameworkSelect = (framework: string) => {
    setSelectedFramework(framework)
    if (framework && promptFrameworks[framework as keyof typeof promptFrameworks]) {
      setPromptContent(promptFrameworks[framework as keyof typeof promptFrameworks].template)
    }
  }

  const handleTechniqueSelect = (technique: string) => {
    setSelectedTechnique(technique)
    if (technique && advancedTechniques[technique as keyof typeof advancedTechniques]) {
      setPromptContent(advancedTechniques[technique as keyof typeof advancedTechniques].template)
    }
  }

  const copyToClipboard = (text: string) => {
    navigator.clipboard.writeText(text)
  }

  return (
    <Box p={6}>
      <VStack spacing={6} align="stretch">
        {/* 标题区域 */}
        <Box>
          <Heading size="lg" mb={2} color="blue.600">
            🎯 提示词工程实验室
          </Heading>
          <Text color="gray.600">
            基于最新提示词工程理论，构建高效、可靠的AI交互提示词
          </Text>
        </Box>

        {/* 质量原则提醒 */}
        <Alert status="info" borderRadius="md">
          <AlertIcon />
          <Box>
            <AlertTitle>提示词质量三大黄金法则</AlertTitle>
            <AlertDescription>
              <Text><strong>清晰性</strong>：指令明确无歧义 | <strong>具体性</strong>：详细定义期望结果 | <strong>上下文</strong>：提供必要背景信息</Text>
            </AlertDescription>
          </Box>
        </Alert>

        <HStack spacing={4} align="flex-start">
          <Switch
            isChecked={showAdvanced}
            onChange={(e) => setShowAdvanced(e.target.checked)}
            colorScheme="purple"
          />
          <Text fontWeight="medium">高级技术模式</Text>
          <Tooltip label="启用高级提示词工程技术，如思维链、自洽性等">
            <InfoIcon color="gray.500" />
          </Tooltip>
        </HStack>

        <Tabs colorScheme="blue" variant="enclosed">
          <TabList>
            <Tab>结构化框架</Tab>
            {showAdvanced && <Tab>高级技术</Tab>}
            <Tab>质量指南</Tab>
            <Tab>常见陷阱</Tab>
            <Tab>自定义编辑</Tab>
          </TabList>

          <TabPanels>
            {/* 结构化框架 */}
            <TabPanel>
              <VStack spacing={4} align="stretch">
                <FormControl>
                  <FormLabel>选择提示词框架</FormLabel>
                  <Select 
                    placeholder="选择一个框架模板"
                    value={selectedFramework}
                    onChange={(e) => handleFrameworkSelect(e.target.value)}
                  >
                    {Object.entries(promptFrameworks).map(([key, framework]) => (
                      <option key={key} value={key}>
                        {framework.name} - {framework.description}
                      </option>
                    ))}
                  </Select>
                </FormControl>

                {selectedFramework && (
                  <Card variant="outline" borderColor="blue.200">
                    <CardHeader>
                      <HStack justify="space-between">
                        <VStack align="start" spacing={1}>
                          <Heading size="md">
                            {promptFrameworks[selectedFramework as keyof typeof promptFrameworks].name}
                          </Heading>
                          <HStack spacing={2}>
                            <Badge colorScheme="blue">
                              {promptFrameworks[selectedFramework as keyof typeof promptFrameworks].complexity}
                            </Badge>
                            <Badge colorScheme="green" variant="outline">
                              {promptFrameworks[selectedFramework as keyof typeof promptFrameworks].category}
                            </Badge>
                          </HStack>
                        </VStack>
                        <IconButton
                          aria-label="复制模板"
                          icon={<CopyIcon />}
                          size="sm"
                          variant="ghost"
                          onClick={() => copyToClipboard(promptFrameworks[selectedFramework as keyof typeof promptFrameworks].template)}
                        />
                      </HStack>
                    </CardHeader>
                    <CardBody>
                      <VStack spacing={3} align="stretch">
                        <Text color="gray.600">
                          {promptFrameworks[selectedFramework as keyof typeof promptFrameworks].description}
                        </Text>
                        
                        <Box>
                          <Text fontWeight="medium" mb={2}>适用场景：</Text>
                          <HStack spacing={2} wrap="wrap">
                            {promptFrameworks[selectedFramework as keyof typeof promptFrameworks].bestFor.map((scenario, index) => (
                              <Badge key={index} colorScheme="purple" variant="subtle">
                                {scenario}
                              </Badge>
                            ))}
                          </HStack>
                        </Box>

                        <Box>
                          <Text fontWeight="medium" mb={2}>使用示例：</Text>
                          <Text fontSize="sm" color="gray.600" fontStyle="italic">
                            {promptFrameworks[selectedFramework as keyof typeof promptFrameworks].example}
                          </Text>
                        </Box>
                      </VStack>
                    </CardBody>
                  </Card>
                )}
              </VStack>
            </TabPanel>

            {/* 高级技术 */}
            {showAdvanced && (
              <TabPanel>
                <VStack spacing={4} align="stretch">
                  <Alert status="warning" borderRadius="md">
                    <AlertIcon />
                    <AlertDescription>
                      高级技术适合复杂任务。对于简单任务，建议使用结构化框架。
                    </AlertDescription>
                  </Alert>

                  <FormControl>
                    <FormLabel>选择高级提示词技术</FormLabel>
                    <Select
                      placeholder="选择一个高级技术"
                      value={selectedTechnique}
                      onChange={(e) => handleTechniqueSelect(e.target.value)}
                    >
                      {Object.entries(advancedTechniques).map(([key, technique]) => (
                        <option key={key} value={key}>
                          {technique.name} - {technique.description}
                        </option>
                      ))}
                    </Select>
                  </FormControl>

                  {selectedTechnique && (
                    <Card variant="outline" borderColor="purple.200">
                      <CardHeader>
                        <HStack justify="space-between">
                          <VStack align="start" spacing={1}>
                            <Heading size="md">
                              {advancedTechniques[selectedTechnique as keyof typeof advancedTechniques].name}
                            </Heading>
                            <HStack spacing={2}>
                              <Badge colorScheme="purple">
                                {advancedTechniques[selectedTechnique as keyof typeof advancedTechniques].complexity}
                              </Badge>
                              <Badge colorScheme="orange" variant="outline">
                                {advancedTechniques[selectedTechnique as keyof typeof advancedTechniques].category}
                              </Badge>
                            </HStack>
                          </VStack>
                          <IconButton
                            aria-label="复制模板"
                            icon={<CopyIcon />}
                            size="sm"
                            variant="ghost"
                            onClick={() => copyToClipboard(advancedTechniques[selectedTechnique as keyof typeof advancedTechniques].template)}
                          />
                        </HStack>
                      </CardHeader>
                      <CardBody>
                        <VStack spacing={3} align="stretch">
                          <Text color="gray.600">
                            {advancedTechniques[selectedTechnique as keyof typeof advancedTechniques].description}
                          </Text>
                          
                          <Box>
                            <Text fontWeight="medium" mb={2}>最佳应用：</Text>
                            <HStack spacing={2} wrap="wrap">
                              {advancedTechniques[selectedTechnique as keyof typeof advancedTechniques].bestFor.map((scenario, index) => (
                                <Badge key={index} colorScheme="purple" variant="subtle">
                                  {scenario}
                                </Badge>
                              ))}
                            </HStack>
                          </Box>
                        </VStack>
                      </CardBody>
                    </Card>
                  )}
                </VStack>
              </TabPanel>
            )}

            {/* 质量指南 */}
            <TabPanel>
              <VStack spacing={4} align="stretch">
                <Heading size="md" color="green.600">
                  ✅ 高质量提示词指南
                </Heading>

                <Accordion allowMultiple>
                  {qualityPrinciples.map((principle, index) => (
                    <AccordionItem key={index}>
                      <AccordionButton>
                        <Box flex="1" textAlign="left">
                          <HStack>
                            <Text fontWeight="bold">{principle.name}</Text>
                            <Text color="gray.600" fontSize="sm">- {principle.description}</Text>
                          </HStack>
                        </Box>
                        <AccordionIcon />
                      </AccordionButton>
                      <AccordionPanel pb={4}>
                        <List spacing={2}>
                          {principle.tips.map((tip, tipIndex) => (
                            <ListItem key={tipIndex}>
                              <ListIcon as={CheckIcon} color="green.500" />
                              {tip}
                            </ListItem>
                          ))}
                        </List>
                      </AccordionPanel>
                    </AccordionItem>
                  ))}
                </Accordion>
              </VStack>
            </TabPanel>

            {/* 常见陷阱 */}
            <TabPanel>
              <VStack spacing={4} align="stretch">
                <Heading size="md" color="red.600">
                  ⚠️ 常见陷阱与解决方案
                </Heading>

                <SimpleGrid columns={{base: 1, lg: 2}} spacing={4}>
                  {commonPitfalls.map((pitfall, index) => (
                    <Card key={index} variant="outline" borderColor="red.200">
                      <CardBody>
                        <VStack align="stretch" spacing={3}>
                          <Badge colorScheme="red" alignSelf="flex-start">
                            问题：{pitfall.problem}
                          </Badge>
                          
                          <Text fontSize="sm" color="gray.600">
                            <strong>影响：</strong>{pitfall.impact}
                          </Text>
                          
                          <Text fontSize="sm" color="green.700">
                            <strong>解决方案：</strong>{pitfall.solution}
                          </Text>
                          
                          <Box bg="gray.50" p={3} borderRadius="md">
                            <Text fontSize="xs" fontWeight="bold" color="red.600" mb={1}>
                              ❌ 错误示例：
                            </Text>
                            <Code fontSize="xs" colorScheme="red">{pitfall.example.bad}</Code>
                            
                            <Text fontSize="xs" fontWeight="bold" color="green.600" mt={2} mb={1}>
                              ✅ 正确示例：
                            </Text>
                            <Code fontSize="xs" colorScheme="green">{pitfall.example.good}</Code>
                          </Box>
                        </VStack>
                      </CardBody>
                    </Card>
                  ))}
                </SimpleGrid>
              </VStack>
            </TabPanel>

            {/* 自定义编辑 */}
            <TabPanel>
              <VStack spacing={4} align="stretch">
                <FormControl>
                  <FormLabel>提示词内容</FormLabel>
                  <Textarea
                    value={promptContent}
                    onChange={(e) => setPromptContent(e.target.value)}
                    placeholder="在这里编写您的提示词..."
                    height="400px"
                    fontSize="sm"
                    fontFamily="mono"
                  />
                </FormControl>

                <HStack spacing={2}>
                  <Button
                    size="sm"
                    variant="outline"
                    onClick={() => copyToClipboard(promptContent)}
                    leftIcon={<CopyIcon />}
                  >
                    复制提示词
                  </Button>
                  <Button
                    size="sm"
                    variant="outline"
                    onClick={() => setPromptContent('')}
                  >
                    清空内容
                  </Button>
                </HStack>

                <Alert status="success" borderRadius="md">
                  <AlertIcon />
                  <AlertDescription>
                    💡 提示：编写完成后，可以在"提示词优化"页面使用真实的LLM API进行测试
                  </AlertDescription>
                </Alert>
              </VStack>
            </TabPanel>
          </TabPanels>
        </Tabs>
      </VStack>
    </Box>
  )
}

export default EnhancedPromptEditor 