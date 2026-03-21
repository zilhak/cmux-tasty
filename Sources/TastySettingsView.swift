import SwiftUI

// MARK: - Tasty Settings Tab

/// Fork-specific settings tab that reorganizes upstream settings into categories
/// and provides a place for fork-only features.
struct TastySettingsView: View {
    enum Category: String, CaseIterable, Identifiable {
        case general
        case appearance
        case sidebar
        case notifications
        case browser
        case automation
        case shortcuts

        var id: String { rawValue }

        var label: String {
            switch self {
            case .general: return "General"
            case .appearance: return "Appearance"
            case .sidebar: return "Sidebar"
            case .notifications: return "Notifications"
            case .browser: return "Browser"
            case .automation: return "Automation"
            case .shortcuts: return "Shortcuts"
            }
        }

        var icon: String {
            switch self {
            case .general: return "gearshape"
            case .appearance: return "paintbrush"
            case .sidebar: return "sidebar.left"
            case .notifications: return "bell"
            case .browser: return "globe"
            case .automation: return "terminal"
            case .shortcuts: return "keyboard"
            }
        }
    }

    @State private var selectedCategory: Category = .general

    var body: some View {
        NavigationSplitView {
            List(Category.allCases, selection: $selectedCategory) { category in
                Label(category.label, systemImage: category.icon)
                    .tag(category)
            }
            .listStyle(.sidebar)
            .navigationSplitViewColumnWidth(min: 150, ideal: 170, max: 200)
        } detail: {
            ScrollView {
                VStack(alignment: .leading, spacing: 14) {
                    switch selectedCategory {
                    case .general:
                        TastyGeneralSettingsSection()
                    case .appearance:
                        TastyAppearanceSettingsSection()
                    case .sidebar:
                        TastySidebarSettingsSection()
                    case .notifications:
                        TastyNotificationsSettingsSection()
                    case .browser:
                        TastyBrowserSettingsSection()
                    case .automation:
                        TastyAutomationSettingsSection()
                    case .shortcuts:
                        TastyShortcutsSettingsSection()
                    }
                }
                .padding(.horizontal, 20)
                .padding(.bottom, 20)
                .padding(.top, 8)
            }
        }
        .toggleStyle(.switch)
    }
}

// MARK: - General

struct TastyGeneralSettingsSection: View {
    private let pickerColumnWidth: CGFloat = 196

    @AppStorage(LanguageSettings.languageKey) private var appLanguage = LanguageSettings.defaultLanguage.rawValue
    @AppStorage(WorkspacePresentationModeSettings.modeKey)
    private var workspacePresentationMode = WorkspacePresentationModeSettings.defaultMode.rawValue
    @AppStorage(WorkspacePlacementSettings.placementKey) private var newWorkspacePlacement = WorkspacePlacementSettings.defaultPlacement.rawValue
    @AppStorage(LastSurfaceCloseShortcutSettings.key)
    private var closeWorkspaceOnLastSurfaceShortcut = LastSurfaceCloseShortcutSettings.defaultValue
    @AppStorage(PaneFirstClickFocusSettings.enabledKey)
    private var paneFirstClickFocusEnabled = PaneFirstClickFocusSettings.defaultEnabled
    @AppStorage(QuitWarningSettings.warnBeforeQuitKey) private var warnBeforeQuitShortcut = QuitWarningSettings.defaultWarnBeforeQuit
    @AppStorage(CommandPaletteRenameSelectionSettings.selectAllOnFocusKey)
    private var commandPaletteRenameSelectAllOnFocus = CommandPaletteRenameSelectionSettings.defaultSelectAllOnFocus
    @AppStorage(CommandPaletteSwitcherSearchSettings.searchAllSurfacesKey)
    private var commandPaletteSearchAllSurfaces = CommandPaletteSwitcherSearchSettings.defaultSearchAllSurfaces
    @AppStorage(TelemetrySettings.sendAnonymousTelemetryKey)
    private var sendAnonymousTelemetry = TelemetrySettings.defaultSendAnonymousTelemetry
    @AppStorage(MenuBarExtraSettings.showInMenuBarKey) private var showMenuBarExtra = MenuBarExtraSettings.defaultShowInMenuBar

    @State private var showLanguageRestartAlert = false
    @State private var isResettingSettings = false
    @State private var telemetryValueAtLaunch = TelemetrySettings.enabledForCurrentLaunch

    private var selectedWorkspacePlacement: NewWorkspacePlacement {
        NewWorkspacePlacement(rawValue: newWorkspacePlacement) ?? WorkspacePlacementSettings.defaultPlacement
    }

    private var minimalModeEnabled: Bool {
        WorkspacePresentationModeSettings.mode(for: workspacePresentationMode) == .minimal
    }

    private var minimalModeBinding: Binding<Bool> {
        Binding(
            get: { minimalModeEnabled },
            set: { newValue in
                workspacePresentationMode = newValue
                    ? WorkspacePresentationModeSettings.Mode.minimal.rawValue
                    : WorkspacePresentationModeSettings.Mode.standard.rawValue
                SettingsWindowController.shared.preserveFocusAfterPreferenceMutation()
            }
        )
    }

    private var keepWorkspaceOpenOnLastSurfaceShortcut: Bool {
        !closeWorkspaceOnLastSurfaceShortcut
    }

    private var keepWorkspaceOpenOnLastSurfaceShortcutBinding: Binding<Bool> {
        Binding(
            get: { keepWorkspaceOpenOnLastSurfaceShortcut },
            set: { closeWorkspaceOnLastSurfaceShortcut = !$0 }
        )
    }

