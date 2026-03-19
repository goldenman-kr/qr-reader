import CoreGraphics

enum PhoneLayout {
    static let phoneSize = CGSize(width: 340, height: 700)
    static let outerCornerRadius: CGFloat = 42
    static let viewfinderCornerRadius: CGFloat = 28

    static func viewfinderRect(in size: CGSize) -> CGRect {
        let horizontalPadding: CGFloat = 12
        let topInset: CGFloat = 52
        let bottomControlsHeight: CGFloat = 120
        return CGRect(
            x: horizontalPadding,
            y: topInset,
            width: size.width - (horizontalPadding * 2),
            height: size.height - topInset - bottomControlsHeight
        )
    }
}
