import Foundation
import Combine

/// A file-tree node for the explorer sidebar.
@MainActor
final class FileNode: Identifiable, ObservableObject {
    let id: UUID
    let name: String
    let path: String
    let isDirectory: Bool
    @Published var children: [FileNode]?
    @Published var isExpanded: Bool = false

    init(name: String, path: String, isDirectory: Bool, children: [FileNode]? = nil) {
        self.id = UUID()
        self.name = name
        self.path = path
        self.isDirectory = isDirectory
        self.children = children
    }

    var icon: String {
        if isDirectory {
            return isExpanded ? "folder.fill" : "folder"
        }
        let ext = (name as NSString).pathExtension.lowercased()
        switch ext {
        case "md", "markdown": return "doc.richtext"
        case "json": return "curlybraces"
        case "swift": return "swift"
        case "txt", "text": return "doc.text"
        case "yml", "yaml": return "list.bullet"
        case "sh", "bash", "zsh": return "terminal"
        default: return "doc"
        }
    }

    /// Whether this file type is viewable in the explorer.
    var isViewable: Bool {
        guard !isDirectory else { return false }
        let ext = (name as NSString).pathExtension.lowercased()
        return ["md", "markdown", "txt", "text", "json", "yml", "yaml", "toml",
                "sh", "bash", "zsh", "swift", "ts", "js", "py", "rb", "go",
                "rs", "java", "kt", "c", "cpp", "h", "css", "html", "xml",
                "env", "gitignore", "dockerfile", "makefile", "cfg", "ini", "conf",
                "log", "csv", ""].contains(ext)
            || name.hasPrefix(".")  // dotfiles
    }

    var isMarkdown: Bool {
        let ext = (name as NSString).pathExtension.lowercased()
        return ext == "md" || ext == "markdown"
    }
}

/// A panel that provides a file explorer (tree) + file viewer with edit mode.
@MainActor
final class ExplorerPanel: Panel, ObservableObject {
    let id: UUID
    let panelType: PanelType = .explorer

    /// Root directory path being explored.
    let rootPath: String

    /// Workspace this panel belongs to.
    private(set) var workspaceId: UUID

    /// The file tree root node.
    @Published private(set) var rootNode: FileNode

    /// Currently selected file path (nil = nothing selected).
    @Published var selectedFilePath: String?

    /// Content of the currently selected file.
    @Published private(set) var fileContent: String = ""

    /// Whether the selected file is a markdown file.
    @Published private(set) var isMarkdownFile: Bool = false

    /// View mode: rendered (for markdown) or raw text.
    @Published var isRawMode: Bool = false

    /// Edit mode: when true, content is editable.
    @Published var isEditMode: Bool = false

    /// Edited content (only used in edit mode).
    @Published var editedContent: String = ""

    /// Whether edited content differs from disk.
    @Published private(set) var hasUnsavedChanges: Bool = false

    /// Tab display title.
    @Published private(set) var displayTitle: String = ""

    /// Tab icon.
    var displayIcon: String? { "folder" }

    /// Whether the file is unavailable.
    @Published private(set) var isFileUnavailable: Bool = false

    /// Focus flash token.
    @Published private(set) var focusFlashToken: Int = 0

    var isDirty: Bool { hasUnsavedChanges }

    // MARK: - File watching

    private nonisolated(unsafe) var dirWatchSource: DispatchSourceFileSystemObject?
    private var dirDescriptor: Int32 = -1
    private nonisolated(unsafe) var fileWatchSource: DispatchSourceFileSystemObject?
    private var fileDescriptor: Int32 = -1
    private var isClosed: Bool = false
    private let watchQueue = DispatchQueue(label: "com.cmux.explorer-file-watch", qos: .utility)

    // MARK: - Init

    init(workspaceId: UUID, rootPath: String) {
        let resolved = (rootPath as NSString).expandingTildeInPath
        let title = (resolved as NSString).lastPathComponent
        self.id = UUID()
        self.workspaceId = workspaceId
        self.rootPath = resolved
        self.displayTitle = title
        self.rootNode = FileNode(name: title, path: resolved, isDirectory: true)

        loadDirectory(node: rootNode)
        rootNode.isExpanded = true
        startDirectoryWatcher()
    }

    // MARK: - Panel protocol

    func focus() {}
    func unfocus() {}

    func close() {
        isClosed = true
        stopDirectoryWatcher()
        stopFileWatcher()
    }

    func triggerFlash(reason: WorkspaceAttentionFlashReason) {
        focusFlashToken += 1
    }

    // MARK: - File tree

