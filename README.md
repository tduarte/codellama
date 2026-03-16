# codellama

A native macOS chat app for running local AI models via [Ollama](https://ollama.com), with agentic tool-calling powered by the [Model Context Protocol (MCP)](https://modelcontextprotocol.io).

## Features

- **Streaming or non-streaming chat** — honor the Settings toggle and chat with any local Ollama model
- **Agent mode** — switch the composer between Chat and Agent, then review the generated plan before any tools run
- **MCP server support** — connect any stdio-based MCP server; tools are automatically discovered and exposed to the model
- **Plan approval** — before executing, the agent presents its plan for you to review and approve
- **Shared skill support** — discover installed `SKILL.md` skills from `~/.config/codellama/skills`, `~/.codex/skills`, `~/.claude/skills`, and workspace-local `.codex/skills` / `.claude/skills`
- **Conversation history** — persistent SwiftData storage with a sidebar for navigating past chats
- **Model switching** — pick from any model pulled in Ollama; auto-selects the first available
- **Configurable** — custom Ollama host, system prompt, default model, streaming toggle, MCP arguments, and MCP environment variables

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

## Skills

codellama reads shared `skills.sh`-style skills from the following roots, in priority order:

1. Workspace `.codex/skills`
2. Workspace `.claude/skills`
3. `~/.config/codellama/skills`
4. `~/.codex/skills`
5. `~/.claude/skills`

Each skill lives at `<root>/<skill-name>/SKILL.md` and uses YAML frontmatter plus Markdown instructions. codellama does not require Codex or Claude to be installed; it simply reads those directories if they exist.

Use agent mode plus `/skill <name>` to invoke an installed skill explicitly. The app shows the parsed metadata, source root, path, and any shadowed duplicates in the Skills browser.

## MCP Server Configuration

Go to **Settings → MCP Servers** to add servers. Each server needs:

- **Command** — the executable to run (e.g. `npx`, `uvx`, `python`)
- **Arguments** — one argument per line, preserving spaces and quoting
- **Environment** — optional key/value environment variables

Tool names are namespaced as `serverName__toolName` to avoid collisions across servers.

Example — add the [filesystem MCP server](https://github.com/modelcontextprotocol/servers/tree/main/src/filesystem):
- Command: `npx`
- Arguments:
  - `-y`
  - `@modelcontextprotocol/server-filesystem`
  - `/path/to/allow`

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
| [jpsim/Yams](https://github.com/jpsim/Yams) | YAML frontmatter parsing for `SKILL.md` skills |
| [swiftlang/swift-markdown](https://github.com/swiftlang/swift-markdown) | Markdown parsing and validation for installed skills |

## Building from the CLI

```bash
xcodebuild -project codellama.xcodeproj -scheme codellama \
  -configuration Debug -destination 'platform=macOS' build
```

## Running Tests

```bash
xcodebuild test -project codellama.xcodeproj -scheme codellama \
  -destination 'platform=macOS' -only-testing:codellamaTests
```

## License

MIT
