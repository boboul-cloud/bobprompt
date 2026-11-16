import SwiftUI
import UIKit

struct TeleprompterTextView: UIViewRepresentable {
    @Binding var attributedText: NSAttributedString
    @Binding var isPlaying: Bool
    var speed: CGFloat // points per second (base speed)
    var mirror: Bool = false
    var sidePadding: CGFloat = 20
    var onFinished: (() -> Void)? = nil
    var onProgress: ((CGFloat) -> Void)? = nil // 0...1
    var onReadingLineChanged: ((String, Int) -> Void)? = nil
    var resetToTop: Binding<Bool>? = nil
    var stopAndReset: Binding<Bool>? = nil  // Full stop: kill displayLink + reset scroll
    var requestVisibleText: Binding<Bool>? = nil
    var onVisibleTextExtracted: ((String) -> Void)? = nil

    func makeCoordinator() -> Coordinator { Coordinator() }

    func makeUIView(context: Context) -> UITextView {
        let tv = UITextView()
        tv.backgroundColor = .clear
        tv.isEditable = false
        tv.isSelectable = false
        tv.showsVerticalScrollIndicator = false
        // Vertical insets will be set dynamically in updateUIView
        tv.textContainerInset = UIEdgeInsets(top: 200, left: sidePadding, bottom: 200, right: sidePadding)
        tv.textContainer.lineBreakMode = .byWordWrapping
        tv.textContainer.widthTracksTextView = true
        context.coordinator.textView = tv
        
        // Add highlight overlay for current reading line
        let highlight = UIView()
        highlight.backgroundColor = UIColor.systemYellow.withAlphaComponent(0.15)
        highlight.layer.cornerRadius = 8
        highlight.layer.borderWidth = 1.5
        highlight.layer.borderColor = UIColor.systemYellow.withAlphaComponent(0.5).cgColor
        highlight.isUserInteractionEnabled = false
        highlight.isHidden = true
        tv.addSubview(highlight)
        context.coordinator.highlightView = highlight
        
        return tv
    }

    func updateUIView(_ uiView: UITextView, context: Context) {
        // Compare against stored base text
        if attributedText != context.coordinator.lastBaseText {
            context.coordinator.lastBaseText = attributedText
            uiView.attributedText = attributedText
            uiView.setContentOffset(.zero, animated: false)
            context.coordinator.targetY = 0
            context.coordinator.currentY = 0
            onProgress?(0)
        }
        
        if let resetBinding = resetToTop, resetBinding.wrappedValue {
            context.coordinator.smoothReset()
            onProgress?(0)
            DispatchQueue.main.async { resetBinding.wrappedValue = false }
        }
        
        // Full stop and reset
        if let stopBinding = stopAndReset, stopBinding.wrappedValue {
            context.coordinator.stop()
            uiView.setContentOffset(.zero, animated: false)
            context.coordinator.targetY = 0
            context.coordinator.currentY = 0
            onProgress?(0)
            DispatchQueue.main.async { stopBinding.wrappedValue = false }
        }
        
        context.coordinator.targetSpeed = speed
        context.coordinator.onFinished = onFinished
        context.coordinator.onProgress = onProgress
        context.coordinator.onReadingLineChanged = onReadingLineChanged
        context.coordinator.onVisibleTextExtracted = onVisibleTextExtracted
        
        if let requestBinding = requestVisibleText, requestBinding.wrappedValue {
            DispatchQueue.main.async {
                requestBinding.wrappedValue = false
                context.coordinator.extractVisibleText(uiView)
            }
        }
        
        // Dynamic vertical insets: half the frame height so first/last line sit at center
        let halfH = max(48, uiView.bounds.height * 0.5)
        let inset = UIEdgeInsets(top: halfH, left: sidePadding, bottom: halfH, right: sidePadding)
        if uiView.textContainerInset != inset {
            uiView.textContainerInset = inset
        }
        
        if mirror {
            if uiView.transform.a != -1 {
                uiView.transform = CGAffineTransform(scaleX: -1, y: 1)
            }
        } else {
            if uiView.transform.a == -1 {
                uiView.transform = .identity
            }
        }
        
        if isPlaying {
            context.coordinator.start()
        } else {
            context.coordinator.pause()
        }
    }

    class Coordinator {
        weak var textView: UITextView?
        var displayLink: CADisplayLink?
        var lastTimestamp: CFTimeInterval = 0
        
        // Smoothing parameters
        var currentY: CGFloat = 0        // Current smoothed position
        var targetY: CGFloat = 0         // Target position
        var currentSpeed: CGFloat = 0    // Current smoothed speed
        var targetSpeed: CGFloat = 60    // Target speed
        
        // Smoothing factors (0 = instant, 1 = never changes)
        let positionSmoothing: CGFloat = 0.85   // Smooth but responsive
        let speedSmoothing: CGFloat = 0.75      // Speed ramps up/down quickly
        
