import SwiftUI
import UIKit

struct TeleprompterTextView: UIViewRepresentable {
    @Binding var attributedText: NSAttributedString
    @Binding var isPlaying: Bool
    var speed: CGFloat // points per second
    var mirror: Bool = false
    var sidePadding: CGFloat = 20
    var onFinished: (() -> Void)? = nil
    var onProgress: ((CGFloat) -> Void)? = nil // 0...1

    func makeCoordinator() -> Coordinator { Coordinator() }

    func makeUIView(context: Context) -> UITextView {
        let tv = UITextView()
        tv.backgroundColor = .clear
        tv.isEditable = false
        tv.isSelectable = false
        tv.showsVerticalScrollIndicator = false
        tv.textContainerInset = UIEdgeInsets(top: 48, left: sidePadding, bottom: 48, right: sidePadding)
        tv.textContainer.lineBreakMode = .byWordWrapping
        tv.textContainer.widthTracksTextView = true
        context.coordinator.textView = tv
        return tv
    }

    func updateUIView(_ uiView: UITextView, context: Context) {
        if uiView.attributedText != attributedText {
            uiView.attributedText = attributedText
            // Reset to top when text changes
            uiView.setContentOffset(.zero, animated: false)
            onProgress?(0)
        }
        context.coordinator.speed = speed
        context.coordinator.onFinished = onFinished
        context.coordinator.onProgress = onProgress
        // Update side padding
        let inset = UIEdgeInsets(top: 48, left: sidePadding, bottom: 48, right: sidePadding)
        if uiView.textContainerInset != inset {
            uiView.textContainerInset = inset
        }
        // Apply mirror transform if needed
        if mirror {
            if uiView.transform.a != -1 { // not mirrored yet
                uiView.transform = CGAffineTransform(scaleX: -1, y: 1)
                uiView.textAlignment = .natural
            }
        } else {
            if uiView.transform.a == -1 { // mirrored -> reset
                uiView.transform = .identity
            }
        }
        if isPlaying {
            context.coordinator.start()
        } else {
            context.coordinator.stop()
        }
    }

    class Coordinator {
        weak var textView: UITextView?
        var displayLink: CADisplayLink?
        var lastTimestamp: CFTimeInterval = 0
        var speed: CGFloat = 60
        var onFinished: (() -> Void)?
        var onProgress: ((CGFloat) -> Void)?

        @objc func tick(_ link: CADisplayLink) {
            guard let tv = textView else { return }
            if lastTimestamp == 0 { lastTimestamp = link.timestamp; return }
            let dt = CGFloat(link.timestamp - lastTimestamp)
            lastTimestamp = link.timestamp

            var offset = tv.contentOffset
            offset.y += dt * speed
            let maxOffset = max(0, tv.contentSize.height - tv.bounds.height + tv.contentInset.bottom)
            if offset.y >= maxOffset {
                offset.y = maxOffset
                tv.setContentOffset(offset, animated: false)
                stop()
                onFinished?()
                onProgress?(1)
                return
            }
            tv.setContentOffset(offset, animated: false)
            let progress = max(0, min(1, maxOffset == 0 ? 1 : offset.y / maxOffset))
            onProgress?(progress)
        }

        func start() {
            guard displayLink == nil else { return }
            lastTimestamp = 0
            let link = CADisplayLink(target: self, selector: #selector(tick(_:)))
            link.add(to: .main, forMode: .default)
            displayLink = link
        }

        func stop() {
            displayLink?.invalidate()
            displayLink = nil
        }
    }
}
