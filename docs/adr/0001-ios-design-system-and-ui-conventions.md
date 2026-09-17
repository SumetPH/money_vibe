# iOS Design System and UI Component Conventions

We standardize the Money Vibe user interface on a modern iOS Inset Grouped, surface-first design language with native Cupertino switches and dark-mode-first contrast. We reject fragmented Material 3 components (such as default `SwitchListTile`, rectangular dialogs, and standard dropdowns) and heavy gradient styling in favor of crisp, clean, structured iOS cards and bottom sheets.

## Considered Options

- **Option 1: Material 3 Default**: Use standard Flutter/Material 3 `SwitchListTile`, `DropdownButtonFormField`, and default card elevation. (Rejected: Inconsistent visual hierarchy, clunky toggle tracks, poor dark mode contrast).
- **Option 2: Heavy Gradient & Neumorphism**: Use gradient cards and colorful surfaces. (Rejected: Visual clutter, reduces readability of financial figures).
- **Option 3 (Selected): iOS Inset Grouped & Surface-First**: Dark mode first, clean surfaces (`darkSurface`/`surface`), subtle borders, uppercase section headers, native `CupertinoSwitch`, and bottom sheet selectors.

## Canonical Patterns

1. **Inset Grouped Card**:
   - `margin: EdgeInsets.symmetric(horizontal: 16, vertical: 6)`
   - `borderRadius: BorderRadius.circular(AppRadii.xLarge)`
   - Border: `Border.all(color: dividerColor.withValues(alpha: 0.35), width: 1)`
   - Section header placed outside the card: uppercase, 12sp, `FontWeight.w600`, `letterSpacing: 0.5`, using `textSecondary`.

2. **Form & Setting Row**:
   - Left: Squircle Icon or Letter Avatar (32-40px, `AppRadii.medium`, background with 12-15% tint).
   - Middle: Title (`15sp`, `FontWeight.w600`, `textPrimary`) and subtitle (`12sp`, `textSecondary`).
   - Right: Trailing control (`CupertinoSwitch`, disclosure arrow, or selected value).

3. **Toggles**:
   - Always use `CupertinoSwitch` with explicit `activeTrackColor` (`AppColors.income` or accent) and `inactiveTrackColor` (`Color(0xFF39393D)` dark / `Color(0xFFE9E9EA)` light). Never use Material `SwitchListTile`.

4. **Numeric & Amount Input Box**:
   - Integrated container with background (`Color(0xFF1C1C1E)` dark / `Color(0xFFF2F2F7)` light) and subtle border.
   - Right-aligned bold number with integrated unit/currency label.
   - Always include `onTapOutside: (_) => FocusManager.instance.primaryFocus?.unfocus()`.
   - TextFields inside cards must explicitly set `border: InputBorder.none`, `enabledBorder: InputBorder.none`, `focusedBorder: InputBorder.none`, and `filled: false` to prevent Material `inputDecorationTheme` from injecting outer rectangular borders.

5. **Search Inputs (iOS Search Bar)**:
   - Always use native `CupertinoSearchTextField` (or a dedicated borderless soft-surface pill with `prefixIcon`).
   - Never wrap a Material `TextField` in an outer bordered `Container` with an external icon, which produces an awkward double border ("box-in-a-box") and misaligned search icon.
   - Background: `darkSurfaceVariant` in dark mode / `surface` (or `Color(0xFFE5E7EB)`) in light mode, `borderRadius: BorderRadius.circular(10)`.

6. **Selection Controls & Modal Bottom Sheets**:
   - Use `showAppModalBottomSheet` instead of dropdowns or dropdown form fields.
   - Bottom sheet headers (`AppModalBottomSheetHeader`) use clean spacing (`Padding(fromLTRB(16, 8, 16, 16))`) without hard divider lines for a cleaner modern iOS appearance.
   - When grouping interactive `ListTile` items in a bottom sheet card, use `Material(color: ..., shape: RoundedRectangleBorder(...), clipBehavior: Clip.antiAlias)` instead of an opaque colored `Container`, so that touch ink splashes render properly on the surface without triggering the Flutter invisible ink warning.

