//
//  SkillInspectorView.swift
//  codellama
//

import SwiftUI
import SwiftData

struct SkillInspectorView: View {
    @Bindable var skillViewModel: SkillViewModel

    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                if skillViewModel.selectedSkill != nil {
                    Button {
                        skillViewModel.selectedSkill = nil
                    } label: {
                        Label("Back", systemImage: "chevron.left")
                            .labelStyle(.iconOnly)
                    }
                    .buttonStyle(.borderless)
                }

                Text("Skills")
                    .font(.headline)

                Spacer()

                Button {
                    skillViewModel.createSkill()
                } label: {
                    Label("New Skill", systemImage: "plus")
                        .labelStyle(.iconOnly)
                }
                .buttonStyle(.borderless)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)

            Divider()

            // Content
            if let skill = skillViewModel.selectedSkill {
                SkillComposerView(skill: skill, skillViewModel: skillViewModel)
            } else {
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

            // Footer
            if !skillViewModel.skills.isEmpty {
                Divider()
                HStack {
                    Spacer()
                    Button(role: .destructive) {
                        if let selectedSkill = skillViewModel.selectedSkill {
                            skillViewModel.deleteSkill(selectedSkill)
                        }
                    } label: {
                        Label("Delete Skill", systemImage: "trash")
                    }
                    .disabled(skillViewModel.selectedSkill == nil)
                    Spacer()
                }
                .padding(.vertical, 8)
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
