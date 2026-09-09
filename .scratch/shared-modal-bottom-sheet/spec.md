# Shared modal bottom sheet pattern

Status: resolved

## Behavior

- Every `showModalBottomSheet` uses one shared visual shell across Light and Dark modes.
- The shell owns the surface color, clipped top radius, native drag handle, and safe-area behavior.
- A titled sheet uses a 16px semibold title and divider; action sheets may omit the title.
- Short menus and small grids remain content-sized.
- Long selection lists use `DraggableScrollableSheet` with `initialChildSize: 0.85`, `minChildSize: 0.3`, and `maxChildSize: 0.85`.
- Existing selection, save, dismiss, and business behavior remains unchanged.
- Persistent calculator keyboards created with `ScaffoldState.showBottomSheet` are excluded.
- Existing tablet and web width behavior remains unchanged.

## Implementation Decisions

- Put modal presentation defaults behind one shared function in `lib/widgets`.
- Use Flutter's native drag handle rather than drawing a handle in each sheet.
- Reuse `AppColors`, `AppRadii.sheet`, `SettingsProvider`, and the existing `BottomSheetThemeData`.
- Migrate all current modal call sites; do not add a dependency or a new state abstraction.

## Validation

- `dart format .`
- `flutter analyze`

## Out of Scope

- Calculator keyboard presentation.
- Changes to modal content or business flows.
- New responsive width constraints.
- Database, repository, provider, schema, or API changes.
