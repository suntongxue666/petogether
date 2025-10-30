const express = require('express');
const cors = require('cors');
const app = express();
const PORT = process.env.PORT || 3000;

// 中间件
app.use(cors());
app.use(express.json({ limit: '10mb' }));

// 存储任务状态（在生产环境中应该使用数据库）
const tasks = new Map();

// 根路径 - 用于健康检查
app.get('/', (req, res) => {
  console.log('Health check request received');
  res.status(200).json({ 
    message: 'Nano Banana Callback Service is running',
    timestamp: new Date().toISOString(),
    routes: ['/api/nanobananaapi-callback']
  });
});

// 回调处理路由
app.post('/api/nanobananaapi-callback', (req, res) => {
  console.log('=== Nano Banana Callback Received ===');
  console.log('Timestamp:', new Date().toISOString());
  console.log('Headers:', req.headers);
  console.log('Body:', JSON.stringify(req.body, null, 2));
  
  try {
    const { taskId, status, result, error_message, callbackSecret } = req.body;
    
    // 验证回调密钥（如果需要）
    const expectedSecret = '73bceb1e1e3fe217e0bf09aa76e1dfe6';
    if (callbackSecret && callbackSecret !== expectedSecret) {
      console.log('Invalid callback secret');
      return res.status(401).json({ error: 'Invalid callback secret' });
    }
    
    // 存储任务信息
    tasks.set(taskId, {
      status,
      result,
      error_message,
      timestamp: new Date().toISOString()
    });
    
    console.log(`Task ${taskId} updated with status: ${status}`);
    
    // 根据状态处理不同情况
    if (status === 'completed') {
      console.log('Task completed successfully');
      console.log('Image URLs:', result?.images?.map(img => img.url));
    } else if (status === 'failed') {
      console.log('Task failed:', error_message);
    } else {
      console.log('Task status:', status);
    }
    
    // 返回成功响应
    res.status(200).json({ 
      message: 'Callback received and processed successfully',
      taskId: taskId,
      status: status
    });
    
  } catch (error) {
    console.error('Error processing callback:', error);
    res.status(500).json({ error: 'Internal server error' });
  }
});

// 获取任务状态（可选的查询接口）
app.get('/api/task/:taskId', (req, res) => {
  const { taskId } = req.params;
  console.log(`Task status request for taskId: ${taskId}`);
  
  const task = tasks.get(taskId);
  if (task) {
    res.status(200).json(task);
  } else {
    res.status(404).json({ error: 'Task not found' });
  }
});

// 获取所有任务（用于调试）
app.get('/api/tasks', (req, res) => {
  console.log('All tasks request received');
  const allTasks = Array.from(tasks.entries()).map(([id, data]) => ({
    taskId: id,
    ...data
  }));
  res.status(200).json(allTasks);
});

// 启动服务器
app.listen(PORT, '0.0.0.0', () => {
  console.log(`=== Nano Banana Callback Service Started ===`);
  console.log(`Server is running on port ${PORT}`);
  console.log(`Health check endpoint: http://localhost:${PORT}/`);
  console.log(`Callback endpoint: http://localhost:${PORT}/api/nanobananaapi-callback`);
  console.log(`Expected callback secret: 73bceb1e1e3fe217e0bf09aa76e1dfe6`);
  console.log('========================================');
});

// 错误处理
process.on('uncaughtException', (error) => {
  console.error('Uncaught Exception:', error);
});

process.on('unhandledRejection', (reason, promise) => {
  console.error('Unhandled Rejection at:', promise, 'reason:', reason);
});