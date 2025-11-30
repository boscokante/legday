import SwiftUI

struct AgentOverlayView: View {
    @ObservedObject var agent: VoiceAgentStore
    
    var body: some View {
        VStack {
            Spacer()
            
            if agent.isActive {
                VStack(spacing: 12) {
                    // Transcript display
                    if !agent.transcript.isEmpty {
                        Text(agent.transcript)
                            .font(.caption)
                            .foregroundColor(.secondary)
                            .padding(.horizontal)
                            .multilineTextAlignment(.center)
                    }
                    
                    // State indicator
                    HStack(spacing: 8) {
                        Circle()
                            .fill(stateColor)
                            .frame(width: 12, height: 12)
                        
                        Text(stateText)
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    
                    // Audio level indicator
                    if agent.state == .listening {
                        AudioLevelView(level: agent.audioLevel)
                    }
                }
                .padding()
                .background(
                    RoundedRectangle(cornerRadius: 12)
                        .fill(.ultraThinMaterial)
                )
                .padding(.bottom, 100)
            }
        }
    }
    
    private var stateColor: Color {
        switch agent.state {
        case .idle:
            return .gray
        case .listening:
            return .green
        case .thinking:
            return .yellow
        case .speaking:
            return .blue
        case .error:
            return .red
        }
    }
    
    private var stateText: String {
        switch agent.state {
        case .idle:
            return "Idle"
        case .listening:
            return "Listening..."
        case .thinking:
            return "Thinking..."
        case .speaking:
            return "Speaking..."
        case .error(let message):
            return "Error: \(message)"
        }
    }
}

struct AudioLevelView: View {
    let level: Float
    
    var body: some View {
        HStack(spacing: 4) {
            ForEach(0..<10) { index in
                RoundedRectangle(cornerRadius: 2)
                    .fill(level > Float(index) / 10.0 ? .green : .gray.opacity(0.3))
                    .frame(width: 3, height: 20)
            }
        }
    }
}