    var body: some View {
        SettingsSectionHeader(title: "General")
        SettingsCard {
            SettingsCardRow(
                String(localized: "settings.app.language", defaultValue: "Language"),
                subtitle: appLanguage != LanguageSettings.languageAtLaunch.rawValue
                    ? String(localized: "settings.app.language.restartSubtitle", defaultValue: "Restart cmux to apply")
                    : nil,
                controlWidth: pickerColumnWidth
            ) {
                Picker("", selection: $appLanguage) {
                    ForEach(AppLanguage.allCases) { lang in
                        Text(lang.displayName).tag(lang.rawValue)
                    }
                }
                .labelsHidden()
                .pickerStyle(.menu)
                .onChange(of: appLanguage) { newValue in
                    guard !isResettingSettings else { return }
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                        let current = appLanguage
                        if let lang = AppLanguage(rawValue: current) {
                            LanguageSettings.apply(lang)
                        }
                        if current != LanguageSettings.languageAtLaunch.rawValue {
                            showLanguageRestartAlert = true
                        }
                    }
                }
            }

            SettingsCardDivider()

            SettingsPickerRow(
                String(localized: "settings.app.newWorkspacePlacement", defaultValue: "New Workspace Placement"),
                subtitle: selectedWorkspacePlacement.description,
                controlWidth: pickerColumnWidth,
                selection: $newWorkspacePlacement
            ) {
                ForEach(NewWorkspacePlacement.allCases) { placement in
                    Text(placement.displayName).tag(placement.rawValue)
                }
            }

            SettingsCardDivider()

            SettingsCardRow(
                String(localized: "settings.app.minimalMode", defaultValue: "Minimal Mode"),
                subtitle: minimalModeEnabled
                    ? String(localized: "settings.app.minimalMode.subtitleOn", defaultValue: "Hide the workspace title bar and move workspace controls into the sidebar.")
                    : String(localized: "settings.app.minimalMode.subtitleOff", defaultValue: "Use the standard workspace title bar and controls.")
            ) {
                Toggle("", isOn: minimalModeBinding)
                    .labelsHidden()
                    .controlSize(.small)
            }

            SettingsCardDivider()

            SettingsCardRow(
                String(localized: "settings.app.closeWorkspaceOnLastSurfaceShortcut", defaultValue: "Keep Workspace Open When Closing Last Surface")
            ) {
                Toggle("", isOn: keepWorkspaceOpenOnLastSurfaceShortcutBinding)
                    .labelsHidden()
                    .controlSize(.small)
            }

            SettingsCardDivider()

            SettingsCardRow(
                String(localized: "settings.app.paneFirstClickFocus", defaultValue: "Focus Pane on First Click"),
                subtitle: paneFirstClickFocusEnabled
                    ? String(localized: "settings.app.paneFirstClickFocus.subtitleOn", defaultValue: "When cmux is inactive, clicking a pane activates the window and focuses that pane in one click.")
                    : String(localized: "settings.app.paneFirstClickFocus.subtitleOff", defaultValue: "When cmux is inactive, the first click only activates the window. Click again to focus the pane.")
            ) {
                Toggle("", isOn: $paneFirstClickFocusEnabled)
                    .labelsHidden()
                    .controlSize(.small)
            }

            SettingsCardDivider()

            SettingsCardRow(
                String(localized: "settings.app.warnBeforeQuit", defaultValue: "Warn Before Quit"),
                subtitle: warnBeforeQuitShortcut
                    ? String(localized: "settings.app.warnBeforeQuit.subtitleOn", defaultValue: "Show a confirmation before quitting with Cmd+Q.")
                    : String(localized: "settings.app.warnBeforeQuit.subtitleOff", defaultValue: "Cmd+Q quits immediately without confirmation.")
            ) {
                Toggle("", isOn: $warnBeforeQuitShortcut)
                    .labelsHidden()
                    .controlSize(.small)
            }

            SettingsCardDivider()

            SettingsCardRow(
                String(localized: "settings.app.showInMenuBar", defaultValue: "Show in Menu Bar"),
                subtitle: String(localized: "settings.app.showInMenuBar.subtitle", defaultValue: "Keep cmux in the menu bar for unread notifications and quick actions.")
            ) {
                Toggle("", isOn: $showMenuBarExtra)
                    .labelsHidden()
                    .controlSize(.small)
            }

            SettingsCardDivider()

            SettingsCardRow(
                String(localized: "settings.app.renameSelectsName", defaultValue: "Rename Selects Existing Name"),
                subtitle: commandPaletteRenameSelectAllOnFocus
                    ? String(localized: "settings.app.renameSelectsName.subtitleOn", defaultValue: "Command Palette rename starts with all text selected.")
                    : String(localized: "settings.app.renameSelectsName.subtitleOff", defaultValue: "Command Palette rename keeps the caret at the end.")
            ) {
                Toggle("", isOn: $commandPaletteRenameSelectAllOnFocus)
                    .labelsHidden()
                    .controlSize(.small)
            }

            SettingsCardDivider()

            SettingsCardRow(
                String(localized: "settings.app.commandPaletteSearchAllSurfaces", defaultValue: "Command Palette Searches All Surfaces"),
                subtitle: commandPaletteSearchAllSurfaces
                    ? String(localized: "settings.app.commandPaletteSearchAllSurfaces.subtitleOn", defaultValue: "Cmd+P also matches terminal, browser, and markdown surfaces across workspaces.")
                    : String(localized: "settings.app.commandPaletteSearchAllSurfaces.subtitleOff", defaultValue: "Cmd+P matches workspace rows only.")
            ) {
                Toggle("", isOn: $commandPaletteSearchAllSurfaces)
                    .labelsHidden()
                    .controlSize(.small)
            }

            SettingsCardDivider()

            SettingsCardRow(
                String(localized: "settings.app.telemetry", defaultValue: "Send anonymous telemetry"),
                subtitle: sendAnonymousTelemetry != telemetryValueAtLaunch
                    ? String(localized: "settings.app.telemetry.subtitleChanged", defaultValue: "Change takes effect on next launch.")
                    : String(localized: "settings.app.telemetry.subtitle", defaultValue: "Share anonymized crash and usage data to help improve cmux.")
            ) {
                Toggle("", isOn: $sendAnonymousTelemetry)
                    .labelsHidden()
                    .controlSize(.small)
            }
        }
        .confirmationDialog(
            String(localized: "settings.app.language.restartDialog.title", defaultValue: "Restart to apply language change?"),
            isPresented: $showLanguageRestartAlert,
            titleVisibility: .visible
        ) {
            Button(String(localized: "settings.app.language.restartDialog.confirm", defaultValue: "Restart Now")) {
                TastySettingsHelper.relaunchApp()
            }
            Button(String(localized: "settings.app.language.restartDialog.later", defaultValue: "Later"), role: .cancel) {}
        }
    }
}

// MARK: - Appearance

struct TastyAppearanceSettingsSection: View {
    private let pickerColumnWidth: CGFloat = 196

    @AppStorage(AppearanceSettings.appearanceModeKey) private var appearanceMode = AppearanceSettings.defaultMode.rawValue
    @AppStorage(AppIconSettings.modeKey) private var appIconMode = AppIconSettings.defaultMode.rawValue
    @AppStorage(SidebarActiveTabIndicatorSettings.styleKey)
    private var sidebarActiveTabIndicatorStyle = SidebarActiveTabIndicatorSettings.defaultStyle.rawValue

    @State private var workspaceTabDefaultEntries = WorkspaceTabColorSettings.defaultPaletteWithOverrides()
    @State private var workspaceTabCustomColors = WorkspaceTabColorSettings.customColors()

