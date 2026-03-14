//
//  SettingsViewModel.swift
//  codellama
//
//  Created by Thiago Duarte on 3/14/26.
//

import SwiftUI
import Defaults

@MainActor
@Observable
final class SettingsViewModel {
    var ollamaHost: String = Defaults[.ollamaHost]
    var systemPrompt: String = Defaults[.systemPrompt]
    var isTestingConnection: Bool = false
    var connectionTestResult: ConnectionTestResult?

    enum ConnectionTestResult: Equatable {
        case success(modelCount: Int)
        case failure(String)
    }

    func save() {
        Defaults[.ollamaHost] = ollamaHost
        Defaults[.systemPrompt] = systemPrompt
    }

    func testConnection() async {
        guard let url = URL(string: ollamaHost) else {
            connectionTestResult = .failure("Invalid URL: \(ollamaHost)")
            return
        }

        isTestingConnection = true
        connectionTestResult = nil

        let client = OllamaClient(baseURL: url)

        let reachable = await client.isReachable()
        guard reachable else {
            isTestingConnection = false
            connectionTestResult = .failure("Cannot reach Ollama at \(ollamaHost). Make sure the server is running.")
            return
        }

        do {
            let response = try await client.listModels()
            connectionTestResult = .success(modelCount: response.models.count)
        } catch {
            connectionTestResult = .failure("Connected but failed to list models: \(error.localizedDescription)")
        }

        isTestingConnection = false
    }

    func resetToDefaults() {
        ollamaHost = Defaults.Keys.ollamaHost.defaultValue
        systemPrompt = Defaults.Keys.systemPrompt.defaultValue
        save()
    }
}
