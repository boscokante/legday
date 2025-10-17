What is a peritendon Achilles injury?# LegDay — iOS App Specification & Build Guide

**Version:** 1.0 (MVP)  
**Target OS:** iOS 16+  
**Language:** Swift 5.9+  
**UI:** SwiftUI  
**Persistence:** Core Data (Lightweight migrations enabled)  
**Architecture:** MVVM + Repository  
**App Icon/Name:** “LegDay”

---

## 1) Product Overview

LegDay replaces fragmented Notes with a fast, structured weightlifting tracker. It shows a day template (e.g., *Leg Day*) with exercises, lets you log sets as **weight × reps** (including warmups like `10×0`), remembers previous sessions, and surfaces simple progress: PRs, volume, and trends.

### Core Goals
- Log sets quickly with minimal taps.
- Auto‑prefill from the last session but never overwrite history.
- Clear history per exercise with simple charts and PRs.
- Offline‑first; no login; export/import JSON.

### Non‑Goals (MVP)
- No social features.
- No complex program design or coaching logic.
- No subscriptions/paywalls.

---

## 2) Primary User Stories (MVP)

1. As a lifter, I select **Today → Leg Day** and see my preset exercises with the **last session** summary per exercise.  
2. I can **log sets quickly**: enter weight and reps, duplicate sets, insert warmups (`10×0`).  
3. I can **copy last session** for an exercise or for the whole day.  
4. I can **view history** per exercise (table + sparkline) and **PRs** (heaviest, 5RM, volume, 1RM est).  
5. I can see **global progress**: weekly sessions, total volume, recent PRs.  
6. I can **edit templates** (add/remove/reorder exercises) without affecting past sessions.  
7. I can **export/import** my data as JSON.

---

## 3) Information Architecture & Screens

### 3.1 Navigation
- **TabView (4 tabs):** Today · History · Progress · Templates

### 3.2 Screens

#### A) Today
- **Header:** Date picker (defaults to today), Day Template picker.
- **Exercise list:** Rows with name and “Last Session” summary.
- **Quick Log sheet (per exercise):**
  - Set list (prefilled from last session if toggled).
  - Inputs: *Weight (lb)*, *Reps*, optional *RPE*, optional *Notes*.
  - Actions: **+ Set**, **Duplicate last set**, **Warmup Presets** (e.g., insert `10×0`), **Save**.
- **Undo last set** (snackbar/toast or toolbar button).

#### B) History (Per Exercise)
- **Picker/Search** for exercise → detail view with:
  - **Table**: date, sets (weight×reps), notes.
  - **Sparkline**: estimated 1RM / top set weight / volume over time.
  - **PRs**: best single, 5RM, volume PR, most sets.

#### C) Progress (Global)
- Cards: **Weekly sessions**, **Total volume**, **Recent PRs**, **Streaks**.

#### D) Templates
- Template list (Leg, Push, Pull, Upper, Lower, Custom…).
- Template detail: draggable exercise order; warmup defaults; target sets/reps.

---

## 4) Data Model (Core Data)

> Use one Core Data model version: **LegDayModel.xcdatamodeld (v1)**. Enable “Use CloudKit” later (post‑MVP) if desired.

### 4.1 Entities

**DayTemplate**
- `id: UUID`
- `name: String` (e.g., “Leg Day”)
- `isDefault: Bool`
- Relationship: `exercises: [TemplateExercise]` (to-many, ordered)

**TemplateExercise**
- `id: UUID`
- `name: String` (e.g., “Bulgarian Split Squat”)
- `defaultWarmupJSON: String?` (JSON array of SetEntry-like objects)
- `defaultWorkingScheme: String?` (free text, optional)
- Inverse: `template: DayTemplate` (to-one)

**WorkoutSession**
- `id: UUID`
- `date: Date` (midnight local)
- `templateNameSnapshot: String`
- Relationship: `entries: [ExerciseEntry]` (to-many, ordered)

**ExerciseEntry**
- `id: UUID`
- `exerciseNameSnapshot: String`
- `notes: String?`
- Relationship: `sets: [SetEntry]` (to-many, ordered)
- Inverse: `session: WorkoutSession`

**SetEntry**
- `id: UUID`
- `order: Int16`
- `weight: Double` (lb)
- `reps: Int16`
- `rpe: Double?`
- `isWarmup: Bool`

> **Why snapshots?** Names in templates can change later. Snapshotting preserves history integrity.