    private var selectedSidebarActiveTabIndicatorStyle: SidebarActiveTabIndicatorStyle {
        SidebarActiveTabIndicatorSettings.resolvedStyle(rawValue: sidebarActiveTabIndicatorStyle)
    }

    private var sidebarIndicatorStyleSelection: Binding<String> {
        Binding(
            get: { selectedSidebarActiveTabIndicatorStyle.rawValue },
            set: { sidebarActiveTabIndicatorStyle = $0 }
        )
    }

    var body: some View {
        SettingsSectionHeader(title: "Theme")
        SettingsCard {
            ThemePickerRow(
                selectedMode: appearanceMode,
                onSelect: { mode in
                    appearanceMode = mode.rawValue
                }
            )

            SettingsCardDivider()

            AppIconPickerRow(
                selectedMode: appIconMode,
                onSelect: { mode in
                    appIconMode = mode.rawValue
                    AppIconSettings.applyIcon(mode)
                }
            )
        }

        SettingsSectionHeader(title: String(localized: "settings.section.workspaceColors", defaultValue: "Workspace Colors"))
        SettingsCard {
            SettingsPickerRow(
                String(localized: "settings.workspaceColors.indicator", defaultValue: "Workspace Color Indicator"),
                controlWidth: pickerColumnWidth,
                selection: sidebarIndicatorStyleSelection
            ) {
                ForEach(SidebarActiveTabIndicatorStyle.allCases) { style in
                    Text(style.displayName).tag(style.rawValue)
                }
            }

            SettingsCardDivider()

            SettingsCardNote(String(localized: "settings.workspaceColors.paletteNote", defaultValue: "Customize the workspace color palette used by Sidebar > Workspace Color. \"Choose Custom Color...\" entries are persisted below."))

            ForEach(Array(workspaceTabDefaultEntries.enumerated()), id: \.element.name) { index, entry in
                if index > 0 {
                    SettingsCardDivider()
                }
                SettingsCardRow(entry.name) {
                    HStack(spacing: 8) {
                        ColorPicker("", selection: defaultTabColorBinding(for: entry.name), supportsOpacity: false)
                            .labelsHidden()
                            .frame(width: 38)

                        Text(entry.hex)
                            .font(.system(size: 12, weight: .medium, design: .monospaced))
                            .foregroundStyle(.secondary)
                            .frame(width: 76, alignment: .trailing)
                    }
                }
            }

            SettingsCardDivider()

            if workspaceTabCustomColors.isEmpty {
                SettingsCardNote(String(localized: "settings.workspaceColors.noCustomColors", defaultValue: "Custom colors: none yet. Use \"Choose Custom Color...\" from a workspace context menu."))
            } else {
                VStack(alignment: .leading, spacing: 8) {
                    Text(String(localized: "settings.workspaceColors.customColors", defaultValue: "Custom Colors"))
                        .font(.system(size: 13, weight: .semibold))

                    ForEach(workspaceTabCustomColors, id: \.self) { hex in
                        HStack(spacing: 8) {
                            Circle()
                                .fill(Color(nsColor: NSColor(hex: hex) ?? .gray))
                                .frame(width: 11, height: 11)

                            Text(hex)
                                .font(.system(size: 12, weight: .medium, design: .monospaced))
                                .foregroundStyle(.secondary)

                            Spacer(minLength: 8)

                            Button(String(localized: "settings.workspaceColors.remove", defaultValue: "Remove")) {
                                removeWorkspaceCustomColor(hex)
                            }
                            .buttonStyle(.bordered)
                            .controlSize(.small)
                        }
                    }
                }
                .padding(.horizontal, 14)
                .padding(.vertical, 10)
            }

            SettingsCardDivider()

            SettingsCardRow(
                String(localized: "settings.workspaceColors.resetPalette", defaultValue: "Reset Palette"),
                subtitle: String(localized: "settings.workspaceColors.resetPalette.subtitle", defaultValue: "Restore built-in defaults and clear all custom colors.")
            ) {
                Button(String(localized: "settings.workspaceColors.resetPalette.button", defaultValue: "Reset")) {
                    resetWorkspaceTabColors()
                }
                .buttonStyle(.bordered)
                .controlSize(.small)
            }
        }
        .onAppear {
            reloadWorkspaceTabColorSettings()
        }
        .onReceive(NotificationCenter.default.publisher(for: UserDefaults.didChangeNotification)) { _ in
            reloadWorkspaceTabColorSettings()
        }
    }

    private func defaultTabColorBinding(for name: String) -> Binding<Color> {
        Binding(
            get: {
                let hex = WorkspaceTabColorSettings.defaultColorHex(named: name)
                return Color(nsColor: NSColor(hex: hex) ?? .systemBlue)
            },
            set: { newValue in
                let hex = NSColor(newValue).hexString()
                WorkspaceTabColorSettings.setDefaultColor(named: name, hex: hex)
                reloadWorkspaceTabColorSettings()
            }
        )
    }

    private func removeWorkspaceCustomColor(_ hex: String) {
        WorkspaceTabColorSettings.removeCustomColor(hex)
        reloadWorkspaceTabColorSettings()
    }

    private func resetWorkspaceTabColors() {
        WorkspaceTabColorSettings.reset()
        reloadWorkspaceTabColorSettings()
    }

    private func reloadWorkspaceTabColorSettings() {
        workspaceTabDefaultEntries = WorkspaceTabColorSettings.defaultPaletteWithOverrides()
        workspaceTabCustomColors = WorkspaceTabColorSettings.customColors()
    }
}

// MARK: - Sidebar

