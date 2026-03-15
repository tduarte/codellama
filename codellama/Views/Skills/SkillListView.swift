//
//  SkillListView.swift
//  codellama
//
//  Created by Codex on 3/14/26.
//

import SwiftUI
import SwiftData

struct SkillListView: View {
    @Bindable var skillViewModel: SkillViewModel
    var isSettingsContext: Bool = false

    var body: some View {
        Group {
            if isSettingsContext {
                HStack(spacing: 0) {
                    sidebarPane
                    Divider()
                    detailPane
                }
            } else {
                NavigationSplitView {
                    sidebarPane
                } detail: {
                    detailPane
                }
                .navigationSplitViewColumnWidth(min: 280, ideal: 340)
            }
        }
        .controlSize(.small)
        .environment(\.defaultMinListRowHeight, 30)
        .onAppear {
            skillViewModel.fetchSkills()
        }
        .alert("Skills Error", isPresented: errorBinding) {
            Button("OK") {
                skillViewModel.error = nil
            }
        } message: {
            Text(skillViewModel.error ?? "Unknown error")
        }
    }

    private var sidebarPane: some View {
        VStack(spacing: 0) {
            VStack(alignment: .leading, spacing: 8) {
                HStack(alignment: .center) {
                    Text("Skills")
                        .font(.headline)
                    Spacer()

                    if isSettingsContext {
                        Button {
                            skillViewModel.createSkill()
                        } label: {
                            Label("Create Skill", systemImage: "plus")
                        }
                        .buttonStyle(.borderedProminent)
                    } else {
                        Button {
                            skillViewModel.createSkill()
                        } label: {
                            Label("New Skill", systemImage: "plus")
                        }

                        Button(role: .destructive) {
                            if let selectedSkill = skillViewModel.selectedSkill {
                                skillViewModel.deleteSkill(selectedSkill)
                            }
                        } label: {
                            Label("Delete Skill", systemImage: "trash")
                        }
                        .disabled(skillViewModel.selectedSkill == nil)
                    }
                }

                Text("Create reusable MCP tool sequences for faster agent workflows.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            .padding(.horizontal, 16)
            .padding(.top, 14)
            .padding(.bottom, 10)

            Divider()

            ZStack {
                List(selection: $skillViewModel.selectedSkill) {
                    ForEach(skillViewModel.skills) { skill in
                        VStack(alignment: .leading, spacing: 4) {
                            Text(skill.name)
                                .font(.headline)

                            Text(skill.descriptionText.isEmpty ? "No description" : skill.descriptionText)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                                .lineLimit(2)
                        }
                        .padding(.vertical, 4)
                        .tag(skill)
                        .contextMenu {
                            Button(role: .destructive) {
                                skillViewModel.deleteSkill(skill)
                            } label: {
                                Label("Delete", systemImage: "trash")
                            }
                        }
                    }
                    .onDelete { offsets in
                        for offset in offsets {
                            skillViewModel.deleteSkill(skillViewModel.skills[offset])
                        }
                    }
                }
                .listStyle(.sidebar)

                if skillViewModel.skills.isEmpty {
                    ContentUnavailableView(
                        "No Skills Yet",
                        systemImage: "wand.and.rays",
                        description: Text("Create a reusable workflow, then select it to edit details.")
                    )
                }
            }
        }
        .frame(minWidth: 300, idealWidth: 320)
        .background(.regularMaterial)
        .overlay(alignment: .trailing) {
            Rectangle()
                .fill(.quaternary.opacity(0.7))
                .frame(width: 1)
        }
    }

    @ViewBuilder
    private var detailPane: some View {
        if let skill = skillViewModel.selectedSkill {
            SkillComposerView(skill: skill, skillViewModel: skillViewModel)
        } else {
            ContentUnavailableView {
                Label("No Skill Selected", systemImage: "wand.and.stars")
            } description: {
                Text(skillViewModel.skills.isEmpty
                    ? "Create a skill to define a reusable MCP tool sequence."
                    : "Select a skill from the list to edit its steps and prompt.")
            } actions: {
                if skillViewModel.skills.isEmpty {
                    Button("Create Skill") {
                        skillViewModel.createSkill()
                    }
                    .buttonStyle(.borderedProminent)
                } else {
                    Text("Choose an item in the left pane.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
        }
    }

    private var errorBinding: Binding<Bool> {
        Binding(
            get: { skillViewModel.error != nil },
            set: { newValue in
                if !newValue {
                    skillViewModel.error = nil
                }
            }
        )
    }

}

#Preview("Empty") {
    let config = ModelConfiguration(isStoredInMemoryOnly: true)
    let container = try! ModelContainer(for: Skill.self, configurations: config)
    let skillViewModel = SkillViewModel(modelContext: container.mainContext)
    SkillListView(skillViewModel: skillViewModel, isSettingsContext: true)
        .environment(AppState())
        .modelContainer(container)
        .frame(width: 780, height: 480)
}

#Preview("With Skills") {
    let config = ModelConfiguration(isStoredInMemoryOnly: true)
    let container = try! ModelContainer(for: Skill.self, configurations: config)

    let skill1 = Skill(name: "Refactor Function",
                       descriptionText: "Reads a Swift file and rewrites a function with improved clarity.",
                       toolSequence: [
                           ToolCall(id: "c1", serverName: "filesystem", toolName: "read_file",
                                    arguments: ["path": "/tmp/file.swift"])
                       ])
    let skill2 = Skill(name: "Summarize Repo",
                       descriptionText: "Lists files and summarizes the project structure.")
    container.mainContext.insert(skill1)
    container.mainContext.insert(skill2)

    let skillViewModel = SkillViewModel(modelContext: container.mainContext)
    skillViewModel.skills = [skill1, skill2]
    skillViewModel.selectedSkill = skill1

    return SkillListView(skillViewModel: skillViewModel, isSettingsContext: true)
        .environment(AppState())
        .modelContainer(container)
        .frame(width: 780, height: 480)
}