### 4.2 Lightweight Migrations
- Add new optional fields only.
- Use “Preserve mapping” and set defaults.

---

## 5) Derived Metrics & Logic

### 5.1 Estimated 1RM (Epley)
```
1RM = weight × (1 + reps / 30)
```
- For each session/exercise, compute top-set est. 1RM (max by 1RM).

### 5.2 Volume
```
Volume = Σ(weight × reps) per exercise/session
```

### 5.3 PRs (per exercise)
- **Heaviest single:** max `weight` where `reps == 1`.
- **Best 5RM:** max `weight` where `reps == 5`.
- **Volume PR:** max session volume for that exercise.
- **Most sets:** max count of sets in a session.

Compute at save time and store a small **PR cache** table or recompute on demand (MVP: compute on demand).

---

## 6) JSON Import/Export

### 6.1 Export
- Single JSON file with all entities; order by date asc.
- Example file name: `LegDay-Export-YYYY-MM-DD.json`.

### 6.2 Import
- Merge by `exerciseNameSnapshot` when attaching to sessions.
- If a conflict is detected, create a new exercise name variant.

### 6.3 Sample JSON (seed + sample session)
```json
{
  "appName": "LegDay",
  "dayTemplates": [
    {
      "id": "leg-day",
      "name": "Leg Day",
      "isDefault": true,
      "exercises": [
        {
          "id": "bulgarian-split-squat",
          "name": "Bulgarian Split Squat",
          "defaultWarmupSets": [
            {"reps": 10, "weight": 0, "isWarmup": true},
            {"reps": 10, "weight": 0, "isWarmup": true}
          ]
        },
        {"id": "leg-press", "name": "Leg Press"},
        {"id": "single-leg-extension", "name": "Single-Leg Extension"},
        {"id": "decline", "name": "Decline"},
        {"id": "hamstring-curl", "name": "Hamstring Curl"},
        {"id": "standing-calf-raise", "name": "Standing Calf Raise"},
        {"id": "seated-calf-raise", "name": "Seated Calf Raise"},
        {"id": "box-jumps", "name": "Box Jumps"}
      ]
    }
  ],
  "sampleSession": {
    "date": "2025-09-24",
    "templateName": "Leg Day",
    "entries": [
      {
        "exerciseName": "Bulgarian Split Squat",
        "sets": [
          {"order": 1, "reps": 10, "weight": 0, "isWarmup": true},
          {"order": 2, "reps": 10, "weight": 0, "isWarmup": true},
          {"order": 3, "reps": 10, "weight": 40},
          {"order": 4, "reps": 5, "weight": 60},
          {"order": 5, "reps": 5, "weight": 75},
          {"order": 6, "reps": 5, "weight": 75},
          {"order": 7, "reps": 5, "weight": 75}
        ]
      }
    ],
    "sessionNotes": "Felt strong on top sets."
  }
}
```

---

## 7) Project Setup (Xcode)

1. **Create Project**
   - App → SwiftUI → “LegDay” (bundle id: `com.yourorg.LegDay`).
   - Check **Use Core Data**.
2. **Targets & Settings**
   - iOS Deployment Target: **16.0**.
   - Signing: your team.
3. **Groups**
   - `Sources/` (Features in subfolders), `Resources/`, `CoreData/`.
4. **Add Core Data Model**
   - `CoreData/LegDayModel.xcdatamodeld` with entities in §4.
   - Set relationships as **Ordered** where noted.
5. **App Icons & Assets**
   - Placeholder icon (later). Name: **LegDay** (label).

---

## 8) Architecture

- **MVVM + Repository**
  - View (SwiftUI) ↔ ViewModel (ObservableObject) ↔ Repository (CoreData stack) ↔ NSPersistentContainer.
- **Coordinators (Optional)** for deep navigation.

### Directory Structure
```
Sources/
  App/
  Core/
    Persistence/
    Models/ (DTOs, helpers—NOT Core Data auto classes)
  Features/
    Today/
    History/
    Progress/
    Templates/
  SharedUI/
CoreData/
Resources/
```

---

## 9) Code: Persistence

