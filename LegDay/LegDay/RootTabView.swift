import SwiftUI

struct RootTabView: View {
    @StateObject private var voiceAgent = VoiceAgentStore()
    
    var body: some View {
        ZStack {
            TabView {
                TodayView()
                    .environmentObject(voiceAgent)
                    .tabItem { Label("Today", systemImage: "calendar") }
                HistoryView()
                    .tabItem { Label("History", systemImage: "clock.arrow.circlepath") }
                ProgressViewGlobal()
                    .tabItem { Label("Progress", systemImage: "chart.xyaxis.line") }
                MetricsView()
                    .tabItem { Label("Metrics", systemImage: "chart.line.uptrend.xyaxis") }
                DataManagementView()
                    .tabItem { Label("Backup", systemImage: "externaldrive") }
                ExerciseManagementView()
                    .tabItem { Label("Settings", systemImage: "gearshape") }
                TemplatesView()
                    .tabItem { Label("Templates", systemImage: "list.bullet.rectangle") }
            }
        }
    }
}

struct RootTabView_Previews: PreviewProvider {
    static var previews: some View {
        RootTabView()
    }
}