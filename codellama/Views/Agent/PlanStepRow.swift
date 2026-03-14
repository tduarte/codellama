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
