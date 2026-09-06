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
    @AppStorage("iPadSidebarVisibility") private var savedSidebarVisibility = "automatic"

    private var columnVisibility: Binding<NavigationSplitViewVisibility> {
        Binding {
            guard UIDevice.current.userInterfaceIdiom == .pad else { return .automatic }
            switch savedSidebarVisibility {
            case "open": return .all
            case "closed": return .detailOnly
            default: return .automatic
            }
        } set: { visibility in
            guard UIDevice.current.userInterfaceIdiom == .pad else { return }
            // Automatic layout changes must not replace an explicit user preference.
            if visibility == .detailOnly {
                savedSidebarVisibility = "closed"
            } else if visibility == .all || visibility == .doubleColumn {
                savedSidebarVisibility = "open"
            }
        }
    }

    var body: some View {
        NavigationSplitView(columnVisibility: columnVisibility) {
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
