#if os(macOS)
import Foundation
import CoreImage
import CoreGraphics

/// Renders a QR code as terminal ASCII blocks — a development aid for pairing.
public enum TerminalQR {
    public static func render(_ string: String) -> String? {
        guard let data = string.data(using: .utf8),
              let filter = CIFilter(name: "CIQRCodeGenerator") else { return nil }
        filter.setValue(data, forKey: "inputMessage")
        filter.setValue("M", forKey: "inputCorrectionLevel")
        guard let ciImage = filter.outputImage else { return nil }

        let context = CIContext(options: nil)
        guard let cgImage = context.createCGImage(ciImage, from: ciImage.extent) else { return nil }

        let width = cgImage.width
        let height = cgImage.height
        guard width > 0, height > 0 else { return nil }

        var pixels = [UInt8](repeating: 0, count: width * height)
        let colorSpace = CGColorSpaceCreateDeviceGray()
        guard let bitmap = CGContext(data: &pixels, width: width, height: height,
                                     bitsPerComponent: 8, bytesPerRow: width, space: colorSpace,
                                     bitmapInfo: CGImageAlphaInfo.none.rawValue) else { return nil }
        bitmap.setFillColor(CGColor(gray: 1, alpha: 1))
        bitmap.fill(CGRect(x: 0, y: 0, width: width, height: height))
        bitmap.draw(cgImage, in: CGRect(x: 0, y: 0, width: width, height: height))

        let border = 2
        let blankLine = String(repeating: "  ", count: width + border * 2)
        var lines: [String] = Array(repeating: blankLine, count: border)
        for y in 0..<height {
            var row = String(repeating: "  ", count: border)
            for x in 0..<width {
                row += pixels[y * width + x] < 128 ? "██" : "  "
            }
            row += String(repeating: "  ", count: border)
            lines.append(row)
        }
        lines.append(contentsOf: Array(repeating: blankLine, count: border))
        return lines.joined(separator: "\n")
    }
}
#endif
