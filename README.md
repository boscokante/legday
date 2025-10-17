# LegDay - Weightlifting Tracker

## Setup Instructions

1. Open Xcode and create a new iOS App project:
   - Name: LegDay
   - Bundle Identifier: com.yourorg.LegDay
   - Interface: SwiftUI
   - Language: Swift
   - Check "Use Core Data"

2. Replace the auto-generated files with the ones in this repository:
   - AppDelegate.swift and SceneDelegate.swift can be deleted (using SwiftUI lifecycle)
   - Keep the .xcdatamodeld file that Xcode created

3. Set up the Core Data model:
   - Follow the instructions in `LegDay/CoreData/README.md`
   - Make sure to set Codegen to "Class Definition" for each entity

4. Build and run the project

## Project Structure

- App/: Main app files
- Core/: Core functionality (Persistence, Models, Repositories, Utilities)
- Features/: Feature-specific views and logic
- CoreData/: Core Data model and setup instructions

## Automated Setup (Experimental)

You can try running the setup script: