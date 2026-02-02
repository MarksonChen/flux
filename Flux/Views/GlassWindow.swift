import AppKit

/// A window with a strong glassomorphism effect - frosted glass with prominent blur, gradient, and borders
final class GlassWindow: NSWindow {

    override init(contentRect: NSRect, styleMask style: NSWindow.StyleMask, backing backingStoreType: NSWindow.BackingStoreType, defer flag: Bool) {
        super.init(contentRect: contentRect, styleMask: style, backing: backingStoreType, defer: flag)
        setupGlassEffect()
    }

    private func setupGlassEffect() {
        titlebarAppearsTransparent = true
        titleVisibility = .visible
        isMovableByWindowBackground = true
        backgroundColor = .clear
        isOpaque = false
        hasShadow = true

        // Don't remember which desktop the window was on - appear on current space
        collectionBehavior = [.moveToActiveSpace]

        guard let contentView = contentView else { return }

        contentView.wantsLayer = true
        contentView.layer?.cornerRadius = Design.CornerRadius.large
        contentView.layer?.masksToBounds = true

        // Base visual effect view for blur
        let effectView = NSVisualEffectView()
        effectView.material = .fullScreenUI
        effectView.blendingMode = .behindWindow
        effectView.state = .active
        effectView.wantsLayer = true
        effectView.translatesAutoresizingMaskIntoConstraints = false
        effectView.layer?.cornerRadius = Design.CornerRadius.large
        effectView.layer?.masksToBounds = true

        contentView.addSubview(effectView, positioned: .below, relativeTo: nil)

        NSLayoutConstraint.activate([
            effectView.topAnchor.constraint(equalTo: contentView.topAnchor),
            effectView.leadingAnchor.constraint(equalTo: contentView.leadingAnchor),
            effectView.trailingAnchor.constraint(equalTo: contentView.trailingAnchor),
            effectView.bottomAnchor.constraint(equalTo: contentView.bottomAnchor)
        ])

        // Add glass overlay with gradient for depth
        let glassOverlay = NSView()
        glassOverlay.wantsLayer = true
        glassOverlay.translatesAutoresizingMaskIntoConstraints = false

        // Create a subtle gradient overlay for the glass effect
        let gradientLayer = CAGradientLayer()
        gradientLayer.colors = [
            NSColor.white.withAlphaComponent(Design.Opacity.medium).cgColor,
            NSColor.white.withAlphaComponent(Design.Opacity.subtle).cgColor,
            NSColor.clear.cgColor
        ]
        gradientLayer.locations = [0, 0.3, 1]
        gradientLayer.startPoint = CGPoint(x: 0.5, y: 0)
        gradientLayer.endPoint = CGPoint(x: 0.5, y: 1)
        gradientLayer.cornerRadius = Design.CornerRadius.large
        glassOverlay.layer = gradientLayer

        contentView.addSubview(glassOverlay, positioned: .above, relativeTo: effectView)

        NSLayoutConstraint.activate([
            glassOverlay.topAnchor.constraint(equalTo: contentView.topAnchor),
            glassOverlay.leadingAnchor.constraint(equalTo: contentView.leadingAnchor),
            glassOverlay.trailingAnchor.constraint(equalTo: contentView.trailingAnchor),
            glassOverlay.bottomAnchor.constraint(equalTo: contentView.bottomAnchor)
        ])

        // Add border view for the glass edge highlight
        let borderView = NSView()
        borderView.wantsLayer = true
        borderView.translatesAutoresizingMaskIntoConstraints = false
        borderView.layer?.cornerRadius = Design.CornerRadius.large
        borderView.layer?.borderWidth = 1
        borderView.layer?.borderColor = NSColor.white.withAlphaComponent(Design.Opacity.border).cgColor
        borderView.layer?.masksToBounds = true

        contentView.addSubview(borderView, positioned: .above, relativeTo: glassOverlay)

        NSLayoutConstraint.activate([
            borderView.topAnchor.constraint(equalTo: contentView.topAnchor),
            borderView.leadingAnchor.constraint(equalTo: contentView.leadingAnchor),
            borderView.trailingAnchor.constraint(equalTo: contentView.trailingAnchor),
            borderView.bottomAnchor.constraint(equalTo: contentView.bottomAnchor)
        ])
    }

    override var canBecomeKey: Bool { true }
    override var canBecomeMain: Bool { true }

    override func keyDown(with event: NSEvent) {
        let chars = event.charactersIgnoringModifiers ?? ""
        let hasCommand = event.modifierFlags.contains(.command)

        // Handle cmd+W to close window
        if hasCommand && chars.lowercased() == "w" {
            close()
            return
        }

        super.keyDown(with: event)
    }
}
