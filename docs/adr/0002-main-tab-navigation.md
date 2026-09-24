# Main-tab navigation owns mobile primary navigation

On mobile, the Main Tabs switch locally rather than navigating through GoRouter. `MainTabScreen` retains tab state and owns primary navigation; its routes remain external entry points. This preserves access to secondary features without resetting a tab on each switch. Current tab names and UI rules live in [design.md](../design.md).
