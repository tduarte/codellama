# CodeLlama — Native macOS Agentic IDE
## Progress Tracker

_Last updated: 2026-03-14 15:42:00 PDT_

| Phase | Status | Commit | Files |
|---|---|---|---|
| Phase 1: Basic Chat + Ollama | ✅ **DONE** | `2d97a2c` | 24 files, 2031 insertions |
| Phase 2: MCP Integration + Agentic Loop | ✅ **DONE** | `5430746` | +16 files |
| Phase 3: Skills Engine + RAG | ✅ **DONE** | uncommitted local changes | +8 Swift files, Textual added |
| Phase 4: Multi-Server Orchestration + Polish | 🟡 IN PROGRESS | uncommitted local changes | MCP health/restart + search/export + task cancellation |

---

## Context

CodeLlama is a native macOS agentic IDE that connects local LLMs (Ollama) with external tool-use capabilities (MCP). Built with Swift/SwiftUI, targeting macOS 26.2+.

**Key drivers:**
- All inference stays local via Ollama (privacy, no API keys)
- MCP provides a standard protocol for connecting to tools (filesystem, GitHub, databases, etc.)
- A "review-first" UI ensures the user approves every action before execution

**Repo:** `/Users/tduarte/.t3/worktrees/codellama/t3code-2b541d9e/`

---

## 1. Architecture Overview

```
codellamaApp (@main)
├── AppState (Ollama lifecycle + mcpHost registry + shared ContextIndexManager)
├── ModelContainer (SwiftData: Conversation, ChatMessage, MCPServerConfig, Skill)
│
├── Views Layer              ├── ViewModels Layer    ├── Services Layer
│   MainView                │   ChatViewModel       │   OllamaClient (actor)
│   SidebarView             │   AgentViewModel      │   MCPHost (@Observable)
│   ChatView                │   SettingsViewModel   │     MCPServerConnection
│   PlanTimelineView        │   SkillViewModel      │     MCPProcessManager
│   DiffView                │                       │   AgentLoop (@Observable)
│   SkillComposerView       │                       │     ContextBuilder
│   SkillListView           │                       │     PlanGenerator
│   SettingsView            │                       │     PlanExecutor
│                           │                       │   Embedding/
│                           │                       │     ContextIndexManager
│                           │                       │     EmbeddingService
│                           │                       │     VectorStore
│                           │                       │     ChunkIndexer
```

### Data Flow

```
Chat mode:
  User input → ChatViewModel.send() → OllamaClient.chatStream() → NDJSON → ChatMessage (SwiftData)

Agent mode:
  User prompt → AgentViewModel.runAgent()
    → AgentLoop.run()
        → Phase 1 (ContextBuilder): queries MCP resources, builds context summary
        → Phase 2 (PlanGenerator): Ollama /api/chat with tools[] → ExecutionPlan
        ⏸ PAUSE → PlanTimelineView shown → user clicks Approve
        → Phase 3 (PlanExecutor): sequential MCPHost.callTool() per AgentStep
    → Results fed back to conversation
```

---

## 2. Key Architecture Decisions (Final)

| Decision | Choice | Rationale |
|---|---|---|
| Ollama client | **Custom `OllamaClient` actor** | OllamaKit doesn't support `tools` for function calling |
| MCP client | **`modelcontextprotocol/swift-sdk`** (SPM, product `MCP`) | Official, v0.10.2, actively maintained |
| App Sandbox | **Disabled** | `Process()` for MCP server spawning blocked by sandbox |
| Hardened Runtime | **Enabled** | Security best practice |
| Markdown | **`gonzalezreal/textual`** | Added for structured markdown rendering in chat bubbles |
| Syntax highlight | **Skipped for Phase 3** | `Textual` was sufficient for the current scope |
| Chat input | **Custom `ChatInputView`** | ChatField unmaintained; native TextEditor with `.onKeyPress` |
| Vector store | **In-memory** (Phase 3), SQLite later | Brute-force cosine similarity fine for <10K chunks |

---

## 3. Current File Tree (47 Swift files)

