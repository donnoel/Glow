import Combine
import Foundation

@MainActor
final class MomentumReportViewModel: ObservableObject {
    @Published private(set) var report: MomentumReport?

    func refresh(period: MomentumReportPeriod, scope: MomentumReportScope, habits: [Habit], entries: [WaterEntry],
                 goals: [WaterDayGoal], unit: WaterUnit) {
        report = MomentumReportBuilder.make(period: period, scope: scope, habits: habits,
                                            entries: entries.map(WaterEntryValue.init),
                                            goals: goals.map(WaterGoalValue.init), unit: unit)
    }
}
