import '../../models/portfolio_annual_report.dart';
import '../database_repository.dart';
import '../supabase_repository.dart';

class SupabasePortfolioAnnualReportAdapter
    implements PortfolioAnnualReportRepositoryInterface {
  final SupabaseRepository _repo;

  SupabasePortfolioAnnualReportAdapter(this._repo);

  @override
  Future<List<PortfolioAnnualReport>> getPortfolioAnnualReports() async {
    if (!_repo.isAuthenticated) return [];
    try {
      _repo.log('Fetching portfolio annual reports from Supabase');
      final response = await _repo.client
          .from('portfolio_annual_reports')
          .select('*, accounts!inner(user_id)')
          .eq('accounts.user_id', _repo.currentUserId!)
          .order('year', ascending: false);

      return (response as List)
          .map(
            (row) => PortfolioAnnualReport.fromMap(
              _repo.normalizeRow(row as Map<String, dynamic>),
            ),
          )
          .toList();
    } catch (e) {
      _repo.logError('Failed to fetch portfolio annual reports', e);
      return [];
    }
  }

  @override
  Future<void> insertPortfolioAnnualReport(PortfolioAnnualReport report) async {
    if (!_repo.isAuthenticated) return;
    try {
      _repo.log('Inserting portfolio annual report: ${report.id}');
      await _repo.client
          .from('portfolio_annual_reports')
          .insert(report.toMap());
      await _repo.updateSyncLog('portfolio_annual_reports');
    } catch (e) {
      _repo.logError('Failed to insert portfolio annual report', e);
      rethrow;
    }
  }

  @override
  Future<void> updatePortfolioAnnualReport(PortfolioAnnualReport report) async {
    if (!_repo.isAuthenticated) return;
    try {
      _repo.log('Updating portfolio annual report: ${report.id}');
      await _repo.client
          .from('portfolio_annual_reports')
          .update(report.toMap())
          .eq('id', report.id);
      await _repo.updateSyncLog('portfolio_annual_reports');
    } catch (e) {
      _repo.logError('Failed to update portfolio annual report', e);
      rethrow;
    }
  }

  @override
  Future<void> deletePortfolioAnnualReport(String id) async {
    if (!_repo.isAuthenticated) return;
    try {
      _repo.log('Deleting portfolio annual report: $id');
      await _repo.client.from('portfolio_annual_reports').delete().eq('id', id);
      await _repo.updateSyncLog('portfolio_annual_reports');
    } catch (e) {
      _repo.logError('Failed to delete portfolio annual report', e);
      rethrow;
    }
  }
}
