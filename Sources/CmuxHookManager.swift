import Foundation
import CoreServices

/// Global hook manager for cmux.
///
/// Manages event-driven hooks that execute shell commands when conditions are met.
/// Conditions include timers (interval, once) and file system events (file/dir changes).
/// Commands run with cmux CLI available in PATH, so they can control cmux.
@MainActor
final class CmuxHookManager {
    static let shared = CmuxHookManager()

    // MARK: - Types

    enum Condition: Equatable {
        /// Fires repeatedly at a fixed interval.
        case interval(seconds: TimeInterval)
        /// Fires once after a delay, then auto-deletes.
        case once(seconds: TimeInterval)
        /// Fires when a specific file is modified.
        case fileModified(path: String)
        /// Fires when a new file is created in a directory.
        case dirCreated(path: String)
        /// Fires when any file in a directory is modified.
        case dirModified(path: String)

        var typeString: String {
            switch self {
            case .interval: return "interval"
            case .once: return "once"
            case .fileModified: return "file-modified"
            case .dirCreated: return "dir-created"
            case .dirModified: return "dir-modified"
            }
        }

        func toDictionary() -> [String: Any] {
            switch self {
            case .interval(let s):
                return ["type": "interval", "every_seconds": s]
            case .once(let s):
                return ["type": "once", "after_seconds": s]
            case .fileModified(let p):
                return ["type": "file-modified", "path": p]
            case .dirCreated(let p):
                return ["type": "dir-created", "path": p]
            case .dirModified(let p):
                return ["type": "dir-modified", "path": p]
            }
        }
    }

    enum RestartPolicy: String {
        case no = "no"
        case always = "always"
    }

    struct Hook: Identifiable {
        let id: UUID
        let condition: Condition
        let command: String
        let restart: RestartPolicy
        let createdAt: Date
        /// Environment snapshot from creation context (CMUX_SURFACE_ID, etc.)
        let environment: [String: String]

        func toDictionary() -> [String: Any] {
            var dict: [String: Any] = [
                "id": id.uuidString,
                "condition": condition.toDictionary(),
                "command": command,
                "restart": restart.rawValue,
                "created_at": ISO8601DateFormatter().string(from: createdAt),
            ]
            if !environment.isEmpty {
                // Only include cmux-related env vars in output
                let cmuxEnv = environment.filter { $0.key.hasPrefix("CMUX_") }
                if !cmuxEnv.isEmpty {
                    dict["environment"] = cmuxEnv
                }
            }
            return dict
        }
    }

    struct LogEntry {
        let date: Date
        let hookId: UUID
        let conditionType: String
        let command: String
        let exitCode: Int32
        let stderr: String?
        let triggerInfo: String?

        func toDictionary() -> [String: Any] {
            var dict: [String: Any] = [
                "date": ISO8601DateFormatter().string(from: date),
                "hook_id": hookId.uuidString,
                "condition": conditionType,
                "command": command,
                "exit_code": exitCode,
            ]
            if let stderr, !stderr.isEmpty { dict["stderr"] = stderr }
            if let triggerInfo, !triggerInfo.isEmpty { dict["trigger_info"] = triggerInfo }
            return dict
        }
    }

    // MARK: - State

    private var hooks: [UUID: Hook] = [:]
    private var timerSources: [UUID: DispatchSourceTimer] = [:]
    private var fsEventStreams: [UUID: FSEventStreamRef] = [:]
    /// Snapshot of directory contents for detecting new files (dir-created).
    private var dirSnapshots: [UUID: Set<String>] = [:]

    private(set) var executionLogs: [LogEntry] = []
    private let maxLogEntries = 200

    /// Persistence file for restart=always hooks.
    private var persistencePath: String {
        let dir = NSSearchPathForDirectoriesInDomains(.applicationSupportDirectory, .userDomainMask, true).first
            ?? NSTemporaryDirectory()
        return (dir as NSString).appendingPathComponent("cmux/hooks.json")
    }

    private init() {}

    // MARK: - Create

