//
//  SkillComposerView.swift
//  codellama
//
//  Created by Codex on 3/14/26.
//

import SwiftUI
import SwiftData

struct SkillComposerView: View {
    let skill: Skill

    @Bindable var skillViewModel: SkillViewModel
    @Environment(AppState.self) private var appState

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                header
                metadataSection
                availableToolsSection
                sequenceSection
            }
            .padding(24)
        }
        .navigationTitle(skill.name)
        .navigationSubtitle("Saved MCP workflow")
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Invocation")
                .font(.headline)

            Text("Run this saved sequence in agent mode with `/skill \(skill.name)`.")
                .foregroundStyle(.secondary)

            if skill.toolSequence.isEmpty {
                Label("Add at least one tool to make this skill executable.", systemImage: "exclamationmark.triangle")
                    .foregroundStyle(.orange)
            }
        }
    }

    private var metadataSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Details")
                .font(.headline)

            TextField(
                "Skill name",
                text: Binding(
                    get: { skill.name },
                    set: { newValue in
                        skill.name = newValue
                        skillViewModel.saveSkill(skill)
                    }
                )
            )
            .textFieldStyle(.roundedBorder)

            TextEditor(text: Binding(
                get: { skill.descriptionText },
                set: { newValue in
                    skill.descriptionText = newValue
                    skillViewModel.saveSkill(skill)
                }
            ))
            .font(.body)
            .frame(minHeight: 90)
            .scrollContentBackground(.hidden)
            .padding(8)
            .background(
                RoundedRectangle(cornerRadius: 10)
                    .fill(.background)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 10)
                    .stroke(.quaternary, lineWidth: 1)
            )
        }
    }

    private var availableToolsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Available Tools")
                    .font(.headline)

                Spacer()

                Text("\(appState.mcpHost.allMCPTools.count) connected")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            if appState.mcpHost.allMCPTools.isEmpty {
                ContentUnavailableView(
                    "No MCP Tools Connected",
                    systemImage: "server.rack",
                    description: Text("Connect an MCP server in Settings to compose reusable skills.")
                )
            } else {
                VStack(spacing: 10) {
                    ForEach(appState.mcpHost.allMCPTools) { tool in
                        HStack(alignment: .top) {
                            VStack(alignment: .leading, spacing: 4) {
                                Text("\(tool.serverName).__\(tool.toolName)")
                                    .font(.system(.body, design: .monospaced))

                                Text(tool.description.isEmpty ? "No description provided." : tool.description)
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }

                            Spacer()

                            Button("Add") {
                                skillViewModel.addTool(tool, to: skill)
                            }
                            .buttonStyle(.bordered)
                        }
                        .padding(12)
                        .background(
                            RoundedRectangle(cornerRadius: 12)
                                .fill(.secondary.opacity(0.08))
                        )
                    }
                }
            }
        }
    }

    private var sequenceSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Tool Sequence")
                .font(.headline)

            if skill.toolSequence.isEmpty {
                ContentUnavailableView(
                    "No Steps Yet",
                    systemImage: "square.stack.3d.down.right",
                    description: Text("Add tools from the list above, then customize each step's JSON arguments.")
                )
            } else {
                VStack(spacing: 12) {
                    ForEach(Array(skill.toolSequence.enumerated()), id: \.element.id) { index, step in
                        StepEditorCard(
                            skill: skill,
                            step: step,
                            index: index,
                            totalCount: skill.toolSequence.count,
                            skillViewModel: skillViewModel
                        )
                    }
                }
            }
        }
    }
}

private struct StepEditorCard: View {
    let skill: Skill
    let step: ToolCall
    let index: Int
    let totalCount: Int

    @Bindable var skillViewModel: SkillViewModel

    @State private var draftArguments: String = "{}"

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Step \(index + 1)")
                        .font(.subheadline.weight(.semibold))
                    Text("\(step.serverName).__\(step.toolName)")
                        .font(.system(.body, design: .monospaced))
                }

                Spacer()

                HStack(spacing: 8) {
                    Button {
                        skillViewModel.moveTool(in: skill, from: index, to: index - 1)
                    } label: {
                        Image(systemName: "arrow.up")
                    }
                    .disabled(index == 0)

                    Button {
                        skillViewModel.moveTool(in: skill, from: index, to: index + 1)
                    } label: {
                        Image(systemName: "arrow.down")
                    }
                    .disabled(index == totalCount - 1)

                    Button(role: .destructive) {
                        skillViewModel.removeTool(at: index, from: skill)
                    } label: {
                        Image(systemName: "trash")
                    }
                }
                .buttonStyle(.borderless)
            }

            TextEditor(text: $draftArguments)
                .font(.system(.body, design: .monospaced))
                .frame(minHeight: 110)
                .scrollContentBackground(.hidden)
                .padding(8)
                .background(
                    RoundedRectangle(cornerRadius: 10)
                        .fill(.background)
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 10)
                        .stroke(.quaternary, lineWidth: 1)
                )

            HStack {
                Spacer()

                Button("Apply Arguments") {
                    do {
                        try skillViewModel.updateArguments(for: skill, stepID: step.id, jsonString: draftArguments)
                    } catch {
                        skillViewModel.error = error.localizedDescription
                    }
                }
                .buttonStyle(.borderedProminent)
            }
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 14)
                .fill(.secondary.opacity(0.08))
        )
        .onAppear {
            draftArguments = skillViewModel.prettyArguments(for: step)
        }
        .onChange(of: step.arguments) {
            draftArguments = skillViewModel.prettyArguments(for: step)
        }
    }
}

#Preview {
    let config = ModelConfiguration(isStoredInMemoryOnly: true)
    let container = try! ModelContainer(for: Skill.self, configurations: config)

    let skill = Skill(
        name: "Refactor Function",
        descriptionText: "Reads a Swift source file and rewrites a named function with improved clarity and style.",
        toolSequence: [
            ToolCall(id: "c1", serverName: "filesystem", toolName: "read_file",
                     arguments: ["path": .string("/tmp/MyView.swift")]),
            ToolCall(id: "c2", serverName: "filesystem", toolName: "write_file",
                     arguments: ["path": .string("/tmp/MyView.swift"), "content": .string("")])
        ]
    )
    container.mainContext.insert(skill)

    let skillViewModel = SkillViewModel(modelContext: container.mainContext)
    skillViewModel.selectedSkill = skill

    return SkillComposerView(skill: skill, skillViewModel: skillViewModel)
        .environment(AppState())
        .modelContainer(container)
        .frame(width: 600, height: 680)
}
