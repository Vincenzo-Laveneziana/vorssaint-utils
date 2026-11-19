// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Vorssaint

import Foundation

enum QuickActionResultMode: String, CaseIterable, Codable, Identifiable {
    case replace
    case preview

    var id: String { rawValue }
}

struct QuickAction: Codable, Identifiable, Equatable {
    var id: String
    var name: String
    var alias: String
    var prompt: String
    var provider: AgentChatProvider
    var model: String
    var shortcut: String
    var resultMode: QuickActionResultMode
    var isEnabled: Bool

    static func builtIns(provider: AgentChatProvider, model: String) -> [QuickAction] {
        [
            QuickAction(id: "fixGrammar", name: "Fix Grammar", alias: "",
                        prompt: "Correct grammar, spelling, and punctuation. Preserve the original meaning, tone, and language. Return only the corrected text.",
                        provider: provider, model: model, shortcut: "",
                        resultMode: .replace, isEnabled: true),
            QuickAction(id: "rewrite", name: "Rewrite", alias: "",
                        prompt: "Rewrite the text to make it clearer and more natural. Preserve its meaning and language. Return only the rewritten text.",
                        provider: provider, model: model, shortcut: "",
                        resultMode: .preview, isEnabled: true),
            QuickAction(id: "summarize", name: "Summarize", alias: "",
                        prompt: "Summarize the text in its original language. Return only the summary.",
                        provider: provider, model: model, shortcut: "",
                        resultMode: .preview, isEnabled: true),
        ]
    }
}