```
codellama/
├── App/
│   ├── codellamaApp.swift              ✅ Phase 1+2
│   └── AppState.swift                  ✅ Phase 1+2+4 (has mcpHost, startup(modelContext:))
├── Extensions/
│   └── Defaults+Keys.swift             ✅ Phase 1
├── Models/
│   ├── OllamaTypes.swift               ✅ Phase 1 (JSONValue, OllamaChatRequest+tools, etc.)
│   ├── Conversation.swift              ✅ Phase 1 (SwiftData @Model)
│   ├── ChatMessage.swift               ✅ Phase 1 (SwiftData @Model, isStreaming, toolCallsJSON)
│   ├── MCPServerConfig.swift           ✅ Phase 2 (SwiftData @Model)
│   ├── AgentTask.swift                 ✅ Phase 1 (Codable, AgentPhase, TimelineEvent)
│   ├── ExecutionPlan.swift             ✅ Phase 1 (Codable, AgentStep, PlanStatus)
│   ├── ToolCall.swift                  ✅ Phase 1 (Codable)
│   ├── ToolResult.swift                ✅ Phase 1 (Codable)
│   └── Skill.swift                     ✅ Phase 3
├── Services/
│   ├── Ollama/
│   │   ├── OllamaClient.swift          ✅ Phase 1+3 (actor, chatStream async→AsyncThrowingStream, embeddings)
│   │   └── OllamaStreamParser.swift    ✅ Phase 1
│   ├── MCP/
│   │   ├── MCPHost.swift               ✅ Phase 2+4 (@Observable, ollamaTools(), callTool(), runtime health state)
│   │   ├── MCPServerConnection.swift   ✅ Phase 2+4 (wraps MCP.Client, bridges Pipe→FileDescriptor, exit recovery)
│   │   └── MCPProcessManager.swift     ✅ Phase 2+4 (Process() lifecycle, /usr/bin/env, unexpected-exit handling)
│   ├── Agent/
│   │   ├── AgentLoop.swift             ✅ Phase 2+3+4 (@Observable, run/approvePlan/cancelPlan, `/skill` execution)
│   │   ├── ContextBuilder.swift        ✅ Phase 2+3 (MCP + indexed context retrieval)
│   │   ├── PlanGenerator.swift         ✅ Phase 2+3 (saved skill summaries in planning prompt)
│   │   └── PlanExecutor.swift          ✅ Phase 2+4
│   └── Embedding/
│       ├── EmbeddingService.swift      ✅ Phase 3
│       ├── VectorStore.swift           ✅ Phase 3
│       ├── ChunkIndexer.swift          ✅ Phase 3
│       └── ContextIndexManager.swift   ✅ Phase 3
├── ViewModels/
│   ├── ChatViewModel.swift             ✅ Phase 1+4 (streaming, cancellation, auto-title, search/export)
│   ├── AgentViewModel.swift            ✅ Phase 2+3+4
│   └── SettingsViewModel.swift         ✅ Phase 1
│   └── SkillViewModel.swift            ✅ Phase 3
├── Views/
│   ├── MainView.swift                  ✅ Phase 1+2+3+4 (status routing, PlanTimelineView overlay, Skills sheet)
│   ├── Sidebar/
│   │   ├── SidebarView.swift           ✅ Phase 1+4
│   │   └── ConversationListItem.swift  ✅ Phase 1+4
│   ├── Chat/
│   │   ├── ChatView.swift              ✅ Phase 1
│   │   ├── MessageBubble.swift         ✅ Phase 1
│   │   ├── ChatInputView.swift         ✅ Phase 1 (custom TextEditor, Enter/Shift+Enter)
│   │   └── StreamingTextView.swift     ✅ Phase 1+3 (`Textual` structured markdown)
│   ├── Agent/
│   │   ├── PlanTimelineView.swift      ✅ Phase 2+4
│   │   ├── PlanStepRow.swift           ✅ Phase 2
│   │   └── ToolCallDetailView.swift    ✅ Phase 2
│   ├── Diff/
│   │   ├── DiffView.swift              ✅ Phase 2
│   │   └── DiffLineView.swift          ✅ Phase 2
│   ├── Skills/
│   │   ├── SkillComposerView.swift     ✅ Phase 3
│   │   └── SkillListView.swift         ✅ Phase 3
│   └── Settings/
│       ├── SettingsView.swift          ✅ Phase 1+2+3 (General + MCP Servers + Skills tabs)
│       ├── OllamaSettingsView.swift    ✅ Phase 1+3 (embedding model + context folder indexing UI)
│       ├── MCPServerSettingsView.swift ✅ Phase 2+4
│       └── MCPServerFormView.swift     ✅ Phase 2
└── Resources/
    ├── Assets.xcassets
    └── codellama.entitlements          ✅ Phase 1 (sandbox off, network client on)
```

