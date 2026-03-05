import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../services/database_manager.dart';
import '../../repositories/database_repository.dart';
import '../../repositories/supabase_repository.dart';
import '../../theme/app_colors.dart';
import '../../providers/settings_provider.dart';
import '../../providers/account_provider.dart';
import '../../providers/auth_provider.dart';
import '../../providers/category_provider.dart';
import '../../providers/transaction_provider.dart';
import '../../providers/budget_provider.dart';
import '../../providers/recurring_transaction_provider.dart';
import '../auth/auth_screen.dart';

class DatabaseSettingsScreen extends StatefulWidget {
  const DatabaseSettingsScreen({super.key});

  @override
  State<DatabaseSettingsScreen> createState() => _DatabaseSettingsScreenState();
}

class _DatabaseSettingsScreenState extends State<DatabaseSettingsScreen> {
  final _urlController = TextEditingController();
  final _keyController = TextEditingController();
  bool _isTestingConnection = false;
  bool _isMigrating = false;
  String? _connectionStatus;
  double? _migrationProgress;
  String? _migrationStatus;

  @override
  void initState() {
    super.initState();
    _loadCurrentConfig();
  }

  void _loadCurrentConfig() {
    final dbManager = DatabaseManager();
    _urlController.text = dbManager.supabaseUrl ?? '';
    _keyController.text = dbManager.supabaseAnonKey ?? '';
  }

  @override
  void dispose() {
    _urlController.dispose();
    _keyController.dispose();
    super.dispose();
  }