    @discardableResult
    func create(
        condition: Condition,
        command: String,
        restart: RestartPolicy = .no,
        environment: [String: String] = [:]
    ) -> Hook {
        let hook = Hook(
            id: UUID(),
            condition: condition,
            command: command,
            restart: restart,
            createdAt: Date(),
            environment: environment
        )
        hooks[hook.id] = hook
        startWatching(hook)

        if restart == .always {
            persistHooks()
        }

        return hook
    }

    // MARK: - List / Delete

    func list() -> [Hook] {
        Array(hooks.values).sorted { $0.createdAt < $1.createdAt }
    }

    @discardableResult
    func delete(hookId: UUID) -> Bool {
        guard let hook = hooks.removeValue(forKey: hookId) else { return false }
        stopWatching(hookId)
        if hook.restart == .always {
            persistHooks()
        }
        return true
    }

    func deleteAll() {
        let ids = Array(hooks.keys)
        for id in ids {
            stopWatching(id)
        }
        hooks.removeAll()
        persistHooks()
    }

    // MARK: - Logs

    func logs(hookId: UUID? = nil) -> [LogEntry] {
        guard let hookId else { return executionLogs }
        return executionLogs.filter { $0.hookId == hookId }
    }

    // MARK: - Persistence (restart=always)

    func restorePersistedHooks() {
        let path = persistencePath
        guard FileManager.default.fileExists(atPath: path),
              let data = try? Data(contentsOf: URL(fileURLWithPath: path)),
              let array = try? JSONSerialization.jsonObject(with: data) as? [[String: Any]] else {
            return
        }

        for entry in array {
            guard let condDict = entry["condition"] as? [String: Any],
                  let command = entry["command"] as? String,
                  let condition = parseCondition(condDict) else { continue }

            let env = entry["environment"] as? [String: String] ?? [:]
            create(condition: condition, command: command, restart: .always, environment: env)
        }
    }

    private func persistHooks() {
        let persistable = hooks.values.filter { $0.restart == .always }
        let array = persistable.map { hook -> [String: Any] in
            var dict = hook.condition.toDictionary()
            return [
                "condition": dict,
                "command": hook.command,
                "environment": hook.environment.filter { $0.key.hasPrefix("CMUX_") },
            ]
        }

        let dir = (persistencePath as NSString).deletingLastPathComponent
        try? FileManager.default.createDirectory(atPath: dir, withIntermediateDirectories: true)

        if let data = try? JSONSerialization.data(withJSONObject: array, options: [.prettyPrinted]) {
            try? data.write(to: URL(fileURLWithPath: persistencePath))
        }
    }

    private func parseCondition(_ dict: [String: Any]) -> Condition? {
        guard let type = dict["type"] as? String else { return nil }
        switch type {
        case "interval":
            guard let secs = dict["every_seconds"] as? TimeInterval else { return nil }
            return .interval(seconds: secs)
        case "once":
            guard let secs = dict["after_seconds"] as? TimeInterval else { return nil }
            return .once(seconds: secs)
        case "file-modified":
            guard let path = dict["path"] as? String else { return nil }
            return .fileModified(path: path)
        case "dir-created":
            guard let path = dict["path"] as? String else { return nil }
            return .dirCreated(path: path)
        case "dir-modified":
            guard let path = dict["path"] as? String else { return nil }
            return .dirModified(path: path)
        default:
            return nil
        }
    }

    // MARK: - Watching

    private func startWatching(_ hook: Hook) {
        switch hook.condition {
        case .interval(let seconds):
            startTimer(hook: hook, interval: seconds, repeats: true)
        case .once(let seconds):
            startTimer(hook: hook, interval: seconds, repeats: false)
        case .fileModified(let path):
            startFSEventStream(hook: hook, path: path, mode: .fileModified)
        case .dirCreated(let path):
            startFSEventStream(hook: hook, path: path, mode: .dirCreated)
        case .dirModified(let path):
            startFSEventStream(hook: hook, path: path, mode: .dirModified)
        }
    }

    private func stopWatching(_ hookId: UUID) {
        if let timer = timerSources.removeValue(forKey: hookId) {
            timer.cancel()
        }
        if let stream = fsEventStreams.removeValue(forKey: hookId) {
            FSEventStreamStop(stream)
            FSEventStreamInvalidate(stream)
            FSEventStreamRelease(stream)
        }
        dirSnapshots.removeValue(forKey: hookId)
    }

