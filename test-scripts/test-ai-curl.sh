curl -X POST "https://aicp.teamshub.com/ai-paas/ai-open/sitech/aiopen/stream/Qwen3-235B-A22B-Public/v1/chat/completions" \
  -H "Content-Type: application/json; charset=UTF-8" \
  -H "Authorization: Bearer 791de2a2c3c67ac45286a695da1bd5e95ccd37b5" \
  -d '{
    "model": "Qwen3-235B",
    "messages": [{"role": "user", "content": "你好"}],
    "stream": false,
    "temperature": 0.7
  }'
