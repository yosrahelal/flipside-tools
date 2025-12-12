# Flipside API Reference

The CLI is a thin wrapper around Flipside's public REST API. You can build your own integrations using the same endpoints.

## Base URL & Authentication

```
Base URL: https://api.flipsidecrypto.xyz
Auth Header: x-api-key: <your-api-key>
```

Get an API key from [flipsidecrypto.xyz/chat/settings/mcp-keys](https://flipsidecrypto.xyz/chat/settings/mcp-keys).

---

## CLI.xyzmand → API Endpoint Mapping

| CLI.xyzmand | HTTP Method | Endpoint |
|-------------|-------------|----------|
| `flipside chat create` | POST | `/public/v2/chat/create` |
| `flipside chat send-message` | POST | `/public/v2/chat/send-message` |
| `flipside chat send-message-sync` | POST | `/public/v2/chat/send-message-sync` |
| `flipside chat list` | GET | `/public/v2/chat/list` |
| `flipside chat list-messages` | GET | `/public/v2/chat/messages` |
| `flipside chat list-attachments` | GET | `/public/v2/chat/attachments` |
| `flipside tools list` | GET | `/public/v2/tools` |
| `flipside tools execute <tool>` | POST | `/public/v2/tools/{toolName}` |
| `flipside tools schema <tool>` | GET | `/public/v2/tools/{toolName}/schema` |
| `flipside catalog agents list` | GET | `/public/v2/agents` |
| `flipside catalog agents run` | POST | `/public/v2/agents/{agentName}/execute` |
| `flipside agent list` | GET | `/public/v2/agents/profile-agents` |
| `flipside agent push` | POST | `/public/v2/agents/profile-agents` |
| `flipside agent describe` | GET | `/public/v2/agents/profile-agents/{name}` |
| `flipside agent delete` | DELETE | `/public/v2/agents/profile-agents/{name}` |
| `flipside config show` (profile) | GET | `/public/v2/profiles/me` |

---

## Key Endpoints

### Chat (Streaming)

```http
POST /public/v2/chat/send-message
Content-Type: application/json
x-api-key: <api-key>
x-session-id: <session-id>
x-stream-mode: uimessage

{
  "agentName": "data_analyst",
  "messages": [{
    "id": "msg-1",
    "role": "user",
    "parts": [{"type": "text", "text": "What is Ethereum gas price?"}]
  }]
}
```

**Stream modes:**
- `text` - Plain text streaming
- `uimessage` - Rich events with tool calls

**SSE Response:**
```
data: {"type":"text-delta","delta":"I'll check..."}
data: {"type":"tool-input-start","toolCallId":"call_1","toolName":"run_sql_query"}
data: {"type":"tool-output-available","toolCallId":"call_1","output":{...}}
```

### Execute Tool

```http
POST /public/v2/tools/run_sql_query
Content-Type: application/json
x-api-key: <api-key>

{"query": "SELECT * FROM ethereum.core.fact_blocks LIMIT 5"}
```

### Execute Agent

```http
POST /public/v2/agents/data_analyst/execute
Content-Type: application/json
x-api-key: <api-key>

{"message": "Analyze ETH gas trends"}
```

---

## Examples

### Python Client

```python
import requests

API_KEY = "your-api-key"
BASE = "https://api.flipsidecrypto.xyz"

# Create chat session
session = requests.post(
    f"{BASE}/public/v2/chat/create",
    headers={"x-api-key": API_KEY},
    json={"uiVersion": "5"}
).json()

# Stream chat response
resp = requests.post(
    f"{BASE}/public/v2/chat/send-message",
    headers={
        "x-api-key": API_KEY,
        "x-session-id": session["id"],
        "x-stream-mode": "uimessage"
    },
    json={
        "agentName": "data_analyst",
        "messages": [{
            "id": "1",
            "role": "user",
            "parts": [{"type": "text", "text": "ETH price?"}]
        }]
    },
    stream=True
)

for line in resp.iter_lines():
    if line.startswith(b"data: "):
        print(line[6:].decode())
```

### cURL

```bash
# Execute SQL query
curl -X POST "https://api.flipsidecrypto.xyz/public/v2/tools/run_sql_query" \
  -H "x-api-key: $API_KEY" \
  -H "Content-Type: application/json" \
  -d '{"query": "SELECT COUNT(*) FROM ethereum.core.fact_blocks"}'

# List available tools
curl "https://api.flipsidecrypto.xyz/public/v2/tools" \
  -H "x-api-key: $API_KEY"

# Execute an agent
curl -X POST "https://api.flipsidecrypto.xyz/public/v2/agents/data_analyst/execute" \
  -H "x-api-key: $API_KEY" \
  -H "Content-Type: application/json" \
  -d '{"message": "What is the TVL on Aave?"}'
```

### JavaScript/Node.js

```javascript
const API_KEY = "your-api-key";
const BASE = "https://api.flipsidecrypto.xyz";

// Execute SQL query
async function runQuery(sql) {
  const response = await fetch(`${BASE}/public/v2/tools/run_sql_query`, {
    method: "POST",
    headers: {
      "x-api-key": API_KEY,
      "Content-Type": "application/json",
    },
    body: JSON.stringify({ query: sql }),
  });
  return response.json();
}

// Stream chat messages
async function streamChat(sessionId, message) {
  const response = await fetch(`${BASE}/public/v2/chat/send-message`, {
    method: "POST",
    headers: {
      "x-api-key": API_KEY,
      "x-session-id": sessionId,
      "x-stream-mode": "text",
      "Content-Type": "application/json",
    },
    body: JSON.stringify({
      agentName: "data_analyst",
      messages: [{
        id: crypto.randomUUID(),
        role: "user",
        parts: [{ type: "text", text: message }],
      }],
    }),
  });

  const reader = response.body.getReader();
  const decoder = new TextDecoder();

  while (true) {
    const { done, value } = await reader.read();
    if (done) break;
    console.log(decoder.decode(value));
  }
}
```

---

## Chat Sessions

Chat sessions maintain conversation history for multi-turn interactions.

### Create a Session

```http
POST /public/v2/chat/create
x-api-key: <api-key>

{"uiVersion": "5", "meta": {"title": "My Analysis"}}
```

### List Sessions

```http
GET /public/v2/chat/list
x-api-key: <api-key>
```

### Get Messages

```http
GET /public/v2/chat/messages?sessionId=<session-id>
x-api-key: <api-key>
```

### Get Attachments

```http
GET /public/v2/chat/attachments?sessionId=<session-id>&type=CSV
x-api-key: <api-key>
```

---

## Tools

### List Available Tools

```http
GET /public/v2/tools
x-api-key: <api-key>
```

### Get Tool Schema

```http
GET /public/v2/tools/run_sql_query/schema
x-api-key: <api-key>
```

### Execute a Tool

```http
POST /public/v2/tools/{toolName}
x-api-key: <api-key>

{...tool-specific parameters}
```

---

## Agents

### List Catalog Agents

```http
GET /public/v2/agents
x-api-key: <api-key>
```

### Execute a Catalog Agent

```http
POST /public/v2/agents/{agentName}/execute
x-api-key: <api-key>

{"message": "Your question here"}
```

### List Your Agents

```http
GET /public/v2/agents/profile-agents
x-api-key: <api-key>
```

### Create/Update an Agent

```http
POST /public/v2/agents/profile-agents
x-api-key: <api-key>
Content-Type: application/json

{
  "name": "my_agent",
  "kind": "chat",
  "description": "My custom agent",
  "systemprompt": "You are...",
  "tools": [{"name": "run_sql_query"}],
  "maxturns": 10,
  "metadata": {"model": "claude-4-5-haiku"}
}
```

### Get Agent Details

```http
GET /public/v2/agents/profile-agents/{name}
x-api-key: <api-key>
```

### Delete an Agent

```http
DELETE /public/v2/agents/profile-agents/{name}
x-api-key: <api-key>
```

---

## Error Handling

The API returns standard HTTP status codes:

| Status | Meaning |
|--------|---------|
| 200 | Success |
| 400 | Bad request (check your parameters) |
| 401 | Invalid or missing API key |
| 404 | Resource not found |
| 429 | Rate limited |
| 500 | Server error |

Error responses include a JSON body:

```json
{
  "error": "Invalid API key",
  "code": "UNAUTHORIZED"
}
```

---

## Rate Limits

API requests are rate limited per API key. If you receive a 429 response, wait before retrying. Contact support for higher limits.
