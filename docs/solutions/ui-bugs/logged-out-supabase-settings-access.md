---
title: Logged-out Supabase settings access
date: 2026-06-03
category: ui-bugs
module: auth_and_data_management
problem_type: ui_bug
component: authentication
symptoms:
  - Logged-out users could not reach Supabase settings from the auth screen.
  - Data management actions that require an authenticated session were visible when opened from the auth flow.
root_cause: missing_workflow_step
resolution_type: code_fix
severity: medium
tags: [auth-flow, supabase-settings, data-management]
---

# Logged-out Supabase settings access

## Problem
Users who had not signed in yet still needed a way to configure Supabase credentials, but the auth screen did not expose that setup path. Once the data management screen became reachable from auth, it also needed to hide backup, import, export, and destructive clear-data actions for logged-out users.

## Symptoms
- The auth screen only presented sign-in and sign-up actions, so a first-time user could get stuck before configuring Supabase.
- Opening data management outside the logged-in settings flow could expose actions that depend on authenticated user data.

## What Didn't Work
- Keeping Supabase configuration only under the normal settings area assumes the user can already enter the app. That does not help a first-time setup or misconfigured Supabase flow.
- Showing the full data management screen to logged-out users mixes configuration with data operations that require a valid user session.

## Solution
Add an explicit Supabase settings entry point to the auth screen, then gate logged-in-only data actions inside `DataManagementScreen`.

```dart
OutlinedButton.icon(
  onPressed: authProvider.isLoading
      ? null
      : () {
          Navigator.of(context).push(
            MaterialPageRoute(
              builder: (_) => const DataManagementScreen(),
            ),
          );
        },
  icon: const Icon(Icons.settings_outlined, size: 18),
  label: const Text('ตั้งค่า Supabase'),
)
```

Inside the data management screen, read auth state and render backup/restore plus clear-data sections only for logged-in users:

```dart
final authProvider = context.watch<AuthProvider>();

if (authProvider.isLoggedIn) ...[
  // Backup/restore and clear-data actions.
]
```

The widget test covers the logged-out path by opening Supabase settings from `AuthScreen`, asserting that the data management screen appears, and confirming the destructive clear-data action is absent.

## Why This Works
Supabase configuration is a prerequisite for authentication, so it belongs in the pre-auth flow as well as the normal settings flow. Separating configuration from account-bound data operations lets logged-out users fix setup problems without exposing actions that should only apply after a user session exists.

## Prevention
- When adding a settings page that can be opened from both authenticated and unauthenticated flows, classify each section as configuration-only or session-bound before rendering it.
- Add widget coverage for pre-auth navigation paths, especially when a logged-out user can reach a screen that normally lives under settings.
- Keep auth-dependent action visibility tied to `AuthProvider` state instead of relying on route origin.

## Related Issues
- None captured in this lightweight pass.
