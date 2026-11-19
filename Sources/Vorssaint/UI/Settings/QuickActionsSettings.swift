// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Vorssaint

import AppKit
import SwiftUI

struct QuickActionsSettings: View {
    @ObservedObject private var service = QuickActionsService.shared
    @ObservedObject private var agents = AgentChatService.shared
    @ObservedObject private var permissions = Permissions.shared
    @ObservedObject private var l10n = L10n.shared
    @State private var editing: QuickAction?

    private func text(_ it: String, _ en: String) -> String { l10n.language == .it ? it : en }

    var body: some View {
        Form {
            Section {
                Toggle(text("Abilita le Azioni AI", "Enable AI Actions"), isOn: $service.isEnabled)
                Text(text("Agiscono solo sul testo selezionato quando avvii un’azione. Per usare i provider CLI serve averli installati e aver effettuato l’accesso.",
                          "Actions run only on text you select and explicitly submit. CLI providers must be installed and signed in."))
                    .font(.caption).foregroundStyle(.secondary)
                if !permissions.accessibility {
                    HStack {
                        Text(text("Accessibilità serve per leggere la selezione e incollare il risultato.",
                                  "Accessibility is needed to read the selection and paste the result."))
                            .font(.caption).foregroundStyle(.secondary)
                        Spacer()
                        Button(text("Concedi accesso", "Grant Access")) { Permissions.shared.requestAccessibility() }
                    }
                }
                if agents.isRefreshingProviders {
                    Label(text("Controllo i provider…", "Checking providers…"), systemImage: "hourglass")
                        .font(.caption).foregroundStyle(.secondary)
                } else if agents.availableProviders.isEmpty {
                    Label(text("Installa e configura Codex CLI o Claude Code.", "Install and configure Codex CLI or Claude Code."),
                          systemImage: "exclamationmark.triangle")
                        .font(.caption).foregroundStyle(.orange)
                }
            } header: {
                Text(text("Azioni AI", "AI Actions"))
            }

            Section {
                ForEach(Array(service.actions.enumerated()), id: \.element.id) { index, action in
                    HStack(spacing: 10) {
                        Image(systemName: "textformat")
                            .foregroundStyle(Color.accentColor).frame(width: 22)
                        VStack(alignment: .leading, spacing: 3) {
                            Text(action.name).font(.system(size: 13, weight: .semibold))
                            Text([action.provider.title,
                                  action.model.isEmpty ? text("Modello predefinito", "Default model") : action.model,
                                  action.resultMode == .replace ? text("Sostituisci", "Replace") : text("Anteprima", "Preview"),
                                  action.alias.isEmpty ? nil : "↳ \(action.alias)",
                                  GlobalShortcut(storageValue: action.shortcut)?.displayString]
                                .compactMap { $0 }
                                .joined(separator: " · "))
                                .font(.caption).foregroundStyle(.secondary).lineLimit(1)
                        }
                        Spacer(minLength: 8)
                        if service.shortcutFailures.contains(action.id) {
                            Image(systemName: "exclamationmark.triangle.fill").foregroundStyle(.orange)
                                .help(text("Scorciatoia già in uso", "Shortcut is already in use"))
                        }
                        VStack(spacing: 0) {
                            Button { service.move(action, by: -1) } label: { Image(systemName: "chevron.up") }
                                .buttonStyle(.plain).disabled(index == 0)
                            Button { service.move(action, by: 1) } label: { Image(systemName: "chevron.down") }
                                .buttonStyle(.plain).disabled(index == service.actions.count - 1)
                        }
                        .font(.system(size: 9, weight: .semibold))
                        .foregroundStyle(.secondary)
                        Toggle("", isOn: Binding(
                            get: { action.isEnabled },
                            set: { enabled in var copy = action; copy.isEnabled = enabled; service.update(copy) }))
                            .labelsHidden().toggleStyle(.switch).controlSize(.small)
                        Button(text("Modifica", "Edit")) { editing = action }
                            .buttonStyle(.bordered).controlSize(.small)
                        if !["fixGrammar", "rewrite", "summarize"].contains(action.id) {
                            Button { service.remove(action) } label: { Image(systemName: "trash") }
                                .buttonStyle(.bordered).controlSize(.small)
                                .help(text("Elimina azione", "Delete action"))
                        }
                    }
                    .padding(.vertical, 3)
                }
                Button {
                    service.addAction()
                    editing = service.actions.last
                } label: {
                    Label(text("Aggiungi azione", "Add Action"), systemImage: "plus")
                }
            } header: {
                Text(text("Le tue azioni", "Your Actions"))
            } footer: {
                Text(text("Ogni azione può usare un provider, un modello, una scorciatoia e una modalità di risultato propri.",
                          "Each action can have its own provider, model, shortcut, and result mode."))
                    .font(.caption)
            }
        }
        .formStyle(.grouped)
        .onAppear { agents.refreshProviders() }
        .sheet(item: $editing) { action in
            QuickActionEditor(action: action) { edited in
                service.update(edited)
                editing = nil
            } cancel: { editing = nil }
        }
    }
}

