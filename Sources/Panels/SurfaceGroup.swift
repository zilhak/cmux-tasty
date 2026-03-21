import Foundation
import Combine
import AppKit
import Bonsplit

/// A surface group that wraps multiple child panels in a split layout.
/// The Workspace sees this as a single panel entry; no nested BonsplitController is needed.
/// Supports any Panel type (Terminal, Browser, Markdown) as children.
@MainActor
final class SurfaceGroup: Panel, ObservableObject {
    let id: UUID
    let panelType: PanelType = .surfaceGroup

    // MARK: - Split Tree

    /// Reuse Bonsplit's SplitOrientation for consistency.
    typealias Orientation = Bonsplit.SplitOrientation

    indirect enum SplitNode {
        case leaf(panel: any Panel)
        case split(first: SplitNode, second: SplitNode, orientation: Orientation, ratio: CGFloat)
    }

    @Published var rootNode: SplitNode
    @Published private(set) var focusedChildId: UUID?

    private(set) var workspaceId: UUID

    // MARK: - Init

    init(
        id: UUID,
        workspaceId: UUID,
        first: any Panel,
        second: any Panel,
        orientation: Orientation,
        ratio: CGFloat = 0.5
    ) {
        self.id = id
        self.workspaceId = workspaceId
        self.rootNode = .split(
            first: .leaf(panel: first),
            second: .leaf(panel: second),
            orientation: orientation,
            ratio: ratio
        )
        self.focusedChildId = first.id
    }

    // MARK: - Child Access

    var allChildPanels: [any Panel] {
        collectLeaves(rootNode)
    }

    /// All terminal panels in the group (for backward compatibility).
    var allTerminalPanels: [TerminalPanel] {
        allChildPanels.compactMap { $0 as? TerminalPanel }
    }

    var focusedChild: (any Panel)? {
        guard let focusedChildId else { return allChildPanels.first }
        return findLeaf(focusedChildId, in: rootNode)
    }

    /// Focused terminal child (for backward compatibility).
    var focusedTerminalChild: TerminalPanel? {
        focusedChild as? TerminalPanel
    }

    var childCount: Int {
        countLeaves(rootNode)
    }

    // MARK: - Panel Protocol

    var displayTitle: String {
        focusedChild?.displayTitle ?? "Terminal"
    }

    var displayIcon: String? {
        focusedChild?.displayIcon ?? "terminal.fill"
    }

    var isDirty: Bool { false }

    func focus() {
        focusedChild?.focus()
    }

    func unfocus() {
        for child in allChildPanels {
            child.unfocus()
        }
    }

    func close() {
        for child in allChildPanels {
            child.close()
        }
    }

    func triggerFlash() {
        focusedChild?.triggerFlash()
    }

    func captureFocusIntent(in window: NSWindow?) -> PanelFocusIntent {
        focusedChild?.captureFocusIntent(in: window) ?? .panel
    }

    func preferredFocusIntentForActivation() -> PanelFocusIntent {
        focusedChild?.preferredFocusIntentForActivation() ?? .panel
    }

    func prepareFocusIntentForActivation(_ intent: PanelFocusIntent) {
        focusedChild?.prepareFocusIntentForActivation(intent)
    }

    @discardableResult
    func restoreFocusIntent(_ intent: PanelFocusIntent) -> Bool {
        focusedChild?.restoreFocusIntent(intent) ?? false
    }

    func ownedFocusIntent(for responder: NSResponder, in window: NSWindow) -> PanelFocusIntent? {
        for child in allChildPanels {
            if let intent = child.ownedFocusIntent(for: responder, in: window) {
                return intent
            }
        }
        return nil
    }

    @discardableResult
    func yieldFocusIntent(_ intent: PanelFocusIntent, in window: NSWindow) -> Bool {
        focusedChild?.yieldFocusIntent(intent, in: window) ?? false
    }

    // MARK: - Group Operations

    func focusChild(_ childId: UUID) {
        guard findLeaf(childId, in: rootNode) != nil else { return }
        focusedChildId = childId
    }

    /// Split the given child, adding a new panel next to it.
    func splitChild(_ childId: UUID, orientation: Orientation, newPanel: any Panel, ratio: CGFloat = 0.5) {
        rootNode = insertSplit(childId: childId, orientation: orientation, newPanel: newPanel, ratio: ratio, in: rootNode)
    }

    /// Remove a child from the tree. Returns the remaining panel if the group should dissolve (1 child left).
    func removeChild(_ childId: UUID) -> (any Panel)? {
        guard let newRoot = removeLeaf(childId, from: rootNode) else { return nil }
        rootNode = newRoot

        // If focused child was removed, focus the first remaining child
        if focusedChildId == childId {
            focusedChildId = allChildPanels.first?.id
        }

        // If only 1 child left, the caller should dissolve this group
        if case .leaf(let remaining) = rootNode {
            return remaining
        }
        return nil
    }

    // MARK: - Tree Helpers

    private func collectLeaves(_ node: SplitNode) -> [any Panel] {
        switch node {
        case .leaf(let panel):
            return [panel]
        case .split(let first, let second, _, _):
            return collectLeaves(first) + collectLeaves(second)
        }
    }

    private func findLeaf(_ id: UUID, in node: SplitNode) -> (any Panel)? {
        switch node {
        case .leaf(let panel):
            return panel.id == id ? panel : nil
        case .split(let first, let second, _, _):
            return findLeaf(id, in: first) ?? findLeaf(id, in: second)
        }
    }

    private func countLeaves(_ node: SplitNode) -> Int {
        switch node {
        case .leaf:
            return 1
        case .split(let first, let second, _, _):
            return countLeaves(first) + countLeaves(second)
        }
    }

    private func insertSplit(childId: UUID, orientation: Orientation, newPanel: any Panel, ratio: CGFloat, in node: SplitNode) -> SplitNode {
        switch node {
        case .leaf(let panel):
            if panel.id == childId {
                return .split(
                    first: .leaf(panel: panel),
                    second: .leaf(panel: newPanel),
                    orientation: orientation,
                    ratio: ratio
                )
            }
            return node
        case .split(let first, let second, let ori, let r):
            return .split(
                first: insertSplit(childId: childId, orientation: orientation, newPanel: newPanel, ratio: ratio, in: first),
                second: insertSplit(childId: childId, orientation: orientation, newPanel: newPanel, ratio: ratio, in: second),
                orientation: ori,
                ratio: r
            )
        }
    }

    private func removeLeaf(_ id: UUID, from node: SplitNode) -> SplitNode? {
        switch node {
        case .leaf(let panel):
            return panel.id == id ? nil : node
        case .split(let first, let second, let ori, let ratio):
            let newFirst = removeLeaf(id, from: first)
            let newSecond = removeLeaf(id, from: second)
            switch (newFirst, newSecond) {
            case (nil, nil):
                return nil
            case (nil, let remaining):
                return remaining
            case (let remaining, nil):
                return remaining
            case (let f?, let s?):
                return .split(first: f, second: s, orientation: ori, ratio: ratio)
            }
        }
    }
}
