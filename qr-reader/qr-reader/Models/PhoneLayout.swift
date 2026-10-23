import CoreGraphics

enum PhoneLayout {
    static let phoneSize = CGSize(width: 340, height: 500)
    static let outerCornerRadius: CGFloat = 34
    static let viewfinderCornerRadius: CGFloat = 22

    static func viewfinderRect(in size: CGSize) -> CGRect {
        let horizontalPadding: CGFloat = 12
        let topInset: CGFloat = 58
        let bottomControlsHeight: CGFloat = 158
        return CGRect(
            x: horizontalPadding,
            y: topInset,
            width: size.width - (horizontalPadding * 2),
            height: size.height - topInset - bottomControlsHeight
        )
    }
}
