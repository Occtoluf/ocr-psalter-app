import Foundation
import UIKit

struct PageLineSegmenter {
    struct Options {
        var maxAnalysisWidth = 1600
        var darkThreshold: UInt8 = 205
        var minLineHeight: Int = 8
        var mergeGap: Int = 8
        var topPadding: Int = 18
        var bottomPadding: Int = 10
        var sidePadding: Int = 16
    }

    var options = Options()

    func segment(image: UIImage) -> [LineCandidate] {
        guard let gray = ImageRasterizer.grayscalePixels(from: image, maxWidth: options.maxAnalysisWidth) else {
            return []
        }

        let rowCounts = rowDarkPixelCounts(gray)
        let smoothed = smooth(rowCounts, radius: 3)
        let threshold = max(4, Int(Double(gray.width) * 0.012))
        let runs = detectRuns(values: smoothed, threshold: threshold)
        let merged = mergeRuns(runs)
            .filter { ($0.upperBound - $0.lowerBound) >= options.minLineHeight }

        let source = image.normalizedOrientation()
        let scaleX = source.size.width / CGFloat(gray.width)
        let scaleY = source.size.height / CGFloat(gray.height)

        var candidates: [LineCandidate] = []

        for (idx, yRange) in merged.enumerated() {
            let xRange = horizontalBounds(gray, yRange: yRange)
            let paddedY0 = max(0, yRange.lowerBound - options.topPadding)
            let paddedY1 = min(gray.height, yRange.upperBound + options.bottomPadding)
            let paddedX0 = max(0, xRange.lowerBound - options.sidePadding)
            let paddedX1 = min(gray.width, xRange.upperBound + options.sidePadding)

            let rect = CGRect(
                x: CGFloat(paddedX0) * scaleX,
                y: CGFloat(paddedY0) * scaleY,
                width: CGFloat(max(1, paddedX1 - paddedX0)) * scaleX,
                height: CGFloat(max(1, paddedY1 - paddedY0)) * scaleY
            )

            guard let crop = source.cropped(to: rect) else {
                continue
            }

            candidates.append(LineCandidate(index: idx + 1, rect: rect, image: crop))
        }

        return candidates
    }

    private func rowDarkPixelCounts(_ image: GrayscaleImage) -> [Int] {
        var counts = [Int](repeating: 0, count: image.height)
        for y in 0..<image.height {
            var count = 0
            for x in 0..<image.width where image[x, y] < options.darkThreshold {
                count += 1
            }
            counts[y] = count
        }
        return counts
    }

    private func smooth(_ values: [Int], radius: Int) -> [Int] {
        guard !values.isEmpty else {
            return []
        }

        var result = [Int](repeating: 0, count: values.count)
        for i in values.indices {
            let lower = max(values.startIndex, i - radius)
            let upper = min(values.endIndex - 1, i + radius)
            let slice = values[lower...upper]
            result[i] = slice.reduce(0, +) / slice.count
        }
        return result
    }

    private func detectRuns(values: [Int], threshold: Int) -> [Range<Int>] {
        var runs: [Range<Int>] = []
        var start: Int?

        for (idx, value) in values.enumerated() {
            if value >= threshold, start == nil {
                start = idx
            } else if value < threshold, let s = start {
                runs.append(s..<idx)
                start = nil
            }
        }

        if let start {
            runs.append(start..<values.count)
        }

        return runs
    }

    private func mergeRuns(_ runs: [Range<Int>]) -> [Range<Int>] {
        guard var current = runs.first else {
            return []
        }

        var merged: [Range<Int>] = []
        for run in runs.dropFirst() {
            if run.lowerBound - current.upperBound <= options.mergeGap {
                current = current.lowerBound..<run.upperBound
            } else {
                merged.append(current)
                current = run
            }
        }
        merged.append(current)
        return merged
    }

    private func horizontalBounds(_ image: GrayscaleImage, yRange: Range<Int>) -> Range<Int> {
        var minX = image.width
        var maxX = 0

        for y in yRange {
            for x in 0..<image.width where image[x, y] < options.darkThreshold {
                minX = min(minX, x)
                maxX = max(maxX, x)
            }
        }

        if minX >= maxX {
            return 0..<image.width
        }

        return minX..<maxX
    }
}
