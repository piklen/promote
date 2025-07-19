import { Box, Container, Heading, Tabs, TabList, TabPanels, Tab, TabPanel } from '@chakra-ui/react'
import PromptList from './components/prompt/PromptList'
import EnhancedPromptEditor from './components/prompt/EnhancedPromptEditor'
import PromptOptimizer from './components/optimization/PromptOptimizer'
import APIConfig from './components/core/APIConfig'

function App() {
  return (
    <Box minH="100vh" bg="gray.50">
      <Container maxW="container.xl" py={8}>
        <Heading as="h1" size="xl" mb={8} textAlign="center" color="blue.600">
          LLM提示词优化平台
        </Heading>
        
        <Tabs colorScheme="blue" variant="enclosed">
          <TabList>
            <Tab>提示词管理</Tab>
            <Tab>提示词优化</Tab>
            <Tab>最佳实践</Tab>
            <Tab>API配置</Tab>
          </TabList>
          
          <TabPanels>
            <TabPanel>
              <PromptList />
            </TabPanel>
            <TabPanel>
              <PromptOptimizer />
            </TabPanel>
            <TabPanel>
              <EnhancedPromptEditor />
            </TabPanel>
            <TabPanel>
              <APIConfig />
            </TabPanel>
          </TabPanels>
        </Tabs>
      </Container>
    </Box>
  )
}

export default App 