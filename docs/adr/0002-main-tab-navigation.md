# Main-tab navigation owns mobile primary navigation

On mobile, accounts, budgets, and transactions are retained Main Tabs that switch locally rather than navigating through GoRouter. Their routes remain external entry points, while Drawer and desktop Sidebar expose the same three Main Tabs only; all other screens are Secondary Screens reached from their relevant context. This deliberately favors preserved in-app state over URL and system-back history for tab changes, and supersedes the route-switching tab structure in ADR 0001.