---

## 4. SPM Dependencies

| Package | URL | Purpose | Status |
|---|---|---|---|
| `MCP` | `github.com/modelcontextprotocol/swift-sdk` ≥0.9.0 | MCP client + STDIO transport | ✅ Added |
| `Defaults` | `github.com/sindresorhus/Defaults` ≥9.0.0 | Type-safe UserDefaults | ✅ Added |
| `Textual` | `github.com/gonzalezreal/textual` | Structured markdown rendering in `StreamingTextView` | ✅ Added (`0.3.1`) |
| `HighlighterSwift` | `github.com/smittytone/HighlighterSwift` ≥3.0.0 | Code syntax highlighting | ⏭️ Skipped by choice; not needed for current Phase 3 scope |

### MCP SDK API Notes (discovered at build time, v0.10.x)
- Class is `Client` (not `MCPClient`)
- `StdioTransport(input:output:)` takes `FileDescriptor` from `System` framework — bridge via `FileDescriptor(rawValue: pipe.fileHandle.fileDescriptor)`
- `client.listTools()` / `client.listResources()` return named tuples, not result structs
- `client.callTool(named:arguments:)` returns `(content: [Tool.Content], isError: Bool?)`
- `Tool.inputSchema` is `Value` (non-optional)
- Tool names are namespaced as `serverName__toolName` to avoid collisions across servers

---

## 5. Phase 3: Skills Engine + RAG (Complete)

**Goal:** User-defined skill abstractions + local context indexing with embeddings.

### Implemented:
1. `Models/Skill.swift` — SwiftData `@Model` { name, descriptionText, toolSequenceJSON: Data }
2. `Services/Embedding/EmbeddingService.swift` — calls Ollama `POST /api/embeddings`
3. `Services/Embedding/VectorStore.swift` — in-memory cosine similarity search over indexed chunks
4. `Services/Embedding/ChunkIndexer.swift` — splits text into overlapping chunks and indexes them
5. `Services/Embedding/ContextIndexManager.swift` — shared local folder index manager with persistence via `Defaults`
6. `ViewModels/SkillViewModel.swift` — CRUD for Skill SwiftData records
7. `Views/Skills/SkillListView.swift` — list of saved skills
8. `Views/Skills/SkillComposerView.swift` — compose reusable MCP tool sequences with argument editing

### Updated:
- `Services/Agent/ContextBuilder.swift` — queries `VectorStore` for relevant chunks in Phase 1
- `Services/Agent/PlanGenerator.swift` — includes saved skill summaries in the planner prompt
- `Services/Agent/AgentLoop.swift` — supports `/skill <name>` invocation for saved tool sequences
- `App/AppState.swift` — owns a shared `ContextIndexManager` and reindexes attached folders on startup
- `codellamaApp.swift` — includes `Skill.self` in the ModelContainer schema and injects skill/index services
- `Views/Settings/SettingsView.swift` — adds a Skills tab
- `Views/Settings/OllamaSettingsView.swift` — adds embedding model configuration plus attach/reindex folder UI
- `Views/MainView.swift` — adds a Skills panel via sheet from the main toolbar
- `Views/Chat/StreamingTextView.swift` — uses `Textual` for structured markdown rendering

### SPM:
- `Textual` (github.com/gonzalezreal/textual) — added and used for rich markdown rendering
- `HighlighterSwift` (github.com/smittytone/HighlighterSwift) — intentionally skipped for now

### Milestone Status:
- ✅ User can attach a folder → files indexed into `VectorStore` → agent uses context in plans
- ✅ User can save a Skill (e.g., "Refactor Function" = read_file + write_file sequence)
- ✅ Skill runs tool sequence automatically when invoked via `/skill <name>`

---

## 6. Phase 4: Multi-Server Orchestration + Polish (In Progress)

**Goal:** Production-quality UX, parallel execution, persistent store.

