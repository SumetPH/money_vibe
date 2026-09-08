DateTime monthlyCycleStart(DateTime month, int startDay) {
  final lastDay = DateTime(month.year, month.month + 1, 0).day;
  return DateTime(month.year, month.month, startDay.clamp(1, lastDay));
}

DateTime monthlyCycleMonth(DateTime date, int startDay) {
  final month = DateTime(date.year, date.month);
  return date.isBefore(monthlyCycleStart(month, startDay))
      ? DateTime(date.year, date.month - 1)
      : month;
}

({DateTime start, DateTime endExclusive}) monthlyCyclePeriod(
  DateTime month,
  int startDay,
) {
  return (
    start: monthlyCycleStart(month, startDay),
    endExclusive: monthlyCycleStart(
      DateTime(month.year, month.month + 1),
      startDay,
    ),
  );
}
