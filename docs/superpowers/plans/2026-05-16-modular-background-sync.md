# Modular Background Sync Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Implement a background synchronization system that detects data updates from other devices (using a `sync_logs` table) and refreshes relevant providers automatically.

**Architecture:** A centralized `SyncProvider` that tracks local module timestamps, compares them with remote timestamps from Supabase on navigation/lifecycle events, and triggers refreshes for mismatched modules.

**Tech Stack:** Flutter, Provider, Supabase, GoRouter.

---

### Task 1: Database Migration
**Files:**
- Create: `supabase/migrations/20260516000000_create_sync_logs.sql` (Note: Run manually in Supabase SQL Editor)

- [ ] **Step 1: Define the SQL for `sync_logs` table**
```sql
CREATE TABLE IF NOT EXISTS public.sync_logs (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id UUID REFERENCES auth.users NOT NULL,
    module_name TEXT NOT NULL,
    last_updated_at TIMESTAMPTZ DEFAULT now() NOT NULL,
    UNIQUE(user_id, module_name)
);

ALTER TABLE public.sync_logs ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Users can manage their own sync logs" ON public.sync_logs
    FOR ALL USING (auth.uid() = user_id);
```

- [ ] **Step 2: Commit migration file (or documentation of it)**
```bash
# Since we might not have a CLI-based migration tool running, 
# we'll save it to a migrations folder for reference.
git add supabase/migrations/20260516000000_create_sync_logs.sql
git commit -m "db: add sync_logs table for background sync"
```

### Task 2: Update Repository Interface and Implementation
**Files:**
- Modify: `lib/repositories/database_repository.dart`
- Modify: `lib/repositories/supabase_repository.dart`

- [ ] **Step 1: Add sync methods to `DatabaseRepository`**
```dart
// lib/repositories/database_repository.dart
abstract class DatabaseRepository {
  // ... existing methods ...
  Future<void> updateSyncLog(String moduleName);
  Future<Map<String, DateTime>> getSyncLogs();
}
```

- [ ] **Step 2: Implement in `SupabaseRepository`**
```dart
// lib/repositories/supabase_repository.dart
@override
Future<void> updateSyncLog(String moduleName) async {
  if (!isAuthenticated) return;
  await client.from('sync_logs').upsert({
    'user_id': currentUserId,
    'module_name': moduleName,
    'last_updated_at': DateTime.now().toIso8601String(),
  }, onConflict: 'user_id, module_name');
}

@override
Future<Map<String, DateTime>> getSyncLogs() async {
  if (!isAuthenticated) return {};
  final response = await client
      .from('sync_logs')
      .select('module_name, last_updated_at')
      .eq('user_id', currentUserId!);
  
  final Map<String, DateTime> logs = {};
  for (final row in (response as List)) {
    logs[row['module_name']] = DateTime.parse(row['last_updated_at']);
  }
  return logs;
}
```

### Task 3: Integrate Write Path in Adapters
**Files:**
- Modify: `lib/repositories/supabase_adapters/*.dart`

- [ ] **Step 1: Update AccountAdapter**
- Call `repo.updateSyncLog('accounts')` in `insertAccount`, `updateAccount`, `deleteAccount`.

- [ ] **Step 2: Update CategoryAdapter**
- Call `repo.updateSyncLog('categories')` in `insertCategory`, `updateCategory`, `deleteCategory`.

- [ ] **Step 3: Update TransactionAdapter**
- Call `repo.updateSyncLog('transactions')` in `insertTransaction`, `updateTransaction`, `deleteTransaction`.

- [ ] **Step 4: Update BudgetAdapter**
- Call `repo.updateSyncLog('budgets')` in `insertBudget`, `updateBudget`, `deleteBudget`.

- [ ] **Step 5: Update PortfolioAdapter**
- Call `repo.updateSyncLog('portfolio')` in `insertHolding`, `updateHolding`, `deleteHolding`.

- [ ] **Step 6: Update RecurringAdapter**
- Call `repo.updateSyncLog('recurring')` in `insertRecurringTransaction`, etc.

### Task 4: Implement SyncProvider
**Files:**
- Create: `lib/providers/sync_provider.dart`

- [ ] **Step 1: Create `SyncProvider` class**
```dart
import 'package:flutter/material.dart';
import '../repositories/database_repository.dart';

class SyncProvider extends ChangeNotifier {
  final DatabaseRepository repository;
  Map<String, DateTime> _localTimestamps = {};
  bool _isChecking = false;

  SyncProvider(this.repository);

  Future<void> checkAndSync(BuildContext context) async {
    if (_isChecking) return;
    _isChecking = true;
    
    try {
      final remoteLogs = await repository.getSyncLogs();
      for (final entry in remoteLogs.entries) {
        final module = entry.key;
        final remoteTime = entry.value;
        final localTime = _localTimestamps[module];

        if (localTime == null || remoteTime.isAfter(localTime)) {
          // Trigger refresh for specific module
          _refreshModule(context, module);
          _localTimestamps[module] = remoteTime;
        }
      }
    } catch (e) {
      debugPrint('Sync Error: $e');
    } finally {
      _isChecking = false;
    }
  }

  void _refreshModule(BuildContext context, String module) {
    // Logic to call provider.fetchData() based on module name
  }
}
```

### Task 5: Global Integration and Triggering
**Files:**
- Modify: `lib/main.dart`

- [ ] **Step 1: Register SyncProvider**
- [ ] **Step 2: Add Global Lifecycle Observer or GoRouter Listener**
- Call `syncProvider.checkAndSync(context)` on navigation or app resume.
