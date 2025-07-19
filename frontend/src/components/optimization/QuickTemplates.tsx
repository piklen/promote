import { useState } from 'react'
import {
  Box,
  VStack,
  HStack,
  Button,
  Badge,
  Text,
  Card,
  CardBody,
  CardHeader,
  Heading,
  SimpleGrid,
  Modal,
  ModalOverlay,
  ModalContent,
  ModalHeader,
  ModalFooter,
  ModalBody,
  ModalCloseButton,
  useDisclosure,
  Textarea,
  IconButton,
  Tooltip,
} from '@chakra-ui/react'
import { CopyIcon, ViewIcon } from '@chakra-ui/icons'

interface QuickTemplate {
  id: string
  name: string
  description: string
  category: string
  complexity: 'simple' | 'medium' | 'complex'
  template: string
  useCase: string
  example: string
}

const quickTemplates: QuickTemplate[] = [
  {
    id: 'zero_shot_cot',
    name: '零样本思维链',
    description: '让AI一步步思考问题，提高推理准确性',
    category: 'reasoning',
    complexity: 'simple',
    useCase: '数学题、逻辑推理、决策分析',
    example: '计算复合利息问题',
    template: `你是一位擅长逻辑推理的分析师。

问题：[在这里描述你的问题]

让我们一步一步地思考这个问题：

1. 首先，理解问题的核心要求
2. 然后，识别关键信息和约束条件  
3. 接下来，制定解决方案
4. 最后，验证答案的合理性

请详细展示你的思考过程。`
  },
  {
    id: 'few_shot_learning',
    name: '少样本学习',
    description: '通过示例指导AI输出格式和风格',
    category: 'learning',
    complexity: 'simple', 
    useCase: '格式规范、风格模仿、数据转换',
    example: '结构化数据提取',
    template: `请根据以下示例的格式处理新的输入：

示例1：
输入：[示例输入1]
输出：[标准化输出1]

示例2：
输入：[示例输入2] 
输出：[标准化输出2]

示例3：
输入：[示例输入3]
输出：[标准化输出3]

现在请处理：
输入：[你的实际输入]
输出：`
  },
  {
    id: 'self_consistency',
    name: '自洽性检验',
    description: '用多种方法解决问题，选择最一致的答案',
    category: 'reasoning',
    complexity: 'complex',
    useCase: '关键决策、复杂推理、提高准确性',
    example: '投资策略分析',
    template: `你是一位资深专家，请用3种不同的方法分析这个问题：

问题：[详细描述你的问题]

方法1 - [第一种分析角度]：
[详细分析过程]
结论：[方法1的结论]

方法2 - [第二种分析角度]：
[详细分析过程]
结论：[方法2的结论]

方法3 - [第三种分析角度]：
[详细分析过程]
结论：[方法3的结论]

综合分析：
对比三种方法的结论，选择最合理和一致的答案，并说明理由。`
  },
  {
    id: 'generated_knowledge',
    name: '生成知识提示',
    description: '先生成相关知识，再基于知识回答问题',
    category: 'reasoning',
    complexity: 'medium',
    useCase: '知识密集型任务、教育场景、专业咨询',
    example: '技术方案分析',
    template: `关于[主题领域]，请先生成一些重要的背景知识：

知识生成任务：
1. 核心概念和定义
2. 重要原理和规律
3. 常见应用场景
4. 最佳实践经验
5. 潜在风险和注意事项

[生成知识内容]

现在，基于上述知识回答以下问题：
[你的具体问题]

请确保答案建立在前面生成的知识基础上。`
  },
  {
    id: 'role_persona',
    name: '专家角色扮演',
    description: '赋予AI专业角色身份，获得专业水准回答',
    category: 'structured',
    complexity: 'medium',
    useCase: '专业咨询、技术指导、创意写作',
    example: '产品设计咨询',
    template: `# 角色设定
你是一位拥有[X年]经验的[专业领域]专家，曾在[知名公司/项目]工作，专精于[具体专业方向]。

# 专业背景
- 教育背景：[相关教育经历]
- 工作经验：[具体工作经验]
- 专业技能：[核心技能列表]
- 成功案例：[典型项目经验]

# 任务要求
以你的专业身份，请针对以下问题提供专业建议：

[具体问题描述]

# 回答要求
1. 运用你的专业知识和经验
2. 提供具体可行的建议
3. 考虑实际应用中的约束条件
4. 给出专业的判断和推荐`
  },
  {
    id: 'prompt_chaining',
    name: '任务链分解',
    description: '将复杂任务分解为简单步骤，逐步完成',
    category: 'workflow',
    complexity: 'medium',
    useCase: '复杂项目、数据分析、内容创作',
    example: '市场研究报告',
    template: `这是一个多步骤的复杂任务，我们将分阶段完成：

# 总体目标
[描述最终要达成的目标]

# 任务分解

## 第一阶段：[阶段名称]
**目标**：[具体目标]
**输入**：[所需输入]
**输出**：[期望输出]
**要求**：[具体要求]

## 第二阶段：[阶段名称]
**目标**：[具体目标]
**输入**：第一阶段的输出结果
**输出**：[期望输出]
**要求**：[具体要求]

## 第三阶段：[阶段名称]
**目标**：[具体目标]
**输入**：第二阶段的输出结果
**输出**：[最终输出]
**要求**：[具体要求]

请先完成第一阶段的任务，我会根据结果继续后续阶段。`
  },
  {
    id: 'self_correction',
    name: '自我纠正优化',
    description: '让AI自我检查和改进答案质量',
    category: 'quality',
    complexity: 'medium',
    useCase: '内容优化、错误检查、质量提升',
    example: '文档审查优化',
    template: `请完成以下任务：

# 初始任务
[详细描述你的任务要求]

---

# 自我检查清单
完成初始回答后，请按以下标准检查你的答案：

## 内容质量检查
1. ✓ 是否完全回答了所有问题？
2. ✓ 信息是否准确可靠？
3. ✓ 逻辑是否清晰连贯？
4. ✓ 是否有遗漏的重要信息？

## 格式规范检查
1. ✓ 是否符合要求的格式？
2. ✓ 结构是否清晰易读？
3. ✓ 表达是否简洁明了？

## 实用性检查
1. ✓ 建议是否具体可行？
2. ✓ 是否考虑了实际约束？
3. ✓ 是否提供了足够的细节？

# 改进版本
如果发现任何问题，请提供改进后的版本。`
  },
  {
    id: 'costar_framework',
    name: 'CO-STAR结构化',
    description: '全面定义情境、目标、风格等要素',
    category: 'structured',
    complexity: 'medium',
    useCase: '内容创作、营销文案、沟通写作',
    example: '产品宣传文案',
    template: `# CO-STAR框架提示词

## Context (情境)
**背景信息**：[详细描述任务背景和相关环境]
**当前状况**：[说明现状和起始条件]

## Objective (目标)  
**主要目标**：[明确的、可衡量的目标]
**成功标准**：[如何判断任务完成得好]

## Style (风格)
**写作风格**：[正式/非正式/技术性/通俗化等]
**语言特点**：[简洁/详细/幽默/严肃等]

## Tone (语气)
**整体语气**：[友好/专业/权威/鼓励性等]
**情感倾向**：[积极/中性/批判等]

## Audience (受众)
**目标受众**：[具体描述受众特征]
**知识水平**：[专业程度、背景知识]
**关注重点**：[受众最关心的问题]

## Response (响应格式)
**输出格式**：[段落/列表/表格/JSON等]
**长度要求**：[字数或篇幅限制]
**结构要求**：[具体的组织结构]`
  }
]