### 9.1 PersistenceController
```swift
import CoreData

enum PersistenceConfig {
    static let modelName = "LegDayModel"
}

final class PersistenceController {
    static let shared = PersistenceController()

    let container: NSPersistentContainer

    init(inMemory: Bool = false) {
        container = NSPersistentContainer(name: PersistenceConfig.modelName)
        if inMemory {
            let desc = NSPersistentStoreDescription()
            desc.type = NSInMemoryStoreType
            container.persistentStoreDescriptions = [desc]
        }
        container.loadPersistentStores { _, error in
            if let error = error { fatalError("Unresolved Core Data error: \(error)") }
            self.container.viewContext.mergePolicy = NSMergeByPropertyObjectTrumpMergePolicy
        }
        container.viewContext.automaticallyMergesChangesFromParent = true
    }

    func saveContext() {
        let context = container.viewContext
        if context.hasChanges {
            do { try context.save() } catch { print("Save error: \(error)") }
        }
    }
}
```

### 9.2 Repository Sketch
```swift
protocol SessionRepository {
    func createSession(date: Date, templateName: String) -> WorkoutSession
    func addExerciseEntry(to session: WorkoutSession, name: String) -> ExerciseEntry
    func addSet(to entry: ExerciseEntry, order: Int, weight: Double, reps: Int16, rpe: Double?, warmup: Bool)
    func lastSession(for exerciseName: String) -> WorkoutSession?
    func fetchSessions(for exerciseName: String) -> [WorkoutSession]
    func save()
}
```

---

## 10) Code: Models & Utilities

### 10.1 Epley 1RM & Volume
```swift
struct LiftingMath {
    static func epley1RM(weight: Double, reps: Int) -> Double {
        guard reps > 0 else { return 0 }
        return weight * (1.0 + (Double(reps) / 30.0))
    }

    static func volume(sets: [(weight: Double, reps: Int)]) -> Double {
        sets.reduce(0) { $0 + ($1.weight * Double($1.reps)) }
    }
}
```

### 10.2 Last Session Summary
```swift
struct LastSessionSummary {
    let topSet: String
    let totalVolume: Double
}

func summarizeLastSession(_ session: WorkoutSession?, for exercise: String) -> LastSessionSummary? {
    guard let session else { return nil }
    let entries = (session.entriesArray).filter { $0.exerciseNameSnapshot == exercise }
    let allSets = entries.flatMap { $0.setsArray }
    guard !allSets.isEmpty else { return nil }
    let top = allSets.max { a, b in a.weight < b.weight }!
    let vol = allSets.reduce(0) { $0 + ($1.weight * Double($1.reps)) }
    return .init(topSet: "\(Int(top.reps))×\(Int(top.weight))", totalVolume: vol)
}
```

> `entriesArray`/`setsArray` are convenience computed properties to unwrap ordered NSOrderedSets.

---

## 11) Code: SwiftUI Views (Skeletons)

### 11.1 App Entry
```swift
@main
struct LegDayApp: App {
    let persistence = PersistenceController.shared
    var body: some Scene {
        WindowGroup {
            RootTabView()
                .environment(\.managedObjectContext, persistence.container.viewContext)
        }
    }
}
```

### 11.2 Root Tabs
```swift
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
```

### 11.3 Today (Stub)
```swift
struct TodayView: View {
    @Environment(\.managedObjectContext) private var ctx
    @State private var selectedTemplateID: NSManagedObjectID?
    @State private var showExerciseSheet: Bool = false
    @State private var activeExerciseName: String?

    var body: some View {
        NavigationStack {
            List {
                // Fetch Template Exercises by selected template...
                Section("Exercises") {
                    // ForEach(template.exercises) { ex in ... }
                    Button("Bulgarian Split Squat") {
                        activeExerciseName = "Bulgarian Split Squat"
                        showExerciseSheet = true
                    }
                }
            }
            .navigationTitle("Today")
        }
        .sheet(isPresented: $showExerciseSheet) {
            if let name = activeExerciseName {
                ExerciseQuickLogSheet(exerciseName: name)
            }
        }
    }
}
```

### 11.4 Exercise Quick Log Sheet (Stub)
```swift
struct ExerciseQuickLogSheet: View {
    let exerciseName: String
    @State private var sets: [(weight: Double, reps: Int, warmup: Bool)] = []

    var body: some View {
        NavigationStack {
            List {
                ForEach(sets.indices, id: \.self) { idx in
                    HStack {
                        Text("#\(idx + 1)")
                        TextField("Weight", value: $sets[idx].weight, format: .number)
                            .keyboardType(.decimalPad)
                        Text("×")
                        TextField("Reps", value: $sets[idx].reps, format: .number)
                            .keyboardType(.numberPad)
                        if sets[idx].warmup { Text("Warmup").foregroundStyle(.secondary) }
                    }
                }
                Button("+ Set") {
                    sets.append((weight: 0, reps: 10, warmup: true))
                }
                Button("Warmup Preset (10×0)") {
                    sets.append((weight: 0, reps: 10, warmup: true))
                }
            }
            .navigationTitle(exerciseName)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") { /* persist to Core Data */ }
                }
                ToolbarItem(placement: .cancellationAction) {
                    Button("Close") { /* dismiss */ }
                }
            }
        }
    }
}
```

