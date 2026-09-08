DateTime _monthlyCycleStart(DateTime month, int startDay) {
  final lastDay = DateTime(month.year, month.month + 1, 0).day;
  return DateTime(month.year, month.month, startDay.clamp(1, lastDay));
}

DateTime monthlyCycleReportingMonth(DateTime date, int startDay) {
  final month = DateTime(date.year, date.month);
  final cycleStartMonth = date.isBefore(_monthlyCycleStart(month, startDay))
      ? DateTime(date.year, date.month - 1)
      : month;
  final endExclusive = _monthlyCycleStart(
    DateTime(cycleStartMonth.year, cycleStartMonth.month + 1),
    startDay,
  );
  final end = endExclusive.subtract(const Duration(days: 1));
  return DateTime(end.year, end.month);
}

({DateTime start, DateTime endExclusive}) monthlyCyclePeriod(
  DateTime reportingMonth,
  int startDay,
) {
  final startMonth = startDay <= 1
      ? reportingMonth
      : DateTime(reportingMonth.year, reportingMonth.month - 1);
  return (
    start: _monthlyCycleStart(startMonth, startDay),
    endExclusive: _monthlyCycleStart(
      DateTime(startMonth.year, startMonth.month + 1),
      startDay,
    ),
  );
}
