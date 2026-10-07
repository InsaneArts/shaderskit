import SwiftUI
#if canImport(UIKit)
import UIKit
#elseif canImport(AppKit)
import AppKit
#endif

// Platform and OS-version shims. Every call site stays free of availability checks.

extension View {
    /// Liquid Glass on iOS/macOS/tvOS 26, a thin material before that.
    @ViewBuilder
    func glassSurface<S: Shape>(_ shape: S) -> some View {
        if #available(iOS 26, macOS 26, tvOS 26, *) {
            self.glassEffect(.regular, in: shape)
        } else {
            self.background(.ultraThinMaterial, in: shape)
        }
    }

    /// Glass button style on OS 26, bordered before that.
    @ViewBuilder
    func glassButtonStyle() -> some View {
        if #available(iOS 26, macOS 26, tvOS 26, *) {
            self.buttonStyle(.glass)
        } else {
            self.buttonStyle(.bordered)
        }
    }

    /// Source of a zoom navigation transition (iOS 18+ only; a no-op elsewhere).
    @ViewBuilder
    func zoomSource(id: String, in namespace: Namespace.ID) -> some View {
        #if os(iOS)
        if #available(iOS 18, *) {
            self.matchedTransitionSource(id: id, in: namespace)
        } else {
            self
        }
        #else
        self
        #endif
    }

    /// Destination of a zoom navigation transition (iOS 18+ only; a no-op elsewhere).
    @ViewBuilder
    func zoomDestination(id: String, in namespace: Namespace.ID) -> some View {
        #if os(iOS)
        if #available(iOS 18, *) {
            self.navigationTransition(.zoom(sourceID: id, in: namespace))
        } else {
            self
        }
        #else
        self
        #endif
    }

    /// Selection haptic on iOS when `trigger` changes.
    @ViewBuilder
    func selectionHaptic<T: Equatable>(trigger: T) -> some View {
        #if os(iOS)
        self.sensoryFeedback(.selection, trigger: trigger)
        #else
        self
        #endif
    }

    /// Impact haptic on iOS when `trigger` changes.
    @ViewBuilder
    func impactHaptic<T: Equatable>(trigger: T) -> some View {
        #if os(iOS)
        self.sensoryFeedback(.impact(weight: .light), trigger: trigger)
        #else
        self
        #endif
    }

    /// Reports whether the view is on screen inside a scroll view. Uses precise scroll
    /// visibility on OS 18+, `onAppear`/`onDisappear` before that.
    @ViewBuilder
    func onScreenChange(_ action: @escaping (Bool) -> Void) -> some View {
        if #available(iOS 18, macOS 15, tvOS 18, *) {
            self.onScrollVisibilityChange(threshold: 0.15, action)
                .onDisappear { action(false) }
        } else {
            self.onAppear { action(true) }
                .onDisappear { action(false) }
        }
    }

    /// Inline navigation title on iOS, default elsewhere.
    @ViewBuilder
    func inlineTitle() -> some View {
        #if os(iOS)
        self.navigationBarTitleDisplayMode(.inline)
        #else
        self
        #endif
    }
}

enum Pasteboard {
    static var isAvailable: Bool {
        #if os(iOS) || os(macOS)
        return true
        #else
        return false
        #endif
    }

    static func copy(_ string: String) {
        #if os(iOS)
        UIPasteboard.general.string = string
        #elseif os(macOS)
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(string, forType: .string)
        #endif
    }

    static func string() -> String? {
        #if os(iOS)
        return UIPasteboard.general.string
        #elseif os(macOS)
        return NSPasteboard.general.string(forType: .string)
        #else
        return nil
        #endif
    }
}

enum DeviceClass {
    static var isPhone: Bool {
        #if os(iOS)
        return UIDevice.current.userInterfaceIdiom == .phone
        #else
        return false
        #endif
    }

    /// How many gallery cards may run a live Metal view at the same time.
    static var liveViewLimit: Int {
        #if os(macOS)
        return 24
        #elseif os(tvOS)
        return 6
        #else
        return isPhone ? 8 : 16
        #endif
    }
}