struct TastySidebarSettingsSection: View {
    @AppStorage(SidebarWorkspaceDetailSettings.hideAllDetailsKey)
    private var sidebarHideAllDetails = SidebarWorkspaceDetailSettings.defaultHideAllDetails
    @AppStorage(SidebarWorkspaceDetailSettings.showNotificationMessageKey)
    private var sidebarShowNotificationMessage = SidebarWorkspaceDetailSettings.defaultShowNotificationMessage
    @AppStorage(SidebarBranchLayoutSettings.key) private var sidebarBranchVerticalLayout = SidebarBranchLayoutSettings.defaultVerticalLayout
    @AppStorage("sidebarShowBranchDirectory") private var sidebarShowBranchDirectory = true
    @AppStorage("sidebarShowPullRequest") private var sidebarShowPullRequest = true
    @AppStorage(BrowserLinkOpenSettings.openSidebarPullRequestLinksInCmuxBrowserKey)
    private var openSidebarPullRequestLinksInCmuxBrowser = BrowserLinkOpenSettings.defaultOpenSidebarPullRequestLinksInCmuxBrowser
    @AppStorage("sidebarShowSSH") private var sidebarShowSSH = true
    @AppStorage("sidebarShowPorts") private var sidebarShowPorts = true
    @AppStorage("sidebarShowLog") private var sidebarShowLog = true
    @AppStorage("sidebarShowProgress") private var sidebarShowProgress = true
    @AppStorage("sidebarShowStatusPills") private var sidebarShowMetadata = true
    @AppStorage("sidebarTintHex") private var sidebarTintHex = SidebarTintDefaults.hex
    @AppStorage("sidebarTintHexLight") private var sidebarTintHexLight: String?
    @AppStorage("sidebarTintHexDark") private var sidebarTintHexDark: String?
    @AppStorage("sidebarTintOpacity") private var sidebarTintOpacity = SidebarTintDefaults.opacity

    private let pickerColumnWidth: CGFloat = 196

    private var settingsSidebarTintLightBinding: Binding<Color> {
        Binding(
            get: { Color(nsColor: NSColor(hex: sidebarTintHexLight ?? sidebarTintHex) ?? .black) },
            set: { sidebarTintHexLight = NSColor($0).hexString() }
        )
    }

    private var settingsSidebarTintDarkBinding: Binding<Color> {
        Binding(
            get: { Color(nsColor: NSColor(hex: sidebarTintHexDark ?? sidebarTintHex) ?? .black) },
            set: { sidebarTintHexDark = NSColor($0).hexString() }
        )
    }

    var body: some View {
        SettingsSectionHeader(title: "Sidebar Details")
        SettingsCard {
            SettingsCardRow(
                String(localized: "settings.app.hideAllSidebarDetails", defaultValue: "Hide All Sidebar Details"),
                subtitle: sidebarHideAllDetails
                    ? String(localized: "settings.app.hideAllSidebarDetails.subtitleOn", defaultValue: "Show only the workspace title row. Overrides the detail toggles below.")
                    : String(localized: "settings.app.hideAllSidebarDetails.subtitleOff", defaultValue: "Show secondary workspace details as controlled by the toggles below.")
            ) {
                Toggle("", isOn: $sidebarHideAllDetails)
                    .labelsHidden()
                    .controlSize(.small)
            }

            SettingsCardDivider()

            SettingsPickerRow(
                String(localized: "settings.app.sidebarBranchLayout", defaultValue: "Sidebar Branch Layout"),
                subtitle: sidebarBranchVerticalLayout
                    ? String(localized: "settings.app.sidebarBranchLayout.subtitleVertical", defaultValue: "Vertical: each branch appears on its own line.")
                    : String(localized: "settings.app.sidebarBranchLayout.subtitleInline", defaultValue: "Inline: all branches share one line."),
                controlWidth: pickerColumnWidth,
                selection: $sidebarBranchVerticalLayout
            ) {
                Text(String(localized: "settings.app.sidebarBranchLayout.vertical", defaultValue: "Vertical")).tag(true)
                Text(String(localized: "settings.app.sidebarBranchLayout.inline", defaultValue: "Inline")).tag(false)
            }
            .disabled(sidebarHideAllDetails)

            SettingsCardDivider()

            SettingsCardRow(
                String(localized: "settings.app.showNotificationMessage", defaultValue: "Show Notification Message in Sidebar")
            ) {
                Toggle("", isOn: $sidebarShowNotificationMessage)
                    .labelsHidden()
                    .controlSize(.small)
            }
            .disabled(sidebarHideAllDetails)

            SettingsCardDivider()

            SettingsCardRow(
                String(localized: "settings.app.showBranchDirectory", defaultValue: "Show Branch + Directory in Sidebar")
            ) {
                Toggle("", isOn: $sidebarShowBranchDirectory)
                    .labelsHidden()
                    .controlSize(.small)
            }
            .disabled(sidebarHideAllDetails)

            SettingsCardDivider()

            SettingsCardRow(
                String(localized: "settings.app.showPullRequests", defaultValue: "Show Pull Requests in Sidebar")
            ) {
                Toggle("", isOn: $sidebarShowPullRequest)
                    .labelsHidden()
                    .controlSize(.small)
            }
            .disabled(sidebarHideAllDetails)

            SettingsCardDivider()

            SettingsCardRow(
                String(localized: "settings.app.openSidebarPRLinks", defaultValue: "Open Sidebar PR Links in cmux Browser"),
                subtitle: openSidebarPullRequestLinksInCmuxBrowser
                    ? String(localized: "settings.app.openSidebarPRLinks.subtitleOn", defaultValue: "Clicks open inside cmux browser.")
                    : String(localized: "settings.app.openSidebarPRLinks.subtitleOff", defaultValue: "Clicks open in your default browser.")
            ) {
                Toggle("", isOn: $openSidebarPullRequestLinksInCmuxBrowser)
                    .labelsHidden()
                    .controlSize(.small)
            }
            .disabled(sidebarHideAllDetails)

            SettingsCardDivider()

            SettingsCardRow(String(localized: "settings.app.showSSH", defaultValue: "Show SSH in Sidebar")) {
                Toggle("", isOn: $sidebarShowSSH)
                    .labelsHidden()
                    .controlSize(.small)
            }

            SettingsCardDivider()

            SettingsCardRow(String(localized: "settings.app.showPorts", defaultValue: "Show Listening Ports in Sidebar")) {
                Toggle("", isOn: $sidebarShowPorts)
                    .labelsHidden()
                    .controlSize(.small)
            }
            .disabled(sidebarHideAllDetails)

            SettingsCardDivider()

            SettingsCardRow(String(localized: "settings.app.showLog", defaultValue: "Show Latest Log in Sidebar")) {
                Toggle("", isOn: $sidebarShowLog)
                    .labelsHidden()
                    .controlSize(.small)
            }
            .disabled(sidebarHideAllDetails)

            SettingsCardDivider()

            SettingsCardRow(String(localized: "settings.app.showProgress", defaultValue: "Show Progress in Sidebar")) {
                Toggle("", isOn: $sidebarShowProgress)
                    .labelsHidden()
                    .controlSize(.small)
            }
            .disabled(sidebarHideAllDetails)

            SettingsCardDivider()

            SettingsCardRow(String(localized: "settings.app.showMetadata", defaultValue: "Show Custom Metadata in Sidebar")) {
                Toggle("", isOn: $sidebarShowMetadata)
                    .labelsHidden()
                    .controlSize(.small)
            }
            .disabled(sidebarHideAllDetails)
        }

        SettingsSectionHeader(title: String(localized: "settings.section.sidebarAppearance", defaultValue: "Sidebar Appearance"))
        SettingsCard {
            SettingsCardRow(
                String(localized: "settings.sidebarAppearance.tintColorLight", defaultValue: "Light Mode Tint")
            ) {
                HStack(spacing: 8) {
                    ColorPicker("", selection: settingsSidebarTintLightBinding, supportsOpacity: false)
                        .labelsHidden()
                        .frame(width: 38)

                    Text(sidebarTintHexLight ?? sidebarTintHex)
                        .font(.system(size: 12, weight: .medium, design: .monospaced))
                        .foregroundStyle(.secondary)
                        .frame(width: 76, alignment: .trailing)
                }
            }

            SettingsCardDivider()

            SettingsCardRow(
                String(localized: "settings.sidebarAppearance.tintColorDark", defaultValue: "Dark Mode Tint")
            ) {
                HStack(spacing: 8) {
                    ColorPicker("", selection: settingsSidebarTintDarkBinding, supportsOpacity: false)
                        .labelsHidden()
                        .frame(width: 38)

                    Text(sidebarTintHexDark ?? sidebarTintHex)
                        .font(.system(size: 12, weight: .medium, design: .monospaced))
                        .foregroundStyle(.secondary)
                        .frame(width: 76, alignment: .trailing)
                }
            }

            SettingsCardDivider()

            SettingsCardRow(
                String(localized: "settings.sidebarAppearance.opacity", defaultValue: "Tint Opacity")
            ) {
                HStack(spacing: 8) {
                    Slider(value: $sidebarTintOpacity, in: 0...1)
                        .frame(width: 120)
                    Text(String(format: "%.0f%%", sidebarTintOpacity * 100))
                        .font(.system(size: 12, design: .monospaced))
                        .foregroundStyle(.secondary)
                        .frame(width: 40, alignment: .trailing)
                }
            }
        }
    }
}

