//
//  HUDViewController.swift
//  ResignTool
//
//  Created by 刘吉新 on 2025/6/22.
//

import Foundation
import Cocoa

class HUDViewController: NSViewController {
    
    // MARK: - UI Elements
    private let backgroundView: NSView = {
        let view = NSView()
        view.wantsLayer = true
        view.layer?.backgroundColor = NSColor.underPageBackgroundColor.withAlphaComponent(0.7).cgColor
        view.alphaValue = 0
        return view
    }()
    
    private let containerView: NSView = {
        let view = NSView()
        view.wantsLayer = true
        view.layer?.cornerRadius = 10
        view.layer?.borderWidth = 0.5
        view.layer?.masksToBounds = true
        view.alphaValue = 0
        return view
    }()
    
    private let textView: NSTextView = {
        let textView = NSTextView()
        textView.isEditable = false
        textView.isSelectable = true
        textView.backgroundColor = .clear
        textView.font = NSFont.monospacedSystemFont(ofSize: 11, weight: .regular)
        textView.autoresizingMask = [.width, .height]
        return textView
    }()
    
    private let scrollView: NSScrollView = {
        let scrollView = NSScrollView()
        scrollView.hasVerticalScroller = true
        scrollView.autohidesScrollers = true
        scrollView.borderType = .noBorder
        return scrollView
    }()
    
    let closeButton: NSButton = {
        let button = NSButton(title: "✕", target: nil, action:nil)
        button.bezelStyle = .circular
        button.setButtonType(.momentaryPushIn)
        button.isBordered = false
        button.focusRingType = .none
        button.translatesAutoresizingMaskIntoConstraints = false
        return button
    }()
    
    // MARK: - Properties
    private var isShowing = false
    private weak var parentWindow: NSWindow?
    private var modalSession: NSApplication.ModalSession?
    private var appearanceObservation: NSKeyValueObservation?
    
    // MARK: - Lifecycle
    override func loadView() {
        view = NSView(frame: NSRect(x: 0, y: 0, width: 320, height: 200))
        view.wantsLayer = true
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        setupUI()
        setupAppearanceObserver()
        setupCloseButton()
        updateColorsForCurrentAppearance()
        
        closeButton.target = self;
        closeButton.action = #selector(closeButtonClicked(_:))
    }
    
    deinit {
        appearanceObservation?.invalidate()
    }
    
    // MARK: - Setup
    private func setupUI() {
        // Background View
        backgroundView.frame = view.bounds
        view.addSubview(backgroundView, positioned: .below, relativeTo: nil)
        
        // Container View
        containerView.frame = view.bounds
        view.addSubview(containerView)
        
        // Scroll View
        scrollView.frame = NSInsetRect(containerView.bounds, 10, 10)
        containerView.addSubview(scrollView)
        
        // Text View
        textView.frame = scrollView.bounds
        scrollView.documentView = textView
        
    }
    
    private func setupCloseButton() {
        containerView.addSubview(closeButton)
//        closeButton.target = self;
//        closeButton.action = #selector(closeButtonClicked(_:))
        
        NSLayoutConstraint.activate([
            closeButton.topAnchor.constraint(equalTo: containerView.topAnchor, constant: 8),
            closeButton.trailingAnchor.constraint(equalTo: containerView.trailingAnchor, constant: -8),
            closeButton.widthAnchor.constraint(equalToConstant: 20),
            closeButton.heightAnchor.constraint(equalToConstant: 20)
        ])
    }
    
    private func setupAppearanceObserver() {
        appearanceObservation = NSApp.observe(\.effectiveAppearance) { [weak self] _, _ in
            self?.updateColorsForCurrentAppearance()
        }
    }
    
    private func updateColorsForCurrentAppearance() {
        let isDarkMode = NSApp.effectiveAppearance.isDarkMode
        
        // Background View
        backgroundView.layer?.backgroundColor = isDarkMode ?
            NSColor.underPageBackgroundColor.withAlphaComponent(0.8).cgColor :
            NSColor.underPageBackgroundColor.withAlphaComponent(0.7).cgColor
        
        // Container View
        containerView.layer?.backgroundColor = isDarkMode ?
            NSColor.controlBackgroundColor.cgColor :
            NSColor.windowBackgroundColor.cgColor
        
        containerView.layer?.borderColor = isDarkMode ?
            NSColor.separatorColor.cgColor :
            NSColor.quaternaryLabelColor.cgColor
        
        // Text View
        textView.textColor = isDarkMode ? .textColor : .labelColor
        textView.insertionPointColor = isDarkMode ? .white : .black
        
        // Scroll View
        scrollView.backgroundColor = .clear
        scrollView.scrollerKnobStyle = isDarkMode ? .light : .dark
        
        // Close Button
        closeButton.contentTintColor = isDarkMode ? .lightGray : .darkGray
    }
    
