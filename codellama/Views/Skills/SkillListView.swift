//
//  SkillListView.swift
//  codellama
//
//  Created by Codex on 3/14/26.
//

import SwiftUI

struct SkillListView: View {
    @Bindable var skillViewModel: SkillViewModel
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationSplitView {
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
            .navigationTitle("Skills")
            .toolbar {
                ToolbarItemGroup(placement: .primaryAction) {
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

                    Button("Done") {
                        dismiss()
                    }
                }
            }
        } detail: {
            if let skill = skillViewModel.selectedSkill {
                SkillComposerView(skill: skill, skillViewModel: skillViewModel)
            } else {
                ContentUnavailableView(
                    "No Skill Selected",
                    systemImage: "wand.and.stars",
                    description: Text("Create a skill to save a reusable MCP tool sequence.")
                )
            }
        }
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
