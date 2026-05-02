//
//  Solution1View.swift
//  Mica
//
//  Created by Luke Charters on 13/9/2025.
//


import Cocoa
import SwiftUI

// MARK: - Solution 1: Basic NSImageView with Scaling
class Solution1View: NSView {
    let symbolName: String
    
    init(symbolName: String) {
        self.symbolName = symbolName
        super.init(frame: .zero)
        setupView()
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    func setupView() {
        wantsLayer = true
        
        // Background rounded rect
        layer?.backgroundColor = NSColor.systemBlue.cgColor
        layer?.cornerRadius = 23
        layer?.shadowColor = NSColor.black.cgColor
        layer?.shadowOpacity = 0.2
        layer?.shadowOffset = CGSize(width: 0, height: -1.25)
        layer?.shadowRadius = 1
        
        // Create image view
        let imageView = NSImageView(frame: NSRect(x: 10.25, y: 10.25, width: 82.5, height: 82.5))
        imageView.image = NSImage(systemSymbolName: symbolName, accessibilityDescription: nil)
        imageView.contentTintColor = .white
        imageView.imageScaling = .scaleProportionallyUpOrDown
        imageView.imageAlignment = .alignCenter
        
        addSubview(imageView)
    }
}

// MARK: - Solution 2: NSImage with Symbol Configuration
class Solution2View: NSView {
    let symbolName: String
    
    init(symbolName: String) {
        self.symbolName = symbolName
        super.init(frame: .zero)
        setupView()
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    var fontSizeMultiplier: CGFloat {
        switch symbolName {
        case let name where name.contains("square"),
             let name where name.contains("circle"),
             let name where name.contains("gearshape"):
            return 1.3
        case let name where name.contains("folder"):
            return 1.0
        default:
            return 1.15
        }
    }
    
    func setupView() {
        wantsLayer = true
        
        // Background
        layer?.backgroundColor = NSColor.systemBlue.cgColor
        layer?.cornerRadius = 23
        layer?.shadowColor = NSColor.black.cgColor
        layer?.shadowOpacity = 0.2
        layer?.shadowOffset = CGSize(width: 0, height: -1.25)
        layer?.shadowRadius = 1
        
        // Configure symbol
        let config = NSImage.SymbolConfiguration(pointSize: 60 * fontSizeMultiplier, weight: .regular)
        let image = NSImage(systemSymbolName: symbolName, accessibilityDescription: nil)?
            .withSymbolConfiguration(config)
        
        let imageView = NSImageView(frame: bounds.insetBy(dx: 10, dy: 10))
        imageView.image = image
        imageView.contentTintColor = .white
        imageView.imageAlignment = .alignCenter
        imageView.autoresizingMask = [.width, .height]
        
        addSubview(imageView)
    }
}

// MARK: - Solution 3: Manual Drawing with Transform
class Solution3View: NSView {
    let symbolName: String
    
    init(symbolName: String) {
        self.symbolName = symbolName
        super.init(frame: .zero)
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    override func draw(_ dirtyRect: NSRect) {
        super.draw(dirtyRect)
        
        // Draw background
        let backgroundPath = NSBezierPath(roundedRect: bounds, xRadius: 23, yRadius: 23)
        NSColor.systemBlue.setFill()
        backgroundPath.fill()
        
        // Draw shadow
        let context = NSGraphicsContext.current?.cgContext
        context?.setShadow(offset: CGSize(width: 0, height: -1.25), blur: 1, color: NSColor.black.withAlphaComponent(0.2).cgColor)
        
        // Configure and draw symbol
        let config = NSImage.SymbolConfiguration(pointSize: 67.5, weight: .regular)
        guard let image = NSImage(systemSymbolName: symbolName, accessibilityDescription: nil)?
            .withSymbolConfiguration(config) else { return }
        
        // Calculate drawing rect to fit 80% of bounds
        let targetSize = NSSize(width: bounds.width * 0.8, height: bounds.height * 0.8)
        let imageSize = image.size
        
        let scale = min(targetSize.width / imageSize.width, targetSize.height / imageSize.height)
        let scaledSize = NSSize(width: imageSize.width * scale, height: imageSize.height * scale)
        
        let drawingRect = NSRect(
            x: (bounds.width - scaledSize.width) / 2,
            y: (bounds.height - scaledSize.height) / 2,
            width: scaledSize.width,
            height: scaledSize.height
        )
        
        NSColor.white.set()
        image.draw(in: drawingRect)
    }
}

// MARK: - Solution 4: CALayer Based
class Solution4View: NSView {
    let symbolName: String
    
