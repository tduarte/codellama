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
    var onClose: () -> Void

    var body: some View {
        VStack(spacing: 0) {

            // MARK: Header
            VStack(alignment: .leading, spacing: 8) {
                Text(title)
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

private extension PlanTimelineView {
    static func sampleToolCall(id: String = "c1", tool: String = "read_file") -> ToolCall {
        ToolCall(id: id, serverName: "filesystem", toolName: tool, arguments: ["path": "/tmp/file.txt"])
    }
}

#Preview("Awaiting Approval") {
    let call1 = ToolCall(id: "c1", serverName: "filesystem", toolName: "read_file",
                         arguments: ["path": "/tmp/config.json"])
    let call2 = ToolCall(id: "c2", serverName: "filesystem", toolName: "list_directory",
                         arguments: ["path": "/tmp"])
    let plan = ExecutionPlan(
        intent: "Read project files and summarize",
        contextSummary: "User wants a summary of project files.",
        steps: [
            AgentStep(index: 0, description: "Read the configuration file", toolCall: call1),
            AgentStep(index: 1, description: "List directory contents", toolCall: call2)
        ],
        status: .awaitingApproval
    )
    PlanTimelineView(
        task: AgentTask(prompt: "Read my project files and give me a summary", phase: .awaitingApproval, plan: plan),
        onApprove: {}, onCancel: {}, onClose: {}
    )
    .frame(width: 520, height: 460)
}

#Preview("Executing") {
    let call = ToolCall(id: "c1", serverName: "filesystem", toolName: "read_file",
                        arguments: ["path": "/tmp/file.txt"])
    let plan = ExecutionPlan(
        intent: "Read and process files",
        contextSummary: "",
        steps: [
            AgentStep(index: 0, description: "Read config file", toolCall: call, status: .succeeded,
                      result: ToolResult(id: "r1", toolCallId: "c1", content: "Done", isError: false)),
            AgentStep(index: 1, description: "Parse contents", toolCall: call, status: .running),
            AgentStep(index: 2, description: "Write summary", toolCall: call, status: .pending)
        ],
        status: .executing
    )
    PlanTimelineView(
        task: AgentTask(prompt: "Process project files", phase: .executing, plan: plan),
        onApprove: {}, onCancel: {}, onClose: {}
    )
    .frame(width: 520, height: 460)
}

#Preview("Planning") {
    PlanTimelineView(
        task: AgentTask(prompt: "Create a new SwiftUI feature", phase: .planning),
        onApprove: {}, onCancel: {}, onClose: {}
    )
    .frame(width: 520, height: 340)
}
