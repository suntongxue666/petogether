#!/bin/bash

# 测试回调URL的脚本
echo "Testing callback URL: https://petogether-callback-backend.onrender.com/api/nanobananaapi-callback"

# 首先测试根路径
echo "Testing root path..."
curl -X GET https://petogether-callback-backend.onrender.com/

echo -e "\nTesting callback endpoint..."
curl -X POST https://petogether-callback-backend.onrender.com/api/nanobananaapi-callback \
  -H "Content-Type: application/json" \
  -d '{
    "taskId": "test-task-123",
    "status": "completed",
    "result": {
      "images": [
        {
          "url": "https://example.com/generated-image.jpg"
        }
      ]
    },
    "timestamp": "2025-10-25T15:00:00Z",
    "callbackSecret": "73bceb1e1e3fe217e0bf09aa76e1dfe6"
  }'

echo -e "\nTest completed. Please check Render.com logs for the callback reception."