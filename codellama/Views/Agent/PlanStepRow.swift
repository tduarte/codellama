//
//  PlanStepRow.swift
//  codellama
//
//  Created by Thiago Duarte on 3/14/26.
//

import SwiftUI

/// A single row in the plan timeline, showing an `AgentStep`'s status,
/// tool call details, and optional result preview.
struct PlanStepRow: View {

    let step: AgentStep

    var body: some View {
        HStack(alignment: .top, spacing: 10) {
            stepStatusIcon
                .frame(width: 20)

            VStack(alignment: .leading, spacing: 4) {
                Text(step.description)
                    .font(.body)

                Text("\(step.toolCall.serverName) → \(step.toolCall.toolName)")
                    .font(.caption)
                    .foregroundStyle(.secondary)

                if let result = step.result {
                    Text(result.isError
                         ? "Error: \(result.content)"
                         : result.content)
                        .font(.caption2)
                        .foregroundStyle(result.isError ? .red : .secondary)
                        .lineLimit(3)
                        .padding(.top, 2)
                }
            }
        }
        .padding(.vertical, 4)
    }

    // MARK: - Status Icon

    @ViewBuilder
    private var stepStatusIcon: some View {
        switch step.status {
        case .pending:
            Image(systemName: "clock")
                .foregroundStyle(.secondary)
        case .running:
            ProgressView()
                .scaleEffect(0.7)
                .frame(width: 16, height: 16)
        case .succeeded:
            Image(systemName: "checkmark.circle.fill")
                .foregroundStyle(.green)
        case .failed:
            Image(systemName: "xmark.circle.fill")
                .foregroundStyle(.red)
        case .skipped:
            Image(systemName: "minus.circle")
                .foregroundStyle(.secondary)
        }
    }
}

#Preview {
    let readCall = ToolCall(id: "c1", serverName: "filesystem", toolName: "read_file",
                            arguments: ["path": "/tmp/config.json"])
    let writeCall = ToolCall(id: "c4", serverName: "filesystem", toolName: "write_file",
                             arguments: ["path": "/tmp/out.txt"])

    VStack(spacing: 0) {
        PlanStepRow(step: AgentStep(index: 0, description: "Read the project configuration file",
                                    toolCall: readCall, status: .pending))
        Divider()
        PlanStepRow(step: AgentStep(index: 1, description: "Fetch repository info",
                                    toolCall: ToolCall(id: "c2", serverName: "github", toolName: "get_repo",
                                                       arguments: ["owner": "apple", "repo": "swift"]),
                                    status: .running))
        Divider()
        PlanStepRow(step: AgentStep(index: 2, description: "List directory contents",
                                    toolCall: readCall, status: .succeeded,
                                    result: ToolResult(id: "r1", toolCallId: "c1",
                                                       content: "config.json\nPackage.swift\nREADME.md",
                                                       isError: false)))
        Divider()
        PlanStepRow(step: AgentStep(index: 3, description: "Write output file",
                                    toolCall: writeCall, status: .failed,
                                    result: ToolResult(id: "r2", toolCallId: "c4",
                                                       content: "Permission denied: /tmp/out.txt",
                                                       isError: true)))
        Divider()
        PlanStepRow(step: AgentStep(index: 4, description: "Clean up temp files",
                                    toolCall: writeCall, status: .skipped))
    }
    .padding()
    .frame(width: 460)
}