    // MARK: - Button Action
    @objc func closeButtonClicked(_ sender: NSButton) {
        dismiss()
    }
    
    // MARK: - Public Methods
    func show(in window: NSWindow) {
        guard !isShowing else { return }
        isShowing = true
        parentWindow = window
        
        // Add to window
        window.contentView?.addSubview(view)
        updateFrames()
        
        // Begin modal session
        modalSession = NSApplication.shared.beginModalSession(for: window)

        disableControls(in: window.contentView)
        
        // Fade in animation
        NSAnimationContext.runAnimationGroup({ context in
            context.duration = 0.3
            context.timingFunction = CAMediaTimingFunction(name: .easeInEaseOut)
            backgroundView.animator().alphaValue = 1
            containerView.animator().alphaValue = 1
        })
    }
    
    private func disableControls(in view: NSView?) {
        view?.subviews.forEach {
            if let control = $0 as? NSControl, control != closeButton { // 保持关闭按钮可用
                control.isEnabled = false
                disableControls(in: $0)
            }
        }
    }
    
    private func enableControls(in view: NSView?) {
        view?.subviews.forEach {
            if let control = $0 as? NSControl {
                control.isEnabled = true
            }
            enableControls(in: $0)
        }
    }
    
    @objc private func updateFrames() {
        guard let window = parentWindow, let contentView = window.contentView else { return }
        
        view.frame = contentView.bounds
        backgroundView.frame = view.bounds
        
        containerView.frame = CGRect(
            x: (contentView.bounds.width - containerView.bounds.width) / 2,
            y: (contentView.bounds.height - containerView.bounds.height) / 2,
            width: containerView.bounds.width,
            height: containerView.bounds.height
        )
        
        scrollView.frame = NSInsetRect(containerView.bounds, 10, 10)
    }
    
    func dismiss() {
        guard isShowing else { return }
        
        NSAnimationContext.runAnimationGroup({ context in
            context.duration = 0.3
            context.timingFunction = CAMediaTimingFunction(name: .easeInEaseOut)
            backgroundView.animator().alphaValue = 0
            containerView.animator().alphaValue = 0
        }, completionHandler: { [weak self] in
            guard let self = self else { return }
            
            if let window = self.parentWindow {
                self.enableControls(in: window.contentView)
            }
            
            if let session = self.modalSession {
                NSApplication.shared.endModalSession(session)
            }
            
            self.view.removeFromSuperview()
            self.isShowing = false
        })
    }
    
    func log(_ message: String) {
        DispatchQueue.main.async {
            let timestamp = DateFormatter.localizedString(from: Date(), dateStyle: .none, timeStyle: .medium)
            let formattedMessage = "[\(timestamp)] \(message)\n"
            
            let textColor: NSColor = NSApp.effectiveAppearance.isDarkMode ? .textColor : .labelColor
            let attributes: [NSAttributedString.Key: Any] = [
                .font: NSFont.monospacedSystemFont(ofSize: 11, weight: .regular),
                .foregroundColor: textColor
            ]
            
            let attributedString = NSAttributedString(string: formattedMessage, attributes: attributes)
            self.textView.textStorage?.append(attributedString)
            self.textView.scrollToEndOfDocument(nil)
        }
    }
}

// MARK: - Appearance Extension
extension NSAppearance {
    var isDarkMode: Bool {
        if #available(macOS 10.14, *) {
            return self.bestMatch(from: [.darkAqua, .aqua]) == .darkAqua
        }
        return false
    }
}

// MARK: - Usage Example
extension HUDViewController {
    static func showHUD(in window: NSWindow) -> HUDViewController {
        let hud = HUDViewController()
        hud.show(in: window)
        return hud
    }
}
