#if canImport(UIKit)
import UIKit
import AVFoundation
import SwiftUI

/// Camera view that scans QR codes and reports their string value (F5 pairing).
public final class QRScannerUIView: UIView {
    public var onCode: ((String) -> Void)?

    private let session = AVCaptureSession()
    private var previewLayer: AVCaptureVideoPreviewLayer?
    private let sessionQueue = DispatchQueue(label: "mitm.qr")
    private let proxy = MetadataProxy()

    public override init(frame: CGRect) { super.init(frame: frame); configure() }
    public required init?(coder: NSCoder) { super.init(coder: coder); configure() }

    private func configure() {
        proxy.onCode = { [weak self] code in
            DispatchQueue.main.async { self?.onCode?(code) }
        }
        guard let device = AVCaptureDevice.default(for: .video),
              let input = try? AVCaptureDeviceInput(device: device),
              session.canAddInput(input) else { return }
        session.addInput(input)

        let output = AVCaptureMetadataOutput()
        guard session.canAddOutput(output) else { return }
        session.addOutput(output)
        output.setMetadataObjectsDelegate(proxy, queue: sessionQueue)
        output.metadataObjectTypes = [.qr]

        let preview = AVCaptureVideoPreviewLayer(session: session)
        preview.videoGravity = .resizeAspectFill
        layer.addSublayer(preview)
        previewLayer = preview
    }

    public override func layoutSubviews() {
        super.layoutSubviews()
        previewLayer?.frame = bounds
    }

    public func start() {
        sessionQueue.async { [session] in if !session.isRunning { session.startRunning() } }
    }

    public func stop() {
        sessionQueue.async { [session] in if session.isRunning { session.stopRunning() } }
    }

    private final class MetadataProxy: NSObject, AVCaptureMetadataOutputObjectsDelegate {
        var onCode: ((String) -> Void)?
        func metadataOutput(_ output: AVCaptureMetadataOutput,
                            didOutput metadataObjects: [AVMetadataObject],
                            from connection: AVCaptureConnection) {
            guard let object = metadataObjects.first as? AVMetadataMachineReadableCodeObject,
                  let value = object.stringValue else { return }
            onCode?(value)
        }
    }
}

/// SwiftUI wrapper around the QR scanner.
public struct QRScannerView: UIViewRepresentable {
    private let onCode: (String) -> Void
    public init(onCode: @escaping (String) -> Void) { self.onCode = onCode }

    public func makeUIView(context: Context) -> QRScannerUIView {
        let view = QRScannerUIView()
        view.onCode = onCode
        view.start()
        return view
    }

    public func updateUIView(_ uiView: QRScannerUIView, context: Context) {}
}
#endif
