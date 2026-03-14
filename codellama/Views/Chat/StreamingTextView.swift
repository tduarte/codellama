//
//  StreamingTextView.swift
//  codellama
//
//  Created by Thiago Duarte on 3/14/26.
//

import SwiftUI
import Textual

struct StreamingTextView: View {
    let text: String
    let isStreaming: Bool

    @State private var cursorVisible: Bool = true

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            StructuredText(markdown: text)
                .textual.structuredTextStyle(.gitHub)
                .textual.textSelection(.enabled)

            if isStreaming {
                Text("|")
                    .foregroundStyle(.secondary)
                    .opacity(cursorVisible ? 1 : 0)
                    .onAppear {
                        withAnimation(.easeInOut(duration: 0.5).repeatForever()) {
                            cursorVisible.toggle()
                        }
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}