    // MARK: - Timer hooks

    private func startTimer(hook: Hook, interval: TimeInterval, repeats: Bool) {
        let timer = DispatchSource.makeTimerSource(queue: .global(qos: .utility))
        if repeats {
            timer.schedule(deadline: .now() + interval, repeating: interval)
        } else {
            timer.schedule(deadline: .now() + interval)
        }

        let hookId = hook.id
        timer.setEventHandler { [weak self] in
            Task { @MainActor in
                guard let self, self.hooks[hookId] != nil else { return }
                self.executeCommand(hook: self.hooks[hookId]!, triggerInfo: nil)

                if !repeats {
                    self.delete(hookId: hookId)
                }
            }
        }

        timerSources[hook.id] = timer
        timer.resume()
    }

    // MARK: - FSEvent hooks

    fileprivate enum FSWatchMode {
        case fileModified
        case dirCreated
        case dirModified
    }

    private func startFSEventStream(hook: Hook, path: String, mode: FSWatchMode) {
        let resolvedPath = (path as NSString).expandingTildeInPath
        let watchPath: String

        switch mode {
        case .fileModified:
            // Watch the parent directory, filter for our specific file
            watchPath = (resolvedPath as NSString).deletingLastPathComponent
        case .dirCreated, .dirModified:
            watchPath = resolvedPath
        }

        // Take initial snapshot for dir-created
        if mode == .dirCreated {
            dirSnapshots[hook.id] = snapshotDirectory(watchPath)
        }

        let hookId = hook.id
        let targetFile = (resolvedPath as NSString).lastPathComponent

        var context = FSEventStreamContext()
        let info = Unmanaged.passRetained(FSEventCallbackInfo(
            manager: self,
            hookId: hookId,
            mode: mode,
            targetFile: targetFile,
            watchPath: watchPath
        ))
        context.info = info.toOpaque()
        context.release = { ptr in
            guard let ptr else { return }
            Unmanaged<FSEventCallbackInfo>.fromOpaque(ptr).release()
        }

        let pathsToWatch = [watchPath] as CFArray
        let flags = UInt32(kFSEventStreamCreateFlagUseCFTypes | kFSEventStreamCreateFlagFileEvents)

        guard let stream = FSEventStreamCreate(
            nil,
            fsEventCallback,
            &context,
            pathsToWatch,
            FSEventStreamEventId(kFSEventStreamEventIdSinceNow),
            0.5,  // latency
            flags
        ) else { return }

        FSEventStreamScheduleWithRunLoop(stream, CFRunLoopGetMain(), CFRunLoopMode.defaultMode.rawValue)
        FSEventStreamStart(stream)
        fsEventStreams[hook.id] = stream
    }

    private func snapshotDirectory(_ path: String) -> Set<String> {
        guard let items = try? FileManager.default.contentsOfDirectory(atPath: path) else {
            return []
        }
        return Set(items)
    }

    fileprivate func handleFSEvent(hookId: UUID, mode: FSWatchMode, targetFile: String, watchPath: String, eventPath: String, flags: UInt32) {
        guard let hook = hooks[hookId] else { return }

        let eventFileName = (eventPath as NSString).lastPathComponent

        switch mode {
        case .fileModified:
            // Only fire if the modified file matches our target
            guard eventFileName == targetFile else { return }
            let isModified = (flags & UInt32(kFSEventStreamEventFlagItemModified)) != 0
            guard isModified else { return }
            executeCommand(hook: hook, triggerInfo: eventPath)

        case .dirCreated:
            let isCreated = (flags & UInt32(kFSEventStreamEventFlagItemCreated)) != 0
            let isFile = (flags & UInt32(kFSEventStreamEventFlagItemIsFile)) != 0
            guard isCreated && isFile else { return }

            // Verify it's genuinely new
            let currentSnapshot = snapshotDirectory(watchPath)
            let previousSnapshot = dirSnapshots[hookId] ?? []
            let newFiles = currentSnapshot.subtracting(previousSnapshot)
            dirSnapshots[hookId] = currentSnapshot

            if newFiles.contains(eventFileName) {
                executeCommand(hook: hook, triggerInfo: eventPath)
            }

        case .dirModified:
            let isModified = (flags & UInt32(kFSEventStreamEventFlagItemModified)) != 0
            let isFile = (flags & UInt32(kFSEventStreamEventFlagItemIsFile)) != 0
            guard isModified && isFile else { return }
            executeCommand(hook: hook, triggerInfo: eventPath)
        }
    }

