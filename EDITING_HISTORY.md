# Editing Workout History on Desktop

## Quick Start

1. **On your phone**: Go to **Backup** tab → Tap **"Export History Only (for editing)"**
2. **Transfer the JSON file** to your desktop (via AirDrop, iCloud, email, etc.)
3. **Edit the file** in Cursor or any text editor
4. **Save the file**
5. **Transfer back** to your phone
6. **On your phone**: Go to **Backup** tab → Tap **"Import Data"** → Select your edited JSON file

## File Format

The exported JSON file looks like this:

```json
{
  "version": "1.0",
  "exportDate": 1234567890.0,
  "workouts": [
    {
      "date": 1234567890.0,
      "date_readable": "Jan 15, 2025",
      "day": "Leg Day",
      "notes": "Your notes here - edit this!",
      "exercises": {
        "Bench Press": [
          {"weight": 135.0, "reps": 10, "warmup": false},
          {"weight": 185.0, "reps": 5, "warmup": false}
        ]
      }
    }
  ],
  "_instructions": "Edit the 'notes' field for any workout..."
}
```

## What You Can Edit

- **`notes`**: Edit the notes field for any workout. This is what the AI sees!
- **`day`**: Change the workout day name (e.g., "Leg Day", "Push Day")
- **`exercises`**: Edit exercise names, weights, reps, or warmup flags
- **`date`**: Change the date (as a Unix timestamp - be careful!)

## Important Notes

- The `date_readable` field is just for reference - don't edit it, it will be ignored on import
- The `_instructions` field will be ignored on import
- When you import, workouts with the same date will be **replaced** (not merged)
- Make sure your JSON is valid - use a JSON validator if needed
- The file is sorted with most recent workouts first for easier editing

## Tips

- Use Cursor's JSON formatting (Cmd+Shift+P → "Format Document")
- Search for specific dates or exercises using Cursor's search
- Make a backup before editing if you're making major changes
- The AI uses the `notes` field to understand your workout context, so fixing scrambled notes will help it give better recommendations!


