import Foundation
import Markdown
import Yams

struct InstalledSkillLoader {
    private let fileManager: FileManager
    private let homeDirectory: URL
    private let maxRelatedContextLength = 8_000

    init(
        fileManager: FileManager = .default,
        homeDirectory: URL = FileManager.default.homeDirectoryForCurrentUser
    ) {
        self.fileManager = fileManager
        self.homeDirectory = homeDirectory
    }

    func loadCatalog(workspaceRoot: URL? = InstalledSkillLoader.defaultWorkspaceRoot()) -> InstalledSkillCatalog {
        let roots = makeRoots(workspaceRoot: workspaceRoot)
        ensureCanonicalRootExists(in: roots)

        var winningSkills: [String: InstalledSkill] = [:]
        var issues: [InstalledSkillIssue] = []

        for root in roots {
            guard fileManager.fileExists(atPath: root.directoryURL.path()) else { continue }

            for candidateDirectory in candidateSkillDirectories(in: root.directoryURL) {
                let skillFileURL = candidateDirectory.appendingPathComponent("SKILL.md", isDirectory: false)
                guard fileManager.fileExists(atPath: skillFileURL.path()) else { continue }

                do {
                    let skill = try parseSkill(at: candidateDirectory, skillFileURL: skillFileURL, source: root.source)
                    if let existing = winningSkills[skill.name] {
                        let duplicate = InstalledSkillDuplicate(
                            id: "\(skill.id)::duplicate",
                            source: skill.source,
                            directoryURL: skill.directoryURL
                        )
                        var updatedExisting = existing
                        updatedExisting = InstalledSkill(
                            id: existing.id,
                            name: existing.name,
                            descriptionText: existing.descriptionText,
                            source: existing.source,
                            directoryURL: existing.directoryURL,
                            skillFileURL: existing.skillFileURL,
                            body: existing.body,
                            headings: existing.headings,
                            relativeReferences: existing.relativeReferences,
                            relatedContextFiles: existing.relatedContextFiles,
                            lastModifiedAt: existing.lastModifiedAt,
                            shadowedLocations: existing.shadowedLocations + [duplicate]
                        )
                        winningSkills[skill.name] = updatedExisting
                    } else {
                        winningSkills[skill.name] = skill
                    }
                } catch {
                    issues.append(
                        InstalledSkillIssue(
                            id: "\(root.source.rawValue)::\(candidateDirectory.path())",
                            source: root.source,
                            directoryURL: candidateDirectory,
                            skillFileURL: skillFileURL,
                            message: error.localizedDescription
                        )
                    )
                }
            }
        }

        return InstalledSkillCatalog(
            skills: winningSkills.values.sorted {
                $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending
            },
            issues: issues.sorted {
                $0.directoryURL.path().localizedCaseInsensitiveCompare($1.directoryURL.path()) == .orderedAscending
            },
            scannedRoots: roots
        )
    }

    func resolveSkill(named requestedName: String, workspaceRoot: URL? = InstalledSkillLoader.defaultWorkspaceRoot()) throws -> InstalledSkill {
        let normalizedName = requestedName.trimmingCharacters(in: .whitespacesAndNewlines)
        let catalog = loadCatalog(workspaceRoot: workspaceRoot)

        guard !normalizedName.isEmpty else {
            throw InstalledSkillLoaderError.skillNotFound(requestedName)
        }

        if let skill = catalog.skills.first(where: {
            $0.name.compare(normalizedName, options: [.caseInsensitive, .diacriticInsensitive]) == .orderedSame
        }) {
            return skill
        }

        throw InstalledSkillLoaderError.skillNotFound(requestedName)
    }

    static func defaultWorkspaceRoot() -> URL? {
        let currentPath = FileManager.default.currentDirectoryPath
        guard !currentPath.isEmpty else { return nil }
        return URL(fileURLWithPath: currentPath, isDirectory: true)
    }

