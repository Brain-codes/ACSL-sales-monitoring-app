/// Dates and times, pinned to West Africa Time.
///
/// M11: nothing in the app pinned a zone. Every `DateFormat` rendered in the
/// handset's zone and the "Today" filter used the handset's local date, so a
/// sale made late in the evening could land on the wrong day — and a phone set
/// to the wrong zone silently reported the wrong day for everything.
///
/// The business runs in Nigeria, so WAT is the answer for every date the user
/// sees or filters by. Nigeria observes **UTC+1 all year and has never used
/// daylight saving**, so a fixed offset is exact here; that is why this needs
/// no timezone database.
///
/// The rule: anything a user reads or filters by goes through this file.
/// Timestamps sent to the server stay UTC/ISO — this is about presentation and
/// day boundaries, not storage.
library;

import 'package:intl/intl.dart';

/// West Africa Time. Fixed, because Nigeria has no daylight saving.
const Duration kWatOffset = Duration(hours: 1);

/// A label for the zone, for anywhere the user should know which day is meant.
const String kWatLabel = 'WAT';

/// [dt] as wall-clock time in Lagos.
///
/// Converts through UTC, so the handset's own zone never enters into it.
DateTime toLagos(DateTime dt) => dt.toUtc().add(kWatOffset);

/// The current moment as wall-clock time in Lagos.
DateTime lagosNow() => DateTime.now().toUtc().add(kWatOffset);

/// Midnight in Lagos on the day [dt] falls on.
DateTime lagosDayStart(DateTime dt) {
  final l = toLagos(dt);
  return DateTime(l.year, l.month, l.day);
}

/// Today's date in Lagos, at midnight.
DateTime lagosToday() => lagosDayStart(DateTime.now());

/// The calendar day [dt] falls on in Lagos, as `yyyy-MM-dd`.
///
/// This is what date filters send to the server. Built from the Lagos wall
/// clock rather than `toIso8601String()`, which would use the handset's zone
/// and hand back the wrong day either side of midnight.
String lagosDateString(DateTime dt) {
  final l = toLagos(dt);
  return '${l.year.toString().padLeft(4, '0')}-'
      '${l.month.toString().padLeft(2, '0')}-'
      '${l.day.toString().padLeft(2, '0')}';
}

/// Whether [a] and [b] fall on the same Lagos day.
bool isSameLagosDay(DateTime a, DateTime b) =>
    lagosDayStart(a) == lagosDayStart(b);

final DateFormat _dayFmt = DateFormat('d MMM yyyy');
final DateFormat _dayTimeFmt = DateFormat('d MMM yyyy, HH:mm');
final DateFormat _timeFmt = DateFormat('HH:mm');

/// A date for display, in Lagos. `9 Sep 2026`.
String formatLagosDate(DateTime? dt) =>
    dt == null ? '—' : _dayFmt.format(toLagos(dt));

/// A date and time for display, in Lagos. `9 Sep 2026, 23:14`.
///
/// The zone is appended because the time of day is exactly where a reader in
/// another zone would otherwise draw the wrong conclusion.
String formatLagosDateTime(DateTime? dt) =>
    dt == null ? '—' : '${_dayTimeFmt.format(toLagos(dt))} $kWatLabel';

/// A time of day for display, in Lagos.
String formatLagosTime(DateTime? dt) =>
    dt == null ? '—' : '${_timeFmt.format(toLagos(dt))} $kWatLabel';
