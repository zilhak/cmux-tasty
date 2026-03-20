import SwiftUI
import Foundation
import Bonsplit

/// View that renders a SurfaceGroup's split tree layout.
/// Each leaf node renders a TerminalPanelView; split nodes render a resizable split container.
struct SurfaceGroupView: View {
    @ObservedObject var group: SurfaceGroup
    let paneId: PaneID
    let isFocused: Bool
    let isVisibleInUI: Bool
    let portalPriority: Int
    let appearance: PanelAppearance
    let onChildFocus: (UUID) -> Void
    let onTriggerFlash: (UUID) -> Void

    var body: some View {
        SurfaceGroupSplitNodeView(
            node: group.rootNode,
            paneId: paneId,
            isFocused: isFocused,
            focusedChildId: group.focusedChildId,
            isVisibleInUI: isVisibleInUI,
            portalPriority: portalPriority,
            appearance: appearance,
            onChildFocus: onChildFocus,
            onTriggerFlash: onTriggerFlash
        )
    }
}

/// Recursive view that renders a SplitNode tree.
private struct SurfaceGroupSplitNodeView: View {
    let node: SurfaceGroup.SplitNode
    let paneId: PaneID
    let isFocused: Bool
    let focusedChildId: UUID?
    let isVisibleInUI: Bool
    let portalPriority: Int
    let appearance: PanelAppearance
    let onChildFocus: (UUID) -> Void
    let onTriggerFlash: (UUID) -> Void

    var body: some View {
        switch node {
        case .leaf(let panel):
            TerminalPanelView(
                panel: panel,
                paneId: paneId,
                isFocused: isFocused && focusedChildId == panel.id,
                isVisibleInUI: isVisibleInUI,
                portalPriority: portalPriority,
                isSplit: true,
                appearance: appearance,
                hasUnreadNotification: false,
                onFocus: { onChildFocus(panel.id) },
                onTriggerFlash: { onTriggerFlash(panel.id) }
            )

        case .split(let first, let second, let orientation, let ratio):
            SurfaceGroupSplitContainer(orientation: orientation, ratio: ratio, dividerColor: appearance.dividerColor) {
                SurfaceGroupSplitNodeView(
                    node: first,
                    paneId: paneId,
                    isFocused: isFocused,
                    focusedChildId: focusedChildId,
                    isVisibleInUI: isVisibleInUI,
                    portalPriority: portalPriority,
                    appearance: appearance,
                    onChildFocus: onChildFocus,
                    onTriggerFlash: onTriggerFlash
                )
            } second: {
                SurfaceGroupSplitNodeView(
                    node: second,
                    paneId: paneId,
                    isFocused: isFocused,
                    focusedChildId: focusedChildId,
                    isVisibleInUI: isVisibleInUI,
                    portalPriority: portalPriority,
                    appearance: appearance,
                    onChildFocus: onChildFocus,
                    onTriggerFlash: onTriggerFlash
                )
            }
        }
    }
}

/// A simple split container that divides space between two child views.
private struct SurfaceGroupSplitContainer<First: View, Second: View>: View {
    let orientation: SplitOrientation
    let ratio: CGFloat
    let dividerColor: Color
    @ViewBuilder let first: First
    @ViewBuilder let second: Second

    private let dividerThickness: CGFloat = 1

    var body: some View {
        GeometryReader { geometry in
            let totalSize = orientation == .horizontal ? geometry.size.width : geometry.size.height
            let firstSize = (totalSize - dividerThickness) * ratio
            let secondSize = totalSize - firstSize - dividerThickness

            if orientation == .horizontal {
                HStack(spacing: 0) {
                    first
                        .frame(width: firstSize)
                    dividerColor
                        .frame(width: dividerThickness)
                    second
                        .frame(width: secondSize)
                }
            } else {
                VStack(spacing: 0) {
                    first
                        .frame(height: firstSize)
                    dividerColor
                        .frame(height: dividerThickness)
                    second
                        .frame(height: secondSize)
                }
            }
        }
    }
}
