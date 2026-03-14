# codellama

A native macOS chat app for running local AI models via [Ollama](https://ollama.com), with agentic tool-calling powered by the [Model Context Protocol (MCP)](https://modelcontextprotocol.io).

## Features

- **Streaming chat** — real-time token-by-token responses from any Ollama model
- **Agentic mode** — multi-step planning loop that calls MCP tools to accomplish tasks
- **MCP server support** — connect any stdio-based MCP server; tools are automatically discovered and exposed to the model
- **Plan approval** — before executing, the agent presents its plan for you to review and approve
- **Conversation history** — persistent SwiftData storage with a sidebar for navigating past chats
- **Model switching** — pick from any model pulled in Ollama; auto-selects the first available
- **Configurable** — custom Ollama host, system prompt, default model, and streaming toggle

## Requirements

- macOS 26.2+
- Xcode 26+
- [Ollama](https://ollama.com/download) installed and running locally
- At least one model pulled, e.g.:
  ```
  ollama pull llama3.1:8b
  ```

## Getting Started

1. Clone the repo:
   ```bash
   git clone https://github.com/tduarte/codellama.git
   cd codellama
   ```

2. Open the project in Xcode:
   ```bash
   open codellama.xcodeproj
   ```

3. Press **Cmd+R** to build and run.

The app will automatically detect Ollama at `/usr/local/bin/ollama`, `/opt/homebrew/bin/ollama`, or anywhere on your PATH. If Ollama isn't running, the app will offer to start it for you.

## MCP Server Configuration

Go to **Settings → MCP Servers** to add servers. Each server needs:

- **Command** — the executable to run (e.g. `npx`, `uvx`, `python`)
- **Arguments** — arguments passed to the command
- **Environment** — optional key/value environment variables

Tool names are namespaced as `serverName__toolName` to avoid collisions across servers.

Example — add the [filesystem MCP server](https://github.com/modelcontextprotocol/servers/tree/main/src/filesystem):
- Command: `npx`
- Arguments: `-y @modelcontextprotocol/server-filesystem /path/to/allow`

## Architecture

```
Services/
  Ollama/       — HTTP streaming client (NDJSON via URLSession)
  MCP/          — MCP server process management + tool routing
  Agent/        — Agentic planning loop (context → plan → execute)
Models/         — SwiftData models + Codable types
ViewModels/     — MVVM observable layer
Views/          — SwiftUI views
```

The agent loop runs three phases:
1. **ContextBuilder** — lists resources from all connected MCP servers
2. **PlanGenerator** — asks the model to produce a tool-call plan
3. **PlanExecutor** — executes each step via MCP, with live UI updates

## Dependencies

| Package | Purpose |
|---|---|
| [sindresorhus/Defaults](https://github.com/sindresorhus/Defaults) | Type-safe UserDefaults |
| [modelcontextprotocol/swift-sdk](https://github.com/modelcontextprotocol/swift-sdk) | Official MCP Swift client |

## Building from the CLI

```bash
xcodebuild -project codellama.xcodeproj -scheme codellama \
  -configuration Debug -destination 'platform=macOS' build
```

## License

MIT
