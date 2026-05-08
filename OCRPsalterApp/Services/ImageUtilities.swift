import CoreGraphics
import UIKit

extension UIImage {
    func normalizedOrientation() -> UIImage {
        if imageOrientation == .up {
            return self
        }

        let format = UIGraphicsImageRendererFormat()
        format.scale = scale
        format.opaque = false
        return UIGraphicsImageRenderer(size: size, format: format).image { _ in
            draw(in: CGRect(origin: .zero, size: size))
        }
    }

    func resizedTo(maxWidth: CGFloat) -> UIImage {
        let source = normalizedOrientation()
        guard source.size.width > maxWidth else {
            return source
        }

        let scale = maxWidth / source.size.width
        let newSize = CGSize(width: maxWidth, height: source.size.height * scale)
        let format = UIGraphicsImageRendererFormat()
        format.scale = 1
        format.opaque = true
        return UIGraphicsImageRenderer(size: newSize, format: format).image { _ in
            UIColor.white.setFill()
            UIRectFill(CGRect(origin: .zero, size: newSize))
            source.draw(in: CGRect(origin: .zero, size: newSize))
        }
    }

    func cropped(to rect: CGRect) -> UIImage? {
        let source = normalizedOrientation()
        guard let cgImage = source.cgImage else {
            return nil
        }

        let scaleX = CGFloat(cgImage.width) / source.size.width
        let scaleY = CGFloat(cgImage.height) / source.size.height
        let pixelRect = CGRect(
            x: rect.origin.x * scaleX,
            y: rect.origin.y * scaleY,
            width: rect.width * scaleX,
            height: rect.height * scaleY
        ).integral

        guard let crop = cgImage.cropping(to: pixelRect) else {
            return nil
        }

        return UIImage(cgImage: crop, scale: source.scale, orientation: .up)
    }
}

struct GrayscaleImage {
    let width: Int
    let height: Int
    let pixels: [UInt8]

    subscript(x: Int, y: Int) -> UInt8 {
        pixels[y * width + x]
    }
}

enum ImageRasterizer {
    static func grayscalePixels(from image: UIImage, maxWidth: Int = 1600) -> GrayscaleImage? {
        let normalized = image.normalizedOrientation().resizedTo(maxWidth: CGFloat(maxWidth))
        guard let cgImage = normalized.cgImage else {
            return nil
        }

        let width = cgImage.width
        let height = cgImage.height
        var pixels = [UInt8](repeating: 255, count: width * height)

        guard let context = CGContext(
            data: &pixels,
            width: width,
            height: height,
            bitsPerComponent: 8,
            bytesPerRow: width,
            space: CGColorSpaceCreateDeviceGray(),
            bitmapInfo: CGImageAlphaInfo.none.rawValue
        ) else {
            return nil
        }

        context.interpolationQuality = .high
        context.draw(cgImage, in: CGRect(x: 0, y: 0, width: width, height: height))
        return GrayscaleImage(width: width, height: height, pixels: pixels)
    }
}
