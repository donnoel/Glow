import SwiftData
import SwiftUI

struct MomentumReportView: View {
    @Environment(\.dismiss) private var dismiss
    @Query private var entries: [WaterEntry]
    @Query private var goals: [WaterDayGoal]
    @Query(sort: [SortDescriptor(\WaterPreferences.updatedAt, order: .reverse), SortDescriptor(\WaterPreferences.id)])
    private var preferences: [WaterPreferences]
    @StateObject private var viewModel = MomentumReportViewModel()
    @State private var period: MomentumReportPeriod = .weekly
    @State private var scope: MomentumReportScope = .all
    let habits: [Habit]

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    VStack(alignment: .leading, spacing: 8) {
                        Picker("Reporting period", selection: $period) {
                            ForEach(MomentumReportPeriod.allCases) { period in
                                Text(period.title).tag(period)
                            }
                        }
                        .pickerStyle(.menu)
                        .accessibilityIdentifier("momentumReportPeriod")

                        Picker("Include habits", selection: $scope) {
                            ForEach(MomentumReportScope.allCases) { scope in
                                Text(scope.title).tag(scope)
                            }
                        }
                        .pickerStyle(.menu)
                        .accessibilityIdentifier("momentumReportScope")

                        Text(period.explanation)
                            .font(.subheadline)
                            .foregroundStyle(GlowTheme.textSecondary)
                    }

                    if let report = viewModel.report {
                        VStack(alignment: .leading, spacing: 8) {
                            Text(report.title)
                                .font(.title2.weight(.semibold))
                                .accessibilityAddTraits(.isHeader)
                                .accessibilityIdentifier("momentumReportTitle")
                            Text(report.dateRange)
                                .foregroundStyle(GlowTheme.textSecondary)
                        }
                        reportSection("Momentum", text: report.momentumText)

                        if !report.habits.isEmpty {
                            VStack(alignment: .leading, spacing: 16) {
                                Text("By habit").font(.headline).accessibilityAddTraits(.isHeader)
                                ForEach(report.habits) { habit in
                                    VStack(alignment: .leading, spacing: 4) {
                                        Text(habit.title).font(.subheadline.weight(.semibold))
                                        Text(habit.detail).font(.subheadline).foregroundStyle(GlowTheme.textSecondary)
                                    }
                                    .accessibilityElement(children: .combine)
                                }
                            }
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(20)
                            .insightsSurfaceCard(cornerRadius: 20)
                        }

                        reportSection("Water rhythm", text: report.waterText)
                        reportSection("About this report", text: report.notes)
                    }
                }
                .textSelection(.enabled)
                .padding(20)
                .frame(maxWidth: 760, alignment: .leading)
                .frame(maxWidth: .infinity)
            }
            .background(GlowTheme.bgPrimary.ignoresSafeArea())
            .foregroundStyle(GlowTheme.textPrimary)
            .navigationTitle("Momentum report")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Done") { dismiss() }
                }
                ToolbarItem(placement: .primaryAction) {
                    if let report = viewModel.report {
                        ShareLink(item: report.shareText, subject: Text("Glow · \(report.title)")) {
                            Label("Share", systemImage: "square.and.arrow.up")
                        }
                        .accessibilityHint("Share the report shown here using Messages, Mail, or another app")
                        .accessibilityIdentifier("shareMomentumReport")
                    }
                }
            }
            .onChange(of: period, initial: true) { _, _ in refresh() }
            .onChange(of: scope) { _, _ in refresh() }
        }
    }

    private func refresh() {
        viewModel.refresh(period: period, scope: scope, habits: habits, entries: entries, goals: goals,
                          unit: preferences.first?.unit ?? .ounces)
    }

    private func reportSection(_ title: String, text: String) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(title).font(.headline).accessibilityAddTraits(.isHeader)
            Text(text).font(.subheadline).foregroundStyle(GlowTheme.textSecondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(20)
        .insightsSurfaceCard(cornerRadius: 20)
    }
}