    private func makeRoots(workspaceRoot: URL?) -> [InstalledSkillRoot] {
        var roots: [InstalledSkillRoot] = []

        if let workspaceRoot {
            roots.append(
                InstalledSkillRoot(
                    source: .workspaceCodex,
                    directoryURL: workspaceRoot.appendingPathComponent(".codex/skills", isDirectory: true)
                )
            )
            roots.append(
                InstalledSkillRoot(
                    source: .workspaceClaude,
                    directoryURL: workspaceRoot.appendingPathComponent(".claude/skills", isDirectory: true)
                )
            )
        }

        roots.append(
            InstalledSkillRoot(
                source: .codellamaConfig,
                directoryURL: homeDirectory.appendingPathComponent(".config/codellama/skills", isDirectory: true)
            )
        )
        roots.append(
            InstalledSkillRoot(
                source: .homeCodex,
                directoryURL: homeDirectory.appendingPathComponent(".codex/skills", isDirectory: true)
            )
        )
        roots.append(
            InstalledSkillRoot(
                source: .homeClaude,
                directoryURL: homeDirectory.appendingPathComponent(".claude/skills", isDirectory: true)
            )
        )
        roots.append(
            InstalledSkillRoot(
                source: .homeAgents,
                directoryURL: homeDirectory.appendingPathComponent(".agents/skills", isDirectory: true)
            )
        )

        return roots
    }

    private func ensureCanonicalRootExists(in roots: [InstalledSkillRoot]) {
        guard let canonicalRoot = roots.first(where: { $0.source == .codellamaConfig }) else { return }
        try? fileManager.createDirectory(at: canonicalRoot.directoryURL, withIntermediateDirectories: true)
    }

    private func candidateSkillDirectories(in rootDirectory: URL) -> [URL] {
        guard let enumerator = fileManager.enumerator(
            at: rootDirectory,
            includingPropertiesForKeys: [.isDirectoryKey, .isRegularFileKey],
            options: [.skipsHiddenFiles, .skipsPackageDescendants]
        ) else {
            return []
        }

        var directories: [URL] = []
        for case let fileURL as URL in enumerator {
            if fileURL.lastPathComponent == "SKILL.md" {
                directories.append(fileURL.deletingLastPathComponent())
                enumerator.skipDescendants()
            }
        }
        return directories
    }

    private func parseSkill(at directoryURL: URL, skillFileURL: URL, source: InstalledSkillSource) throws -> InstalledSkill {
        let rawContents = try String(contentsOf: skillFileURL, encoding: .utf8)
        let split = try splitFrontmatter(from: rawContents)
        let metadata = try parseMetadata(from: split.frontmatter)

        let trimmedBody = split.body.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedBody.isEmpty else {
            throw InstalledSkillLoaderError.emptyBody(skillFileURL.lastPathComponent)
        }

        _ = Document(parsing: trimmedBody)

        let relatedFiles = loadRelatedFiles(from: trimmedBody, relativeTo: directoryURL)
        let skillID = "\(source.rawValue)::\(directoryURL.standardizedFileURL.path())"
        let modificationDate = (try? skillFileURL.resourceValues(forKeys: [.contentModificationDateKey]))?.contentModificationDate

        return InstalledSkill(
            id: skillID,
            name: metadata.name,
            descriptionText: metadata.description,
            source: source,
            directoryURL: directoryURL,
            skillFileURL: skillFileURL,
            body: trimmedBody,
            headings: extractHeadings(from: trimmedBody),
            relativeReferences: extractReferences(from: trimmedBody, relativeTo: directoryURL),
            relatedContextFiles: relatedFiles,
            lastModifiedAt: modificationDate,
            shadowedLocations: []
        )
    }

    private func splitFrontmatter(from contents: String) throws -> (frontmatter: String, body: String) {
        let normalized = contents.replacingOccurrences(of: "\r\n", with: "\n")
        guard normalized.hasPrefix("---\n") else {
            throw InstalledSkillLoaderError.missingFrontmatter
        }

        let remainder = normalized.dropFirst(4)
        guard let closingRange = remainder.range(of: "\n---\n") else {
            throw InstalledSkillLoaderError.unterminatedFrontmatter
        }

        let frontmatter = String(remainder[..<closingRange.lowerBound])
        let bodyStart = closingRange.upperBound
        let body = String(remainder[bodyStart...])
        return (frontmatter, body)
    }

