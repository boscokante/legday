import SwiftUI

struct RootTabView: View {
    var body: some View {
        TabView {
            TodayView()
                .tabItem { Label("Today", systemImage: "calendar") }
            HistoryView()
                .tabItem { Label("History", systemImage: "clock.arrow.circlepath") }
            ProgressViewGlobal()
                .tabItem { Label("Progress", systemImage: "chart.xyaxis.line") }
            TemplatesView()
                .tabItem { Label("Templates", systemImage: "list.bullet.rectangle") }
        }
    }
}

struct RootTabView_Previews: PreviewProvider {
    static var previews: some View {
        RootTabView()
    }
}