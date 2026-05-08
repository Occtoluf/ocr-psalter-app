import CoreGraphics
import CoreML
import Foundation
import UIKit

struct LineImagePreprocessor {
    func makeInputArray(from image: UIImage, targetHeight: Int, targetWidth: Int) throws -> MLMultiArray {
        guard let rendered = renderLine(image, targetHeight: targetHeight, targetWidth: targetWidth),
              let cgImage = rendered.cgImage
        else {
            throw OCRServiceError.preprocessingFailed
        }

        var pixels = [UInt8](repeating: 255, count: targetWidth * targetHeight)
        guard let context = CGContext(
            data: &pixels,
            width: targetWidth,
            height: targetHeight,
            bitsPerComponent: 8,
            bytesPerRow: targetWidth,
            space: CGColorSpaceCreateDeviceGray(),
            bitmapInfo: CGImageAlphaInfo.none.rawValue
        ) else {
            throw OCRServiceError.preprocessingFailed
        }

        context.interpolationQuality = .high
        context.draw(cgImage, in: CGRect(x: 0, y: 0, width: targetWidth, height: targetHeight))

        let array = try MLMultiArray(
            shape: [
                NSNumber(value: 1),
                NSNumber(value: 1),
                NSNumber(value: targetHeight),
                NSNumber(value: targetWidth)
            ],
            dataType: .float32
        )

        for y in 0..<targetHeight {
            for x in 0..<targetWidth {
                let value = Float(pixels[y * targetWidth + x]) / 255.0
                array[
                    [
                        NSNumber(value: 0),
                        NSNumber(value: 0),
                        NSNumber(value: y),
                        NSNumber(value: x)
                    ]
                ] = NSNumber(value: value)
            }
        }

        return array
    }

    private func renderLine(_ image: UIImage, targetHeight: Int, targetWidth: Int) -> UIImage? {
        let source = image.normalizedOrientation()
        let sourceSize = source.size
        guard sourceSize.width > 0, sourceSize.height > 0 else {
            return nil
        }

        let scaleByHeight = CGFloat(targetHeight) / sourceSize.height
        let widthAtTargetHeight = sourceSize.width * scaleByHeight
        let finalScale: CGFloat

        if widthAtTargetHeight <= CGFloat(targetWidth) {
            finalScale = scaleByHeight
        } else {
            finalScale = CGFloat(targetWidth) / sourceSize.width
        }

        let drawSize = CGSize(
            width: max(1, sourceSize.width * finalScale),
            height: max(1, sourceSize.height * finalScale)
        )
        let origin = CGPoint(
            x: 0,
            y: (CGFloat(targetHeight) - drawSize.height) / 2.0
        )

        let format = UIGraphicsImageRendererFormat()
        format.scale = 1
        format.opaque = true

        let renderer = UIGraphicsImageRenderer(
            size: CGSize(width: targetWidth, height: targetHeight),
            format: format
        )

        return renderer.image { context in
            UIColor.white.setFill()
            context.fill(CGRect(x: 0, y: 0, width: targetWidth, height: targetHeight))
            source.draw(in: CGRect(origin: origin, size: drawSize))
        }
    }
}
