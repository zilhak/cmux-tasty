import SwiftUI
import MarkdownUI

/// SwiftUI view for the ExplorerPanel — file tree sidebar + content viewer.
struct ExplorerPanelView: View {
    @ObservedObject var panel: ExplorerPanel
    let isFocused: Bool
    let isVisibleInUI: Bool
    let portalPriority: Int
    let onRequestPanelFocus: () -> Void

    @State private var focusFlashOpacity: Double = 0.0
    @State private var focusFlashAnimationGeneration: Int = 0
    @State private var sidebarWidth: CGFloat = 200
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        HStack(spacing: 0) {
            // Left: file tree
            sidebarView
                .frame(width: sidebarWidth)

            // Divider (draggable)
            Rectangle()
                .fill(Color(nsColor: .separatorColor))
                .frame(width: 1)
                .gesture(
                    DragGesture()
                        .onChanged { value in
                            let newWidth = sidebarWidth + value.translation.width
                            sidebarWidth = max(120, min(400, newWidth))
                        }
                )
                .onHover { hovering in
                    if hovering {
                        NSCursor.resizeLeftRight.push()
                    } else {
                        NSCursor.pop()
                    }
                }

            // Right: content viewer
            contentView
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .background(backgroundColor)
        .overlay {
            RoundedRectangle(cornerRadius: FocusFlashPattern.ringCornerRadius)
                .stroke(cmuxAccentColor().opacity(focusFlashOpacity), lineWidth: 3)
                .shadow(color: cmuxAccentColor().opacity(focusFlashOpacity * 0.35), radius: 10)
                .padding(FocusFlashPattern.ringInset)
                .allowsHitTesting(false)
        }
        .onChange(of: panel.focusFlashToken) { _ in
            triggerFocusFlashAnimation()
        }
    }

    // MARK: - Sidebar (file tree)

    private var sidebarView: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                Image(systemName: "folder")
                    .foregroundColor(.secondary)
                    .font(.system(size: 12))
                Text(panel.displayTitle)
                    .font(.system(size: 12, weight: .medium))
                    .lineLimit(1)
                Spacer()
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(sidebarHeaderColor)

            Divider()

