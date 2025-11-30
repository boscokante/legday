# Adding Microphone Permission to LegDay

Since your project uses `GENERATE_INFOPLIST_FILE = YES`, add the microphone permission via Build Settings.

## Method 1: Via Build Settings (Recommended)

1. In Xcode, select the **LegDay** target
2. Click the **Build Settings** tab
3. In the search box at the top, type: `infoplist`
4. Look for **"Info.plist Values"** section (or search for `INFOPLIST_KEY`)
5. Find or add: **`INFOPLIST_KEY_NSMicrophoneUsageDescription`**
6. Double-click the value column and enter:
   ```
   LegDay needs microphone access to enable voice-controlled workout tracking with your personal trainer assistant.
   ```

## Method 2: Via Info Tab (Alternative)

If you see the Info tab:
1. Select the **LegDay** target
2. Click the **Info** tab
3. Look for **"Custom iOS Target Properties"** section (not macOS)
4. Right-click in the table → **Add Row** (or use the + button if visible)
5. Select **"Privacy - Microphone Usage Description"** from the dropdown
6. Enter the value:
   ```
   LegDay needs microphone access to enable voice-controlled workout tracking with your personal trainer assistant.
   ```

## Method 3: Direct Build Setting Entry

1. Select **LegDay** target → **Build Settings**
2. Click the **+** button at the top (or right-click → **Add User-Defined Setting**)
3. Name it: `INFOPLIST_KEY_NSMicrophoneUsageDescription`
4. Set the value:
   ```
   LegDay needs microphone access to enable voice-controlled workout tracking with your personal trainer assistant.
   ```

After adding this, clean build folder (Cmd+Shift+K) and rebuild.




