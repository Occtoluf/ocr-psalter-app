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

        pixels = binarize(pixels, width: targetWidth, height: targetHeight)
        pixels = removeDenseEdgeBands(pixels, width: targetWidth, height: targetHeight)

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

    private func binarize(_ pixels: [UInt8], width: Int, height: Int) -> [UInt8] {
        let threshold = otsuThreshold(pixels)
        return pixels.map { $0 < threshold ? 0 : 255 }
    }

    private func otsuThreshold(_ pixels: [UInt8]) -> UInt8 {
        var histogram = [Int](repeating: 0, count: 256)
        for pixel in pixels {
            histogram[Int(pixel)] += 1
        }

        let total = pixels.count
        let totalWeighted = histogram.enumerated().reduce(0) { partial, item in
            partial + item.offset * item.element
        }

        var backgroundWeight = 0
        var backgroundSum = 0
        var bestThreshold = 170
        var bestVariance = -1.0

        for threshold in 0..<256 {
            backgroundWeight += histogram[threshold]
            if backgroundWeight == 0 {
                continue
            }

            let foregroundWeight = total - backgroundWeight
            if foregroundWeight == 0 {
                break
            }

            backgroundSum += threshold * histogram[threshold]
            let backgroundMean = Double(backgroundSum) / Double(backgroundWeight)
            let foregroundMean = Double(totalWeighted - backgroundSum) / Double(foregroundWeight)
            let variance = Double(backgroundWeight)
                * Double(foregroundWeight)
                * pow(backgroundMean - foregroundMean, 2)

            if variance > bestVariance {
                bestVariance = variance
                bestThreshold = threshold
            }
        }

        return UInt8(min(220, max(95, bestThreshold + 8)))
    }

    private func removeDenseEdgeBands(_ pixels: [UInt8], width: Int, height: Int) -> [UInt8] {
        var cleaned = pixels
        let maxScanColumns = min(42, max(1, width / 18))
        let denseLimit = Int(Double(height) * 0.55)

        func darkCount(column x: Int) -> Int {
            var count = 0
            for y in 0..<height where cleaned[y * width + x] == 0 {
                count += 1
            }
            return count
        }

        func whiten(column x: Int) {
            for y in 0..<height {
                cleaned[y * width + x] = 255
            }
        }

        var safeColumns = 0
        for x in 0..<maxScanColumns {
            if darkCount(column: x) > denseLimit {
                whiten(column: x)
                safeColumns = 0
            } else {
                safeColumns += 1
                if safeColumns >= 4 {
                    break
                }
            }
        }

        safeColumns = 0
        for x in stride(from: width - 1, through: max(0, width - maxScanColumns), by: -1) {
            if darkCount(column: x) > denseLimit {
                whiten(column: x)
                safeColumns = 0
            } else {
                safeColumns += 1
                if safeColumns >= 4 {
                    break
                }
            }
        }

        return cleaned
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