            // Tree
            ScrollView {
                LazyVStack(alignment: .leading, spacing: 0) {
                    if let children = panel.rootNode.children {
                        ForEach(children) { node in
                            fileTreeRow(node: node, depth: 0)
                        }
                    }
                }
                .padding(.vertical, 4)
            }
        }
        .background(sidebarBackgroundColor)
    }

    private func fileTreeRow(node: FileNode, depth: Int) -> AnyView {
        AnyView(VStack(alignment: .leading, spacing: 0) {
            HStack(spacing: 4) {
                // Indent
                Spacer()
                    .frame(width: CGFloat(depth) * 16 + 8)

                // Expand arrow for directories
                if node.isDirectory {
                    Image(systemName: node.isExpanded ? "chevron.down" : "chevron.right")
                        .font(.system(size: 9))
                        .foregroundColor(.secondary)
                        .frame(width: 12)
                } else {
                    Spacer().frame(width: 12)
                }

                // Icon
                Image(systemName: node.icon)
                    .font(.system(size: 11))
                    .foregroundColor(node.isDirectory ? .accentColor : .secondary)
                    .frame(width: 16)

                // Name
                Text(node.name)
                    .font(.system(size: 12))
                    .foregroundColor(node.path == panel.selectedFilePath ? .white : .primary)
                    .lineLimit(1)

                Spacer()
            }
            .padding(.vertical, 3)
            .background(
                RoundedRectangle(cornerRadius: 4)
                    .fill(node.path == panel.selectedFilePath ? Color.accentColor.opacity(0.8) : Color.clear)
            )
            .contentShape(Rectangle())
            .onTapGesture {
                onRequestPanelFocus()
                if node.isDirectory {
                    panel.toggleDirectory(node: node)
                } else if node.isViewable {
                    panel.selectFile(node.path)
                }
            }

            // Children (if expanded)
            if node.isDirectory && node.isExpanded, let children = node.children {
                ForEach(children) { child in
                    fileTreeRow(node: child, depth: depth + 1)
                }
            }
        })
    }

    // MARK: - Content viewer

    private var contentView: some View {
        VStack(spacing: 0) {
            if let path = panel.selectedFilePath {
                // Toolbar
                contentToolbar(path: path)
                Divider()

                if panel.isFileUnavailable {
                    fileUnavailableView
                } else if panel.isEditMode {
                    editView
                } else if panel.isMarkdownFile && !panel.isRawMode {
                    markdownView
                } else {
                    rawTextView
                }
            } else {
                noSelectionView
            }
        }
    }

    private func contentToolbar(path: String) -> some View {
        HStack(spacing: 8) {
            // File path
            Image(systemName: panel.isMarkdownFile ? "doc.richtext" : "doc.text")
                .foregroundColor(.secondary)
                .font(.system(size: 11))
            Text((path as NSString).lastPathComponent)
                .font(.system(size: 12, weight: .medium))
                .lineLimit(1)

            if panel.hasUnsavedChanges {
                Circle()
                    .fill(Color.orange)
                    .frame(width: 6, height: 6)
            }

            Spacer()

            // Mode toggles
            if panel.isMarkdownFile {
                Button(action: { panel.isRawMode.toggle() }) {
                    Text(panel.isRawMode ? "Preview" : "Raw")
                        .font(.system(size: 11))
                }
                .buttonStyle(.borderless)
            }

            Button(action: {
                if panel.isEditMode && panel.hasUnsavedChanges {
                    panel.saveFile()
                }
                panel.toggleEditMode()
            }) {
                HStack(spacing: 3) {
                    Image(systemName: panel.isEditMode ? "checkmark.circle" : "pencil")
                        .font(.system(size: 11))
                    Text(panel.isEditMode ? (panel.hasUnsavedChanges ? "Save" : "Done") : "Edit")
                        .font(.system(size: 11))
                }
            }
            .buttonStyle(.borderless)
            .keyboardShortcut("s", modifiers: .command)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 6)
        .background(sidebarHeaderColor)
    }

    // MARK: - Markdown rendered view

    private var markdownView: some View {
        ScrollView {
            Markdown(panel.fileContent)
                .markdownTheme(explorerMarkdownTheme)
                .textSelection(.enabled)
                .padding(.horizontal, 24)
                .padding(.vertical, 16)
        }
    }

    // MARK: - Raw text view

    private var rawTextView: some View {
        ScrollView([.horizontal, .vertical]) {
            Text(panel.fileContent)
                .font(.system(size: 13, design: .monospaced))
                .textSelection(.enabled)
                .padding(16)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    // MARK: - Edit view

    private var editView: some View {
        ExplorerTextEditorView(
            text: Binding(
                get: { panel.editedContent },
                set: { panel.updateEditedContent($0) }
            )
        )
    }

    // MARK: - Empty states

    private var noSelectionView: some View {
        VStack(spacing: 12) {
            Image(systemName: "doc.text.magnifyingglass")
                .font(.system(size: 40))
                .foregroundColor(.secondary)
            Text("Select a file to view")
                .font(.headline)
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private var fileUnavailableView: some View {
        VStack(spacing: 12) {
            Image(systemName: "doc.questionmark")
                .font(.system(size: 40))
                .foregroundColor(.secondary)
            Text("File unavailable")
                .font(.headline)
                .foregroundColor(.primary)
            Text(panel.selectedFilePath ?? "")
                .font(.system(size: 12, design: .monospaced))
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    // MARK: - Colors

    private var backgroundColor: Color {
        colorScheme == .dark
            ? Color(nsColor: NSColor(white: 0.12, alpha: 1.0))
            : Color(nsColor: NSColor(white: 0.98, alpha: 1.0))
    }

    private var sidebarBackgroundColor: Color {
        colorScheme == .dark
            ? Color(nsColor: NSColor(white: 0.10, alpha: 1.0))
            : Color(nsColor: NSColor(white: 0.95, alpha: 1.0))
    }

    private var sidebarHeaderColor: Color {
        colorScheme == .dark
            ? Color(nsColor: NSColor(white: 0.14, alpha: 1.0))
            : Color(nsColor: NSColor(white: 0.92, alpha: 1.0))
    }

    // MARK: - Theme

    private var explorerMarkdownTheme: Theme {
        let isDark = colorScheme == .dark
        return Theme()
            .text {
                ForegroundColor(isDark ? .white.opacity(0.9) : .primary)
                FontSize(14)
            }
            .heading1 { configuration in
                VStack(alignment: .leading, spacing: 8) {
                    configuration.label
                        .markdownTextStyle { FontSize(24); FontWeight(.bold) }
                    Divider()
                }
                .padding(.top, 16)
                .padding(.bottom, 8)
            }
            .heading2 { configuration in
                configuration.label
                    .markdownTextStyle { FontSize(20); FontWeight(.semibold) }
                    .padding(.top, 12)
                    .padding(.bottom, 4)
            }
            .heading3 { configuration in
                configuration.label
                    .markdownTextStyle { FontSize(16); FontWeight(.semibold) }
                    .padding(.top, 8)
                    .padding(.bottom, 2)
            }
            .codeBlock { configuration in
                ScrollView(.horizontal) {
                    configuration.label
                        .markdownTextStyle {
                            FontFamilyVariant(.monospaced)
                            FontSize(13)
                        }
                        .padding(12)
                }
                .background(isDark ? Color(white: 0.08) : Color(white: 0.94))
                .cornerRadius(6)
                .padding(.vertical, 4)
            }
            .code {
                FontFamilyVariant(.monospaced)
                FontSize(13)
                BackgroundColor(isDark ? Color(white: 0.18) : Color(white: 0.90))
            }
    }

    // MARK: - Focus flash

    private func triggerFocusFlashAnimation() {
        let generation = focusFlashAnimationGeneration + 1
        focusFlashAnimationGeneration = generation

        for segment in FocusFlashPattern.segments {
            DispatchQueue.main.asyncAfter(deadline: .now() + segment.delay) {
                guard focusFlashAnimationGeneration == generation else { return }
                withAnimation(.easeInOut(duration: segment.duration)) {
                    focusFlashOpacity = segment.targetOpacity
                }
            }
        }
    }
}

// MARK: - Text editor wrapper (NSTextView for proper editing)

struct ExplorerTextEditorView: NSViewRepresentable {
    @Binding var text: String

    func makeNSView(context: Context) -> NSScrollView {
        let scrollView = NSTextView.scrollableTextView()
        let textView = scrollView.documentView as! NSTextView

        textView.isEditable = true
        textView.isSelectable = true
        textView.allowsUndo = true
        textView.isRichText = false
        textView.font = NSFont.monospacedSystemFont(ofSize: 13, weight: .regular)
        textView.textColor = .textColor
        textView.backgroundColor = .textBackgroundColor
        textView.isAutomaticQuoteSubstitutionEnabled = false
        textView.isAutomaticDashSubstitutionEnabled = false
        textView.isAutomaticTextReplacementEnabled = false
        textView.delegate = context.coordinator

        textView.string = text
        return scrollView
    }

    func updateNSView(_ scrollView: NSScrollView, context: Context) {
        let textView = scrollView.documentView as! NSTextView
        if textView.string != text {
            let selectedRange = textView.selectedRange()
            textView.string = text
            textView.setSelectedRange(selectedRange)
        }
    }

    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }

    class Coordinator: NSObject, NSTextViewDelegate {
        let parent: ExplorerTextEditorView

        init(_ parent: ExplorerTextEditorView) {
            self.parent = parent
        }

        func textDidChange(_ notification: Notification) {
            guard let textView = notification.object as? NSTextView else { return }
            parent.text = textView.string
        }
    }
}
