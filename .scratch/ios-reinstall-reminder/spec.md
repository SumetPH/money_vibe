# iOS reinstall reminder

Status: ready-for-agent

## Problem Statement

iOS development builds need to be reinstalled regularly, but a user has no clear in-app indication of the remaining usable period or a reminder when that period ends.

## Solution

For each app build, establish a Reinstall deadline seven local-time days after its first launch. Show its Installation status in Settings, surface an unobtrusive state on the Settings navigation icon near the deadline, and send one local Reinstall reminder at the deadline when the Reinstall reminder setting is enabled.

## User Stories

1. As an iOS development-build user, I want a Reinstall deadline to start on the first launch of a build, so that the seven-day period matches my actual use of that build.
2. As an iOS development-build user, I want a new build number to begin a new Reinstall deadline, so that an in-place IPA update gives me a fresh seven-day period.
3. As an iOS development-build user, I want to see the Installation status in Settings, so that I know exactly how much time remains.
4. As an iOS development-build user, I want the remaining duration displayed in days and hours, so that I can plan a reinstall without calculating timestamps.
5. As an iOS development-build user, I want Settings to state clearly when the Reinstall deadline has passed, so that I know to install the latest build.
6. As an iOS development-build user, I want a Reinstall reminder at the deadline, so that I am alerted even when I am not viewing Settings.
7. As an iOS development-build user, I want to enable or disable the Reinstall reminder in Settings, so that I control whether iOS sends that notification.
8. As an iOS development-build user, I want the permission prompt on the first app launch while the default Reinstall reminder is enabled, so that the reminder can be scheduled for this build.
9. As an iOS development-build user, I want disabling the Reinstall reminder to cancel its pending notification without hiding the Installation status, so that I retain the information without being interrupted.
10. As an iOS development-build user, I want a warning dot on the Settings navigation icon with at most one day remaining, so that I notice an approaching Reinstall deadline without persistent visual noise.
11. As an iOS development-build user, I want the Settings navigation icon to show an exclamation mark after the Reinstall deadline, so that the urgent state is distinguishable from an approaching deadline.
12. As an iOS development-build user, I want the same Installation status on both light and dark themes, so that the reminder remains readable in my chosen appearance.

## Implementation Decisions

- Use the installed build number as the build identity. Persist the identity and the first-launch local timestamp in device preferences; replace both when the build identity changes.
- Define the Reinstall deadline as exactly seven local-time days after that timestamp. The Installation status derives its remaining duration from the current local time and formats only days and whole hours.
- Add one focused Reinstall reminder service as the public behavior seam. It owns deadline state calculation and coordinates scheduling/cancellation through the existing local-notification capability; it does not add a new dependency or backend schema.
- Reuse the existing local-notification initialization and permission flow. The reminder notification is scheduled once at the Reinstall deadline with title “ถึงเวลาติดตั้ง Money Vibe ใหม่” and body “เวอร์ชันนี้ใช้งานครบ 7 วันแล้ว กรุณาติดตั้ง build ล่าสุด”.
- Default the Reinstall reminder setting to enabled. Request iOS notification permission on the first app launch so the reminder can be scheduled; if permission is denied, preserve the setting and show the Installation status normally.
- Show a Settings row for Installation status and a SwitchListTile for the Reinstall reminder setting. Both use the existing theme tokens and remain visible irrespective of notification permission.
- Decorate the existing Settings navigation item in both narrow-screen drawer and wide-screen sidebar: a warning dot at one day or less remaining, then an exclamation mark after expiry.
- Apply this behavior only on iOS device builds. Other platforms neither schedule a Reinstall reminder nor show its navigation badge.

## Testing Decisions

- Test the public Reinstall reminder service seam, not widget implementation details or private preference keys.
- Cover first launch, a repeated launch of the same build, a changed build number, remaining-duration formatting, deadline expiry, and enabled/disabled scheduling decisions with worked local-time examples.
- The repository has no existing test suite; add the smallest Flutter unit-test setup and one service-focused test file only if required to execute these behavior checks.

## Out of Scope

- Blocking app access after the Reinstall deadline.
- Repeated notifications after the single Reinstall reminder.
- Server-side tracking, Supabase schema changes, analytics, or remote configuration.
- Android, web, desktop, or persistent operating-system app-icon badges.
- A countdown timer that continuously updates every second.

## Further Notes

- The status remains visible if the Reinstall reminder setting is disabled.
- A regular app reinstall starts a new preference store; an IPA update is detected from its changed build number.
- The feature uses local device time and does not convert time zones.