// MARK: - Notifications

struct TastyNotificationsSettingsSection: View {
    private let notificationSoundControlWidth: CGFloat = 280

    @AppStorage(WorkspaceAutoReorderSettings.key) private var workspaceAutoReorder = WorkspaceAutoReorderSettings.defaultValue
    @AppStorage(NotificationBadgeSettings.dockBadgeEnabledKey) private var notificationDockBadgeEnabled = NotificationBadgeSettings.defaultDockBadgeEnabled
    @AppStorage(NotificationPaneRingSettings.enabledKey) private var notificationPaneRingEnabled = NotificationPaneRingSettings.defaultEnabled
    @AppStorage(NotificationPaneFlashSettings.enabledKey) private var notificationPaneFlashEnabled = NotificationPaneFlashSettings.defaultEnabled
    @AppStorage(NotificationSoundSettings.key) private var notificationSound = NotificationSoundSettings.defaultValue
    @AppStorage(NotificationSoundSettings.customFilePathKey)
    private var notificationSoundCustomFilePath = NotificationSoundSettings.defaultCustomFilePath
    @AppStorage(NotificationSoundSettings.customCommandKey) private var notificationCustomCommand = NotificationSoundSettings.defaultCustomCommand

    @ObservedObject private var notificationStore = TerminalNotificationStore.shared

    private var notificationPermissionStatusText: String {
        notificationStore.authorizationState.statusLabel
    }

    private var notificationPermissionStatusColor: Color {
        switch notificationStore.authorizationState {
        case .authorized, .provisional, .ephemeral: return .green
        case .denied: return .red
        case .unknown, .notDetermined: return .secondary
        }
    }

    var body: some View {
        SettingsSectionHeader(title: "Notifications")
        SettingsCard {
            SettingsCardRow("Desktop Notifications") {
                HStack(spacing: 6) {
                    Text(notificationPermissionStatusText)
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundStyle(notificationPermissionStatusColor)
                        .frame(width: 98, alignment: .trailing)

                    Button(notificationStore.authorizationState == .unknown || notificationStore.authorizationState == .notDetermined ? "Enable" : "Open Settings") {
                        switch notificationStore.authorizationState {
                        case .unknown, .notDetermined:
                            notificationStore.requestAuthorizationFromSettings()
                        case .authorized, .denied, .provisional, .ephemeral:
                            notificationStore.openNotificationSettings()
                        }
                    }
                    .controlSize(.small)

                    Button("Send Test") {
                        notificationStore.sendSettingsTestNotification()
                    }
                    .controlSize(.small)
                }
            }

            SettingsCardDivider()

            SettingsCardRow(
                String(localized: "settings.app.reorderOnNotification", defaultValue: "Reorder on Notification"),
                subtitle: String(localized: "settings.app.reorderOnNotification.subtitle", defaultValue: "Move workspaces to the top when they receive a notification. Disable for stable shortcut positions.")
            ) {
                Toggle("", isOn: $workspaceAutoReorder)
                    .labelsHidden()
                    .controlSize(.small)
            }

            SettingsCardDivider()

            SettingsCardRow(
                String(localized: "settings.app.dockBadge", defaultValue: "Dock Badge"),
                subtitle: String(localized: "settings.app.dockBadge.subtitle", defaultValue: "Show unread count on app icon (Dock and Cmd+Tab).")
            ) {
                Toggle("", isOn: $notificationDockBadgeEnabled)
                    .labelsHidden()
                    .controlSize(.small)
            }

            SettingsCardDivider()

            SettingsCardRow(
                String(localized: "settings.notifications.paneRing.title", defaultValue: "Unread Pane Ring")
            ) {
                Toggle("", isOn: $notificationPaneRingEnabled)
                    .labelsHidden()
                    .controlSize(.small)
            }

            SettingsCardDivider()

            SettingsCardRow(
                String(localized: "settings.notifications.paneFlash.title", defaultValue: "Pane Flash")
            ) {
                Toggle("", isOn: $notificationPaneFlashEnabled)
                    .labelsHidden()
                    .controlSize(.small)
            }

            SettingsCardDivider()

            SettingsCardRow(
                String(localized: "settings.notifications.sound.title", defaultValue: "Notification Sound"),
                controlWidth: notificationSoundControlWidth
            ) {
                HStack(spacing: 6) {
                    Picker("", selection: $notificationSound) {
                        ForEach(NotificationSoundSettings.systemSounds, id: \.value) { sound in
                            Text(sound.label).tag(sound.value)
                        }
                    }
                    .labelsHidden()
                }
            }

            SettingsCardDivider()

            SettingsCardRow("Notification Command") {
                TextField("say \"done\"", text: $notificationCustomCommand)
                    .textFieldStyle(.roundedBorder)
                    .frame(width: 200)
            }
        }
        .onAppear {
            notificationStore.refreshAuthorizationStatus()
        }
    }
}

