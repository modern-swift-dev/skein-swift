#if canImport(AppKit) || (canImport(UIKit) && !os(watchOS))
import SwiftUI

#if canImport(AppKit)
import AppKit
#else
import UIKit
#endif

@MainActor final class TestViewHost<Content: View> {
    #if canImport(AppKit)
    private let controller: NSHostingController<Content>
    #else
    private let controller: UIHostingController<Content>
    private let window: UIWindow
    #endif

    init(rootView: Content) {
        #if canImport(AppKit)
        controller = NSHostingController(rootView: rootView)
        #else
        controller = UIHostingController(rootView: rootView)
        window = UIWindow(frame: CGRect(x: 0, y: 0, width: 320, height: 480))
        window.rootViewController = controller
        window.makeKeyAndVisible()
        #endif
    }

    func layout() {
        #if canImport(AppKit)
        controller.view.layoutSubtreeIfNeeded()
        #else
        controller.view.layoutIfNeeded()
        #endif
    }

    func close() {
        #if canImport(UIKit) && !canImport(AppKit)
        window.isHidden = true
        window.rootViewController = nil
        #endif
    }
}
#endif
