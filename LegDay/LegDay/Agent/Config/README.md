# API Key Configuration

For personal use, add your OpenAI API key directly in `Secrets.swift`.

## Setup

1. Copy `Secrets.example.swift` to `Secrets.swift`:
   ```bash
   cp LegDay/LegDay/Agent/Config/Secrets.example.swift LegDay/LegDay/Agent/Config/Secrets.swift
   ```

2. Edit `Secrets.swift` and replace `YOUR_API_KEY_HERE` with your actual OpenAI API key:
   ```swift
   static let openAIAPIKey = "sk-your-actual-key-here"
   ```

3. `Secrets.swift` is gitignored and will never be committed to the repository.

## Getting Your API Key

1. Go to https://platform.openai.com/api-keys
2. Create a new API key
3. Copy it and paste into `Secrets.swift`

## Security

- ✅ `Secrets.swift` is in `.gitignore` - never committed
- ✅ `Secrets.example.swift` is committed as a template (no real keys)
- ⚠️ Keep your API key secure - don't share it publicly