    init(symbolName: String) {
        self.symbolName = symbolName
        super.init(frame: .zero)
        setupView()
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    func setupView() {
        wantsLayer = true
        
        // Background layer
        layer?.backgroundColor = NSColor.systemBlue.cgColor
        layer?.cornerRadius = 23
        layer?.shadowColor = NSColor.black.cgColor
        layer?.shadowOpacity = 0.2
        layer?.shadowOffset = CGSize(width: 0, height: -1.25)
        layer?.shadowRadius = 1
        
        // Create symbol image
        let config = NSImage.SymbolConfiguration(pointSize: 67.5, weight: .regular)
        guard let image = NSImage(systemSymbolName: symbolName, accessibilityDescription: nil)?
            .withSymbolConfiguration(config) else { return }
        
        // Tint the image white
        let tintedImage = NSImage(size: image.size)
        tintedImage.lockFocus()
        NSColor.white.set()
        image.draw(at: .zero, from: NSRect(origin: .zero, size: image.size), operation: .sourceIn, fraction: 1.0)
        tintedImage.unlockFocus()
        
        // Create image layer
        let imageLayer = CALayer()
        imageLayer.contents = tintedImage
        imageLayer.contentsGravity = .resizeAspect
        imageLayer.frame = bounds.insetBy(dx: 10.25, dy: 10.25)
        
        layer?.addSublayer(imageLayer)
    }
}

// MARK: - Solution 5: Dynamic Size Calculation
class Solution5View: NSView {
    let symbolName: String
    private var imageView: NSImageView!
    
    init(symbolName: String) {
        self.symbolName = symbolName
        super.init(frame: .zero)
        setupView()
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    func setupView() {
        wantsLayer = true
        
        // Background
        layer?.backgroundColor = NSColor.systemBlue.cgColor
        layer?.cornerRadius = 23
        layer?.shadowColor = NSColor.black.cgColor
        layer?.shadowOpacity = 0.2
        layer?.shadowOffset = CGSize(width: 0, height: -1.25)
        layer?.shadowRadius = 1
        
        // Start with large size
        var fontSize: CGFloat = 67.5
        var config = NSImage.SymbolConfiguration(pointSize: fontSize, weight: .regular)
        var image = NSImage(systemSymbolName: symbolName, accessibilityDescription: nil)?
            .withSymbolConfiguration(config)
        
        // Check if image is too large and scale down if needed
        if let image = image {
            let maxSize: CGFloat = 82.5
            if image.size.width > maxSize || image.size.height > maxSize {
                let scale = min(maxSize / image.size.width, maxSize / image.size.height)
                fontSize *= scale
                config = NSImage.SymbolConfiguration(pointSize: fontSize, weight: .regular)
                self.imageView?.image = NSImage(systemSymbolName: symbolName, accessibilityDescription: nil)?
                    .withSymbolConfiguration(config)
            }
        }
        
        imageView = NSImageView(frame: bounds.insetBy(dx: 10.25, dy: 10.25))
        imageView.image = image
        imageView.contentTintColor = .white
        imageView.imageAlignment = .alignCenter
        imageView.imageScaling = .scaleProportionallyUpOrDown
        imageView.autoresizingMask = [.width, .height]
        
        addSubview(imageView)
    }
}

// MARK: - Solution 6: Custom Scaling Logic
class Solution6View: NSView {
    let symbolName: String
    
    init(symbolName: String) {
        self.symbolName = symbolName
        super.init(frame: .zero)
        setupView()
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    func setupView() {
        wantsLayer = true
        
        // Background
        layer?.backgroundColor = NSColor.systemBlue.cgColor
        layer?.cornerRadius = 23
        layer?.shadowColor = NSColor.black.cgColor
        layer?.shadowOpacity = 0.2
        layer?.shadowOffset = CGSize(width: 0, height: -1.25)
        layer?.shadowRadius = 1
        
        // Try different sizes until one fits
        let sizes: [CGFloat] = [67.5, 60, 50, 40]
        var finalImage: NSImage?
        
        for size in sizes {
            let config = NSImage.SymbolConfiguration(pointSize: size, weight: .regular)
            if let image = NSImage(systemSymbolName: symbolName, accessibilityDescription: nil)?
                .withSymbolConfiguration(config) {
                if image.size.width <= 82.5 && image.size.height <= 82.5 {
                    finalImage = image
                    break
                }
            }
        }
        
        let imageView = NSImageView(frame: bounds.insetBy(dx: 10.25, dy: 10.25))
        imageView.image = finalImage
        imageView.contentTintColor = .white
        imageView.imageAlignment = .alignCenter
        imageView.autoresizingMask = [.width, .height]
        
        addSubview(imageView)
    }
}

// MARK: - Main Window Controller
class SymbolGridViewController: NSViewController {
    let testSymbols = ["folder.fill.badge.plus", "square", "gearshape", "star.fill"]
    var selectedSymbol = "folder.fill.badge.plus"
    
    var segmentedControl: NSSegmentedControl!
    var scrollView: NSScrollView!
    var gridContainer: NSView!
    
    override func loadView() {
        view = NSView(frame: NSRect(x: 0, y: 0, width: 800, height: 600))
        view.wantsLayer = true
        
        setupUI()
    }
    
