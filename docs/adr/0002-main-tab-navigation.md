# Main-tab navigation owns mobile primary navigation

On mobile, accounts, budgets, and transactions are retained Main Tabs that switch locally rather than navigating through GoRouter. Their routes remain external entry points, while Drawer and desktop Sidebar expose the Main Tabs alongside the existing Secondary Screen destinations. This keeps primary tab state local without removing access to secondary features, and supersedes the route-switching tab structure in ADR 0001.
