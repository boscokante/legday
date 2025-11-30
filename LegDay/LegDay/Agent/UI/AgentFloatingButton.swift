import SwiftUI

struct AgentFloatingButton: View {
    @ObservedObject var agent: VoiceAgentStore
    
    var body: some View {
        Button(action: {
            if agent.isActive {
                agent.stopSession()
            } else {
                Task {
                    await agent.startSession()
                }
            }
        }) {
            Image(systemName: agent.isActive ? "mic.fill" : "mic.slash.fill")
                .font(.title2)
                .foregroundColor(.white)
                .frame(width: 60, height: 60)
                .background(
                    Circle()
                        .fill(agent.isActive ? .red : .blue)
                        .shadow(radius: 8)
                )
        }
        .buttonStyle(.plain)
    }
}