    // MARK: - Command execution

    private func executeCommand(hook: Hook, triggerInfo: String?) {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/bin/sh")
        process.arguments = ["-c", hook.command]

        var env = ProcessInfo.processInfo.environment
        // Inject hook context
        env["CMUX_HOOK_ID"] = hook.id.uuidString
        env["CMUX_HOOK_CONDITION"] = hook.condition.typeString
        if let triggerInfo {
            env["CMUX_HOOK_FILE"] = triggerInfo
        }
        // Restore creator's cmux env (surface, workspace, socket)
        for (key, value) in hook.environment {
            env[key] = value
        }
        process.environment = env

        process.standardOutput = FileHandle.nullDevice
        let stderrPipe = Pipe()
        process.standardError = stderrPipe

        let hookId = hook.id
        let condType = hook.condition.typeString
        let command = hook.command

        do {
            try process.run()
        } catch {
            appendLog(LogEntry(
                date: Date(), hookId: hookId, conditionType: condType,
                command: command, exitCode: -1,
                stderr: error.localizedDescription, triggerInfo: triggerInfo
            ))
            return
        }

        let capturedProcess = process
        let capturedPipe = stderrPipe
        Task.detached { [weak self] in
            capturedProcess.waitUntilExit()
            let exitCode = capturedProcess.terminationStatus
            let stderrData = capturedPipe.fileHandleForReading.readDataToEndOfFile()
            let stderrStr = String(data: stderrData, encoding: .utf8)?
                .trimmingCharacters(in: .whitespacesAndNewlines)
            let entry = LogEntry(
                date: Date(), hookId: hookId, conditionType: condType,
                command: command, exitCode: exitCode,
                stderr: stderrStr, triggerInfo: triggerInfo
            )
            await self?.appendLog(entry)
        }
    }

    private func appendLog(_ entry: LogEntry) {
        executionLogs.append(entry)
        if executionLogs.count > maxLogEntries {
            executionLogs.removeFirst(executionLogs.count - maxLogEntries)
        }
    }
}

// MARK: - FSEvent callback bridge

private final class FSEventCallbackInfo {
    weak var manager: CmuxHookManager?
    let hookId: UUID
    let mode: CmuxHookManager.FSWatchMode
    let targetFile: String
    let watchPath: String

    init(manager: CmuxHookManager, hookId: UUID, mode: CmuxHookManager.FSWatchMode, targetFile: String, watchPath: String) {
        self.manager = manager
        self.hookId = hookId
        self.mode = mode
        self.targetFile = targetFile
        self.watchPath = watchPath
    }
}

private func fsEventCallback(
    streamRef: ConstFSEventStreamRef,
    clientInfo: UnsafeMutableRawPointer?,
    numEvents: Int,
    eventPaths: UnsafeMutableRawPointer,
    eventFlags: UnsafePointer<FSEventStreamEventFlags>,
    eventIds: UnsafePointer<FSEventStreamEventId>
) {
    guard let clientInfo else { return }
    let info = Unmanaged<FSEventCallbackInfo>.fromOpaque(clientInfo).takeUnretainedValue()
    guard let manager = info.manager else { return }

    let paths = Unmanaged<CFArray>.fromOpaque(eventPaths).takeUnretainedValue()

    for i in 0..<numEvents {
        guard let pathRef = CFArrayGetValueAtIndex(paths, i) else { continue }
        let path = Unmanaged<CFString>.fromOpaque(pathRef).takeUnretainedValue() as String
        let flags = eventFlags[i]

        Task { @MainActor in
            manager.handleFSEvent(
                hookId: info.hookId,
                mode: info.mode,
                targetFile: info.targetFile,
                watchPath: info.watchPath,
                eventPath: path,
                flags: flags
            )
        }
    }
}
