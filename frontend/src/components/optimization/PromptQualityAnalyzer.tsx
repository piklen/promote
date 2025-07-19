import { useState } from 'react'
import {
  Box,
  VStack,
  HStack,
  Text,
  Button,
  Progress,
  Badge,
  Card,
  CardBody,
  CardHeader,
  Heading,
  List,
  ListItem,
  ListIcon,
  Alert,
  AlertIcon,
  AlertDescription,
  Accordion,
  AccordionItem,
  AccordionButton,
  AccordionPanel,
  AccordionIcon,
  SimpleGrid,
  Stat,
  StatLabel,
  StatNumber,
  StatHelpText,
  Icon,
} from '@chakra-ui/react'
import { CheckIcon, WarningIcon, InfoIcon, CloseIcon } from '@chakra-ui/icons'

interface QualityCheck {
  id: string
  name: string
  description: string
  category: 'clarity' | 'specificity' | 'context' | 'structure' | 'completeness'
  weight: number
  check: (prompt: string) => { passed: boolean; score: number; issues: string[]; suggestions: string[] }
}

interface AnalysisResult {
  totalScore: number
  categoryScores: Record<string, number>
  issues: Array<{ category: string; issue: string; suggestion: string }>
  strengths: string[]
  recommendations: string[]
}

