import SwiftUI

struct APISettingsView: View {
    @AppStorage("openai_api_key") private var apiKey: String = ""
    @State private var showingKey = false
    
    var body: some View {
        Form {
            Section {
                HStack {
                    if showingKey {
                        TextField("sk-...", text: $apiKey)
                            .textContentType(.password)
                            .autocapitalization(.none)
                    } else {
                        SecureField("sk-...", text: $apiKey)
                            .textContentType(.password)
                            .autocapitalization(.none)
                    }
                    
                    Button(showingKey ? "Hide" : "Show") {
                        showingKey.toggle()
                    }
                    .font(.caption)
                }
            } header: {
                Text("OpenAI API Key")
            } footer: {
                Text("Your API key is stored locally and never shared. Get your key from platform.openai.com")
            }
            
            Section {
                Link("Get API Key", destination: URL(string: "https://platform.openai.com/api-keys")!)
                Link("Realtime API Docs", destination: URL(string: "https://platform.openai.com/docs/guides/realtime")!)
            }
        }
        .navigationTitle("Voice Coach Settings")
    }
}