private struct QuickActionEditor: View {
    @State var action: QuickAction
    let save: (QuickAction) -> Void
    let cancel: () -> Void
    @ObservedObject private var agents = AgentChatService.shared
    @ObservedObject private var l10n = L10n.shared
    @State private var errorText: String?
    @State private var recordingShortcut = false

    private func text(_ it: String, _ en: String) -> String { l10n.language == .it ? it : en }
    private var currentShortcut: GlobalShortcut? { GlobalShortcut(storageValue: action.shortcut) }

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text(text("Modifica azione", "Edit Action")).font(.headline)
            TextField(text("Nome", "Name"), text: $action.name).textFieldStyle(.roundedBorder)
            TextField(text("Alias facoltativo", "Optional alias"), text: $action.alias).textFieldStyle(.roundedBorder)
            HStack {
                Picker(text("Provider", "Provider"), selection: $action.provider) {
                    ForEach(AgentChatProvider.allCases) { provider in
                        HStack {
                            Text(provider.title)
                            if !agents.availableProviders.contains(provider) { Text("— unavailable").foregroundStyle(.secondary) }
                        }.tag(provider)
                    }
                }
                .frame(width: 220)
                Menu {
                    Button(text("Modello predefinito", "Provider default")) { action.model = "" }
                    Divider()
                    ForEach(action.provider.suggestedModels, id: \.self) { model in
                        Button(model) { action.model = model }
                    }
                } label: {
                    Text(action.model.isEmpty ? text("Modello", "Model") : action.model)
                        .lineLimit(1).truncationMode(.middle)
                }
            }
            TextField(text("ID modello facoltativo", "Optional model ID"), text: $action.model)
                .textFieldStyle(.roundedBorder)
            Picker(text("Risultato", "Result"), selection: $action.resultMode) {
                Text(text("Sostituisci la selezione", "Replace selection")).tag(QuickActionResultMode.replace)
                Text(text("Mostra anteprima", "Show preview")).tag(QuickActionResultMode.preview)
            }
            VStack(alignment: .leading, spacing: 5) {
                Text(text("Prompt", "Prompt")).font(.caption).foregroundStyle(.secondary)
                TextEditor(text: $action.prompt)
                    .font(.system(size: 12))
                    .frame(minHeight: 105)
                    .overlay(RoundedRectangle(cornerRadius: 6).stroke(Color.secondary.opacity(0.25)))
            }
            HStack(spacing: 10) {
                Text(text("Scorciatoia", "Shortcut"))
                ShortcutRecorderButton(
                    shortcut: currentShortcut ?? .commandBarDefault,
                    isEnabled: true,
                    waitingTitle: text("Premi una scorciatoia", "Press a shortcut"),
                    emptyTitle: action.shortcut.isEmpty ? text("Nessuna", "None") : nil,
                    clearAction: { action.shortcut = "" },
                    recordingChanged: { recordingShortcut = $0 },
                    invalidAction: { errorText = text("Scorciatoia non valida", "Invalid shortcut") },
                    captureAction: { action.shortcut = $0.storageValue; errorText = nil })
                    .frame(width: 190)
            }
            if let errorText { Text(errorText).font(.caption).foregroundStyle(.orange) }
            HStack {
                Spacer()
                Button(text("Annulla", "Cancel"), action: cancel)
                Button(text("Salva", "Save"), action: commit)
                    .buttonStyle(.borderedProminent)
                    .disabled(action.name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
                              || action.prompt.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
                              || recordingShortcut)
            }
        }
        .padding(20)
        .frame(width: 500)
        .onAppear { agents.refreshProviders() }
    }

    private func commit() {
        let shortcut = currentShortcut
        if let shortcut {
            if let conflict = GlobalShortcutRole.conflict(for: shortcut, excluding: nil,
                                                          includeInactive: true) {
                errorText = String(format: l10n.s.shortcutConflictFormat, conflict.title(l10n.s))
                return
            }
            if let conflict = WindowLayoutService.shared.shortcutConflictTitle(shortcut) {
                errorText = String(format: l10n.s.shortcutConflictFormat, conflict)
                return
            }
            if QuickActionsService.shared.actions.contains(where: {
                $0.id != action.id && $0.isEnabled && GlobalShortcut(storageValue: $0.shortcut) == shortcut
            }) {
                errorText = text("Un’altra azione usa già questa scorciatoia.", "Another action already uses this shortcut.")
                return
            }
        }
        action.name = action.name.trimmingCharacters(in: .whitespacesAndNewlines)
        action.alias = action.alias.trimmingCharacters(in: .whitespacesAndNewlines)
        action.prompt = action.prompt.trimmingCharacters(in: .whitespacesAndNewlines)
        action.model = action.model.trimmingCharacters(in: .whitespacesAndNewlines)
        save(action)
    }
}