        var onFinished: (() -> Void)?
        var onProgress: ((CGFloat) -> Void)?
        var onReadingLineChanged: ((String, Int) -> Void)?
        var onVisibleTextExtracted: ((String) -> Void)?
        
        // Base text tracking
        var lastBaseText: NSAttributedString?
        
        // Highlight overlay for current line
        var highlightView: UIView?
        
        private var lastReadPosition: Int = -1
        private var warmupFrames: Int = 0
        private var isResetting: Bool = false
        private var readingFrameCounter: Int = 0
        private var needsFirstLineRead: Bool = false

        @objc func tick(_ link: CADisplayLink) {
            guard let tv = textView else { return }
            
            let maxOffset = max(0, tv.contentSize.height - tv.bounds.height + tv.contentInset.bottom)
            
            // Wait for layout
            if maxOffset <= 0 {
                warmupFrames += 1
                if warmupFrames > 180 { stop() }
                lastTimestamp = 0
                return
            }
            warmupFrames = 0
            
            // Read the first line as soon as layout is ready
            if needsFirstLineRead {
                needsFirstLineRead = false
                extractReadingLine(tv)
                updateHighlight(tv)
            }
            
            if lastTimestamp == 0 {
                lastTimestamp = link.timestamp
                currentY = tv.contentOffset.y
                targetY = currentY
                return
            }
            
            let dt = CGFloat(link.timestamp - lastTimestamp)
            lastTimestamp = link.timestamp
            
            // Skip large time jumps (background return)
            guard dt < 0.5 else { lastTimestamp = link.timestamp; return }
            
            // Handle reset animation
            if isResetting {
                currentY = currentY * 0.85 // Smooth deceleration to top
                if currentY < 1 {
                    currentY = 0
                    targetY = 0
                    isResetting = false
                }
                tv.contentOffset.y = currentY
                onProgress?(0)
                return
            }
            
            // Smooth speed interpolation (prevents abrupt speed changes)
            let effectiveTargetSpeed = isPaused ? 0 : targetSpeed
            currentSpeed = currentSpeed * speedSmoothing + effectiveTargetSpeed * (1 - speedSmoothing)
            
            // If paused and speed is negligible, skip further processing
            if isPaused && currentSpeed < 0.1 {
                currentSpeed = 0
                return
            }
            
            // Update target position based on smoothed speed
            targetY += dt * currentSpeed
            
            // Smooth position interpolation (the magic for fluid scrolling!)
            // Using exponential smoothing for buttery-smooth movement
            let smoothFactor = 1 - pow(positionSmoothing, dt * 60) // Frame-rate independent
            currentY = currentY + (targetY - currentY) * smoothFactor
            
            // Clamp and finish
            if currentY >= maxOffset {
                currentY = maxOffset
                targetY = maxOffset
                tv.contentOffset.y = currentY
                stop()
                onFinished?()
                onProgress?(1)
                return
            }
            
            tv.contentOffset.y = currentY
            let progress = max(0, min(1, currentY / maxOffset))
            onProgress?(progress)
            
            // Update highlight every frame for smooth tracking
            updateHighlight(tv)
            
            // Extract reading line ~10 times per second (voice sync)
            readingFrameCounter += 1
            if readingFrameCounter >= 6 {
                readingFrameCounter = 0
                extractReadingLine(tv)
            }
        }
        
        func smoothReset() {
            isResetting = true
            targetY = 0
            currentSpeed = 0
            highlightView?.isHidden = true
        }
        
        private func extractReadingLine(_ tv: UITextView) {
            let layoutManager = tv.layoutManager
            let textContainer = tv.textContainer
            
            // Reading position = center of visible frame, converted to text container coordinates
            let centerInContent = tv.contentOffset.y + tv.bounds.height * 0.5
            let readingY = centerInContent - tv.textContainerInset.top
            let readingPoint = CGPoint(x: 10, y: readingY)
            
            var fraction: CGFloat = 0
            let glyphIndex = layoutManager.glyphIndex(for: readingPoint, in: textContainer, fractionOfDistanceThroughGlyph: &fraction)
            let charIndex = layoutManager.characterIndexForGlyph(at: glyphIndex)
            
            guard let text = tv.text, charIndex < text.count else { return }
            if charIndex == lastReadPosition { return }
            
            var lineRange = NSRange()
            layoutManager.lineFragmentRect(forGlyphAt: glyphIndex, effectiveRange: &lineRange)
            let lineCharRange = layoutManager.characterRange(forGlyphRange: lineRange, actualGlyphRange: nil)
            
            guard lineCharRange.location != NSNotFound,
                  lineCharRange.location + lineCharRange.length <= text.count else { return }
            
            let startIndex = text.index(text.startIndex, offsetBy: lineCharRange.location)
            let endIndex = text.index(startIndex, offsetBy: lineCharRange.length)
            let lineText = String(text[startIndex..<endIndex]).trimmingCharacters(in: .whitespacesAndNewlines)
            
            guard !lineText.isEmpty else { return }
            
            if charIndex > lastReadPosition {
                lastReadPosition = charIndex
                onReadingLineChanged?(lineText, charIndex)
            }
        }
        