// 提示词质量检查规则
const qualityChecks: QualityCheck[] = [
  {
    id: 'length_check',
    name: '长度合理性',
    description: '提示词长度适中，不过短也不过长',
    category: 'completeness',
    weight: 10,
    check: (prompt: string) => {
      const length = prompt.trim().length
      const issues: string[] = []
      const suggestions: string[] = []
      let score = 100
      
      if (length < 50) {
        issues.push('提示词过短，可能缺乏必要信息')
        suggestions.push('增加背景信息、具体要求或示例')
        score = 30
      } else if (length > 2000) {
        issues.push('提示词过长，可能导致模型混淆')
        suggestions.push('考虑分解为多个步骤或使用提示链')
        score = 60
      }
      
      return { passed: score > 70, score, issues, suggestions }
    }
  },
  {
    id: 'clear_instruction',
    name: '指令清晰度',
    description: '包含明确的动作词和具体指令',
    category: 'clarity',
    weight: 20,
    check: (prompt: string) => {
      const actionWords = ['分析', '生成', '创建', '写', '总结', '解释', '比较', '评估', '设计', '计算', '翻译', '优化']
      const issues: string[] = []
      const suggestions: string[] = []
      
      const hasActionWord = actionWords.some(word => prompt.includes(word))
      const hasQuestionMark = prompt.includes('？') || prompt.includes('?')
      
      let score = 100
      
      if (!hasActionWord && !hasQuestionMark) {
        issues.push('缺乏明确的动作指令')
        suggestions.push('添加明确的动作词，如"请分析"、"请生成"等')
        score -= 40
      }
      
      if (prompt.includes('可能') || prompt.includes('也许') || prompt.includes('大概')) {
        issues.push('包含模糊表达')
        suggestions.push('使用确定性语言，避免"可能"、"也许"等模糊词汇')
        score -= 20
      }
      
      return { passed: score > 70, score, issues, suggestions }
    }
  },
  {
    id: 'specificity_check',
    name: '具体性要求',
    description: '包含具体的要求、格式或约束条件',
    category: 'specificity',
    weight: 20,
    check: (prompt: string) => {
      const issues: string[] = []
      const suggestions: string[] = []
      let score = 100
      
      const hasFormat = /格式|列表|表格|JSON|段落|字数|长度/.test(prompt)
      const hasConstraints = /要求|限制|条件|标准|规范/.test(prompt)
      const hasExamples = /例如|比如|示例|例子/.test(prompt)
      
      if (!hasFormat) {
        issues.push('未指定输出格式')
        suggestions.push('明确指定期望的输出格式（如列表、段落、JSON等）')
        score -= 25
      }
      
      if (!hasConstraints) {
        issues.push('缺乏具体约束条件')
        suggestions.push('添加具体要求，如字数限制、质量标准等')
        score -= 25
      }
      
      if (!hasExamples && prompt.length > 200) {
        issues.push('复杂任务缺乏示例')
        suggestions.push('为复杂任务提供具体示例')
        score -= 15
      }
      
      return { passed: score > 70, score, issues, suggestions }
    }
  },
  {
    id: 'context_check',
    name: '上下文信息',
    description: '提供充分的背景信息和上下文',
    category: 'context',
    weight: 15,
    check: (prompt: string) => {
      const issues: string[] = []
      const suggestions: string[] = []
      let score = 100
      
      const hasBackground = /背景|环境|情况|场景|目的|目标/.test(prompt)
      const hasRole = /你是|作为|角色|专家|助手/.test(prompt)
      const hasAudience = /受众|用户|读者|观众|目标人群/.test(prompt)
      
      if (!hasBackground) {
        issues.push('缺乏背景信息')
        suggestions.push('添加任务背景和相关环境信息')
        score -= 30
      }
      
      if (!hasRole && prompt.length > 100) {
        issues.push('未定义AI角色')
        suggestions.push('为AI指定明确的角色身份')
        score -= 20
      }
      
      if (!hasAudience && /写|创建|生成.*文/.test(prompt)) {
        issues.push('内容创作任务未指定目标受众')
        suggestions.push('明确指定目标受众特征')
        score -= 15
      }
      
      return { passed: score > 70, score, issues, suggestions }
    }
  },
  {
    id: 'structure_check',
    name: '结构清晰性',
    description: '使用清晰的结构和分隔符组织内容',
    category: 'structure',
    weight: 15,
    check: (prompt: string) => {
      const issues: string[] = []
      const suggestions: string[] = []
      let score = 100
      
      const hasHeaders = /#{1,6}|【|】|\[|\]/.test(prompt)
      const hasNumbering = /\d+\.|第.*步|首先|然后|最后/.test(prompt)
      const hasSeparators = /---|###|===/.test(prompt)
      
      if (prompt.length > 300 && !hasHeaders && !hasNumbering) {
        issues.push('长提示词缺乏清晰结构')
        suggestions.push('使用标题、编号或分隔符组织内容')
        score -= 30
      }
      
      if (prompt.length > 500 && !hasSeparators) {
        issues.push('复杂提示词缺乏分隔符')
        suggestions.push('使用分隔符（如---、###）分隔不同部分')
        score -= 20
      }
      
      return { passed: score > 70, score, issues, suggestions }
    }
  },
  {
    id: 'positive_instruction',
    name: '正面指令',
    description: '使用正面指令而非负面限制',
    category: 'clarity',
    weight: 10,
    check: (prompt: string) => {
      const issues: string[] = []
      const suggestions: string[] = []
      let score = 100
      
      const negativePatterns = /不要|别|禁止|避免|不能|不可|不应该/.test(prompt)
      const positivePatterns = /请|应该|需要|要求|希望/.test(prompt)
      
      if (negativePatterns && !positivePatterns) {
        issues.push('过多使用负面指令')
        suggestions.push('转换为正面指令，明确告诉AI应该做什么')
        score -= 40
      } else if (negativePatterns) {
        issues.push('包含负面指令')
        suggestions.push('尽量使用正面表达方式')
        score -= 20
      }
      
      return { passed: score > 70, score, issues, suggestions }
    }
  },
  {
    id: 'framework_usage',
    name: '框架使用',
    description: '是否使用了结构化提示词框架',
    category: 'structure',
    weight: 10,
    check: (prompt: string) => {
      const issues: string[] = []
      const suggestions: string[] = []
      let score = 70 // 默认分数，不强制要求
      
      const frameworks = [
        'Context', 'Objective', 'Style', 'Tone', 'Audience', 'Response',
        'Role', 'Task', 'Format',
        'Capacity', 'Insight', 'Statement', 'Personality', 'Experiment'
      ]
      
      const hasFramework = frameworks.some(f => prompt.includes(f) || prompt.includes(f.toLowerCase()))
      
      if (!hasFramework && prompt.length > 400) {
        suggestions.push('考虑使用CO-STAR、RTF等结构化框架')
        score = 60
      } else if (hasFramework) {
        score = 100
      }
      
      return { passed: score > 70, score, issues, suggestions }
    }
  }
]

interface PromptQualityAnalyzerProps {
  prompt: string
  onAnalyze?: (result: AnalysisResult) => void
}

