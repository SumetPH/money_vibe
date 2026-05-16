# Spec: Modular Background Sync System

**Date:** 2026-05-16  
**Topic:** Background data synchronization across multiple platforms (Mobile & Web)  
**Status:** Draft  

## 1. Problem Statement
Users using Money Vibe on multiple devices (e.g., Mobile and Web) experience data staleness. Currently, they must manually restart the app or refresh the page to see updates made on another device.

## 2. Proposed Solution
Implement an action-triggered background sync mechanism using a `sync_logs` table in Supabase. The system will track update timestamps per module and refresh local data only when a change is detected.

## 3. Architecture

### 3.1 Database Layer (Supabase)
A new table `sync_logs` will be created to track the last update time for each module per user.

| Column | Type | Description |
| --- | --- | --- |
| id | uuid | Primary key |
| user_id | uuid | Foreign key to auth.users |
| module_name | text | Module identifier (e.g., 'transactions', 'accounts', 'budgets', 'categories', 'recurring', 'portfolio') |
| last_updated_at | timestamptz | Timestamp of the last change |

**Constraints:**
- Unique constraint on `(user_id, module_name)`.
- RLS enabled: `auth.uid() = user_id`.

### 3.2 Data Layer (Repository)
Update `DatabaseRepository` and `SupabaseRepository`:
- `updateSyncLog(String moduleName)`: Upserts a row with `now()` for the given module.
- `getSyncLogs()`: Returns a map of `module_name -> last_updated_at` for the current user.

### 3.3 State Layer (Provider)
A new `SyncProvider` will act as the coordinator:
- **State:** `Map<String, DateTime> _localTimestamps`
- **Logic:** `checkAndRefresh()`
    1. Fetches remote logs from `getSyncLogs()`.
    2. Compares with `_localTimestamps`.
    3. If remote > local for a module:
        - Calls the corresponding provider's fetch method.
        - Updates `_localTimestamps`.

### 3.4 Integration Points (Triggers)
- **Navigation:** Every time a user changes screens (handled via `GoRouter` observer or a base screen mixin).
- **App Lifecycle:** When the app returns from the background (AppLifecycleState.resumed).
- **Data Mutation:** Every insert/update/delete operation in existing repositories will automatically call `updateSyncLog`.

## 4. Design for Isolation & Clarity
- **Decoupling:** `SyncProvider` will not be tightly coupled to all other providers. It will use a registration mechanism or a registry of "Refreshable" interfaces.
- **Efficiency:** The sync check is a single, small query fetching only a few rows.

## 5. Security & Consistency
- RLS ensures users only see their own logs.
- Timestamps use server time (`now()`) to avoid issues with local clock drifts.

## 6. Implementation Phases
1. **Migration:** Create the `sync_logs` table and policies in Supabase.
2. **Repository:** Implement sync log methods.
3. **Write Path:** Integrate `updateSyncLog` into all data mutation methods.
4. **Provider:** Implement `SyncProvider` logic.
5. **Trigger Path:** Integrate sync checks into navigation and lifecycle.
