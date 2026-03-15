# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Build & Run

### Xcode MCP (preferred)

The Xcode MCP is available and should be used instead of the `xcodebuild` CLI whenever possible. It provides real-time integration with the running Xcode instance.

**Workflow:**

1. **Get the tab identifier** (required by most tools):
   ```
   XcodeListWindows → returns tabIdentifier (e.g. "windowtab1")
   ```

2. **Build the project:**
   ```
   BuildProject(tabIdentifier: "windowtab1")
   ```

3. **Check for errors after building:**
   ```
   GetBuildLog(tabIdentifier: "windowtab1", severity: "error")
   GetBuildLog(tabIdentifier: "windowtab1", severity: "warning")   // for warnings too
   ```
   You can also filter by file glob: `GetBuildLog(..., glob: "**/*.swift")`

4. **Run tests:**
   ```
   GetTestList(tabIdentifier: "windowtab1")          // list all tests
   RunAllTests(tabIdentifier: "windowtab1")           // run all
   RunSomeTests(tabIdentifier: "windowtab1", ...)     // run specific tests
   ```

5. **SwiftUI previews:**
   ```
   RenderPreview(tabIdentifier: "windowtab1", ...)    // render a preview without launching the app
   ```

6. **Apple documentation:**
   ```
   DocumentationSearch(query: "SwiftData @Model")
   ```

7. **Execute a Swift snippet** (useful for quick API checks):
   ```
   ExecuteSnippet(...)
   ```

8. **List current issues in the navigator:**
   ```
   XcodeListNavigatorIssues(tabIdentifier: "windowtab1")
   ```

The Xcode MCP also provides file tools (`XcodeRead`, `XcodeWrite`, `XcodeUpdate`, `XcodeGrep`, `XcodeGlob`, `XcodeLS`, `XcodeMV`, `XcodeRM`, `XcodeMakeDir`) but the standard Claude Code tools (`Read`, `Edit`, `Grep`, `Glob`) are equivalent and preferred for file I/O.

### Fallback: xcodebuild CLI

Use these only when Xcode is not open or the MCP is unavailable:

```bash
# Build (standard)
xcodebuild -project codellama.xcodeproj -scheme codellama \
  -configuration Debug -destination 'platform=macOS' build

# Check errors only (recommended for agents)
xcodebuild -project codellama.xcodeproj -scheme codellama \
  -configuration Debug -destination 'platform=macOS' build \
  2>&1 | grep -E "error:|warning:|BUILD SUCCEEDED|BUILD FAILED"

# Clean build
xcodebuild clean -project codellama.xcodeproj -scheme codellama
```

**Worktree workflow:** After completing any task in a git worktree, always open the worktree's project in Xcode so the user can inspect and run it:

```bash
open <worktree-path>/codellama.xcodeproj
```

Open `codellama.xcodeproj` in Xcode and press **Cmd+R** to build and run.

**Requirements:**
- Xcode 26+ with macOS 26.2 SDK
- Ollama installed locally (`/usr/local/bin/ollama` or `/opt/homebrew/bin/ollama`)
- At least one model pulled, e.g. `ollama pull llama3.1:8b`

---

## Project Status

| Phase | Status | Commit |
|---|---|---|
| Phase 1: Streaming chat + Ollama client | ✅ Done | `2d97a2c` |
| Phase 2: MCP integration + Agentic loop | ✅ Done | `5430746` |
| Phase 3: Skills Engine + RAG | ✅ Done | local worktree changes |
| Phase 4: Multi-server orchestration + Polish | 🔲 Future | — |

---

## Architecture

macOS SwiftUI app (MVVM + SwiftData) for chatting with local Ollama models with agentic MCP tool-calling capabilities.

### UI Framework Guidance

- This is a **SwiftUI-first** project. Build and modify UI in SwiftUI views and view models.
- Do not treat this as an AppKit UI codebase.
- Use AppKit only for macOS-specific integrations where SwiftUI has no equivalent (for example, `NSSavePanel` or `NSOpenPanel`).

### Entry Point & Lifecycle