// MARK: - Browser

struct TastyBrowserSettingsSection: View {
    private let pickerColumnWidth: CGFloat = 196

    @AppStorage(BrowserSearchSettings.searchEngineKey) private var browserSearchEngine = BrowserSearchSettings.defaultSearchEngine.rawValue
    @AppStorage(BrowserSearchSettings.searchSuggestionsEnabledKey) private var browserSearchSuggestionsEnabled = BrowserSearchSettings.defaultSearchSuggestionsEnabled
    @AppStorage(BrowserThemeSettings.modeKey) private var browserThemeMode = BrowserThemeSettings.defaultMode.rawValue
    @AppStorage(BrowserLinkOpenSettings.openTerminalLinksInCmuxBrowserKey) private var openTerminalLinksInCmuxBrowser = BrowserLinkOpenSettings.defaultOpenTerminalLinksInCmuxBrowser
    @AppStorage(BrowserLinkOpenSettings.interceptTerminalOpenCommandInCmuxBrowserKey)
    private var interceptTerminalOpenCommandInCmuxBrowser = BrowserLinkOpenSettings.initialInterceptTerminalOpenCommandInCmuxBrowserValue()
    @AppStorage(BrowserLinkOpenSettings.browserHostWhitelistKey) private var browserHostWhitelist = BrowserLinkOpenSettings.defaultBrowserHostWhitelist
    @AppStorage(BrowserLinkOpenSettings.browserExternalOpenPatternsKey)
    private var browserExternalOpenPatterns = BrowserLinkOpenSettings.defaultBrowserExternalOpenPatterns

    @State private var browserHistoryEntryCount: Int = 0
    @State private var showClearBrowserHistoryConfirmation = false

    private var selectedBrowserThemeMode: BrowserThemeMode {
        BrowserThemeSettings.mode(for: browserThemeMode)
    }

    private var browserThemeModeSelection: Binding<String> {
        Binding(
            get: { browserThemeMode },
            set: { browserThemeMode = BrowserThemeSettings.mode(for: $0).rawValue }
        )
    }

    var body: some View {
        SettingsSectionHeader(title: "Browser")
        SettingsCard {
            SettingsPickerRow(
                String(localized: "settings.browser.searchEngine", defaultValue: "Default Search Engine"),
                controlWidth: pickerColumnWidth,
                selection: $browserSearchEngine
            ) {
                ForEach(BrowserSearchEngine.allCases) { engine in
                    Text(engine.displayName).tag(engine.rawValue)
                }
            }

            SettingsCardDivider()

            SettingsCardRow(String(localized: "settings.browser.searchSuggestions", defaultValue: "Show Search Suggestions")) {
                Toggle("", isOn: $browserSearchSuggestionsEnabled)
                    .labelsHidden()
                    .controlSize(.small)
            }

            SettingsCardDivider()

            SettingsPickerRow(
                String(localized: "settings.browser.theme", defaultValue: "Browser Theme"),
                controlWidth: pickerColumnWidth,
                selection: browserThemeModeSelection
            ) {
                ForEach(BrowserThemeMode.allCases) { mode in
                    Text(mode.displayName).tag(mode.rawValue)
                }
            }

            SettingsCardDivider()

            SettingsCardRow(
                String(localized: "settings.browser.openTerminalLinks", defaultValue: "Open Terminal Links in cmux Browser")
            ) {
                Toggle("", isOn: $openTerminalLinksInCmuxBrowser)
                    .labelsHidden()
                    .controlSize(.small)
            }

            SettingsCardDivider()

            SettingsCardRow(
                String(localized: "settings.browser.interceptOpen", defaultValue: "Intercept open http(s) in Terminal")
            ) {
                Toggle("", isOn: $interceptTerminalOpenCommandInCmuxBrowser)
                    .labelsHidden()
                    .controlSize(.small)
            }

            if openTerminalLinksInCmuxBrowser || interceptTerminalOpenCommandInCmuxBrowser {
                SettingsCardDivider()

                VStack(alignment: .leading, spacing: 6) {
                    SettingsCardRow(
                        String(localized: "settings.browser.hostWhitelist", defaultValue: "Hosts to Open in Embedded Browser")
                    ) {
                        EmptyView()
                    }

                    TextEditor(text: $browserHostWhitelist)
                        .font(.system(.body, design: .monospaced))
                        .frame(minHeight: 60, maxHeight: 120)
                        .scrollContentBackground(.hidden)
                        .padding(6)
                        .background(Color(nsColor: .controlBackgroundColor))
                        .cornerRadius(6)
                        .overlay(
                            RoundedRectangle(cornerRadius: 6)
                                .stroke(Color(nsColor: .separatorColor), lineWidth: 0.5)
                        )
                        .padding(.horizontal, 16)
                        .padding(.bottom, 12)
                }

                SettingsCardDivider()

                VStack(alignment: .leading, spacing: 6) {
                    SettingsCardRow(
                        String(localized: "settings.browser.externalPatterns", defaultValue: "URLs to Always Open Externally")
                    ) {
                        EmptyView()
                    }

                    TextEditor(text: $browserExternalOpenPatterns)
                        .font(.system(.body, design: .monospaced))
                        .frame(minHeight: 60, maxHeight: 120)
                        .scrollContentBackground(.hidden)
                        .padding(6)
                        .background(Color(nsColor: .controlBackgroundColor))
                        .cornerRadius(6)
                        .overlay(
                            RoundedRectangle(cornerRadius: 6)
                                .stroke(Color(nsColor: .separatorColor), lineWidth: 0.5)
                        )
                        .padding(.horizontal, 16)
                        .padding(.bottom, 12)
                }
            }

            SettingsCardDivider()

            SettingsCardRow(String(localized: "settings.browser.history", defaultValue: "Browsing History")) {
                Button(String(localized: "settings.browser.history.clearButton", defaultValue: "Clear History…")) {
                    showClearBrowserHistoryConfirmation = true
                }
                .buttonStyle(.bordered)
                .controlSize(.small)
                .disabled(browserHistoryEntryCount == 0)
            }
        }
        .onAppear {
            BrowserHistoryStore.shared.loadIfNeeded()
            browserThemeMode = BrowserThemeSettings.mode(defaults: .standard).rawValue
            browserHistoryEntryCount = BrowserHistoryStore.shared.entries.count
        }
        .onReceive(BrowserHistoryStore.shared.$entries) { entries in
            browserHistoryEntryCount = entries.count
        }
        .confirmationDialog(
            String(localized: "settings.browser.history.clearDialog.title", defaultValue: "Clear browser history?"),
            isPresented: $showClearBrowserHistoryConfirmation,
            titleVisibility: .visible
        ) {
            Button(String(localized: "settings.browser.history.clearDialog.confirm", defaultValue: "Clear History"), role: .destructive) {
                BrowserHistoryStore.shared.clearHistory()
            }
            Button(String(localized: "settings.browser.history.clearDialog.cancel", defaultValue: "Cancel"), role: .cancel) {}
        }
    }
}