    func loadDirectory(node: FileNode) {
        guard node.isDirectory else { return }
        let fm = FileManager.default
        guard let items = try? fm.contentsOfDirectory(atPath: node.path) else {
            node.children = []
            return
        }

        let sorted = items.sorted { lhs, rhs in
            let lhsPath = (node.path as NSString).appendingPathComponent(lhs)
            let rhsPath = (node.path as NSString).appendingPathComponent(rhs)
            var lhsIsDir: ObjCBool = false
            var rhsIsDir: ObjCBool = false
            fm.fileExists(atPath: lhsPath, isDirectory: &lhsIsDir)
            fm.fileExists(atPath: rhsPath, isDirectory: &rhsIsDir)
            if lhsIsDir.boolValue != rhsIsDir.boolValue {
                return lhsIsDir.boolValue  // directories first
            }
            return lhs.localizedCaseInsensitiveCompare(rhs) == .orderedAscending
        }

        node.children = sorted.compactMap { name -> FileNode? in
            // Skip hidden files except common dotfiles
            if name.hasPrefix(".") && ![".", ".env", ".gitignore", ".claude"].contains(where: { name.hasPrefix($0) }) {
                return nil
            }
            let fullPath = (node.path as NSString).appendingPathComponent(name)
            var isDir: ObjCBool = false
            guard fm.fileExists(atPath: fullPath, isDirectory: &isDir) else { return nil }
            return FileNode(name: name, path: fullPath, isDirectory: isDir.boolValue)
        }
    }

    func toggleDirectory(node: FileNode) {
        guard node.isDirectory else { return }
        node.isExpanded.toggle()
        if node.isExpanded && (node.children == nil || node.children?.isEmpty == true) {
            loadDirectory(node: node)
        }
    }

    // MARK: - File selection

    func selectFile(_ path: String) {
        // Save unsaved changes warning could go here
        selectedFilePath = path
        isEditMode = false
        hasUnsavedChanges = false
        loadFileContent(path)
        stopFileWatcher()
        startFileWatcher(path)
    }

    private func loadFileContent(_ path: String) {
        let ext = (path as NSString).pathExtension.lowercased()
        isMarkdownFile = (ext == "md" || ext == "markdown")
        isRawMode = !isMarkdownFile

        guard let data = FileManager.default.contents(atPath: path) else {
            fileContent = ""
            isFileUnavailable = true
            return
        }
        isFileUnavailable = false
        fileContent = String(data: data, encoding: .utf8)
            ?? String(data: data, encoding: .isoLatin1)
            ?? "(binary file)"
        editedContent = fileContent
    }

    // MARK: - Edit mode

    func toggleEditMode() {
        if isEditMode {
            // Exiting edit mode — discard unsaved changes
            editedContent = fileContent
            hasUnsavedChanges = false
        } else {
            editedContent = fileContent
        }
        isEditMode.toggle()
    }

    func updateEditedContent(_ newContent: String) {
        editedContent = newContent
        hasUnsavedChanges = (editedContent != fileContent)
    }

    func saveFile() {
        guard let path = selectedFilePath, hasUnsavedChanges else { return }
        guard let data = editedContent.data(using: .utf8) else { return }
        do {
            try data.write(to: URL(fileURLWithPath: path), options: .atomic)
            fileContent = editedContent
            hasUnsavedChanges = false
        } catch {
            NSLog("[ExplorerPanel] Failed to save: \(error.localizedDescription)")
        }
    }

    // MARK: - Directory watching

    private func startDirectoryWatcher() {
        let fd = open(rootPath, O_EVTONLY)
        guard fd >= 0 else { return }
        dirDescriptor = fd

        let source = DispatchSource.makeFileSystemObjectSource(
            fileDescriptor: fd,
            eventMask: [.write, .rename, .delete],
            queue: watchQueue
        )
        source.setEventHandler { [weak self] in
            Task { @MainActor in
                guard let self, !self.isClosed else { return }
                self.loadDirectory(node: self.rootNode)
            }
        }
        source.setCancelHandler { Darwin.close(fd) }
        dirWatchSource = source
        source.resume()
    }

    private func stopDirectoryWatcher() {
        dirWatchSource?.cancel()
        dirWatchSource = nil
        if dirDescriptor >= 0 { Darwin.close(dirDescriptor); dirDescriptor = -1 }
    }

    // MARK: - File watching (selected file)

    private func startFileWatcher(_ path: String) {
        let fd = open(path, O_EVTONLY)
        guard fd >= 0 else { return }
        fileDescriptor = fd

        let source = DispatchSource.makeFileSystemObjectSource(
            fileDescriptor: fd,
            eventMask: [.write, .extend, .delete, .rename],
            queue: watchQueue
        )
        source.setEventHandler { [weak self] in
            Task { @MainActor in
                guard let self, !self.isClosed, let selectedPath = self.selectedFilePath else { return }
                if !self.isEditMode {
                    self.loadFileContent(selectedPath)
                }
            }
        }
        source.setCancelHandler { Darwin.close(fd) }
        fileWatchSource = source
        source.resume()
    }

    private func stopFileWatcher() {
        fileWatchSource?.cancel()
        fileWatchSource = nil
        if fileDescriptor >= 0 { Darwin.close(fileDescriptor); fileDescriptor = -1 }
    }
}