`codellamaApp.swift` → creates `ModelContainer` (schema: `Conversation`, `ChatMessage`, `MCPServerConfig`) → initializes `AppState` → passes `modelContext` to `AppState.startup()` → renders `MainView`.

`AppState.startup(modelContext:)` sequence:
1. Locate Ollama binary (`/usr/local/bin/ollama`, `/opt/homebrew/bin/ollama`, PATH)
2. Check reachability: `GET http://localhost:11434`
3. Fetch models: `GET /api/tags` → `availableModels`
4. Connect enabled `MCPServerConfig` records from SwiftData → `mcpHost.connect(config:)`
5. Set `status = .ready`

`MainView` routes on `appState.status`: `.checking`/`.connecting` → spinner, `.ollamaNotFound` → download link, `.ollamaNotRunning` → Start button, `.ready` → `NavigationSplitView`.

### Three-Layer Service Architecture

**1. Ollama Layer** (`Services/Ollama/`)
- `OllamaClient` — `actor`, HTTP streaming via `URLSession.bytes(for:).lines` (NDJSON)
- `chatStream(request:) async -> AsyncThrowingStream<OllamaChatChunk, Error>` — must be `async` due to actor isolation with `SWIFT_DEFAULT_ACTOR_ISOLATION = MainActor`
- `OllamaStreamParser` — decodes individual NDJSON lines

**2. MCP Layer** (`Services/MCP/`)
- `MCPHost` — `@Observable @MainActor` singleton held by `AppState`; aggregates tools from all servers as `serverName__toolName`; converts to `OllamaTool` for function calling; routes `ToolCall` to correct server
- `MCPServerConnection` — wraps `MCP.Client` (from `modelcontextprotocol/swift-sdk`); bridges Foundation `Pipe` → `System.FileDescriptor` for `StdioTransport`
- `MCPProcessManager` — `NSLock`-protected `Process()` lifecycle manager; spawns via `/usr/bin/env` for PATH resolution

**3. Agent Layer** (`Services/Agent/`)
Three-phase loop in `AgentLoop` (`@Observable @MainActor`):
- **Phase 1** `ContextBuilder` — lists resources from all connected MCP servers, builds `ContextMap`
- **Phase 2** `PlanGenerator` — sends prompt + context + `mcpHost.ollamaTools()` to Ollama `/api/chat` (non-streaming), extracts `tool_calls` → `ExecutionPlan` of `AgentStep`s
- **⏸ Pause** — `AgentLoop.currentTask.phase == .awaitingApproval` → `PlanTimelineView` shown
- **Phase 3** `PlanExecutor` — executes each `AgentStep` via `MCPHost.callTool()`, calls `onStepUpdate` after each for live UI updates

### Data Flow

```
Chat mode:
  User input → ChatViewModel.send(appState:)
    → OllamaClient.chatStream() → NDJSON chunks
    → accumulate into ChatMessage.content (SwiftData, isStreaming flag)

Agent mode:
  User prompt → AgentViewModel.runAgent()
    → AgentLoop.run(prompt:model:)
        → ContextBuilder → ContextMap
        → PlanGenerator → ExecutionPlan (awaitingApproval)
        ⏸ PlanTimelineView shown, user approves
        → AgentLoop.approvePlan()
        → PlanExecutor → MCPHost.callTool() per step
    → Results → conversation messages
```

### Persistence

SwiftData models (in `ModelContainer` schema):
- `Conversation` — has `@Relationship(deleteRule: .cascade)` to `ChatMessage`
- `ChatMessage` — `role: String`, `content`, `toolCallsJSON: Data?`, `isStreaming: Bool`, `createdAt: Date`
- `MCPServerConfig` — `command`, `arguments: [String]`, `environmentJSON: Data?`, `isEnabled: Bool`

UserDefaults (via `Defaults` package, keys in `Extensions/Defaults+Keys.swift`):
- `ollamaHost` (default: `http://localhost:11434`)
- `defaultModel` (default: `llama3.1:8b`)
- `systemPrompt`
- `streamResponses`

### Key Types

