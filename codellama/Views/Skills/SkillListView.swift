import SwiftUI

struct SkillListView: View {
    enum LayoutStyle {
        case horizontal
        case vertical
    }

    @Bindable var skillViewModel: SkillViewModel
    var isSettingsContext: Bool = false
    var layoutStyle: LayoutStyle = .horizontal
    var showsDetailPane: Bool = true
    var onDismiss: (() -> Void)? = nil

    var body: some View {
        Group {
            if showsDetailPane {
                switch layoutStyle {
                case .horizontal:
                    HStack(spacing: 0) {
                        sidebarPane
                        Divider()
                        detailPane
                    }

                case .vertical:
                    VSplitView {
                        sidebarPane
                            .frame(minHeight: 220, idealHeight: 280, maxHeight: 360)
                        detailPane
                    }
                }
            } else {
                sidebarPane
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
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
            HStack {
                Text("Skills")
                    .font(.title2.weight(.semibold))
                Spacer()
                Button {
                    skillViewModel.refreshSkills()
                } label: {
                    Label("Refresh", systemImage: "arrow.clockwise")
                }
                .modifier(RefreshButtonStyle(isProminent: isSettingsContext))

                if let onDismiss {
                    Button {
                        onDismiss()
                    } label: {
                        Image(systemName: "xmark")
                    }
                    .buttonStyle(.borderless)
                    .help("Close")
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)

            Divider()

            ZStack {
                List(selection: selectionBinding) {
                    if !skillViewModel.skills.isEmpty {
                        Section("Installed") {
                            ForEach(skillViewModel.skills) { skill in
                                VStack(alignment: .leading, spacing: 4) {
                                    Text(skill.name)
                                        .font(.headline)

                                    Text(skill.descriptionText.isEmpty ? skill.sourceLabel : skill.descriptionText)
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                        .lineLimit(2)
                                }
                                .padding(.vertical, 4)
                                .tag(skill.id)
                            }
                        }
                    }

                    if !skillViewModel.issues.isEmpty {
                        Section("Issues") {
                            ForEach(skillViewModel.issues) { issue in
                                VStack(alignment: .leading, spacing: 4) {
                                    Text(issue.directoryURL.lastPathComponent)
                                        .font(.headline)

                                    Text(issue.message)
                                        .font(.caption)
                                        .foregroundStyle(.red)
                                        .lineLimit(3)
                                }
                                .padding(.vertical, 4)
                            }
                        }
                    }
                }
                .listStyle(.sidebar)

                if skillViewModel.skills.isEmpty && skillViewModel.issues.isEmpty {
                    ContentUnavailableView(
                        "No Skills Found",
                        systemImage: "wand.and.rays",
                        description: Text("Add shared SKILL.md skills to one of the scanned roots, then refresh.")
                    )
                }
            }
        }
        .frame(minWidth: 320, idealWidth: 340)
        .background(.regularMaterial)
    }

    @ViewBuilder
    private var detailPane: some View {
        if let selectedSkill = skillViewModel.selectedSkill {
            SkillDetailView(skill: selectedSkill)
        } else {
            VStack(alignment: .leading, spacing: 16) {
                ContentUnavailableView {
                    Label("No Skill Selected", systemImage: "wand.and.stars")
                } description: {
                    Text("Select an installed skill to inspect its metadata and instructions.")
                }

                scannedRootsSection
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
            .padding(24)
        }
    }

    private var scannedRootsSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Scanned Roots")
                .font(.headline)

            ForEach(skillViewModel.scannedRoots) { root in
                VStack(alignment: .leading, spacing: 2) {
                    Text(root.source.label)
                    Text(root.directoryURL.path())
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .textSelection(.enabled)
                }
            }
        }
    }

    private var selectionBinding: Binding<String?> {
        Binding(
            get: { skillViewModel.selectedSkillID },
            set: { skillViewModel.selectedSkillID = $0 }
        )
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

private struct RefreshButtonStyle: ViewModifier {
    let isProminent: Bool

    @ViewBuilder
    func body(content: Content) -> some View {
        if isProminent {
            content.buttonStyle(.borderedProminent)
        } else {
            content.buttonStyle(.bordered)
        }
    }
}

private struct SkillDetailView: View {
    let skill: InstalledSkill

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                header
                metadataSection

                if !skill.shadowedLocations.isEmpty {
                    duplicatesSection
                }

                if !skill.relatedContextFiles.isEmpty {
                    relatedContextSection
                }

                instructionsSection
            }
            .padding(24)
        }
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(skill.name)
                .font(.title2.weight(.semibold))

            Text(skill.descriptionText.isEmpty ? "No description provided." : skill.descriptionText)
                .foregroundStyle(.secondary)
        }
    }

    private var metadataSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Metadata")
                .font(.headline)

            metadataRow("Source", value: skill.sourceLabel)
            metadataRow("Directory", value: skill.directoryURL.path())
            metadataRow("Skill File", value: skill.skillFileURL.path())

            if let lastModifiedAt = skill.lastModifiedAt {
                metadataRow("Last Modified", value: lastModifiedAt.formatted(date: .abbreviated, time: .shortened))
            }

            if !skill.headings.isEmpty {
                metadataRow("Headings", value: skill.headings.joined(separator: " • "))
            }
        }
    }

    private var duplicatesSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Shadowed Duplicates")
                .font(.headline)

            ForEach(skill.shadowedLocations) { duplicate in
                VStack(alignment: .leading, spacing: 2) {
                    Text(duplicate.sourceLabel)
                    Text(duplicate.directoryURL.path())
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .textSelection(.enabled)
                }
            }
        }
    }

    private var relatedContextSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Referenced Context")
                .font(.headline)

            ForEach(skill.relatedContextFiles, id: \.relativePath) { file in
                VStack(alignment: .leading, spacing: 6) {
                    Text(file.relativePath)
                        .font(.subheadline.weight(.semibold))

                    Text(file.content)
                        .font(.system(.caption, design: .monospaced))
                        .textSelection(.enabled)
                        .padding(10)
                        .background(
                            RoundedRectangle(cornerRadius: 10)
                                .fill(.fill.quaternary)
                        )
                }
            }
        }
    }

    private var instructionsSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Instructions")
                .font(.headline)

            Text(skill.body)
                .font(.body)
                .textSelection(.enabled)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(12)
                .background(
                    RoundedRectangle(cornerRadius: 12)
                        .fill(.fill.quaternary)
                )
        }
    }

    private func metadataRow(_ label: String, value: String) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(label)
                .font(.caption.weight(.semibold))
                .foregroundStyle(.secondary)
            Text(value)
                .textSelection(.enabled)
        }
    }
}
