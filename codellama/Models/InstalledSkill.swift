import Foundation

struct InstalledSkill: Identifiable, Hashable, Sendable {
    let id: String
    let name: String
    let descriptionText: String
    let source: InstalledSkillSource
    let directoryURL: URL
    let skillFileURL: URL
    let body: String
    let headings: [String]
    let relativeReferences: [InstalledSkillReference]
    let relatedContextFiles: [InstalledSkillContextFile]
    let lastModifiedAt: Date?
    let shadowedLocations: [InstalledSkillDuplicate]

    var sourceLabel: String { source.label }
}

struct InstalledSkillReference: Hashable, Sendable {
    let destination: String
    let resolvedURL: URL?
}

struct InstalledSkillContextFile: Hashable, Sendable {
    let relativePath: String
    let resolvedURL: URL
    let content: String
}

struct InstalledSkillDuplicate: Hashable, Sendable, Identifiable {
    let id: String
    let source: InstalledSkillSource
    let directoryURL: URL

    var sourceLabel: String { source.label }
}

struct InstalledSkillIssue: Identifiable, Hashable, Sendable {
    let id: String
    let source: InstalledSkillSource
    let directoryURL: URL
    let skillFileURL: URL
    let message: String
}

enum InstalledSkillSource: String, CaseIterable, Hashable, Sendable {
    case workspaceCodex
    case workspaceClaude
    case codellamaConfig
    case homeCodex
    case homeClaude

    var label: String {
        switch self {
        case .workspaceCodex:
            return "Workspace .codex"
        case .workspaceClaude:
            return "Workspace .claude"
        case .codellamaConfig:
            return "~/.config/codellama"
        case .homeCodex:
            return "~/.codex"
        case .homeClaude:
            return "~/.claude"
        }
    }
}

struct InstalledSkillCatalog: Sendable {
    let skills: [InstalledSkill]
    let issues: [InstalledSkillIssue]
    let scannedRoots: [InstalledSkillRoot]
}

struct InstalledSkillRoot: Identifiable, Hashable, Sendable {
    let source: InstalledSkillSource
    let directoryURL: URL

    var id: String { "\(source.rawValue)::\(directoryURL.path())" }
}