// MARK: - Automation

struct TastyAutomationSettingsSection: View {
    private let pickerColumnWidth: CGFloat = 196

    @AppStorage(SocketControlSettings.appStorageKey) private var socketControlMode = SocketControlSettings.defaultMode.rawValue
    @AppStorage(ClaudeCodeIntegrationSettings.hooksEnabledKey)
    private var claudeCodeHooksEnabled = ClaudeCodeIntegrationSettings.defaultHooksEnabled
    @AppStorage("cmuxPortBase") private var cmuxPortBase = 9100
    @AppStorage("cmuxPortRange") private var cmuxPortRange = 10

    @State private var socketPasswordDraft = ""
    @State private var socketPasswordStatusMessage: String?
    @State private var socketPasswordStatusIsError = false
    @State private var showOpenAccessConfirmation = false
    @State private var pendingOpenAccessMode: SocketControlMode?

    private var selectedSocketControlMode: SocketControlMode {
        SocketControlSettings.migrateMode(socketControlMode)
    }

    private var hasSocketPasswordConfigured: Bool {
        SocketControlPasswordStore.hasConfiguredPassword()
    }

    private var socketModeSelection: Binding<String> {
        Binding(
            get: { socketControlMode },
            set: { newValue in
                let normalized = SocketControlSettings.migrateMode(newValue)
                if normalized == .allowAll && selectedSocketControlMode != .allowAll {
                    pendingOpenAccessMode = normalized
                    showOpenAccessConfirmation = true
                    return
                }
                socketControlMode = normalized.rawValue
                if normalized != .password {
                    socketPasswordStatusMessage = nil
                    socketPasswordStatusIsError = false
                }
            }
        )
    }

    var body: some View {
        SettingsSectionHeader(title: "Automation")
        SettingsCard {
            SettingsPickerRow(
                String(localized: "settings.automation.socketMode", defaultValue: "Socket Control Mode"),
                subtitle: selectedSocketControlMode.description,
                controlWidth: pickerColumnWidth,
                selection: socketModeSelection
            ) {
                ForEach(SocketControlMode.uiCases) { mode in
                    Text(mode.displayName).tag(mode.rawValue)
                }
            }

            SettingsCardDivider()

            SettingsCardNote(String(localized: "settings.automation.socketMode.note", defaultValue: "Controls access to the local Unix socket for programmatic control. Choose a mode that matches your threat model."))

            if selectedSocketControlMode == .password {
                SettingsCardDivider()
                SettingsCardRow(
                    String(localized: "settings.automation.socketPassword", defaultValue: "Socket Password"),
                    subtitle: hasSocketPasswordConfigured
                        ? String(localized: "settings.automation.socketPassword.subtitleSet", defaultValue: "Stored in Application Support.")
                        : String(localized: "settings.automation.socketPassword.subtitleUnset", defaultValue: "No password set. External clients will be blocked until one is configured.")
                ) {
                    HStack(spacing: 8) {
                        SecureField(String(localized: "settings.automation.socketPassword.placeholder", defaultValue: "Password"), text: $socketPasswordDraft)
                            .textFieldStyle(.roundedBorder)
                            .frame(width: 170)
                        Button(hasSocketPasswordConfigured ? String(localized: "settings.automation.socketPassword.change", defaultValue: "Change") : String(localized: "settings.automation.socketPassword.set", defaultValue: "Set")) {
                            saveSocketPassword()
                        }
                        .buttonStyle(.bordered)
                        .controlSize(.small)
                        .disabled(socketPasswordDraft.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                        if hasSocketPasswordConfigured {
                            Button(String(localized: "settings.automation.socketPassword.clear", defaultValue: "Clear")) {
                                clearSocketPassword()
                            }
                            .buttonStyle(.bordered)
                            .controlSize(.small)
                        }
                    }
                }
                if let message = socketPasswordStatusMessage {
                    Text(message)
                        .font(.caption)
                        .foregroundStyle(socketPasswordStatusIsError ? Color.red : Color.secondary)
                        .padding(.horizontal, 14)
                        .padding(.bottom, 8)
                }
            }

            if selectedSocketControlMode == .allowAll {
                SettingsCardDivider()
                Text(String(localized: "settings.automation.openAccessWarning", defaultValue: "Warning: Full open access makes the control socket world-readable/writable on this Mac and disables auth checks. Use only for local debugging."))
                    .font(.caption)
                    .foregroundStyle(.red)
                    .padding(.horizontal, 14)
                    .padding(.vertical, 8)
            }
        }

        SettingsCard {
            SettingsCardRow(
                String(localized: "settings.automation.claudeCode", defaultValue: "Claude Code Integration"),
                subtitle: claudeCodeHooksEnabled
                    ? String(localized: "settings.automation.claudeCode.subtitleOn", defaultValue: "Sidebar shows Claude session status and notifications.")
                    : String(localized: "settings.automation.claudeCode.subtitleOff", defaultValue: "Claude Code runs without cmux integration.")
            ) {
                Toggle("", isOn: $claudeCodeHooksEnabled)
                    .labelsHidden()
                    .controlSize(.small)
            }
        }

        SettingsCard {
            SettingsCardRow(String(localized: "settings.automation.portBase", defaultValue: "Port Base"), controlWidth: pickerColumnWidth) {
                TextField("", value: $cmuxPortBase, format: .number)
                    .textFieldStyle(.roundedBorder)
                    .multilineTextAlignment(.trailing)
            }

            SettingsCardDivider()

            SettingsCardRow(String(localized: "settings.automation.portRange", defaultValue: "Port Range Size"), controlWidth: pickerColumnWidth) {
                TextField("", value: $cmuxPortRange, format: .number)
                    .textFieldStyle(.roundedBorder)
                    .multilineTextAlignment(.trailing)
            }

            SettingsCardDivider()

            SettingsCardNote(String(localized: "settings.automation.port.note", defaultValue: "Each workspace gets CMUX_PORT and CMUX_PORT_END env vars with a dedicated port range. New terminals inherit these values."))
        }
        .confirmationDialog(
            String(localized: "settings.automation.openAccess.dialog.title", defaultValue: "Enable full open access?"),
            isPresented: $showOpenAccessConfirmation,
            titleVisibility: .visible
        ) {
            Button(String(localized: "settings.automation.openAccess.dialog.confirm", defaultValue: "Enable Full Open Access"), role: .destructive) {
                socketControlMode = (pendingOpenAccessMode ?? .allowAll).rawValue
                pendingOpenAccessMode = nil
            }
            Button(String(localized: "settings.automation.openAccess.dialog.cancel", defaultValue: "Cancel"), role: .cancel) {
                pendingOpenAccessMode = nil
            }
        }
    }

    private func saveSocketPassword() {
        let trimmed = socketPasswordDraft.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            socketPasswordStatusMessage = String(localized: "settings.automation.socketPassword.enterFirst", defaultValue: "Enter a password first.")
            socketPasswordStatusIsError = true
            return
        }
        do {
            try SocketControlPasswordStore.savePassword(trimmed)
            socketPasswordDraft = ""
            socketPasswordStatusMessage = String(localized: "settings.automation.socketPassword.saved", defaultValue: "Password saved.")
            socketPasswordStatusIsError = false
        } catch {
            socketPasswordStatusMessage = String(localized: "settings.automation.socketPassword.saveFailed", defaultValue: "Failed to save password (\(error.localizedDescription)).")
            socketPasswordStatusIsError = true
        }
    }

