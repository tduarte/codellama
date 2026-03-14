//
//  OllamaSettingsView.swift
//  codellama
//
//  Created by Thiago Duarte on 3/14/26.
//

import SwiftUI
import Defaults

struct OllamaSettingsView: View {
    @State private var host: String = Defaults[.ollamaHost]
    @State private var systemPrompt: String = Defaults[.systemPrompt]
    @State private var connectionResult: ConnectionTestResult?
    @State private var isTesting: Bool = false

    enum ConnectionTestResult {
        case success
        case failure(String)
    }

    var body: some View {
        Form {
            Section("Ollama Server") {
                TextField("Host URL", text: $host)
                    .textFieldStyle(.roundedBorder)

                HStack {
                    Button("Test Connection") {
                        testConnection()
                    }
                    .disabled(isTesting)

                    if isTesting {
                        ProgressView()
                            .controlSize(.small)
                    }

                    if let result = connectionResult {
                        switch result {
                        case .success:
                            Label("Connected", systemImage: "checkmark.circle.fill")
                                .foregroundStyle(.green)
                                .font(.caption)
                        case .failure(let message):
                            Label(message, systemImage: "xmark.circle.fill")
                                .foregroundStyle(.red)
                                .font(.caption)
                        }
                    }
                }
            }

            Section("Default System Prompt") {
                TextEditor(text: $systemPrompt)
                    .font(.body)
                    .frame(minHeight: 80)
                    .scrollContentBackground(.hidden)
                    .padding(4)
                    .background(
                        RoundedRectangle(cornerRadius: 6)
                            .fill(.background)
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: 6)
                            .stroke(.quaternary, lineWidth: 1)
                    )
            }

            HStack {
                Spacer()
                Button("Save") {
                    save()
                }
                .buttonStyle(.borderedProminent)
            }
        }
        .formStyle(.grouped)
        .padding()
    }

    // MARK: - Actions

    private func save() {
        Defaults[.ollamaHost] = host
        Defaults[.systemPrompt] = systemPrompt
    }

    private func testConnection() {
        isTesting = true
        connectionResult = nil

        Task {
            guard let url = URL(string: host) else {
                connectionResult = .failure("Invalid URL")
                isTesting = false
                return
            }

            let client = OllamaClient(baseURL: url)
            let reachable = await client.isReachable()

            connectionResult = reachable ? .success : .failure("Cannot reach Ollama")
            isTesting = false
        }
    }
}
