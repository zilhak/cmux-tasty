import AppKit
import SwiftUI

/// Invisible background view that intercepts ⌘+/⌘−/⌘0 for markdown zoom control.
/// Attach via `.background(MarkdownZoomKeyMonitor(zoomLevel: $zoom, isFocused: focused))`.
struct MarkdownZoomKeyMonitor: NSViewRepresentable {
    @Binding var zoomLevel: Double
    let isFocused: Bool

    func makeNSView(context: Context) -> NSView {
        context.coordinator.startMonitor()
        return NSView(frame: .zero)
    }

    func updateNSView(_ nsView: NSView, context: Context) {
        context.coordinator.update(zoomLevel: $zoomLevel, isFocused: isFocused)
    }

    static func dismantleNSView(_ nsView: NSView, coordinator: Coordinator) {
        coordinator.stopMonitor()
    }

    func makeCoordinator() -> Coordinator {
        Coordinator(zoomLevel: $zoomLevel, isFocused: isFocused)
    }

    final class Coordinator {
        private var zoomLevel: Binding<Double>
        private var isFocused: Bool
        private var monitor: Any?

        static let minLevel: Double = 0.5
        static let maxLevel: Double = 3.0
        static let step: Double = 0.1

        init(zoomLevel: Binding<Double>, isFocused: Bool) {
            self.zoomLevel = zoomLevel
            self.isFocused = isFocused
        }

        func update(zoomLevel: Binding<Double>, isFocused: Bool) {
            self.zoomLevel = zoomLevel
            self.isFocused = isFocused
        }

        func startMonitor() {
            guard monitor == nil else { return }
            monitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { [weak self] event in
                guard let self, self.isFocused,
                      event.modifierFlags.intersection(.deviceIndependentFlagsMask) == .command,
                      let chars = event.charactersIgnoringModifiers else { return event }
                switch chars {
                case "=", "+":
                    let new = min(self.zoomLevel.wrappedValue + Self.step, Self.maxLevel)
                    self.zoomLevel.wrappedValue = (new * 10).rounded() / 10
                    return nil
                case "-":
                    let new = max(self.zoomLevel.wrappedValue - Self.step, Self.minLevel)
                    self.zoomLevel.wrappedValue = (new * 10).rounded() / 10
                    return nil
                case "0":
                    self.zoomLevel.wrappedValue = 1.0
                    return nil
                default:
                    return event
                }
            }
        }

        func stopMonitor() {
            if let monitor {
                NSEvent.removeMonitor(monitor)
                self.monitor = nil
            }
        }
    }
}
