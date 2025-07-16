class SortOption {
  final String name;
  final DateRange value;

  SortOption({
    required this.name,
    required this.value,
  });
}

class DateRange {
  final DateTime start;
  final DateTime end;

  DateRange({
    required this.start,
    required this.end,
  });
}
