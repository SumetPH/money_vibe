# Money Flutter - Project Context

## Project Overview

**Money Flutter** is a personal finance management application built with Flutter. It provides comprehensive money tracking capabilities including:

- **Transaction Management**: Track income, expenses, transfers, and debt repayments
- **Account Management**: Support for multiple account types (cash, bank accounts, credit cards, debts, investments)
- **Category Management**: Organize transactions with customizable expense/income categories
- **Local Storage**: SQLite database for offline-first data persistence

### Tech Stack

| Component | Technology |
|-----------|------------|
| Framework | Flutter (SDK ^3.10.0) |
| Language | Dart |
| State Management | Provider pattern with `ChangeNotifier` |
| Database | SQLite (`sqflite`) |
| Key Dependencies | `provider`, `intl`, `uuid`, `sqflite`, `path` |

## Project Structure

```
lib/
├── main.dart                 # App entry point, provider initialization, routing
├── database/
│   └── database_helper.dart  # SQLite database operations (singleton)
├── models/
│   ├── account.dart          # Account model with types and balance tracking
│   ├── category.dart         # Category model (expense/income)
│   └── transaction.dart      # Transaction model with type enum
├── providers/
│   ├── account_provider.dart     # Account state management + balance computation
│   ├── category_provider.dart    # Category state management
│   └── transaction_provider.dart # Transaction state management + grouping
├── screens/
│   ├── account/              # Account-related UI screens
│   ├── category/             # Category management screens
│   └── transaction/          # Transaction list/detail screens
├── theme/
│   ├── app_theme.dart        # Material theme configuration
│   └── app_colors.dart       # App-wide color constants
└── widgets/                  # Reusable UI components
```

## Building and Running

### Prerequisites
- Flutter SDK ^3.10.0
- Dart SDK (bundled with Flutter)

### Commands

```bash
# Install dependencies
flutter pub get

# Run the app (debug mode)
flutter run

# Run on specific device
flutter run -d <device_id>

# Build for Android
flutter build apk      # Debug APK
flutter build appbundle # Release App Bundle

# Build for iOS
flutter build ios

# Run tests
flutter test

# Code analysis
flutter analyze

# Format code
dart format .
```

### Available Routes

| Route | Screen |
|-------|--------|
| `/` | Transaction list (home) |
| `/accounts` | Account list |
| `/categories` | Category list |

## Architecture Patterns

### State Management
- Uses **Provider** pattern with `ChangeNotifier`
- Three main providers: `AccountProvider`, `CategoryProvider`, `TransactionProvider`
- Providers are initialized in `main.dart` and passed via `MultiProvider`

### Data Flow
1. **Models** define data structures with `toMap()`/`fromMap()` for serialization
2. **DatabaseHelper** provides CRUD operations for SQLite
3. **Providers** manage in-memory state + persist to database
4. **Screens** consume providers via `Provider.of<T>(context)` or `Consumer<T>`

### Database Schema

**accounts**: `id`, `name`, `type`, `initial_balance`, `currency`, `start_date`, `icon`, `color`, `auto_clear`, `show_on_main`, `is_default`, `exclude_from_net_worth`, `is_hidden`, `group_name`, `note`

**categories**: `id`, `name`, `type`, `icon`, `color`, `parent_id`, `is_default`, `note`

**transactions**: `id`, `type`, `amount`, `account_id`, `category_id`, `to_account_id`, `payee`, `location`, `date_time`, `note`, `tags`, `is_cleared`, `record_date`

## Development Conventions

### Code Style
- Follows `flutter_lints` rules (see `analysis_options.yaml`)
- Uses trailing commas for better formatting
- Private members prefixed with `_`
- Null safety enabled (Dart 3.x)

### Naming Conventions
- **Files**: snake_case (e.g., `account_provider.dart`)
- **Classes**: PascalCase (e.g., `AppTransaction`)
- **Variables/Functions**: camelCase (e.g., `getBalance`)
- **Constants**: camelCase with `static const` (e.g., `AppColors.header`)

### Key Patterns
- **Seed Data**: Providers include seed data for first-launch initialization
- **Balance Computation**: Centralized in `AccountProvider.getBalance()`
- **Transaction Types**: Enum-based (`expense`, `income`, `transfer`, `debtRepay`)
- **Amount Formatting**: Helper functions in `main.dart` (`formatAmount`, `formatAmountShort`)

### Testing
- Tests located in `/test` directory
- Uses `flutter_test` framework
- Current test suite is minimal (placeholder test exists)

## Key Business Logic

### Transaction Types
- **Expense**: Money spent (reduces balance)
- **Income**: Money received (increases balance)
- **Transfer**: Move money between accounts
- **Debt Repay**: Debt/credit card payment

### Account Types
- **Cash**: Physical cash/wallet
- **Bank Account**: Savings/checking accounts
- **Credit Card**: Credit cards (negative balance = owed)
- **Debt**: Loans/debts (negative balance = owed)
- **Investment**: Investment accounts

### Color Coding
- Green (`#4CAF50`): Income
- Red (`#F44336`): Expense
- Blue (`#2196F3`): Transfer
- Header: Dark blue (`#1B3548`)

## Additional Notes

- **Localization**: Uses Thai language for some UI elements (category labels, account types)
- **Currency**: Default is THB (Thai Baht)
- **Database**: Single SQLite database (`money.db`) in app documents directory
- **Platform Support**: Android, iOS, Web, Windows, Linux, macOS
