import Foundation

/// Manages per-surface event hooks.
///
/// Hooks are shell commands that execute when specific events fire on a surface.
/// Each hook is identified by a unique ID and scoped to a (surfaceId, event) pair.
@MainActor
final class SurfaceHookManager {
    static let shared = SurfaceHookManager()

    /// Supported hook event types.
    enum Event: String, CaseIterable {
        case processExit = "process-exit"
        case claudeIdle = "claude-idle"
    }

    /// A registered hook entry.
    struct Hook: Identifiable {
        let id: UUID
        let surfaceId: UUID
        let event: Event
        let command: String
        let createdAt: Date

        func toDictionary() -> [String: Any] {
            [
                "id": id.uuidString,
                "surface_id": surfaceId.uuidString,
                "event": event.rawValue,
                "command": command,
                "created_at": ISO8601DateFormatter().string(from: createdAt),
            ]
        }
    }

    /// surfaceId -> event -> [Hook]
    private var hooks: [UUID: [Event: [Hook]]] = [:]

    private init() {}

    // MARK: - Registration

    /// Register a hook. Returns the created hook.
    @discardableResult
    func setHook(surfaceId: UUID, event: Event, command: String) -> Hook {
        let hook = Hook(
            id: UUID(),
            surfaceId: surfaceId,
            event: event,
            command: command,
            createdAt: Date()
        )
        hooks[surfaceId, default: [:]][event, default: []].append(hook)
        return hook
    }

    /// List all hooks for a surface, optionally filtered by event.
    func listHooks(surfaceId: UUID, event: Event? = nil) -> [Hook] {
        guard let surfaceHooks = hooks[surfaceId] else { return [] }
        if let event {
            return surfaceHooks[event] ?? []
        }
        return surfaceHooks.values.flatMap { $0 }
    }

    /// Remove a hook by its ID. Returns true if found and removed.
    @discardableResult
    func unsetHook(hookId: UUID) -> Bool {
        for (surfaceId, eventMap) in hooks {
            for (event, hookList) in eventMap {
                if let idx = hookList.firstIndex(where: { $0.id == hookId }) {
                    hooks[surfaceId]?[event]?.remove(at: idx)
                    // Clean up empty containers
                    if hooks[surfaceId]?[event]?.isEmpty == true {
                        hooks[surfaceId]?.removeValue(forKey: event)
                    }
                    if hooks[surfaceId]?.isEmpty == true {
                        hooks.removeValue(forKey: surfaceId)
                    }
                    return true
                }
            }
        }
        return false
    }

    /// Remove all hooks for a surface. Called when a surface is closed.
    func removeAllHooks(surfaceId: UUID) {
        hooks.removeValue(forKey: surfaceId)
    }

    /// Returns all surface IDs that have hooks registered for the given event.
    func surfacesWithHooks(for event: Event) -> [UUID] {
        hooks.compactMap { (surfaceId, eventMap) in
            eventMap[event]?.isEmpty == false ? surfaceId : nil
        }
    }

    // MARK: - Firing

    /// Fire all hooks registered for the given event on a surface.
    /// Hooks run asynchronously in background processes and do not block the caller.
    func fire(event: Event, surfaceId: UUID, environment: [String: String] = [:]) {
        guard let eventHooks = hooks[surfaceId]?[event], !eventHooks.isEmpty else { return }

        var env = environment
        env["CMUX_HOOK_EVENT"] = event.rawValue
        env["CMUX_HOOK_SURFACE_ID"] = surfaceId.uuidString

        for hook in eventHooks {
            env["CMUX_HOOK_ID"] = hook.id.uuidString
            executeHookCommand(hook.command, environment: env)
        }
    }

    // MARK: - Private

    private func executeHookCommand(_ command: String, environment: [String: String]) {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/bin/sh")
        process.arguments = ["-c", command]

        var processEnv = ProcessInfo.processInfo.environment
        for (key, value) in environment {
            processEnv[key] = value
        }
        process.environment = processEnv

        // Detach stdout/stderr so the hook doesn't inherit the app's file descriptors
        process.standardOutput = FileHandle.nullDevice
        process.standardError = FileHandle.nullDevice

        do {
            try process.run()
        } catch {
#if DEBUG
            NSLog("[SurfaceHookManager] Failed to execute hook command: \(error.localizedDescription)")
#endif
        }
    }
}