---

## 12) Seeding Initial Data

On first launch, if there are no templates, insert the **Leg Day** template:

```swift
struct SeedData {
    static func insertIfNeeded(context: NSManagedObjectContext) {
        // Check for existing templates; if none, create "Leg Day" with exercises
    }
}
```

Exercises (order):  
1) Bulgarian Split Squat (warmups: `10×0`, `10×0`)  
2) Leg Press (warmups: `10×0`, `10×0`)  
3) Single-Leg Extension  
4) Decline  
5) Hamstring Curl  
6) Standing Calf Raise  
7) Seated Calf Raise  
8) Box Jumps

---

## 13) Acceptance Criteria (MVP)

1. **Branding & Launch**: App name and icon label show **LegDay**.  
2. **Templates & Today**: Create/select **Leg Day**; view exercises in order with “Last Session” summaries.  
3. **Set Logging**: Can enter exactly `10×0, 10×0, 10×40, 5×60, 5×75, 5×75, 5×75` for Bulgarian Split Squat; duplicate, delete, and insert warmups.  
4. **History & PRs**: Table + sparkline; show best single, 5RM, volume PR, most sets; est. 1RM via Epley.  
5. **Progress**: Weekly sessions, total volume, recent PRs, streaks.  
6. **Data**: Export/Import JSON; local storage with safe migrations.  
7. **Performance/Accessibility**: Cold start <1s; log typical exercise in <10s; Dynamic Type + VoiceOver.

---

## 14) QA Checklist

- ✅ Create Leg Day template; add all specified exercises.  
- ✅ Log the example Bulgarian Split Squat session; verify history shows identical sets.  
- ✅ Verify PRs update when heavier sets are logged.  
- ✅ Export JSON; delete app; reinstall; import JSON; verify restoration.  
- ✅ Test with VoiceOver and larger text sizes.  
- ✅ Backgrounding and relaunch keep unsaved edits (autosave draft or confirm discard).

---

## 15) App Store Metadata (Draft)

**Name:** LegDay — Weightlifting Log  
**Subtitle:** Log sets fast. See progress clearly.  
**Description (short):**  
LegDay makes strength logging effortless. Build day templates, capture weight×reps (warmups too), auto-copy last session, and see PRs and trends with clean charts. Offline-first—so it’s always ready when you are.

**Keywords:** lifting, workout log, weightlifting, strength, gym, sets, reps, progress, PR, 1RM

**Privacy:** No sign-in. Data stored on-device. Optional iCloud/Health (post-MVP).

---

## 16) Roadmap (Post‑MVP)

- iCloud sync; HealthKit write/read (bodyweight).  
- Apple Watch quick‑log.  
- CSV export.  
- Tagging (hypertrophy, peaking).  
- Rest timer; tempo; supersets.  
- Program templates and cycles.

---

## 17) Build Commands & Notes

- Xcode → Product → Build (⌘B).  
- Run on device (recommended for keyboard & haptics).  
- Add `NSHealthShareUsageDescription` / `NSHealthUpdateUsageDescription` only when HealthKit is added.  
- For charts, you can use **Swift Charts** (iOS 16+) or simple custom sparklines; keep minimal for MVP.

---

## 18) BitRig / Handoff Summary (Paste‑ready)

**App:** LegDay — iOS (SwiftUI + Core Data, iOS 16+)  
**Goal:** Day templates, fast set logging (weight×reps), last-session prefill, history, PRs, progress.  
**Key Entities:** DayTemplate, TemplateExercise, WorkoutSession, ExerciseEntry, SetEntry.  
**Calculations:** Epley est. 1RM, volume, PR detection (on demand).  
**MVP Screens:** Today, History (per exercise), Progress (global), Templates.  
**Export/Import:** JSON (schema above).  
**Acceptance Criteria:** See §13.  
**Non‑Functional:** Offline-first, startup <1s, accessible.

---

## 19) License / Ownership

© You/YourOrg. All rights reserved. No third‑party data collection in MVP.