**`JSONValue`** (`Models/OllamaTypes.swift`) — custom `enum` (string/number/bool/object/array/null) with full `Codable`, `Hashable`, `Sendable`, and `ExpressibleBy*Literal` conformances. Used everywhere for untyped JSON. MCP SDK's `Value` type is converted to/from `JSONValue` at the boundary in `MCPServerConnection`.

**`AgentTask`** (`Models/AgentTask.swift`) — ephemeral `Codable` struct (not persisted). Holds `phase: AgentPhase`, `plan: ExecutionPlan?`, `timeline: [TimelineEvent]`.

**`ExecutionPlan`** / **`AgentStep`** (`Models/ExecutionPlan.swift`) — `Codable`. Each step has a `ToolCall` and `ToolResult?` plus `StepStatus`.

---

## Dependencies (SPM)

| Product | Package URL | Purpose |
|---|---|---|
| `Defaults` | `github.com/sindresorhus/Defaults` ≥9.0.0 | Type-safe UserDefaults |
| `MCP` | `github.com/modelcontextprotocol/swift-sdk` ≥0.9.0 | Official MCP client + STDIO transport |
| `Textual` | `github.com/gonzalezreal/textual` | Structured markdown rendering |
| `HighlighterSwift` | `github.com/smittytone/HighlighterSwift` ≥3.0.0 | Skipped for current Phase 3 scope |

---

## Critical Gotchas

### 1. Actor isolation — `OllamaClient.chatStream()` must be `await`ed
`SWIFT_DEFAULT_ACTOR_ISOLATION = MainActor` is set in the project. `OllamaClient` is an `actor`. Methods that return `AsyncThrowingStream` are declared `async` so callers can cross the actor boundary with `await`:
```swift
// ✅ Correct
for try await chunk in await client.chatStream(request: request) { ... }

// ❌ Wrong — actor-isolated method can't be called synchronously from MainActor
for try await chunk in client.chatStream(request: request) { ... }
```

### 2. SwiftData `@Model` default values
Use `Date.now` (fully qualified), not `.now`, inside `@Model` classes. The SwiftData macro expander doesn't resolve implicit type context:
```swift
// ✅
var createdAt: Date = Date.now

// ❌ Compiler error from macro-generated code
var createdAt: Date = .now
```

### 3. MCP SDK `StdioTransport` uses `System.FileDescriptor`
The MCP Swift SDK v0.9+ requires `System.FileDescriptor`, not `Foundation.FileHandle`. Bridge pattern:
```swift
import System
let inputFD = FileDescriptor(rawValue: stdinPipe.fileHandleForReading.fileDescriptor)
let outputFD = FileDescriptor(rawValue: stdoutPipe.fileHandleForWriting.fileDescriptor)
let transport = StdioTransport(input: inputFD, output: outputFD)
```

### 4. MCP tool name namespacing
Tools from different servers are registered as `serverName__toolName` (double underscore) in `MCPHost.ollamaTools()` to avoid collisions. When routing tool calls back to servers, split on `__`:
```swift
// Tool exposed to Ollama: "filesystem__read_file"
// Routes to: connections["filesystem"]?.callTool(name: "read_file", ...)
```

### 5. App Sandbox is intentionally disabled
`ENABLE_APP_SANDBOX = NO` in both Debug and Release. Required for `Process()` to spawn MCP server subprocesses. Do not re-enable.

### 6. `AgentViewModel` initialization in `codellamaApp.swift`
`AgentViewModel` is initialized with `appState.ollamaClient ?? OllamaClient()`. Before `AppState.startup()` completes, `ollamaClient` is `nil` so it falls back to a default client. Agent features should only be accessible when `appState.status == .ready`.

---

## What to Work on Next (Phase 4)

Current Phase 4 candidates:

1. Parallel tool execution in `MCPHost` via `TaskGroup`
2. Auto-restart crashed MCP servers in `MCPProcessManager`
3. Server health status indicators in the UI
4. SQLite-backed persistent vector store
5. Cmd+K command palette
6. Drag-and-drop files into chat context
7. Conversation search and export
8. Debounced UI updates and request cancellation