7. **Metric Grid & Status Capsule**:
   - Financial comparisons (percentage, current vs target values, diffs) must use structured 2x3 or 2-column rounded metric tiles (`_MetricTile`).
   - Status indicators must use rounded pill capsules (`AppRadii.full`) with 12% semantic tint.

8. **Scaffold Header & Navigation Bar (AppBar)**:
   - **Background & Zero Elevation**: Set `backgroundColor: isDarkMode ? AppColors.darkBackground : AppColors.background`, `elevation: 0`, and `scrolledUnderElevation: 0` to create a seamless canvas-matched iOS header.
   - **Main / Tab Screens (iOS Large Title)**:
     - Two-tier title hierarchy in `AppBar.title`:
       - Eyebrow / Supertitle context: `13sp`, `FontWeight.w600`, `textSecondary` (e.g., 'ภาพรวมการเงิน' or period subtitle).
       - Large Title: `30sp`, `FontWeight.w700`, `textPrimary` (e.g., 'บัญชี', 'ธุรกรรม').
     - Parameters: `toolbarHeight: 104` to `112`, `centerTitle: false`, `automaticallyImplyLeading: false`, and `titleSpacing: isLargeScreen ? 24 : 16`.
   - **Form / Detail Screens (Standard Header)**:
     - Centered title (`centerTitle: true`), `18sp`, `FontWeight.w700`, `textPrimary`.
     - `leadingWidth: 64` with circular surface back or close button.
   - **Circular Surface Action & Leading Buttons**:
     - Never place raw, unstyled icon buttons floating directly on the scaffold background.
     - Encase leading and action icons inside circular surface containers with proper touch ripple:
       ```dart
       Material(
         color: isDarkMode ? AppColors.darkSurface : AppColors.surface,
         shape: const CircleBorder(),
         clipBehavior: Clip.antiAlias,
         child: IconButton(
           icon: const Icon(Icons.more_horiz, size: 20),
           onPressed: () => ...,
         ),
       )
       ```
     - For destructive actions (e.g., delete), use `AppColors.expense` for the icon while preserving the circular surface container.

9. **Floating Capsule Bottom Navigation (`AppBottomNavigation`)**:
   - **Floating Pill Dock**:
     - Never use sticky, full-width rectangular Material `NavigationBar` or `BottomNavigationBar`.
     - Always use `AppBottomNavigation` floating capsule dock:
       - Margin: `EdgeInsets.symmetric(horizontal: 12)`
       - Radius: `BorderRadius.circular(AppRadii.sheet)`
       - Border: `Border.all(color: dividerColor.withValues(alpha: 0.35), width: 1)`
       - Shadow: `BoxShadow(color: Colors.black.withValues(alpha: isDarkMode ? 0.35 : 0.08), blurRadius: 16, offset: const Offset(0, 4))`
       - Inset padding: `SafeArea(top: false, minimum: const EdgeInsets.symmetric(vertical: 6))`
   - **Tab & Action Structure**:
     - Three Main Tab destinations: บัญชี (`/accounts`), แผน (`/budgets`), and รายการ (`/transactions`). เมนูเปิด AppDrawer, which also exposes secondary destinations. See ADR 0002 for retained tab state and primary-navigation ownership.
     - Central elevated Quick-Add FAB: Dedicated circular action button (`width: 54, height: 54`, `shape: CircleBorder()`, `color: fabColor`, `onFab` icon `Icons.add_rounded, size: 30`) for immediate transaction creation.
   - **Responsive & Scoped Integration**:
     - Show on mobile only (`isLargeScreen ? null : ...` where `isLargeScreen` is width >= 800px).
     - Must be wrapped in `Builder` inside `Scaffold.bottomNavigationBar` so that `onOpenDrawer: () => Scaffold.of(context).openDrawer()` receives a descendant context with access to the Scaffold.

## Code Safety & Non-Regression Rules

- **Zero Regression**: Redesigning any screen must strictly preserve calculations, repository calls, Providers, debounce timers, and validation logic.
- **Tokens**: Colors must come from `AppColors` and radii from `AppRadii`. Translucent tints using `.withValues(alpha: ...)` on black/white or semantic colors are permitted for iOS depth.
