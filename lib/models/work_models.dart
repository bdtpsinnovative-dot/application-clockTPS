class AttendanceRecord {
  const AttendanceRecord({
    required this.date,
    required this.status,
    this.checkInAt,
    this.checkOutAt,
  });

  factory AttendanceRecord.fromJson(Map<String, dynamic> json) {
    return AttendanceRecord(
      date: DateTime.parse(json['date'] as String),
      status: json['status'] as String? ?? 'no_record',
      checkInAt: _tryDate(json['check_in_at']),
      checkOutAt: _tryDate(json['check_out_at']),
    );
  }

  final DateTime date;
  final String status;
  final DateTime? checkInAt;
  final DateTime? checkOutAt;
}

class WorkRequestRecord {
  const WorkRequestRecord({
    required this.id,
    required this.type,
    required this.date,
    required this.reason,
    required this.status,
    required this.isOffsite,
    this.duration,
  });

  factory WorkRequestRecord.leave(Map<String, dynamic> json) {
    return WorkRequestRecord(
      id: json['id'] as String? ?? '',
      type: json['leave_type'] as String? ?? 'ใบลา',
      date: DateTime.parse(json['date'] as String),
      reason: json['reason'] as String? ?? '',
      status: json['status'] as String? ?? 'pending',
      duration: json['duration'] as String?,
      isOffsite: false,
    );
  }

  factory WorkRequestRecord.offsite(Map<String, dynamic> json) {
    return WorkRequestRecord(
      id: json['id'] as String? ?? '',
      type: 'ออกหน้างาน',
      date: DateTime.parse(json['date'] as String),
      reason: json['reason'] as String? ?? '',
      status: json['status'] as String? ?? 'pending',
      isOffsite: true,
    );
  }

  final String id;
  final String type;
  final DateTime date;
  final String reason;
  final String status;
  final String? duration;
  final bool isOffsite;
}

class HolidayRecord {
  const HolidayRecord({
    required this.id,
    required this.date,
    required this.name,
    required this.numDays,
  });

  factory HolidayRecord.fromJson(Map<String, dynamic> json) {
    return HolidayRecord(
      id: json['id'] as String? ?? '',
      date: DateTime.parse(json['date'] as String),
      name: json['name'] as String? ?? 'วันหยุด',
      numDays: json['num_days'] as int? ?? 1,
    );
  }

  final String id;
  final DateTime date;
  final String name;
  final int numDays;
}

DateTime? _tryDate(dynamic value) {
  if (value is! String || value.isEmpty) return null;
  return DateTime.tryParse(value)?.toLocal();
}
