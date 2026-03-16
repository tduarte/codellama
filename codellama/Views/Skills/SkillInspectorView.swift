import SwiftUI

struct SkillInspectorView: View {
    @Bindable var skillViewModel: SkillViewModel

    var body: some View {
        SkillListView(
            skillViewModel: skillViewModel,
            layoutStyle: .horizontal,
            showsDetailPane: false
        )
    }
}
