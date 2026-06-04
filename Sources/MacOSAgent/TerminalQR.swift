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
        filter.setValue("L", forKey: "inputCorrectionLevel")
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

        // Compact rendering: half-block (▀) packs two module rows per text line and one
        // column per character. ANSI fg/bg force true black-on-white regardless of the
        // terminal theme (so phone scanners read it). A 4-module quiet zone is added.
        func dark(_ x: Int, _ y: Int) -> Bool {
            guard x >= 0, x < width, y >= 0, y < height else { return false } // outside = light
            return pixels[y * width + x] < 128
        }
        let esc = "\u{1b}"
        let reset = "\(esc)[0m"
        let quiet = 4
        var lines: [String] = []
        var y = -quiet
        while y < height + quiet {
            var line = ""
            var lastFg = -1, lastBg = -1
            for x in (-quiet)..<(width + quiet) {
                let fg = dark(x, y) ? 30 : 97        // 30 = black, 97 = bright white
                let bg = dark(x, y + 1) ? 40 : 107   // 40 = black bg, 107 = white bg
                if fg != lastFg || bg != lastBg {
                    line += "\(esc)[\(fg);\(bg)m"
                    lastFg = fg; lastBg = bg
                }
                line += "▀"
            }
            line += reset
            lines.append(line)
            y += 2
        }
        return lines.joined(separator: "\n")
    }
}
#endif
