# Project Gemini Instructions (GEMINI.md)

This file contains foundational mandates for AI agents working on the **Money Vibe** project.

## 🛠 Core Mandates
- **Always refer to [AGENTS.md](AGENTS.md)** for detailed coding standards, architecture, and UI requirements.
- **Dark Mode Support**: Every new UI component MUST support both Light and Dark modes using `AppColors`.
- **Repository Pattern**: Adhere to the `DatabaseRepository` interface when implementing data logic for both SQLite and Supabase.
- **DateTime**: Use local time without timezone conversion.
- **Validation**: Run `flutter analyze` and `flutter test` before completing tasks.

## 📂 Project Structure
- `lib/models/`: Data models.
- `lib/repositories/`: Data access layer (SQLite & Supabase).
- `lib/providers/`: State management (Provider).
- `lib/screens/`: UI screens.
- `lib/theme/`: App colors and themes.

## 🚀 Key Workflows
1. **Feature Implementation**: Model -> Repository -> Provider -> UI.
2. **Database Changes**: Must be implemented in both `SqliteRepository` and `SupabaseRepository`.
3. **UI Styling**: Use `AppColors` and check `isDarkMode` from `SettingsProvider`.

For more details, see [AGENTS.md](AGENTS.md).
