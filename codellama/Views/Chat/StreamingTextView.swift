//
//  StreamingTextView.swift
//  codellama
//
//  Created by Thiago Duarte on 3/14/26.
//

import SwiftUI

struct StreamingTextView: View {
    let text: String
    let isStreaming: Bool

    @State private var cursorVisible: Bool = true

    var body: some View {
        HStack(alignment: .lastTextBaseline, spacing: 0) {
            Text(LocalizedStringKey(text))
                .textSelection(.enabled)

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
    }
}