        func extractVisibleText(_ tv: UITextView) {
            let layoutManager = tv.layoutManager
            let textContainer = tv.textContainer
            
            guard let text = tv.text, !text.isEmpty else {
                DispatchQueue.main.async { [weak self] in
                    self?.onVisibleTextExtracted?("")
                }
                return
            }
            
            // Same reading position as extractReadingLine (center of frame, text container coords)
            let centerInContent = tv.contentOffset.y + tv.bounds.height * 0.5
            let readingY = centerInContent - tv.textContainerInset.top
            let readingPoint = CGPoint(x: 10, y: readingY)
            
            var fraction: CGFloat = 0
            let glyphIndex = layoutManager.glyphIndex(for: readingPoint, in: textContainer, fractionOfDistanceThroughGlyph: &fraction)
            let charIndex = layoutManager.characterIndexForGlyph(at: glyphIndex)
            
            guard charIndex < text.count else {
                DispatchQueue.main.async { [weak self] in self?.onVisibleTextExtracted?("") }
                return
            }
            
            var lineRange = NSRange()
            layoutManager.lineFragmentRect(forGlyphAt: glyphIndex, effectiveRange: &lineRange)
            let lineCharRange = layoutManager.characterRange(forGlyphRange: lineRange, actualGlyphRange: nil)
            
            guard lineCharRange.location != NSNotFound,
                  lineCharRange.location + lineCharRange.length <= text.count else {
                DispatchQueue.main.async { [weak self] in self?.onVisibleTextExtracted?("") }
                return
            }
            
            let startIndex = text.index(text.startIndex, offsetBy: lineCharRange.location)
            let endIndex = text.index(startIndex, offsetBy: lineCharRange.length)
            let lineText = String(text[startIndex..<endIndex]).trimmingCharacters(in: .whitespacesAndNewlines)
            
            DispatchQueue.main.async { [weak self] in
                self?.onVisibleTextExtracted?(lineText)
            }
        }

        private var isPaused: Bool = false
        
        func start() {
            isResetting = false
            
            if displayLink != nil {
                // Already running and not paused — nothing to do
                guard isPaused else { return }
                // Resume from pause
                isPaused = false
                // Allow re-emitting the current line so voice restarts
                if lastReadPosition > 0 { lastReadPosition -= 1 }
                needsFirstLineRead = true
                // Re-sync so we don't jump from where we drifted
                if let tv = textView {
                    currentY = tv.contentOffset.y
                    targetY = currentY
                }
                lastTimestamp = 0  // Force re-init of timestamp
                return
            }
            
            // Fresh start
            isPaused = false
            lastTimestamp = 0
            lastReadPosition = -1
            warmupFrames = 0
            readingFrameCounter = 0
            needsFirstLineRead = true
            
            if let tv = textView {
                currentY = tv.contentOffset.y
                targetY = currentY
            }
            
            let link = CADisplayLink(target: self, selector: #selector(tick(_:)))
            link.preferredFrameRateRange = CAFrameRateRange(minimum: 60, maximum: 120, __preferred: 120)
            link.add(to: .main, forMode: .common)
            displayLink = link
            
            // First line will be read on the first valid tick (when layout is ready)
        }

        func pause() {
            isPaused = true
            // Smooth deceleration: target speed goes to 0, smoothing handles the rest
        }
        
        /// Position highlight frame around the current reading line
        private func updateHighlight(_ tv: UITextView) {
            guard let highlight = highlightView else { return }
            let layoutManager = tv.layoutManager
            let textContainer = tv.textContainer
            
            // Text container coordinates
            let centerInContent = tv.contentOffset.y + tv.bounds.height * 0.5
            let readingY = centerInContent - tv.textContainerInset.top
            let readingPoint = CGPoint(x: 10, y: readingY)
            
            var fraction: CGFloat = 0
            let glyphIndex = layoutManager.glyphIndex(for: readingPoint, in: textContainer, fractionOfDistanceThroughGlyph: &fraction)
            
            var lineGlyphRange = NSRange()
            let lineRect = layoutManager.lineFragmentRect(forGlyphAt: glyphIndex, effectiveRange: &lineGlyphRange)
            
            // Convert from text container coordinates to text view coordinates
            let inset = tv.textContainerInset
            let padding: CGFloat = 4
            let frame = CGRect(
                x: lineRect.origin.x + inset.left - padding,
                y: lineRect.origin.y + inset.top - padding,
                width: lineRect.width + padding * 2,
                height: lineRect.height + padding * 2
            )
            
            highlight.frame = frame
            highlight.isHidden = false
        }
        
        func stop() {
            displayLink?.invalidate()
            displayLink = nil
            isPaused = false
            currentSpeed = 0
            highlightView?.isHidden = true
        }
    }
}
