#!/usr/bin/env bash
# Fails when screens re-implement UI primitives that have a shared widget or
# theme token. See docs/design.md ("Shared widgets และ tokens").
# A line directly preceded by `// design-check: allow <reason>` is skipped.
set -euo pipefail
cd "$(dirname "$0")/.."

status=0

# check <description> <regex> <files...>
check() {
  local description=$1 pattern=$2
  shift 2
  local matches hits
  matches=$(grep -nE -B1 "$pattern" "$@" || true)
  hits=$(PATTERN="$pattern" awk '
    /design-check: allow/ { allow = 1; next }
    $0 ~ ENVIRON["PATTERN"] { if (!allow) print; allow = 0; next }
    { allow = 0 }
  ' <<<"$matches")
  if [[ -n "$hits" ]]; then
    echo "✗ $description"
    echo "$hits" | sed 's/^/    /'
    status=1
  fi
}

files_except() {
  find lib/screens lib/widgets -name '*.dart' | grep -vE "$1"
}

check 'Use AppSwitch instead of CupertinoSwitch' \
  'CupertinoSwitch\(' $(files_except 'lib/widgets/app_switch\.dart')

check 'Use AppDraggableSheet instead of DraggableScrollableSheet' \
  'DraggableScrollableSheet\(' $(files_except 'lib/widgets/app_modal_bottom_sheet\.dart')

check 'Use showAppConfirmDialog instead of AlertDialog' \
  'AlertDialog\(' $(files_except 'lib/widgets/app_confirm_dialog\.dart')

check 'Use AppCloseButton / AppBackButton for AppBar leading buttons' \
  'Icons\.arrow_back(_rounded)?[,)]' $(files_except 'lib/widgets/app_bar_buttons\.dart')

check 'Use AppSectionHeader / AppInsetCard / AppCardDivider instead of local helpers' \
  'Widget _build(SectionHeader|InsetCard|CardDivider|IndentedDivider)\(' \
  $(files_except '^$')

check 'Use AppColors.borderFor for card and divider borders' \
  'AppColors\.darkDivider(\.withValues\(alpha: 0\.4\)|[[:space:]]*:[[:space:]]*AppColors\.divider\)[[:space:]]*\.withValues)' \
  $(files_except '^$')

check 'Use AppColors tokens instead of hard-coded Color(0x...) values' \
  'Color\(0x[0-9A-Fa-f]+\)' $(files_except '^$')

if [[ $status -eq 0 ]]; then
  echo '✓ design check passed'
fi
exit $status
