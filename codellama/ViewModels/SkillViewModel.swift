import Foundation

@MainActor
@Observable
final class SkillViewModel {
    private let loader: InstalledSkillLoader

    var skills: [InstalledSkill] = []
    var issues: [InstalledSkillIssue] = []
    var scannedRoots: [InstalledSkillRoot] = []
    var selectedSkillID: InstalledSkill.ID?
    var error: String?

    init(loader: InstalledSkillLoader = InstalledSkillLoader()) {
        self.loader = loader
    }

    var selectedSkill: InstalledSkill? {
        guard let selectedSkillID else { return skills.first }
        return skills.first(where: { $0.id == selectedSkillID }) ?? skills.first
    }

    func fetchSkills() {
        let catalog = loader.loadCatalog()
        skills = catalog.skills
        issues = catalog.issues
        scannedRoots = catalog.scannedRoots

        if let selectedSkillID,
           !skills.contains(where: { $0.id == selectedSkillID }) {
            self.selectedSkillID = skills.first?.id
        } else if self.selectedSkillID == nil {
            self.selectedSkillID = skills.first?.id
        }

        error = nil
    }

    func refreshSkills() {
        fetchSkills()
    }

    func selectSkill(_ skill: InstalledSkill?) {
        selectedSkillID = skill?.id
    }
}
