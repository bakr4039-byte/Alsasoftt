class AttendanceEvent {
  final int id;
  final DateTime checkTime;
  final String checkType; // in | out
  final String source;

  AttendanceEvent({
    required this.id,
    required this.checkTime,
    required this.checkType,
    required this.source,
  });

  factory AttendanceEvent.fromJson(Map<String, dynamic> json) => AttendanceEvent(
        id: json['id'],
        checkTime: DateTime.parse(json['check_time']),
        checkType: json['check_type'],
        source: json['source'],
      );
}

class AttendanceStatusDay {
  final DateTime date;
  final String status;
  final int? minutesLate;
  final int? minutesEarlyLeave;

  AttendanceStatusDay({
    required this.date,
    required this.status,
    this.minutesLate,
    this.minutesEarlyLeave,
  });

  factory AttendanceStatusDay.fromJson(Map<String, dynamic> json) => AttendanceStatusDay(
        date: DateTime.parse(json['status_date']),
        status: json['status'],
        minutesLate: json['minutes_late'],
        minutesEarlyLeave: json['minutes_early_leave'],
      );
}
