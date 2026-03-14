//
//  SkillViewModel.swift
//  codellama
//
//  Created by Codex on 3/14/26.
//

import Foundation
import SwiftData

@MainActor
@Observable
final class SkillViewModel {
    var skills: [Skill] = []
    var selectedSkill: Skill?
    var error: String?

    private let modelContext: ModelContext

    init(modelContext: ModelContext) {
        self.modelContext = modelContext
    }

    func fetchSkills() {
        let descriptor = FetchDescriptor<Skill>(sortBy: [
            SortDescriptor(\Skill.updatedAt, order: .reverse),
            SortDescriptor(\Skill.createdAt, order: .reverse)
        ])

        do {
            skills = try modelContext.fetch(descriptor)
            if selectedSkill == nil {
                selectedSkill = skills.first
            } else if let selectedSkill,
                      !skills.contains(where: { $0.id == selectedSkill.id }) {
                self.selectedSkill = skills.first
            }
        } catch {
            self.error = "Failed to fetch skills: \(error.localizedDescription)"
        }
    }

    @discardableResult
    func createSkill() -> Skill {
        let baseName = "New Skill"
        let existingNames = Set(skills.map(\.name))
        var candidate = baseName
        var suffix = 2

        while existingNames.contains(candidate) {
            candidate = "\(baseName) \(suffix)"
            suffix += 1
        }

        let skill = Skill(name: candidate)
        skill.updatedAt = .now
        modelContext.insert(skill)
        persistChanges(selecting: skill)
        return skill
    }

    func deleteSkill(_ skill: Skill) {
        let deletedID = skill.id
        modelContext.delete(skill)
        persistChanges()

        if selectedSkill?.id == deletedID {
            selectedSkill = skills.first
        }
    }

    func saveSkill(_ skill: Skill) {
        skill.updatedAt = .now
        persistChanges(selecting: skill)
    }

    func addTool(_ tool: MCPToolInfo, to skill: Skill) {
        var sequence = skill.toolSequence
        sequence.append(
            ToolCall(
                id: UUID().uuidString,
                serverName: tool.serverName,
                toolName: tool.toolName,
                arguments: defaultArguments(for: tool.inputSchema)
            )
        )
        skill.toolSequence = sequence
        saveSkill(skill)
    }

    func removeTool(at index: Int, from skill: Skill) {
        var sequence = skill.toolSequence
        guard sequence.indices.contains(index) else { return }
        sequence.remove(at: index)
        skill.toolSequence = sequence
        saveSkill(skill)
    }

    func moveTool(in skill: Skill, from index: Int, to newIndex: Int) {
        var sequence = skill.toolSequence
        guard sequence.indices.contains(index),
              sequence.indices.contains(newIndex) || newIndex == sequence.count else { return }

        let tool = sequence.remove(at: index)
        sequence.insert(tool, at: newIndex)
        skill.toolSequence = sequence
        saveSkill(skill)
    }

    func updateArguments(for skill: Skill, stepID: String, jsonString: String) throws {
        let trimmed = jsonString.trimmingCharacters(in: .whitespacesAndNewlines)
        let rawData = Data((trimmed.isEmpty ? "{}" : trimmed).utf8)
        let object = try JSONSerialization.jsonObject(with: rawData)
        guard let dictionary = object as? [String: Any] else {
            throw SkillEditingError.argumentsMustBeJSONObject
        }

        let arguments = try dictionary.mapValues(JSONValue.fromFoundationObject)
        var sequence = skill.toolSequence
        guard let index = sequence.firstIndex(where: { $0.id == stepID }) else { return }

        let old = sequence[index]
        sequence[index] = ToolCall(
            id: old.id,
            serverName: old.serverName,
            toolName: old.toolName,
            arguments: arguments
        )
        skill.toolSequence = sequence
        saveSkill(skill)
    }

    func prettyArguments(for toolCall: ToolCall) -> String {
        guard !toolCall.arguments.isEmpty else { return "{}" }
        let object = toolCall.arguments.mapValues { $0.foundationObject() }
        guard let data = try? JSONSerialization.data(withJSONObject: object, options: [.prettyPrinted, .sortedKeys]),
              let string = String(data: data, encoding: .utf8) else {
            return "{}"
        }
        return string
    }

    private func persistChanges(selecting skill: Skill? = nil) {
        do {
            try modelContext.save()
            fetchSkills()
            if let skill {
                selectedSkill = skills.first(where: { $0.id == skill.id }) ?? skill
            }
            error = nil
        } catch {
            self.error = "Failed to save skills: \(error.localizedDescription)"
        }
    }

    private func defaultArguments(for schema: JSONValue?) -> [String: JSONValue] {
        guard case .object(let schemaObject) = schema,
              case .object(let properties)? = schemaObject["properties"] else {
            return [:]
        }

        return properties.reduce(into: [String: JSONValue]()) { partialResult, pair in
            let propertySchema = pair.value
            partialResult[pair.key] = placeholderValue(for: propertySchema)
        }
    }

    private func placeholderValue(for schema: JSONValue) -> JSONValue {
        guard case .object(let schemaObject) = schema,
              case .string(let type)? = schemaObject["type"] else {
            return .string("")
        }

        switch type {
        case "boolean":
            return .bool(false)
        case "integer", "number":
            return .number(0)
        case "array":
            return .array([])
        case "object":
            return .object([:])
        default:
            return .string("")
        }
    }
}

enum SkillEditingError: LocalizedError {
    case argumentsMustBeJSONObject

    var errorDescription: String? {
        switch self {
        case .argumentsMustBeJSONObject:
            return "Tool arguments must be a JSON object."
        }
    }
}
