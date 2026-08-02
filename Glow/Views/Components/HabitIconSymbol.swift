import SwiftUI

/// Renders both SF Symbols and the small set of custom practice symbols used by Glow.
struct HabitIconSymbol: View {
    let name: String
    var size: CGFloat = 18
    var weight: Font.Weight = .semibold

    var body: some View {
        Group {
            switch name {
            case HabitIconLibrary.martiniIconName:
                MartiniGlassShape()
            case HabitIconLibrary.candyIconName:
                Image("HabitCandyGummies")
                    .renderingMode(.original)
                    .resizable()
                    .scaledToFit()
                    .scaleEffect(1.25)
            case HabitIconLibrary.cannabisIconName:
                Image("HabitCannabisLeaf")
                    .renderingMode(.template)
                    .resizable()
                    .scaledToFit()
            default:
                Image(systemName: name)
                    .font(.system(size: size, weight: weight))
            }
        }
        .frame(width: size, height: size)
        .accessibilityHidden(true)
    }
}

private struct MartiniGlassShape: Shape {
    func path(in rect: CGRect) -> Path {
        let width = rect.width
        let height = rect.height
        let line = max(width * 0.085, 1)
        var path = Path()

        path.addRoundedRect(
            in: CGRect(x: width * 0.08, y: height * 0.08, width: width * 0.84, height: line),
            cornerSize: CGSize(width: line / 2, height: line / 2)
        )

        path.move(to: CGPoint(x: width * 0.12, y: height * 0.13))
        path.addLine(to: CGPoint(x: width * 0.22, y: height * 0.13))
        path.addLine(to: CGPoint(x: width * 0.53, y: height * 0.57))
        path.addLine(to: CGPoint(x: width * 0.47, y: height * 0.64))
        path.closeSubpath()

        path.move(to: CGPoint(x: width * 0.78, y: height * 0.13))
        path.addLine(to: CGPoint(x: width * 0.88, y: height * 0.13))
        path.addLine(to: CGPoint(x: width * 0.53, y: height * 0.64))
        path.addLine(to: CGPoint(x: width * 0.47, y: height * 0.57))
        path.closeSubpath()

        path.addRect(CGRect(x: width * 0.46, y: height * 0.57, width: width * 0.08, height: height * 0.29))
        path.addRoundedRect(
            in: CGRect(x: width * 0.23, y: height * 0.82, width: width * 0.54, height: height * 0.1),
            cornerSize: CGSize(width: line / 2, height: line / 2)
        )
        path.addEllipse(in: CGRect(x: width * 0.57, y: height * 0.24, width: width * 0.17, height: height * 0.17))

        return path
    }
}
