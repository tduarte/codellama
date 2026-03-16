import XCTest
@testable import codellama

final class InstalledSkillLoaderTests: XCTestCase {
    private var temporaryRootURL: URL!
    private var homeRootURL: URL!
    private var workspaceRootURL: URL!
    private var loader: InstalledSkillLoader!

    override func setUpWithError() throws {
        temporaryRootURL = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
        homeRootURL = temporaryRootURL.appendingPathComponent("home", isDirectory: true)
        workspaceRootURL = temporaryRootURL.appendingPathComponent("workspace", isDirectory: true)

        try FileManager.default.createDirectory(at: homeRootURL, withIntermediateDirectories: true)
        try FileManager.default.createDirectory(at: workspaceRootURL, withIntermediateDirectories: true)

        loader = InstalledSkillLoader(
            fileManager: .default,
            homeDirectory: homeRootURL
        )
    }

    override func tearDownWithError() throws {
        if let temporaryRootURL {
            try? FileManager.default.removeItem(at: temporaryRootURL)
        }
        loader = nil
        workspaceRootURL = nil
        homeRootURL = nil
        temporaryRootURL = nil
    }

    func testLoaderPrefersHigherPriorityRootsAndTracksShadowedDuplicates() throws {
        try writeSkill(
            named: "review",
            sourceRoot: workspaceRootURL.appendingPathComponent(".codex/skills", isDirectory: true),
            description: "Workspace skill"
        )
        try writeSkill(
            named: "review",
            sourceRoot: homeRootURL.appendingPathComponent(".config/codellama/skills", isDirectory: true),
            description: "Config skill"
        )

        let catalog = loader.loadCatalog(workspaceRoot: workspaceRootURL)

        XCTAssertEqual(catalog.skills.count, 1)
        XCTAssertEqual(catalog.skills.first?.name, "review")
        XCTAssertEqual(catalog.skills.first?.source, .workspaceCodex)
        XCTAssertEqual(catalog.skills.first?.shadowedLocations.count, 1)
        XCTAssertEqual(catalog.skills.first?.shadowedLocations.first?.source, .codellamaConfig)
    }

    func testLoaderReportsMalformedSkillWithoutCrashingCatalogLoad() throws {
        let malformedRoot = workspaceRootURL.appendingPathComponent(".claude/skills", isDirectory: true)
        let malformedDirectory = malformedRoot.appendingPathComponent("broken", isDirectory: true)
        try FileManager.default.createDirectory(at: malformedDirectory, withIntermediateDirectories: true)

        let malformedContents = """
        ---
        description: Missing name
        ---

        # Broken
        """
        try malformedContents.write(
            to: malformedDirectory.appendingPathComponent("SKILL.md"),
            atomically: true,
            encoding: .utf8
        )

        let catalog = loader.loadCatalog(workspaceRoot: workspaceRootURL)

        XCTAssertTrue(catalog.skills.isEmpty)
        XCTAssertEqual(catalog.issues.count, 1)
        XCTAssertTrue(catalog.issues[0].message.contains("name"))
    }

    func testResolveSkillReturnsParsedReferencedContextFiles() throws {
        let configRoot = homeRootURL.appendingPathComponent(".config/codellama/skills", isDirectory: true)
        let skillDirectory = configRoot.appendingPathComponent("ship", isDirectory: true)
        try FileManager.default.createDirectory(at: skillDirectory, withIntermediateDirectories: true)
        try "Ship checklist".write(
            to: skillDirectory.appendingPathComponent("checklist.md"),
            atomically: true,
            encoding: .utf8
        )

        let contents = """
        ---
        name: ship
        description: Release workflow
        ---

        # Ship

        Read [checklist](checklist.md) before release.
        """
        try contents.write(
            to: skillDirectory.appendingPathComponent("SKILL.md"),
            atomically: true,
            encoding: .utf8
        )

        let skill = try loader.resolveSkill(named: "ship", workspaceRoot: workspaceRootURL)

        XCTAssertEqual(skill.relatedContextFiles.count, 1)
        XCTAssertEqual(skill.relatedContextFiles.first?.relativePath, "checklist.md")
        XCTAssertEqual(skill.relatedContextFiles.first?.content, "Ship checklist")
    }

    private func writeSkill(
        named name: String,
        sourceRoot: URL,
        description: String
    ) throws {
        let skillDirectory = sourceRoot.appendingPathComponent(name, isDirectory: true)
        try FileManager.default.createDirectory(at: skillDirectory, withIntermediateDirectories: true)

        let contents = """
        ---
        name: \(name)
        description: \(description)
        ---

        # \(name.capitalized)

        Follow the steps carefully.
        """
        try contents.write(
            to: skillDirectory.appendingPathComponent("SKILL.md"),
            atomically: true,
            encoding: .utf8
        )
    }
}
