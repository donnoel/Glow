import Foundation

nonisolated enum WaterUnit: String, CaseIterable, Identifiable {
    case ounces, milliliters

    var id: String { rawValue }
    var title: String { self == .ounces ? "US fluid ounces" : "Milliliters" }
    var symbol: String { self == .ounces ? "fl oz" : "mL" }
    static let millilitersPerOunce = 29.5735295625
    static var defaultPresets: [Double] { [12, 21, 24, 28].map { $0 * millilitersPerOunce } }

    func milliliters(from value: Double) -> Double {
        self == .ounces ? value * Self.millilitersPerOunce : value
    }

    func value(from milliliters: Double) -> Double {
        self == .ounces ? milliliters / Self.millilitersPerOunce : milliliters
    }

    func number(_ milliliters: Double) -> String {
        value(from: milliliters).formatted(.number.precision(.fractionLength(0...1)))
    }

    func inputNumber(_ milliliters: Double) -> String {
        value(from: milliliters).formatted(.number.grouping(.never).precision(.fractionLength(0...4)))
    }

    func label(_ milliliters: Double) -> String { "\(number(milliliters)) \(symbol)" }

    static func isValidAmount(_ value: Double) -> Bool {
        value.isFinite && value > 0 && value <= 100_000
    }

    func parse(_ text: String, locale: Locale = .current) -> Double? {
        let text = text.trimmingCharacters(in: .whitespacesAndNewlines)
        // Reject partial parses such as "12oops" and scientific notation.
        let separator = locale.decimalSeparator ?? "."
        let parts = text.components(separatedBy: separator)
        guard !text.isEmpty, parts.count <= 2,
              text.allSatisfy({ $0.isNumber || String($0) == separator }),
              let value = Double(parts.joined(separator: ".")) else { return nil }
        let amount = milliliters(from: value)
        return Self.isValidAmount(amount) ? amount : nil
    }
}
