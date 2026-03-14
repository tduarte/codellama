//
//  PlanTimelineView.swift
//  codellama
//
//  Created by Thiago Duarte on 3/14/26.
//

import SwiftUI

/// Review-first UI that shows the full execution plan before any tools run.
///
/// The user can inspect each step, then approve or cancel the plan.
struct PlanTimelineView: View {

    let task: AgentTask
    var onApprove: () -> Void
    var onCancel: () -> Void

    var body: some View {
        VStack(spacing: 0) {

            // MARK: Header
            VStack(alignment: .leading, spacing: 8) {
                Text("Review Plan")
                    .font(.title2)
                    .bold()

                Text(task.prompt)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .lineLimit(3)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding()

            Divider()

            // MARK: Steps
            if let plan = task.plan {
                if plan.steps.isEmpty {
                    ContentUnavailableView(
                        "No Steps",
                        systemImage: "square.stack.3d.up.slash",
                        description: Text("The model did not generate any tool calls for this prompt.")
                    )
                    .frame(maxHeight: .infinity)
                } else {
                    ScrollView {
                        LazyVStack(alignment: .leading, spacing: 0) {
                            ForEach(plan.steps) { step in
                                PlanStepRow(step: step)
                                    .padding(.horizontal)

                                if step.id != plan.steps.last?.id {
                                    Divider()
                                        .padding(.horizontal)
                                }
                            }
                        }
                        .padding(.vertical, 8)
                    }
                }
            } else {
                ProgressView("Generating plan…")
                    .frame(maxHeight: .infinity)
            }

            Divider()

            // MARK: Footer
            HStack {
                if task.phase == .executing {
                    ProgressView()
                        .scaleEffect(0.8)
                    Text("Executing…")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                Spacer()

                Button("Cancel", role: .cancel, action: onCancel)
                    .disabled(task.phase == .executing)

                Button("Approve & Run") {
                    onApprove()
                }
                .buttonStyle(.borderedProminent)
                .disabled(task.phase != .awaitingApproval || (task.plan?.steps.isEmpty ?? true))
            }
            .padding()
        }
    }
}