### Implemented in this pass
- `ViewModels/ChatViewModel.swift` — added pending dropped-file attachments, validation, PDF extraction, native image upload for vision-capable models, and prompt composition for chat context
- `Views/Chat/ChatInputView.swift` — added attached-file chips, drop-target affordance, and send-state updates for attachment-only prompts
- `Views/Chat/ChatView.swift` — enabled drag-and-drop file ingestion on the chat surface with inline error feedback
- `Views/CommandPalette/CommandPaletteView.swift` — added a searchable command palette for app actions, conversation switching, skill access, and server recovery
- `Views/MainView.swift` — wired the command palette into the main window, toolbar, and live app actions
- `codellamaApp.swift` — registered a global `Cmd+K` menu command for opening the palette
- `Services/Embedding/VectorStore.swift` — replaced the in-memory store with a SQLite-backed persistent store plus fallback in-memory mode
- `Services/Embedding/ChunkIndexer.swift` — skips re-embedding unchanged resources by checking persisted fingerprints before chunk generation
- `Services/Embedding/ContextIndexManager.swift` — prunes deleted local files while preserving unchanged indexed resources across launches
- `Services/Agent/ContextBuilder.swift` — filters persisted context matches to currently available MCP servers plus local indexed files
- `Services/MCP/MCPHost.swift` — added `TaskGroup`-based parallel tool dispatch for independent calls
- `Services/Agent/PlanExecutor.swift` — batches likely read-only steps across different MCP servers while preserving overall plan order
- `Services/MCP/MCPHost.swift` — added `MCPServerRuntimeState`, tracked lifecycle per server, and wired restart/enable/disable/remove flows
- `Services/MCP/MCPProcessManager.swift` — added termination callbacks and unexpected-exit detection
- `Services/MCP/MCPServerConnection.swift` — records connection failures and unexpected process termination state
- `Views/Settings/MCPServerSettingsView.swift` — live connection state text, enable/disable wiring, and restart button
- `Views/Sidebar/SidebarView.swift` — server health section with restart affordance, searchable conversations, and export action
- `ViewModels/ChatViewModel.swift` — conversation search filtering and Markdown export
- `Services/Agent/AgentLoop.swift` — persistent execution task, stop/cancel behavior, and dismissable terminal states
- `Services/Agent/PlanExecutor.swift` — cancellation-aware execution with skipped remaining steps
- `Views/Agent/PlanTimelineView.swift` — visible planning/executing/completed/cancelled states instead of approval-only UI

### Milestone status
- ✅ Auto-restart crashed MCP servers in `MCPProcessManager`
- ✅ Server health status indicators in sidebar/settings
- ✅ Conversation search + Markdown export
- ✅ Request cancellation for agent plan execution

### Remaining Phase 4 work
- Debounced UI updates beyond the current cancellation/polish pass

---

## 7. Build Instructions

```bash
# Standard build (from project root)
xcodebuild -project codellama.xcodeproj -scheme codellama \
  -configuration Debug -destination 'platform=macOS' build

# Check errors only
xcodebuild ... build 2>&1 | grep -E "error:|BUILD SUCCEEDED|BUILD FAILED"

# Clean
xcodebuild clean -project codellama.xcodeproj -scheme codellama
```

**Requires:** Xcode 26+, macOS 26.2+ SDK, Ollama installed locally.

---

## 8. Known Gotchas

1. **`SWIFT_DEFAULT_ACTOR_ISOLATION = MainActor`** — all types default to `@MainActor`. When calling into other actors (like `OllamaClient`), methods that return `AsyncThrowingStream` must be `async` so the caller can `await` crossing the actor boundary. See `OllamaClient.chatStream() async ->`.

2. **SwiftData `@Model` default values** — must use `Date.now` not `.now` in `@Model` classes (the macro expander doesn't resolve `.now` in its generated code).

3. **MCP `StdioTransport` takes `FileDescriptor`** (from `System` module), not `FileHandle`. Bridge: `FileDescriptor(rawValue: pipe.fileHandleForReading.fileDescriptor)`.

4. **Tool name namespacing** — MCP tools are registered as `serverName__toolName` (double underscore) in `MCPHost.ollamaTools()` to avoid name collisions when multiple servers expose similarly-named tools.

5. **Sandbox is disabled** — `ENABLE_APP_SANDBOX = NO` in both Debug and Release build configs. This is intentional and required for `Process()` to spawn MCP servers.

6. **`AgentViewModel` needs a valid `OllamaClient`** — `codellamaApp.swift` passes `appState.ollamaClient ?? OllamaClient()` which means before Ollama connects, the fallback client points to localhost:11434. Agent features should be gated on `appState.status == .ready`.
