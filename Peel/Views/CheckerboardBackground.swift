//
//  CheckerboardBackground.swift
//  Peel
//

import SwiftUI

/// The familiar grey checkerboard that signals transparency behind an image.
struct CheckerboardBackground: View {
    var square: CGFloat = 10

    var body: some View {
        Canvas { context, size in
            let light = Color(white: 0.95)
            let dark = Color(white: 0.82)
            context.fill(Path(CGRect(origin: .zero, size: size)), with: .color(light))

            let columns = Int((size.width / square).rounded(.up))
            let rows = Int((size.height / square).rounded(.up))
            for row in 0..<rows {
                for column in 0..<columns where (row + column).isMultiple(of: 2) {
                    let rect = CGRect(
                        x: CGFloat(column) * square,
                        y: CGFloat(row) * square,
                        width: square,
                        height: square
                    )
                    context.fill(Path(rect), with: .color(dark))
                }
            }
        }
        .drawingGroup()
    }
}

#Preview {
    CheckerboardBackground()
        .frame(width: 240, height: 160)
}