  Future<void> _testConnection() async {
    final url = _urlController.text.trim();
    final key = _keyController.text.trim();

    if (url.isEmpty || key.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('กรุณากรอก URL และ API Key ก่อนทดสอบ'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    setState(() {
      _isTestingConnection = true;
      _connectionStatus = null;
    });

    debugPrint('[DatabaseSettings] Testing connection to: $url');

    // ทดสอบด้วยค่าจาก TextField โดยตรง ไม่ต้องบันทึกก่อน
    final dbManager = DatabaseManager();
    bool success = false;
    String? errorMessage;
    
    try {
      success = await dbManager.testSupabaseConnectionWithCredentials(
        url: url,
        anonKey: key,
      );
    } catch (e) {
      debugPrint('[DatabaseSettings] Connection test error: $e');
      errorMessage = e.toString();
      success = false;
    }

    setState(() {
      _isTestingConnection = false;
      _connectionStatus = success ? 'เชื่อมต่อสำเร็จ' : 'เชื่อมต่อไม่สำเร็จ';
    });

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            success
                ? 'เชื่อมต่อ Supabase สำเร็จ!'
                : 'เชื่อมต่อไม่สำเร็จ${errorMessage != null ? ': $errorMessage' : ''}',
          ),
          backgroundColor: success ? AppColors.income : AppColors.expense,
        ),
      );
    }
  }

  Future<void> _saveSupabaseConfig() async {
    final url = _urlController.text.trim();
    final key = _keyController.text.trim();

    if (url.isEmpty || key.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('กรุณากรอก URL และ API Key'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    final dbManager = DatabaseManager();
    final success = await dbManager.configureSupabase(url: url, anonKey: key);

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            success ? 'บันทึกการตั้งค่าเรียบร้อย' : 'ไม่สามารถบันทึกได้',
          ),
          backgroundColor: success ? AppColors.income : AppColors.expense,
        ),
      );
    }
  }

  Future<void> _clearSupabaseConfig() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('ยืนยันการลบ'),
        content: const Text(
          'ต้องการลบการตั้งค่า Supabase และกลับไปใช้ SQLite ใช่หรือไม่?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('ยกเลิก'),
          ),
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('ลบ', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    final dbManager = DatabaseManager();
    await dbManager.clearSupabaseConfig();

    _urlController.clear();
    _keyController.clear();

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('ลบการตั้งค่าเรียบร้อย กลับไปใช้ SQLite')),
      );
    }
  }

  Future<void> _migrateToSupabase() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('ยืนยันการย้ายข้อมูล'),
        content: const Text(
          'การย้ายข้อมูลจะคัดลอกข้อมูลทั้งหมดจาก SQLite ไปยัง Supabase\n\n'
          'หมายเหตุ: ข้อมูลเดิมใน SQLite จะไม่ถูกลบ',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('ยกเลิก'),
          ),
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text(
              'ย้ายข้อมูล',
              style: TextStyle(color: Colors.blue),
            ),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    setState(() {
      _isMigrating = true;
      _migrationProgress = 0;
      _migrationStatus = 'กำลังเตรียมการ...';
    });

    final dbManager = DatabaseManager();
    try {
      final results = await dbManager.migrateToSupabase(
        onProgress: (status, progress) {
          setState(() {
            _migrationStatus = status;
            _migrationProgress = progress;
          });
        },
      );

      final total = results.values.fold<int>(0, (sum, count) => sum + count);

      // Reload providers after migration
      if (mounted) {
        await _reloadAllProviders(context);
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('ย้ายข้อมูลสำเร็จ! ทั้งหมด $total records'),
            backgroundColor: AppColors.income,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('เกิดข้อผิดพลาด: $e'),
            backgroundColor: AppColors.expense,
          ),
        );
      }
    } finally {
      setState(() {
        _isMigrating = false;
      });
    }
  }

  Future<void> _migrateFromSupabase() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('ยืนยันการดึงข้อมูล'),
        content: const Text(
          'การดึงข้อมูลจะคัดลอกข้อมูลทั้งหมดจาก Supabase มายัง SQLite\n\n'
          '⚠️ ข้อมูลเดิมใน SQLite จะถูกลบและแทนที่ด้วยข้อมูลจาก Supabase',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('ยกเลิก'),
          ),
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text(
              'ดึงข้อมูล',
              style: TextStyle(color: Colors.orange),
            ),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    setState(() {
      _isMigrating = true;
      _migrationProgress = 0;
      _migrationStatus = 'กำลังเตรียมการ...';
    });

    final dbManager = DatabaseManager();
    try {
      final results = await dbManager.migrateFromSupabase(
        onProgress: (status, progress) {
          setState(() {
            _migrationStatus = status;
            _migrationProgress = progress;
          });
        },
      );

      final total = results.values.fold<int>(0, (sum, count) => sum + count);

      // Reload providers after migration
      if (mounted) {
        await _reloadAllProviders(context);
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('ดึงข้อมูลสำเร็จ! ทั้งหมด $total records'),
            backgroundColor: AppColors.income,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('เกิดข้อผิดพลาด: $e'),
            backgroundColor: AppColors.expense,
          ),
        );
      }
    } finally {
      setState(() {
        _isMigrating = false;
      });
    }
  }

  Future<void> _switchMode(DatabaseMode mode) async {
    final dbManager = DatabaseManager();
    final authProvider = context.read<AuthProvider>();

    if (mode == DatabaseMode.supabase && !dbManager.canUseSupabase) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('กรุณาตั้งค่า Supabase ก่อน'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    // ถ้า switch ไป Supabase แต่ยังไม่ได้ login
    // → ต้อง initialize Supabase ก่อน แล้วค่อยไปหน้า login
    if (mode == DatabaseMode.supabase && !authProvider.isLoggedIn) {
      // Initialize Supabase ก่อน (สร้าง SupabaseRepository)
      if (dbManager.supabaseUrl != null && dbManager.supabaseAnonKey != null) {
        try {
          // สร้าง SupabaseRepository ชั่วคราวเพื่อ initialize Supabase
          final tempRepo = SupabaseRepository(
            supabaseUrl: dbManager.supabaseUrl!,
            supabaseAnonKey: dbManager.supabaseAnonKey!,
          );
          await tempRepo.init();

          // Initialize AuthProvider หลังจาก Supabase พร้อม
          await authProvider.init();
        } catch (e) {
          debugPrint('[DatabaseSettings] Error initializing Supabase: $e');
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text('ไม่สามารถเชื่อมต่อ Supabase ได้: $e'),
                backgroundColor: AppColors.expense,
              ),
            );
          }
          return;
        }
      }

      // ไปหน้า login
      debugPrint('[DatabaseSettings] Navigating to AuthScreen...');
      final loginSuccess = await Navigator.push<bool>(
        context,
        MaterialPageRoute(builder: (_) => const AuthScreen()),
      );
      debugPrint(
        '[DatabaseSettings] Returned from AuthScreen: loginSuccess=$loginSuccess, isLoggedIn=${authProvider.isLoggedIn}',
      );

      // ถ้า login ไม่สำเร็จ (กด back หรือ error) → ไม่ต้อง switch mode
      if (loginSuccess != true && !authProvider.isLoggedIn) {
        return;
      }
    }

    final success = await dbManager.switchMode(mode);

    if (success) {
      // Reload all providers after switching mode (เฉพาะถ้าเป็น SQLite หรือ login แล้ว)
      if (mounted) {
        await _reloadAllProviders(context);
      }
    } else if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('ไม่สามารถสลับโหมดได้'),
          backgroundColor: AppColors.expense,
        ),
      );
    }
  }

  Future<void> _reloadAllProviders(BuildContext context) async {
    debugPrint('[DatabaseSettings] Reloading all providers...');

    final dbManager = DatabaseManager();
    final authProvider = context.read<AuthProvider>();

    // ถ้าเป็น Supabase mode แต่ยังไม่ได้ login → ไม่ต้อง reload providers
    if (dbManager.isSupabaseMode && !authProvider.isLoggedIn) {
      debugPrint(
        '[DatabaseSettings] Skipping reload - not logged in to Supabase',
      );
      return;
    }

    // เก็บ ScaffoldMessenger ไว้ก่อนเข้า async
    final scaffoldMessenger = ScaffoldMessenger.of(context);

    try {
      await Future.wait([
        context.read<AccountProvider>().reload(),
        context.read<CategoryProvider>().reload(),
        context.read<TransactionProvider>().reload(),
        context.read<BudgetProvider>().reload(),
        context.read<RecurringTransactionProvider>().reload(),
      ]);

      debugPrint('[DatabaseSettings] All providers reloaded');

      if (mounted) {
        scaffoldMessenger.showSnackBar(
          const SnackBar(
            content: Text('โหลดข้อมูลสำเร็จ!'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      debugPrint('[DatabaseSettings] Error reloading providers: $e');
      if (mounted) {
        scaffoldMessenger.showSnackBar(
          SnackBar(
            content: Text('โหลดข้อมูลไม่สำเร็จ: $e'),
            backgroundColor: AppColors.expense,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDarkMode = context.watch<SettingsProvider>().isDarkMode;
    final backgroundColor = isDarkMode
        ? AppColors.darkBackground
        : AppColors.background;
    final surfaceColor = isDarkMode ? AppColors.darkSurface : Colors.white;
    final textColor = isDarkMode
        ? AppColors.darkTextPrimary
        : AppColors.textPrimary;
    final secondaryTextColor = isDarkMode
        ? AppColors.darkTextSecondary
        : AppColors.textSecondary;

    return Scaffold(
      backgroundColor: backgroundColor,
      appBar: AppBar(
        backgroundColor: AppColors.header,
        foregroundColor: textColor,
        title: Text('ตั้งค่า Database'),
        elevation: 0,
      ),
      body: Consumer<DatabaseManager>(
        builder: (context, dbManager, _) {
          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              // Current Mode Card
              _buildCard(
                surfaceColor: surfaceColor,
                textColor: textColor,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'โหมดปัจจุบัน',
                      style: TextStyle(
                        fontSize: 14,
                        color: secondaryTextColor,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Icon(
                          dbManager.isSqliteMode ? Icons.storage : Icons.cloud,
                          color: dbManager.isSqliteMode
                              ? Colors.orange
                              : Colors.blue,
                          size: 32,
                        ),
                        const SizedBox(width: 12),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              dbManager.isSqliteMode
                                  ? 'SQLite (Local)'
                                  : 'Supabase (Cloud)',
                              style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                                color: textColor,
                              ),
                            ),
                            Text(
                              dbManager.isSqliteMode
                                  ? 'เก็บข้อมูลในเครื่อง'
                                  : 'เก็บข้อมูลบน Cloud',
                              style: TextStyle(
                                fontSize: 12,
                                color: secondaryTextColor,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    Row(
                      children: [
                        Expanded(
                          child: _buildModeButton(
                            'SQLite',
                            Icons.storage,
                            Colors.orange,
                            dbManager.isSqliteMode,
                            () => _switchMode(DatabaseMode.sqlite),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: _buildModeButton(
                            'Supabase',
                            Icons.cloud,
                            Colors.blue,
                            dbManager.isSupabaseMode,
                            () => _switchMode(DatabaseMode.supabase),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 16),

              // Supabase Configuration Card
              _buildCard(
                surfaceColor: surfaceColor,
                textColor: textColor,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'ตั้งค่า Supabase',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: textColor,
                      ),
                    ),
                    const SizedBox(height: 16),
                    TextField(
                      controller: _urlController,
                      decoration: InputDecoration(
                        labelText: 'Supabase URL',
                        hintText: 'https://your-project.supabase.co',
                        labelStyle: TextStyle(color: secondaryTextColor),
                        hintStyle: TextStyle(
                          color: secondaryTextColor.withAlpha(128),
                        ),
                        border: const OutlineInputBorder(),
                        enabledBorder: OutlineInputBorder(
                          borderSide: BorderSide(
                            color: isDarkMode
                                ? AppColors.darkDivider
                                : AppColors.divider,
                          ),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderSide: BorderSide(color: AppColors.header),
                        ),
                      ),
                      style: TextStyle(color: textColor),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: _keyController,
                      decoration: InputDecoration(
                        labelText: 'Anon Key',
                        hintText: 'your-anon-key',
                        labelStyle: TextStyle(color: secondaryTextColor),
                        hintStyle: TextStyle(
                          color: secondaryTextColor.withAlpha(128),
                        ),
                        border: const OutlineInputBorder(),
                        enabledBorder: OutlineInputBorder(
                          borderSide: BorderSide(
                            color: isDarkMode
                                ? AppColors.darkDivider
                                : AppColors.divider,
                          ),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderSide: BorderSide(color: AppColors.header),
                        ),
                      ),
                      style: TextStyle(color: textColor),
                      obscureText: true,
                    ),
                    const SizedBox(height: 16),
                    Row(
                      children: [
                        Expanded(
                          child: OutlinedButton.icon(
                            onPressed: _isTestingConnection
                                ? null
                                : _testConnection,
                            icon: _isTestingConnection
                                ? const SizedBox(
                                    width: 16,
                                    height: 16,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                    ),
                                  )
                                : const Icon(Icons.network_check, size: 18),
                            label: const Text('ทดสอบ'),
                            style: OutlinedButton.styleFrom(
                              foregroundColor: textColor,
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: ElevatedButton.icon(
                            onPressed: _saveSupabaseConfig,
                            icon: const Icon(Icons.save, size: 18),
                            label: const Text('บันทึก'),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: AppColors.header,
                              foregroundColor: Colors.white,
                            ),
                          ),
                        ),
                      ],
                    ),
                    if (_connectionStatus != null) ...[
                      const SizedBox(height: 8),
                      Text(
                        _connectionStatus!,
                        style: TextStyle(
                          color: _connectionStatus == 'เชื่อมต่อสำเร็จ'
                              ? AppColors.income
                              : AppColors.expense,
                          fontSize: 12,
                        ),
                      ),
                    ],
                    if (dbManager.canUseSupabase) ...[
                      const SizedBox(height: 8),
                      TextButton.icon(
                        onPressed: _clearSupabaseConfig,
                        icon: const Icon(Icons.delete_outline, size: 18),
                        label: const Text('ลบการตั้งค่า'),
                        style: TextButton.styleFrom(
                          foregroundColor: AppColors.expense,
                        ),
                      ),
                    ],
                  ],
                ),
              ),

              const SizedBox(height: 16),

              // Migration Card
              if (dbManager.canUseSupabase)
                _buildCard(
                  surfaceColor: surfaceColor,
                  textColor: textColor,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'ย้ายข้อมูล',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: textColor,
                        ),
                      ),
                      const SizedBox(height: 16),
                      if (_isMigrating) ...[
                        LinearProgressIndicator(
                          value: _migrationProgress,
                          backgroundColor: isDarkMode
                              ? AppColors.darkDivider
                              : AppColors.divider,
                          valueColor: AlwaysStoppedAnimation<Color>(
                            AppColors.header,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          _migrationStatus ?? 'กำลังดำเนินการ...',
                          style: TextStyle(
                            fontSize: 12,
                            color: secondaryTextColor,
                          ),
                        ),
                      ] else ...[
                        // Upload to Supabase
                        Text(
                          'SQLite → Supabase',
                          style: TextStyle(
                            fontSize: 14,
                            color: secondaryTextColor,
                          ),
                        ),
                        const SizedBox(height: 8),
                        SizedBox(
                          width: double.infinity,
                          child: ElevatedButton.icon(
                            onPressed: _migrateToSupabase,
                            icon: const Icon(Icons.cloud_upload),
                            label: const Text('ย้ายข้อมูลไป Supabase'),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.blue,
                              foregroundColor: Colors.white,
                            ),
                          ),
                        ),
                        const SizedBox(height: 16),
                        const Divider(),
                        const SizedBox(height: 16),
                        // Download from Supabase
                        Text(
                          'Supabase → SQLite',
                          style: TextStyle(
                            fontSize: 14,
                            color: secondaryTextColor,
                          ),
                        ),
                        const SizedBox(height: 8),
                        SizedBox(
                          width: double.infinity,
                          child: OutlinedButton.icon(
                            onPressed: _migrateFromSupabase,
                            icon: const Icon(Icons.cloud_download),
                            label: const Text('ดึงข้อมูลจาก Supabase'),
                            style: OutlinedButton.styleFrom(
                              foregroundColor: Colors.orange,
                              side: const BorderSide(color: Colors.orange),
                            ),
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          '⚠️ ข้อมูลเดิมใน SQLite จะถูกแทนที่',
                          style: TextStyle(
                            fontSize: 12,
                            color: AppColors.expense,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),

              const SizedBox(height: 16),

              // Info Card
              _buildCard(
                surfaceColor: surfaceColor,
                textColor: textColor,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'คำแนะนำ',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: textColor,
                      ),
                    ),
                    const SizedBox(height: 12),
                    _buildInfoItem(
                      icon: Icons.storage,
                      title: 'SQLite',
                      description:
                          'เหมาะสำหรับใช้งานคนเดียว ไม่ต้องการ internet',
                      textColor: textColor,
                      secondaryTextColor: secondaryTextColor,
                    ),
                    const Divider(height: 24),
                    _buildInfoItem(
                      icon: Icons.cloud,
                      title: 'Supabase',
                      description:
                          'เหมาะสำหรับต้องการ sync ข้อมูลข้ามอุปกรณ์ ต้องมี internet',
                      textColor: textColor,
                      secondaryTextColor: secondaryTextColor,
                    ),
                  ],
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildCard({
    required Color surfaceColor,
    required Color textColor,
    required Widget child,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: surfaceColor,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withAlpha(13),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: child,
    );
  }

  Widget _buildModeButton(
    String label,
    IconData icon,
    Color color,
    bool isActive,
    VoidCallback onTap,
  ) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12),
        decoration: BoxDecoration(
          color: isActive ? color.withAlpha(26) : Colors.transparent,
          border: Border.all(
            color: isActive ? color : Colors.grey.shade300,
            width: 2,
          ),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Column(
          children: [
            Icon(icon, color: isActive ? color : Colors.grey),
            const SizedBox(height: 4),
            Text(
              label,
              style: TextStyle(
                color: isActive ? color : Colors.grey,
                fontWeight: isActive ? FontWeight.bold : FontWeight.normal,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildInfoItem({
    required IconData icon,
    required String title,
    required String description,
    required Color textColor,
    required Color secondaryTextColor,
  }) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 20, color: secondaryTextColor),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: TextStyle(fontWeight: FontWeight.w500, color: textColor),
              ),
              Text(
                description,
                style: TextStyle(fontSize: 12, color: secondaryTextColor),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
