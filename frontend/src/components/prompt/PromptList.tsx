import { useState, useEffect } from 'react'
import {
  Box,
  Button,
  Card,
  CardBody,
  CardHeader,
  Heading,
  Text,
  VStack,
  HStack,
  IconButton,
  useToast,
  Modal,
  ModalOverlay,
  ModalContent,
  ModalHeader,
  ModalBody,
  ModalFooter,
  ModalCloseButton,
  FormControl,
  FormLabel,
  Input,
  Textarea,
  useDisclosure,
  Spinner,
  Badge,
} from '@chakra-ui/react'
import { AddIcon, EditIcon, DeleteIcon } from '@chakra-ui/icons'
import { promptApi, Prompt, PromptCreate } from '../../services/api'

function PromptList() {
  const [prompts, setPrompts] = useState<Prompt[]>([])
  const [loading, setLoading] = useState(true)
  const [newPrompt, setNewPrompt] = useState<PromptCreate>({ title: '', description: '' })
  const { isOpen, onOpen, onClose } = useDisclosure()
  const toast = useToast()

  useEffect(() => {
    loadPrompts()
  }, [])

  const loadPrompts = async () => {
    try {
      setLoading(true)
      const data = await promptApi.getPrompts()
      setPrompts(data)
    } catch (error) {
      toast({
        title: '加载失败',
        description: '无法加载提示词列表',
        status: 'error',
        duration: 3000,
        isClosable: true,
      })
    } finally {
      setLoading(false)
    }
  }

  const handleCreatePrompt = async () => {
    if (!newPrompt.title.trim()) {
      toast({
        title: '请输入标题',
        status: 'warning',
        duration: 2000,
        isClosable: true,
      })
      return
    }

    try {
      const created = await promptApi.createPrompt(newPrompt)
      setPrompts([...prompts, created])
      setNewPrompt({ title: '', description: '' })
      onClose()
      toast({
        title: '创建成功',
        status: 'success',
        duration: 2000,
        isClosable: true,
      })
    } catch (error) {
      toast({
        title: '创建失败',
        status: 'error',
        duration: 3000,
        isClosable: true,
      })
    }
  }

  const handleDeletePrompt = async (id: number) => {
    if (!window.confirm('确定要删除这个提示词项目吗？')) return

    try {
      await promptApi.deletePrompt(id)
      setPrompts(prompts.filter(p => p.id !== id))
      toast({
        title: '删除成功',
        status: 'success',
        duration: 2000,
        isClosable: true,
      })
    } catch (error) {
      toast({
        title: '删除失败',
        status: 'error',
        duration: 3000,
        isClosable: true,
      })
    }
  }

  if (loading) {
    return (
      <Box textAlign="center" py={10}>
        <Spinner size="xl" color="blue.500" />
      </Box>
    )
  }

  return (
    <Box>
      <HStack justify="space-between" mb={6}>
        <Heading size="md">我的提示词项目</Heading>
        <Button leftIcon={<AddIcon />} colorScheme="blue" onClick={onOpen}>
          新建项目
        </Button>
      </HStack>

      <VStack spacing={4} align="stretch">
        {prompts.length === 0 ? (
          <Card>
            <CardBody textAlign="center" py={10}>
              <Text color="gray.500">还没有任何提示词项目，点击"新建项目"创建第一个吧！</Text>
            </CardBody>
          </Card>
        ) : (
          prompts.map((prompt) => (
            <Card key={prompt.id} _hover={{ shadow: 'md' }} transition="shadow 0.2s">
              <CardHeader>
                <HStack justify="space-between">
                  <VStack align="start" spacing={1}>
                    <Heading size="sm">{prompt.title}</Heading>
                    {prompt.description && (
                      <Text fontSize="sm" color="gray.600">
                        {prompt.description}
                      </Text>
                    )}
                  </VStack>
                  <HStack>
                    <Badge colorScheme="green">
                      创建于 {new Date(prompt.created_at).toLocaleDateString()}
                    </Badge>
                    <IconButton
                      aria-label="编辑"
                      icon={<EditIcon />}
                      size="sm"
                      variant="ghost"
                    />
                    <IconButton
                      aria-label="删除"
                      icon={<DeleteIcon />}
                      size="sm"
                      variant="ghost"
                      colorScheme="red"
                      onClick={() => handleDeletePrompt(prompt.id)}
                    />
                  </HStack>
                </HStack>
              </CardHeader>
            </Card>
          ))
        )}
      </VStack>

      {/* 创建新提示词的模态框 */}
      <Modal isOpen={isOpen} onClose={onClose}>
        <ModalOverlay />
        <ModalContent>
          <ModalHeader>创建新的提示词项目</ModalHeader>
          <ModalCloseButton />
          <ModalBody>
            <VStack spacing={4}>
              <FormControl isRequired>
                <FormLabel>项目标题</FormLabel>
                <Input
                  placeholder="例如：客服机器人提示词"
                  value={newPrompt.title}
                  onChange={(e) => setNewPrompt({ ...newPrompt, title: e.target.value })}
                />
              </FormControl>
              <FormControl>
                <FormLabel>项目描述</FormLabel>
                <Textarea
                  placeholder="描述这个提示词项目的用途和目标"
                  value={newPrompt.description || ''}
                  onChange={(e) => setNewPrompt({ ...newPrompt, description: e.target.value })}
                />
              </FormControl>
            </VStack>
          </ModalBody>
          <ModalFooter>
            <Button variant="ghost" mr={3} onClick={onClose}>
              取消
            </Button>
            <Button colorScheme="blue" onClick={handleCreatePrompt}>
              创建
            </Button>
          </ModalFooter>
        </ModalContent>
      </Modal>
    </Box>
  )
}

export default PromptList 