    private func parseMetadata(from frontmatter: String) throws -> (name: String, description: String) {
        guard let object = try Yams.load(yaml: frontmatter) else {
            throw InstalledSkillLoaderError.invalidFrontmatter("Frontmatter is empty.")
        }

        guard let dictionary = object as? [String: Any] else {
            throw InstalledSkillLoaderError.invalidFrontmatter("Frontmatter must decode to a dictionary.")
        }

        guard let rawName = dictionary["name"] as? String else {
            throw InstalledSkillLoaderError.invalidFrontmatter("Missing required 'name' field.")
        }

        let name = rawName.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !name.isEmpty else {
            throw InstalledSkillLoaderError.invalidFrontmatter("'name' cannot be empty.")
        }

        let description = (dictionary["description"] as? String)?
            .trimmingCharacters(in: .whitespacesAndNewlines) ?? ""

        return (name, description)
    }

    private func extractHeadings(from body: String) -> [String] {
        body
            .split(separator: "\n")
            .compactMap { line -> String? in
                let trimmed = line.trimmingCharacters(in: .whitespacesAndNewlines)
                guard trimmed.hasPrefix("#") else { return nil }
                return trimmed.trimmingCharacters(in: CharacterSet(charactersIn: "# ")).trimmingCharacters(in: .whitespacesAndNewlines)
            }
            .filter { !$0.isEmpty }
    }

    private func extractReferences(from body: String, relativeTo directoryURL: URL) -> [InstalledSkillReference] {
        let destinations = body.matches(of: /\[[^\]]+\]\(([^)]+)\)/).compactMap { match in
            String(match.1)
        }

        return destinations.map { destination in
            let resolvedURL = resolveRelativeReference(destination, relativeTo: directoryURL)
            return InstalledSkillReference(destination: destination, resolvedURL: resolvedURL)
        }
    }

    private func loadRelatedFiles(from body: String, relativeTo directoryURL: URL) -> [InstalledSkillContextFile] {
        extractReferences(from: body, relativeTo: directoryURL)
            .compactMap { reference in
                guard let resolvedURL = reference.resolvedURL else { return nil }
                guard fileManager.fileExists(atPath: resolvedURL.path()) else { return nil }
                guard let data = try? Data(contentsOf: resolvedURL),
                      let contents = String(data: data, encoding: .utf8) else {
                    return nil
                }

                let trimmed = contents.trimmingCharacters(in: .whitespacesAndNewlines)
                guard !trimmed.isEmpty else { return nil }

                let clamped = trimmed.count > maxRelatedContextLength
                    ? String(trimmed.prefix(maxRelatedContextLength)) + "\n\n[Truncated]"
                    : trimmed

                return InstalledSkillContextFile(
                    relativePath: reference.destination,
                    resolvedURL: resolvedURL,
                    content: clamped
                )
            }
    }

    private func resolveRelativeReference(_ destination: String, relativeTo directoryURL: URL) -> URL? {
        guard !destination.contains("://"), !destination.hasPrefix("#") else { return nil }
        return directoryURL.appendingPathComponent(destination).standardizedFileURL
    }
}

enum InstalledSkillLoaderError: LocalizedError {
    case missingFrontmatter
    case unterminatedFrontmatter
    case invalidFrontmatter(String)
    case emptyBody(String)
    case skillNotFound(String)

    var errorDescription: String? {
        switch self {
        case .missingFrontmatter:
            return "Missing YAML frontmatter header."
        case .unterminatedFrontmatter:
            return "Unterminated YAML frontmatter block."
        case .invalidFrontmatter(let message):
            return message
        case .emptyBody(let fileName):
            return "\(fileName) does not include any instructions."
        case .skillNotFound(let name):
            return "Could not find an installed skill named '\(name)'."
        }
    }
}