    func setupUI() {
        // Title label
        let titleLabel = NSTextField(labelWithString: "AppKit SF Symbol Sizing Solutions")
        titleLabel.font = NSFont.systemFont(ofSize: 24, weight: .bold)
        titleLabel.alignment = .center
        titleLabel.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(titleLabel)
        
        // Segmented control for symbol selection
        segmentedControl = NSSegmentedControl(labels: testSymbols, trackingMode: .selectOne, target: self, action: #selector(symbolChanged(_:)))
        segmentedControl.selectedSegment = 0
        segmentedControl.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(segmentedControl)
        
        // Scroll view
        scrollView = NSScrollView()
        scrollView.hasVerticalScroller = true
        scrollView.hasHorizontalScroller = true
        scrollView.autohidesScrollers = false
        scrollView.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(scrollView)
        
        // Grid container
        gridContainer = NSView()
        gridContainer.translatesAutoresizingMaskIntoConstraints = false
        scrollView.documentView = gridContainer
        
        // Setup constraints
        NSLayoutConstraint.activate([
            titleLabel.topAnchor.constraint(equalTo: view.topAnchor, constant: 20),
            titleLabel.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            
            segmentedControl.topAnchor.constraint(equalTo: titleLabel.bottomAnchor, constant: 20),
            segmentedControl.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            segmentedControl.widthAnchor.constraint(equalToConstant: 600),
            
            scrollView.topAnchor.constraint(equalTo: segmentedControl.bottomAnchor, constant: 20),
            scrollView.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 20),
            scrollView.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -20),
            scrollView.bottomAnchor.constraint(equalTo: view.bottomAnchor, constant: -20)
        ])
        
        updateGrid()
    }
    
    @objc func symbolChanged(_ sender: NSSegmentedControl) {
        selectedSymbol = testSymbols[sender.selectedSegment]
        updateGrid()
    }
    
    func updateGrid() {
        // Clear existing views
        gridContainer.subviews.forEach { $0.removeFromSuperview() }
        
        let solutions: [(NSView, String, String)] = [
            (Solution1View(symbolName: selectedSymbol), "Basic Scaling", "NSImageView.imageScaling"),
            (Solution2View(symbolName: selectedSymbol), "Symbol Config", "Dynamic pointSize"),
            (Solution3View(symbolName: selectedSymbol), "Manual Drawing", "draw(_ dirtyRect:)"),
            (Solution4View(symbolName: selectedSymbol), "CALayer Based", "CALayer contents"),
            (Solution5View(symbolName: selectedSymbol), "Dynamic Sizing", "Size calculation"),
            (Solution6View(symbolName: selectedSymbol), "Multi-Size Try", "Fallback sizes")
        ]
        
        let itemSize: CGFloat = 103
        let spacing: CGFloat = 40
        let labelHeight: CGFloat = 40
        let columns = 3
        
        for (index, (solutionView, title, subtitle)) in solutions.enumerated() {
            let row = index / columns
            let col = index % columns
            
            let x = CGFloat(col) * (itemSize + spacing) + spacing
            let y = CGFloat(row) * (itemSize + spacing + labelHeight) + spacing
            
            // Solution view
            solutionView.frame = NSRect(x: x, y: y + labelHeight, width: itemSize, height: itemSize)
            gridContainer.addSubview(solutionView)
            
            // Title label
            let titleLabel = NSTextField(labelWithString: title)
            titleLabel.font = NSFont.systemFont(ofSize: 11, weight: .medium)
            titleLabel.alignment = .center
            titleLabel.frame = NSRect(x: x, y: y + 20, width: itemSize, height: 20)
            gridContainer.addSubview(titleLabel)
            
            // Subtitle label
            let subtitleLabel = NSTextField(labelWithString: subtitle)
            subtitleLabel.font = NSFont.systemFont(ofSize: 9)
            subtitleLabel.textColor = .secondaryLabelColor
            subtitleLabel.alignment = .center
            subtitleLabel.frame = NSRect(x: x, y: y, width: itemSize, height: 20)
            gridContainer.addSubview(subtitleLabel)
        }
        
        // Update container size
        let rows = (solutions.count + columns - 1) / columns
        let contentHeight = CGFloat(rows) * (itemSize + spacing + labelHeight) + spacing
        let contentWidth = CGFloat(columns) * (itemSize + spacing) + spacing
        gridContainer.frame = NSRect(x: 0, y: 0, width: contentWidth, height: contentHeight)
    }
}

// MARK: - Window Setup
class AppDelegate: NSObject, NSApplicationDelegate {
    var window: NSWindow!
    
    func applicationDidFinishLaunching(_ notification: Notification) {
        window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 800, height: 600),
            styleMask: [.titled, .closable, .miniaturizable, .resizable],
            backing: .buffered,
            defer: false
        )
        
        window.title = "AppKit SF Symbol Solutions"
        window.center()
        window.contentViewController = SymbolGridViewController()
        window.makeKeyAndOrderFront(nil)
    }
}


// MARK: - SwiftUI Preview for Whole Grid
struct SymbolGridPreview: NSViewControllerRepresentable {
    func makeNSViewController(context: Context) -> SymbolGridViewController {
        SymbolGridViewController()
    }

    func updateNSViewController(_ nsViewController: SymbolGridViewController, context: Context) {
        // Optionally tweak the preview state here, e.g.:
        // nsViewController.selectedSymbol = "gearshape"
        // nsViewController.updateGrid()
    }
}

#Preview("Grid") {
    SymbolGridPreview()
        .frame(width: 600, height: 600)
}
