import Foundation
import UIKit

struct PageLineSegmenter {
    struct Options {
        var maxAnalysisWidth = 1600
        var minLineHeight: Int = 10
        var mergeGap: Int = 5
        var topPadding: Int = 24
        var bottomPadding: Int = 10
        var sidePadding: Int = 16
        var projectionSideInset: Double = 0.04
    }

    var options = Options()

    func segment(image: UIImage) -> [LineCandidate] {
        guard let gray = ImageRasterizer.grayscalePixels(from: image, maxWidth: options.maxAnalysisWidth) else {
            return []
        }

        let inkThreshold = estimateInkThreshold(gray)
        let xAnalysisRange = analysisXRange(width: gray.width)
        let rowCounts = rowDarkPixelCounts(
            gray,
            inkThreshold: inkThreshold,
            xRange: xAnalysisRange
        )
        let smoothed = smooth(rowCounts, radius: max(3, gray.height / 700))
        let threshold = projectionThreshold(values: smoothed, width: xAnalysisRange.count)
        let runs = detectRuns(values: smoothed, threshold: threshold)
        let merged = splitLargeRuns(
            mergeRuns(runs),
            values: smoothed,
            threshold: threshold,
            pageHeight: gray.height
        )
            .filter { ($0.upperBound - $0.lowerBound) >= options.minLineHeight }

        let source = image.normalizedOrientation()
        let scaleX = source.size.width / CGFloat(gray.width)
        let scaleY = source.size.height / CGFloat(gray.height)

        var candidates: [LineCandidate] = []

        for (idx, yRange) in merged.enumerated() {
            let xRange = horizontalBounds(
                gray,
                yRange: yRange,
                inkThreshold: inkThreshold
            )
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

    private func estimateInkThreshold(_ image: GrayscaleImage) -> UInt8 {
        var histogram = [Int](repeating: 0, count: 256)
        for pixel in image.pixels {
            histogram[Int(pixel)] += 1
        }

        let total = image.pixels.count
        let totalWeighted = histogram.enumerated().reduce(0) { partial, item in
            partial + item.offset * item.element
        }

        var backgroundWeight = 0
        var backgroundSum = 0
        var bestThreshold = 128
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

        let adjusted = min(190, max(70, bestThreshold + 12))
        return UInt8(adjusted)
    }

    private func analysisXRange(width: Int) -> Range<Int> {
        let inset = Int(Double(width) * options.projectionSideInset)
        let lower = min(max(0, inset), max(0, width - 1))
        let upper = max(lower + 1, width - inset)
        return lower..<upper
    }

    private func rowDarkPixelCounts(
        _ image: GrayscaleImage,
        inkThreshold: UInt8,
        xRange: Range<Int>
    ) -> [Int] {
        var counts = [Int](repeating: 0, count: image.height)
        for y in 0..<image.height {
            var count = 0
            for x in xRange where image[x, y] < inkThreshold {
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

    private func projectionThreshold(values: [Int], width: Int) -> Int {
        guard !values.isEmpty else {
            return 1
        }

        let sorted = values.sorted()
        let p50 = percentile(sorted, 0.50)
        let p90 = percentile(sorted, 0.90)
        let dynamic = p50 + max(4, Int(Double(max(1, p90 - p50)) * 0.28))
        let widthFloor = max(4, Int(Double(width) * 0.0035))
        return max(widthFloor, dynamic)
    }

    private func percentile(_ sortedValues: [Int], _ q: Double) -> Int {
        guard !sortedValues.isEmpty else {
            return 0
        }

        let clamped = min(1.0, max(0.0, q))
        let idx = Int(Double(sortedValues.count - 1) * clamped)
        return sortedValues[idx]
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

    private func splitLargeRuns(
        _ runs: [Range<Int>],
        values: [Int],
        threshold: Int,
        pageHeight: Int
    ) -> [Range<Int>] {
        var output: [Range<Int>] = []
        let largeRunHeight = max(80, pageHeight / 9)

        for run in runs {
            let height = run.upperBound - run.lowerBound
            guard height > largeRunHeight else {
                output.append(run)
                continue
            }

            let localValues = Array(values[run])
            let sorted = localValues.sorted()
            let highThreshold = max(
                threshold + 4,
                percentile(sorted, 0.62)
            )
            let localRuns = detectRuns(values: localValues, threshold: highThreshold)
                .map { (run.lowerBound + $0.lowerBound)..<(run.lowerBound + $0.upperBound) }
            let refined = mergeRuns(localRuns)
                .filter { ($0.upperBound - $0.lowerBound) >= options.minLineHeight }

            if refined.count >= 2 {
                output.append(contentsOf: refined)
            } else {
                output.append(run)
            }
        }

        return output
    }

    private func horizontalBounds(
        _ image: GrayscaleImage,
        yRange: Range<Int>,
        inkThreshold: UInt8
    ) -> Range<Int> {
        var minX = image.width
        var maxX = 0

        for y in yRange {
            for x in 0..<image.width where image[x, y] < inkThreshold {
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