interface QuickTemplatesProps {
  onSelectTemplate: (template: string) => void
}

function QuickTemplates({ onSelectTemplate }: QuickTemplatesProps) {
  const { isOpen, onOpen, onClose } = useDisclosure()
  const [selectedTemplate, setSelectedTemplate] = useState<QuickTemplate | null>(null)

  const handleViewTemplate = (template: QuickTemplate) => {
    setSelectedTemplate(template)
    onOpen()
  }

  const handleUseTemplate = (template: string) => {
    onSelectTemplate(template)
    onClose()
  }

  const copyToClipboard = (text: string) => {
    navigator.clipboard.writeText(text)
  }

  const getComplexityColor = (complexity: string) => {
    switch (complexity) {
      case 'simple': return 'green'
      case 'medium': return 'yellow'
      case 'complex': return 'red'
      default: return 'gray'
    }
  }

  const getCategoryColor = (category: string) => {
    switch (category) {
      case 'reasoning': return 'purple'
      case 'learning': return 'blue'
      case 'structured': return 'teal'
      case 'workflow': return 'orange'
      case 'quality': return 'pink'
      default: return 'gray'
    }
  }

  return (
    <Box>
      <VStack spacing={4} align="stretch">
        <Box>
          <Heading size="md" mb={2} color="purple.600">
            🚀 快速模板
          </Heading>
          <Text fontSize="sm" color="gray.600">
            基于提示词工程最佳实践的预制模板，快速构建高质量提示词
          </Text>
        </Box>

        <SimpleGrid columns={{ base: 1, md: 2, lg: 3 }} spacing={4}>
          {quickTemplates.map((template) => (
            <Card key={template.id} variant="outline" size="sm">
              <CardHeader pb={2}>
                <VStack align="start" spacing={2}>
                  <HStack justify="space-between" width="100%">
                    <Heading size="sm">{template.name}</Heading>
                    <HStack spacing={1}>
                      <Badge colorScheme={getComplexityColor(template.complexity)} size="sm">
                        {template.complexity}
                      </Badge>
                      <Badge colorScheme={getCategoryColor(template.category)} variant="outline" size="sm">
                        {template.category}
                      </Badge>
                    </HStack>
                  </HStack>
                  <Text fontSize="xs" color="gray.600" noOfLines={2}>
                    {template.description}
                  </Text>
                </VStack>
              </CardHeader>
              <CardBody pt={0}>
                <VStack align="stretch" spacing={3}>
                  <Box>
                    <Text fontSize="xs" fontWeight="medium" color="gray.700" mb={1}>
                      适用场景：
                    </Text>
                    <Text fontSize="xs" color="gray.600">
                      {template.useCase}
                    </Text>
                  </Box>
                  
                  <HStack spacing={2}>
                    <Button
                      size="xs"
                      colorScheme="purple"
                      onClick={() => handleUseTemplate(template.template)}
                      flex={1}
                    >
                      使用模板
                    </Button>
                    <Tooltip label="预览模板">
                      <IconButton
                        aria-label="预览"
                        icon={<ViewIcon />}
                        size="xs"
                        variant="outline"
                        onClick={() => handleViewTemplate(template)}
                      />
                    </Tooltip>
                    <Tooltip label="复制模板">
                      <IconButton
                        aria-label="复制"
                        icon={<CopyIcon />}
                        size="xs"
                        variant="outline"
                        onClick={() => copyToClipboard(template.template)}
                      />
                    </Tooltip>
                  </HStack>
                </VStack>
              </CardBody>
            </Card>
          ))}
        </SimpleGrid>
      </VStack>

      {/* 模板预览模态框 */}
      <Modal isOpen={isOpen} onClose={onClose} size="xl">
        <ModalOverlay />
        <ModalContent>
          <ModalHeader>
            <VStack align="start" spacing={2}>
              <HStack>
                <Text>{selectedTemplate?.name}</Text>
                <Badge colorScheme={selectedTemplate ? getComplexityColor(selectedTemplate.complexity) : 'gray'}>
                  {selectedTemplate?.complexity}
                </Badge>
                <Badge colorScheme={selectedTemplate ? getCategoryColor(selectedTemplate.category) : 'gray'} variant="outline">
                  {selectedTemplate?.category}
                </Badge>
              </HStack>
              <Text fontSize="sm" color="gray.600">
                {selectedTemplate?.description}
              </Text>
            </VStack>
          </ModalHeader>
          <ModalCloseButton />
          <ModalBody>
            <VStack spacing={4} align="stretch">
              <Box>
                <Text fontWeight="medium" mb={2}>使用示例：</Text>
                <Text fontSize="sm" color="gray.600" fontStyle="italic">
                  {selectedTemplate?.example}
                </Text>
              </Box>
              
              <Box>
                <Text fontWeight="medium" mb={2}>模板内容：</Text>
                <Textarea
                  value={selectedTemplate?.template || ''}
                  readOnly
                  height="300px"
                  fontSize="sm"
                  fontFamily="mono"
                />
              </Box>
            </VStack>
          </ModalBody>
          <ModalFooter>
            <HStack spacing={2}>
              <Button
                variant="outline"
                onClick={() => selectedTemplate && copyToClipboard(selectedTemplate.template)}
                leftIcon={<CopyIcon />}
              >
                复制模板
              </Button>
              <Button
                colorScheme="purple"
                onClick={() => selectedTemplate && handleUseTemplate(selectedTemplate.template)}
              >
                使用此模板
              </Button>
            </HStack>
          </ModalFooter>
        </ModalContent>
      </Modal>
    </Box>
  )
}

export default QuickTemplates 