function PromptQualityAnalyzer({ prompt, onAnalyze }: PromptQualityAnalyzerProps) {
  const [analysisResult, setAnalysisResult] = useState<AnalysisResult | null>(null)
  const [isAnalyzing, setIsAnalyzing] = useState(false)

  const analyzePrompt = () => {
    if (!prompt.trim()) return
    
    setIsAnalyzing(true)
    
    // 模拟分析延迟
    setTimeout(() => {
      const results = qualityChecks.map(check => ({
        check,
        result: check.check(prompt)
      }))
      
      // 计算总分和分类分数
      let totalWeightedScore = 0
      let totalWeight = 0
      const categoryScores: Record<string, number> = {}
      const categoryWeights: Record<string, number> = {}
      
      results.forEach(({ check, result }) => {
        totalWeightedScore += result.score * check.weight
        totalWeight += check.weight
        
        if (!categoryScores[check.category]) {
          categoryScores[check.category] = 0
          categoryWeights[check.category] = 0
        }
        categoryScores[check.category] += result.score * check.weight
        categoryWeights[check.category] += check.weight
      })
      
      // 归一化分类分数
      Object.keys(categoryScores).forEach(category => {
        categoryScores[category] = categoryScores[category] / categoryWeights[category]
      })
      
      const totalScore = totalWeightedScore / totalWeight
      
      // 收集问题和建议
      const issues: Array<{ category: string; issue: string; suggestion: string }> = []
      const strengths: string[] = []
      
      results.forEach(({ check, result }) => {
        if (result.passed) {
          strengths.push(check.name)
        } else {
          result.issues.forEach((issue, index) => {
            issues.push({
              category: check.category,
              issue,
              suggestion: result.suggestions[index] || '建议优化此方面'
            })
          })
        }
      })
      
      // 生成总体建议
      const recommendations: string[] = []
      if (totalScore < 60) {
        recommendations.push('提示词需要大幅改进，建议重新设计')
      } else if (totalScore < 80) {
        recommendations.push('提示词有改进空间，重点优化标记的问题')
      } else {
        recommendations.push('提示词质量良好，可进行微调优化')
      }
      
      const analysisResult: AnalysisResult = {
        totalScore,
        categoryScores,
        issues,
        strengths,
        recommendations
      }
      
      setAnalysisResult(analysisResult)
      onAnalyze?.(analysisResult)
      setIsAnalyzing(false)
    }, 1000)
  }

  const getScoreColor = (score: number) => {
    if (score >= 80) return 'green'
    if (score >= 60) return 'yellow'
    return 'red'
  }

  const getCategoryName = (category: string) => {
    const names = {
      clarity: '清晰度',
      specificity: '具体性',
      context: '上下文',
      structure: '结构性',
      completeness: '完整性'
    }
    return names[category as keyof typeof names] || category
  }

  const getCategoryIcon = (category: string) => {
    const icons = {
      clarity: CheckIcon,
      specificity: InfoIcon,
      context: InfoIcon,
      structure: InfoIcon,
      completeness: CheckIcon
    }
    return icons[category as keyof typeof icons] || InfoIcon
  }

  return (
    <Box>
      <VStack spacing={4} align="stretch">
        <Card variant="outline">
          <CardHeader>
            <HStack justify="space-between">
              <Heading size="md" color="green.600">
                📊 提示词质量分析器
              </Heading>
              <Button
                onClick={analyzePrompt}
                isLoading={isAnalyzing}
                loadingText="分析中..."
                colorScheme="green"
                size="sm"
                isDisabled={!prompt.trim()}
              >
                分析质量
              </Button>
            </HStack>
          </CardHeader>
          <CardBody>
            <Text fontSize="sm" color="gray.600">
              基于提示词工程最佳实践，从清晰度、具体性、上下文、结构性等维度评估提示词质量
            </Text>
          </CardBody>
        </Card>

        {analysisResult && (
          <VStack spacing={4} align="stretch">
            {/* 总体分数 */}
            <Card variant="outline" borderColor={`${getScoreColor(analysisResult.totalScore)}.200`}>
              <CardBody>
                <SimpleGrid columns={{ base: 1, md: 3 }} spacing={4}>
                  <Stat>
                    <StatLabel>总体质量分数</StatLabel>
                    <StatNumber color={`${getScoreColor(analysisResult.totalScore)}.500`}>
                      {analysisResult.totalScore.toFixed(0)}分
                    </StatNumber>
                    <StatHelpText>
                      <Badge colorScheme={getScoreColor(analysisResult.totalScore)}>
                        {analysisResult.totalScore >= 80 ? '优秀' : 
                         analysisResult.totalScore >= 60 ? '良好' : '需改进'}
                      </Badge>
                    </StatHelpText>
                  </Stat>
                  
                  <Stat>
                    <StatLabel>发现问题</StatLabel>
                    <StatNumber color="red.500">{analysisResult.issues.length}</StatNumber>
                    <StatHelpText>需要优化的方面</StatHelpText>
                  </Stat>
                  
                  <Stat>
                    <StatLabel>优势方面</StatLabel>
                    <StatNumber color="green.500">{analysisResult.strengths.length}</StatNumber>
                    <StatHelpText>已做得很好的方面</StatHelpText>
                  </Stat>
                </SimpleGrid>
              </CardBody>
            </Card>

            {/* 分类分数 */}
            <Card variant="outline">
              <CardHeader>
                <Heading size="sm">分维度评分</Heading>
              </CardHeader>
              <CardBody>
                <VStack spacing={3}>
                  {Object.entries(analysisResult.categoryScores).map(([category, score]) => (
                    <Box key={category} width="100%">
                      <HStack justify="space-between" mb={1}>
                        <HStack>
                          <Icon as={getCategoryIcon(category)} color={`${getScoreColor(score)}.500`} />
                          <Text fontSize="sm" fontWeight="medium">
                            {getCategoryName(category)}
                          </Text>
                        </HStack>
                        <Text fontSize="sm" color={`${getScoreColor(score)}.500`} fontWeight="bold">
                          {score.toFixed(0)}分
                        </Text>
                      </HStack>
                      <Progress 
                        value={score} 
                        colorScheme={getScoreColor(score)}
                        size="sm"
                        borderRadius="md"
                      />
                    </Box>
                  ))}
                </VStack>
              </CardBody>
            </Card>

            {/* 问题和建议 */}
            {analysisResult.issues.length > 0 && (
              <Card variant="outline" borderColor="orange.200">
                <CardHeader>
                  <Heading size="sm" color="orange.600">
                    ⚠️ 发现的问题与改进建议
                  </Heading>
                </CardHeader>
                <CardBody>
                  <Accordion allowMultiple>
                    {analysisResult.issues.map((issue, index) => (
                      <AccordionItem key={index}>
                        <AccordionButton>
                          <Box flex="1" textAlign="left">
                            <HStack>
                              <Icon as={WarningIcon} color="orange.500" />
                              <Text fontSize="sm">{issue.issue}</Text>
                              <Badge colorScheme="orange" variant="outline" size="sm">
                                {getCategoryName(issue.category)}
                              </Badge>
                            </HStack>
                          </Box>
                          <AccordionIcon />
                        </AccordionButton>
                        <AccordionPanel pb={4}>
                          <Alert status="info" size="sm">
                            <AlertIcon />
                            <AlertDescription fontSize="sm">
                              <strong>建议：</strong>{issue.suggestion}
                            </AlertDescription>
                          </Alert>
                        </AccordionPanel>
                      </AccordionItem>
                    ))}
                  </Accordion>
                </CardBody>
              </Card>
            )}

            {/* 优势方面 */}
            {analysisResult.strengths.length > 0 && (
              <Card variant="outline" borderColor="green.200">
                <CardHeader>
                  <Heading size="sm" color="green.600">
                    ✅ 做得很好的方面
                  </Heading>
                </CardHeader>
                <CardBody>
                  <List spacing={2}>
                    {analysisResult.strengths.map((strength, index) => (
                      <ListItem key={index}>
                        <ListIcon as={CheckIcon} color="green.500" />
                        <Text fontSize="sm" display="inline">{strength}</Text>
                      </ListItem>
                    ))}
                  </List>
                </CardBody>
              </Card>
            )}

            {/* 总体建议 */}
            <Alert status="info" borderRadius="md">
              <AlertIcon />
              <Box>
                <Text fontWeight="bold" fontSize="sm" mb={1}>总体建议</Text>
                <VStack align="start" spacing={1}>
                  {analysisResult.recommendations.map((recommendation, index) => (
                    <Text key={index} fontSize="sm">{recommendation}</Text>
                  ))}
                </VStack>
              </Box>
            </Alert>
          </VStack>
        )}
      </VStack>
    </Box>
  )
}

export default PromptQualityAnalyzer 