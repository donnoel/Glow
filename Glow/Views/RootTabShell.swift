import SwiftUI

struct RootTabShell: View {
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass

    var body: some View {
        if horizontalSizeClass == .regular {
            IPadRootShell()
        } else {
            TabView {
                HomeView()
                    .tabItem {
                        Label("Today", systemImage: "sun.max")
                    }

                InsightsRootView()
                    .tabItem {
                        Label("Insights", systemImage: "chart.line.uptrend.xyaxis")
                    }

                LibraryRootView()
                    .tabItem {
                        Label("Library", systemImage: "square.grid.2x2")
                    }
            }
        }
    }
}

private struct IPadRootShell: View {
    @State private var selection: AppSection? = .today

    var body: some View {
        NavigationSplitView {
            List(AppSection.allCases, selection: $selection) { section in
                Label(section.title, systemImage: section.icon)
                    .tag(section)
            }
            .navigationTitle("Glow")
            .navigationBarTitleDisplayMode(.inline)
            .navigationSplitViewColumnWidth(min: 220, ideal: 240, max: 280)
        } detail: {
            Group {
                switch selection ?? .today {
                case .today:
                    HomeView()
                case .insights:
                    InsightsRootView()
                case .library:
                    LibraryRootView()
                }
            }
        }
        .navigationSplitViewStyle(.balanced)
    }
}

private enum AppSection: String, CaseIterable, Hashable, Identifiable {
    case today
    case insights
    case library

    var id: String { rawValue }

    var title: String {
        switch self {
        case .today: return "Today"
        case .insights: return "Insights"
        case .library: return "Library"
        }
    }

    var icon: String {
        switch self {
        case .today: return "sun.max"
        case .insights: return "chart.line.uptrend.xyaxis"
        case .library: return "square.grid.2x2"
        }
    }
}