    private func clearSocketPassword() {
        do {
            try SocketControlPasswordStore.clearPassword()
            socketPasswordDraft = ""
            socketPasswordStatusMessage = String(localized: "settings.automation.socketPassword.cleared", defaultValue: "Password cleared.")
            socketPasswordStatusIsError = false
        } catch {
            socketPasswordStatusMessage = String(localized: "settings.automation.socketPassword.clearFailed", defaultValue: "Failed to clear password (\(error.localizedDescription)).")
            socketPasswordStatusIsError = true
        }
    }
}

// MARK: - Shortcuts

struct TastyShortcutsSettingsSection: View {
    enum ShortcutTab: String, CaseIterable, Identifiable {
        case general
        case workspace
        case navigation
        case panes
        case surfaceGroup
        case panels

        var id: String { rawValue }

        var label: String {
            switch self {
            case .general: return String(localized: "settings.shortcuts.tab.general", defaultValue: "General")
            case .workspace: return String(localized: "settings.shortcuts.tab.workspace", defaultValue: "Workspace")
            case .navigation: return String(localized: "settings.shortcuts.tab.navigation", defaultValue: "Navigation")
            case .panes: return String(localized: "settings.shortcuts.tab.panes", defaultValue: "Panes")
            case .surfaceGroup: return String(localized: "settings.shortcuts.tab.surfaceGroup", defaultValue: "Surface Group")
            case .panels: return String(localized: "settings.shortcuts.tab.panels", defaultValue: "Panels")
            }
        }

        var actions: [KeyboardShortcutSettings.Action] {
            switch self {
            case .general:
                return [.toggleSidebar, .newTab, .newWindow, .closeWindow, .openFolder, .sendFeedback, .showNotifications, .jumpToUnread, .triggerFlash]
            case .workspace:
                return [.nextSidebarTab, .prevSidebarTab, .renameTab, .renameWorkspace, .closeWorkspace]
            case .navigation:
                return [.nextSurface, .prevSurface, .newSurface, .toggleTerminalCopyMode]
            case .panes:
                return [.nextPane, .prevPane, .focusLeft, .focusRight, .focusUp, .focusDown, .splitRight, .splitDown, .toggleSplitZoom, .splitBrowserRight, .splitBrowserDown]
            case .surfaceGroup:
                return [.createSurfaceGroup]
            case .panels:
                return [.openBrowser, .toggleBrowserDeveloperTools, .showBrowserJavaScriptConsole]
            }
        }
    }

    @AppStorage(ShortcutHintDebugSettings.showHintsOnCommandHoldKey)
    private var showShortcutHintsOnCommandHold = ShortcutHintDebugSettings.defaultShowHintsOnCommandHold

    @State private var shortcutResetToken = UUID()
    @State private var selectedTab: ShortcutTab = .general

    var body: some View {
        SettingsSectionHeader(title: "Keyboard Shortcuts")
        SettingsCard {
            SettingsCardRow(
                String(localized: "settings.shortcuts.showHints", defaultValue: "Show Cmd/Ctrl-Hold Shortcut Hints"),
                subtitle: showShortcutHintsOnCommandHold
                    ? String(localized: "settings.shortcuts.showHints.subtitleOn", defaultValue: "Holding Cmd (sidebar/titlebar) or Ctrl/Cmd (pane tabs) shows shortcut hint pills.")
                    : String(localized: "settings.shortcuts.showHints.subtitleOff", defaultValue: "Holding Cmd or Ctrl keeps shortcut hint pills hidden.")
            ) {
                Toggle("", isOn: $showShortcutHintsOnCommandHold)
                    .labelsHidden()
                    .controlSize(.small)
            }
        }

        Picker("", selection: $selectedTab) {
            ForEach(ShortcutTab.allCases) { tab in
                Text(tab.label).tag(tab)
            }
        }
        .pickerStyle(.segmented)
        .padding(.top, 4)

        SettingsCard {
            let actions = selectedTab.actions
            ForEach(Array(actions.enumerated()), id: \.element.id) { index, action in
                ShortcutSettingRow(action: action)
                    .padding(.horizontal, 14)
                    .padding(.vertical, 9)
                if index < actions.count - 1 {
                    SettingsCardDivider()
                }
            }
        }
        .id(shortcutResetToken)

        Text(String(localized: "settings.shortcuts.recordHint", defaultValue: "Click a shortcut value to record a new shortcut."))
            .font(.caption)
            .foregroundColor(.secondary)
            .padding(.leading, 2)
    }
}

// MARK: - Helper

enum TastySettingsHelper {
    static func relaunchApp() {
        let bundlePath = Bundle.main.bundlePath
        let task = Process()
        task.executableURL = URL(fileURLWithPath: "/bin/sh")
        task.arguments = ["-c", "sleep 1 && open -n -- \"$RELAUNCH_PATH\""]
        task.environment = ["RELAUNCH_PATH": bundlePath]
        do {
            try task.run()
        } catch {
            return
        }
        NSApplication.shared.terminate(nil)
    }
}
