import SwiftUI

struct GlowWatchWaterView: View {
    @ObservedObject var model: GlowWatchViewModel
    let now: Date

    private var day: GlowWatchDay { .waterDay(date: now) }

    var body: some View {
        Section("Water") {
            if let goal = model.state.waterGoal(on: day), WaterUnit.isValidAmount(goal) {
                let total = model.state.waterTotal(on: day)
                VStack(alignment: .leading, spacing: 8) {
                    Label("\(WaterUnit.ounces.number(total)) of \(WaterUnit.ounces.label(goal))", systemImage: "drop.fill")
                        .font(.headline)
                        .fixedSize(horizontal: false, vertical: true)
                    ProgressView(value: min(total, goal), total: goal)
                        .accessibilityHidden(true)
                    Text(total + 0.001 >= goal ? "Goal reached" : "\(WaterUnit.ounces.label(max(0, goal - total))) to go")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }
                .accessibilityElement(children: .ignore)
                .accessibilityLabel("Water today")
                .accessibilityValue("\(WaterUnit.ounces.label(total)) of \(WaterUnit.ounces.label(goal)). \(total + 0.001 >= goal ? "Goal reached" : "Goal not yet reached")")

                ViewThatFits(in: .horizontal) {
                    HStack(spacing: 6) { amountButtons }
                    VStack(spacing: 6) { amountButtons }
                }
                .buttonStyle(.bordered)
                .disabled(model.isSaving)

                if model.state.lastWaterEntry?.day == day {
                    Button("Undo last drink", systemImage: "arrow.uturn.backward") {
                        Task { await model.undoWater() }
                    }
                    .frame(minHeight: 44)
                    .disabled(model.isSaving)
                }
                if !model.state.pendingWater.isEmpty {
                    Text("Saved on Watch · waiting to sync")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }
                if model.waterNudgesEnabled {
                    waterTapStatus
                }
            } else {
                Text("Open Glow on your iPhone to load your water goal.")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }
        }
        .tint(.cyan)
    }

    @ViewBuilder
    private var waterTapStatus: some View {
        switch model.waterNotificationStatus {
        case .notDetermined:
            Button("Enable water taps", systemImage: "hand.wave") {
                Task { await model.enableWaterTaps() }
            }
            .frame(minHeight: 44)
            .disabled(model.isRequestingWaterPermission)
            .accessibilityHint("Allows gentle Watch notifications when you are behind your water goal")
        case .denied:
            Text("Water taps are off for this Watch. Allow Glow notifications in Watch settings to receive them.")
                .font(.footnote)
                .foregroundStyle(.secondary)
        case .authorized:
            Text("Gentle water taps are on.")
                .font(.footnote)
                .foregroundStyle(.secondary)
            if let next = model.nextWaterNudge, next > now {
                Text("Next planned nudge: \(next.formatted(date: .abbreviated, time: .shortened))")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }

        }
    }

    private var amountButtons: some View {
        ForEach([8, 21, 24], id: \.self) { ounces in
            Button {
                Task { await model.addWater(ounces: ounces) }
            } label: {
                VStack(spacing: 2) {
                    Text("+\(ounces)").font(.headline)
                    Text("oz").font(.caption)
                }
                .fixedSize()
                .frame(maxWidth: .infinity, minHeight: 44)
            }
            .accessibilityLabel("Add \(ounces) US fluid ounces of water")
        }
    }
}
