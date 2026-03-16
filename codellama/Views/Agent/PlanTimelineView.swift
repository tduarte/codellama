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
    var isRunning: Bool = false
    var onApprove: () -> Void
    var onCancel: () -> Void
    var onClose: () -> Void

    var body: some View {
        VStack(spacing: 0) {

            // MARK: Header
            VStack(alignment: .leading, spacing: 8) {
                HStack(alignment: .firstTextBaseline) {
                    Text(title)
                        .font(.title2)
                        .bold()

                    if isRunning {
                        ProgressView()
                            .controlSize(.small)
                            .padding(.leading, 4)
                    }
                }

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
                if task.phase == .architecting || task.phase == .planning || task.phase == .executing {
                    ProgressView()
                        .scaleEffect(0.8)
                    Text(statusText)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                } else {
                    Text(statusText)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                Spacer()

                if task.phase == .awaitingApproval {
                    Button("Cancel", role: .cancel, action: onCancel)

                    Button("Approve & Run") {
                        onApprove()
                    }
                    .buttonStyle(.borderedProminent)
                    .disabled(task.plan?.steps.isEmpty ?? true)
                } else if task.phase == .executing || task.phase == .planning || task.phase == .architecting {
                    Button("Stop", role: .destructive, action: onCancel)
                } else {
                    Button("Close", action: onClose)
                }
            }
            .padding()
        }
    }

    private var title: String {
        switch task.phase {
        case .architecting, .planning:
            return "Generating Plan"
        case .awaitingApproval:
            return "Review Plan"
        case .executing:
            return "Executing Plan"
        case .completed:
            return "Plan Complete"
        case .failed:
            return "Plan Failed"
        case .cancelled:
            return "Plan Cancelled"
        }
    }

    private var statusText: String {
        switch task.phase {
        case .architecting:
            return "Collecting context…"
        case .planning:
            return "Asking the model to build a plan…"
        case .awaitingApproval:
            return "Waiting for approval"
        case .executing:
            return "Executing…"
        case .completed:
            return "Completed"
        case .failed:
            return "Finished with errors"
        case .cancelled:
            return "Cancelled"
        }
    }
}
