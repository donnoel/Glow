import SwiftUI

struct RootTabShell: View {
    var body: some View {
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
