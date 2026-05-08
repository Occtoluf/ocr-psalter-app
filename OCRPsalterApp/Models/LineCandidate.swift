import Foundation
import UIKit

struct LineCandidate: Identifiable {
    var id = UUID()
    var index: Int
    var rect: CGRect
    var image: UIImage
    var isEnabled: Bool = true
}
