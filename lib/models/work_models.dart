import 'dart:convert';

class AttendanceRecord {
  const AttendanceRecord({
    required this.date,
    required this.status,
    required this.userId,
    this.checkInAt,
    this.checkOutAt,
  });

  factory AttendanceRecord.fromJson(Map<String, dynamic> json) {
    return AttendanceRecord(
      date: DateTime.parse(json['date'] as String),
      status: json['status'] as String? ?? 'no_record',
      userId: json['user_id'] as String? ?? '',
      checkInAt: _tryDate(json['check_in_at']),
      checkOutAt: _tryDate(json['check_out_at']),
    );
  }

  final DateTime date;
  final String status;
  final String userId;
  final DateTime? checkInAt;
  final DateTime? checkOutAt;
}

class WorkRequestRecord {
  const WorkRequestRecord({
    required this.id,
    required this.userId,
    required this.type,
    required this.date,
    required this.reason,
    required this.status,
    required this.isOffsite,
    this.duration,
    this.medicalCertUrl,
    this.swapDate,
  });

  factory WorkRequestRecord.leave(Map<String, dynamic> json) {
    DateTime? parsedSwapDate;
    if (json['swap_date'] != null && json['swap_date'] is String) {
      try {
        parsedSwapDate = DateTime.parse(json['swap_date'] as String);
      } catch (_) {}
    }
    return WorkRequestRecord(
      id: json['id'] as String? ?? '',
      userId: json['user_id'] as String? ?? '',
      type: json['leave_type'] as String? ?? 'ใบลา',
      date: DateTime.parse(json['date'] as String),
      reason: json['reason'] as String? ?? '',
      status: json['status'] as String? ?? 'pending',
      duration: json['duration'] as String?,
      isOffsite: false,
      medicalCertUrl: json['medical_cert_url'] as String?,
      swapDate: parsedSwapDate,
    );
  }

  factory WorkRequestRecord.offsite(Map<String, dynamic> json) {
    return WorkRequestRecord(
      id: json['id'] as String? ?? '',
      userId: json['user_id'] as String? ?? '',
      type: 'ออกหน้างาน',
      date: DateTime.parse(json['date'] as String),
      reason: json['reason'] as String? ?? '',
      status: json['status'] as String? ?? 'pending',
      isOffsite: true,
      medicalCertUrl: null,
      swapDate: null,
    );
  }

  final String id;
  final String userId;
  final String type;
  final DateTime date;
  final String reason;
  final String status;
  final String? duration;
  final bool isOffsite;
  final String? medicalCertUrl;
  final DateTime? swapDate;

  List<String> get attachments {
    if (medicalCertUrl == null || medicalCertUrl!.trim().isEmpty) return [];
    final urlStr = medicalCertUrl!.trim();
    if (urlStr.startsWith('[') && urlStr.endsWith(']')) {
      try {
        final decoded = jsonDecode(urlStr);
        if (decoded is List) {
          return decoded.map((e) => e.toString()).toList();
        }
      } catch (_) {}
    }
    return urlStr.split(',').map((s) => s.trim()).where((s) => s.isNotEmpty).toList();
  }
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

class LeaveBalanceRecord {
  const LeaveBalanceRecord({
    required this.leaveType,
    required this.quota,
    required this.used,
    required this.remaining,
  });

  factory LeaveBalanceRecord.fromJson(Map<String, dynamic> json) {
    return LeaveBalanceRecord(
      leaveType: json['leave_type'] as String? ?? '',
      quota: (json['quota'] as num? ?? 0).toDouble(),
      used: (json['used'] as num? ?? 0).toDouble(),
      remaining: (json['remaining'] as num? ?? 0).toDouble(),
    );
  }

  final String leaveType;
  final double quota;
  final double used;
  final double remaining;
}

class TaskRecord {
  const TaskRecord({
    required this.id,
    required this.assignedTo,
    required this.title,
    required this.description,
    required this.dueDate,
    required this.status,
    this.assignedBy,
    required this.createdAt,
  });

  factory TaskRecord.fromJson(Map<String, dynamic> json) {
    return TaskRecord(
      id: json['id'] as String? ?? '',
      assignedTo: json['assigned_to'] as String? ?? '',
      title: json['title'] as String? ?? '',
      description: json['description'] as String? ?? '',
      dueDate: DateTime.parse(json['due_date'] as String),
      status: json['status'] as String? ?? 'pending',
      assignedBy: json['assigned_by'] as String?,
      createdAt: DateTime.parse(json['created_at'] as String).toLocal(),
    );
  }

  final String id;
  final String assignedTo;
  final String title;
  final String description;
  final DateTime dueDate;
  final String status; // "pending" | "in_progress" | "completed"
  final String? assignedBy;
  final DateTime createdAt;
}

class AdminHistoryRecord {
  const AdminHistoryRecord({
    required this.date,
    required this.userName,
    required this.email,
    required this.department,
    required this.position,
    required this.status,
    required this.type,
    required this.reason,
    this.checkInAt,
    this.checkOutAt,
    required this.createdAt,
  });

  factory AdminHistoryRecord.fromJson(Map<String, dynamic> json) {
    return AdminHistoryRecord(
      date: DateTime.parse(json['date'] as String),
      userName: json['user_name'] as String? ?? '',
      email: json['email'] as String? ?? '',
      department: json['department'] as String? ?? '',
      position: json['position'] as String? ?? '',
      status: json['status'] as String? ?? '',
      type: json['type'] as String? ?? '',
      reason: json['reason'] as String? ?? '',
      checkInAt: _tryDate(json['check_in_at']),
      checkOutAt: _tryDate(json['check_out_at']),
      createdAt: DateTime.parse(json['created_at'] as String),
    );
  }

  final DateTime date;
  final String userName;
  final String email;
  final String department;
  final String position;
  final String status;
  final String type;
  final String reason;
  final DateTime? checkInAt;
  final DateTime? checkOutAt;
  final DateTime createdAt;
}
