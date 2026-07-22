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
    this.assignedToName = '',
    required this.title,
    required this.description,
    required this.dueDate,
    required this.status,
    this.assignedBy,
    this.assignedByName,
    this.brandId,
    this.categoryId,
    this.subItems = const [],
    required this.createdAt,
    this.cardTotal = 0,
    this.cardDone = 0,
    this.assigneeIds = const [],
  });

  factory TaskRecord.fromJson(Map<String, dynamic> json) {
    final rawSubs = json['sub_items'];
    final subs = rawSubs is List
        ? rawSubs.map((e) => TaskSubItem.fromJson(e as Map<String, dynamic>)).toList()
        : <TaskSubItem>[];
    
    final rawAssignees = json['assignee_ids'];
    final assigneeList = rawAssignees is List
        ? rawAssignees.map((e) => e.toString()).toList()
        : <String>[];

    return TaskRecord(
      id: json['id'] as String? ?? '',
      assignedTo: json['assigned_to'] as String? ?? '',
      assignedToName: json['assigned_to_name'] as String? ?? '',
      title: json['title'] as String? ?? '',
      description: json['description'] as String? ?? '',
      dueDate: DateTime.parse(json['due_date'] as String),
      status: json['status'] as String? ?? 'pending',
      assignedBy: json['assigned_by'] as String?,
      assignedByName: json['assigned_by_name'] as String?,
      brandId: json['brand_id'] as String?,
      categoryId: json['category_id'] as String?,
      subItems: subs,
      createdAt: DateTime.parse(json['created_at'] as String).toLocal(),
      cardTotal: (json['card_total'] as num?)?.toInt() ?? 0,
      cardDone: (json['card_done'] as num?)?.toInt() ?? 0,
      assigneeIds: assigneeList,
    );
  }

  final String id;
  final String assignedTo;
  final String assignedToName;
  final String title;
  final String description;
  final DateTime dueDate;
  final String status; // "pending" | "in_progress" | "completed"
  final String? assignedBy;
  final String? assignedByName;
  final String? brandId;
  final String? categoryId;
  final List<TaskSubItem> subItems;
  final DateTime createdAt;
  final int cardTotal;
  final int cardDone;
  final List<String> assigneeIds;
}

class TaskSubItem {
  const TaskSubItem({
    required this.id,
    required this.taskId,
    this.cardId,
    required this.title,
    required this.isDone,
    required this.status,
    required this.sortOrder,
    this.startDate,
    this.dueDate,
    this.linkUrl,
    this.attachmentUrl,
    this.verificationNotes,
    this.adminComment,
    this.verifications = const [],
  });

  factory TaskSubItem.fromJson(Map<String, dynamic> json) {
    final rawVerifications = json['verifications'];
    final verificationList = rawVerifications is List
        ? rawVerifications.map((e) => SubItemVerification.fromJson(e as Map<String, dynamic>)).toList()
        : <SubItemVerification>[];

    return TaskSubItem(
      id: json['id'] as String? ?? '',
      taskId: json['task_id'] as String? ?? '',
      cardId: json['card_id'] as String?,
      title: json['title'] as String? ?? '',
      isDone: json['is_done'] as bool? ?? false,
      status: json['status'] as String? ?? 'pending',
      sortOrder: json['sort_order'] as int? ?? 0,
      startDate: json['start_date'] != null ? DateTime.tryParse(json['start_date'] as String)?.toLocal() : null,
      dueDate: json['due_date'] != null ? DateTime.tryParse(json['due_date'] as String)?.toLocal() : null,
      linkUrl: json['link_url'] as String?,
      attachmentUrl: json['attachment_url'] as String?,
      verificationNotes: json['verification_notes'] as String?,
      adminComment: json['admin_comment'] as String?,
      verifications: verificationList,
    );
  }

  final String id;
  final String taskId;
  final String? cardId;
  final String title;
  final bool isDone;
  final String status;
  final int sortOrder;
  final DateTime? startDate;
  final DateTime? dueDate;
  final String? linkUrl;
  final String? attachmentUrl;
  final String? verificationNotes;
  final String? adminComment;
  final List<SubItemVerification> verifications;

  TaskSubItem copyWith({
    String? id,
    String? taskId,
    String? cardId,
    String? title,
    bool? isDone,
    String? status,
    int? sortOrder,
    DateTime? startDate,
    DateTime? dueDate,
    String? linkUrl,
    String? attachmentUrl,
    String? verificationNotes,
    String? adminComment,
    List<SubItemVerification>? verifications,
  }) {
    return TaskSubItem(
      id: id ?? this.id,
      taskId: taskId ?? this.taskId,
      cardId: cardId ?? this.cardId,
      title: title ?? this.title,
      isDone: isDone ?? this.isDone,
      status: status ?? this.status,
      sortOrder: sortOrder ?? this.sortOrder,
      startDate: startDate ?? this.startDate,
      dueDate: dueDate ?? this.dueDate,
      linkUrl: linkUrl ?? this.linkUrl,
      attachmentUrl: attachmentUrl ?? this.attachmentUrl,
      verificationNotes: verificationNotes ?? this.verificationNotes,
      adminComment: adminComment ?? this.adminComment,
      verifications: verifications ?? this.verifications,
    );
  }
}

class SubItemVerification {
  const SubItemVerification({
    required this.id,
    required this.subItemId,
    this.verifiedBy,
    required this.verifierName,
    required this.round,
    required this.status,
    this.notes,
    required this.createdAt,
  });

  factory SubItemVerification.fromJson(Map<String, dynamic> json) {
    return SubItemVerification(
      id: json['id'] as String? ?? '',
      subItemId: json['sub_item_id'] as String? ?? '',
      verifiedBy: json['verified_by'] as String?,
      verifierName: json['verifier_name'] as String? ?? '',
      round: json['round'] as int? ?? 0,
      status: json['status'] as String? ?? '',
      notes: json['notes'] as String?,
      createdAt: json['created_at'] != null ? DateTime.parse(json['created_at'] as String).toLocal() : DateTime.now(),
    );
  }

  final String id;
  final String subItemId;
  final String? verifiedBy;
  final String verifierName;
  final int round;
  final String status; // "approved" | "rejected"
  final String? notes;
  final DateTime createdAt;
}

class TaskListRecord {
  const TaskListRecord({
    required this.id,
    required this.taskId,
    required this.name,
    this.description = '',
    required this.sortOrder,
    this.startDate,
    this.dueDate,
    this.cards = const [],
  });

  factory TaskListRecord.fromJson(Map<String, dynamic> json) {
    final rawCards = json['cards'];
    final cardsList = rawCards is List
        ? rawCards.map((e) => TaskCardRecord.fromJson(e as Map<String, dynamic>)).toList()
        : <TaskCardRecord>[];

    return TaskListRecord(
      id: json['id'] as String? ?? '',
      taskId: json['task_id'] as String? ?? '',
      name: json['name'] as String? ?? '',
      description: json['description'] as String? ?? '',
      sortOrder: json['sort_order'] as int? ?? 0,
      startDate: json['start_date'] != null ? DateTime.tryParse(json['start_date'] as String)?.toLocal() : null,
      dueDate: json['due_date'] != null ? DateTime.tryParse(json['due_date'] as String)?.toLocal() : null,
      cards: cardsList,
    );
  }

  final String id;
  final String taskId;
  final String name;
  final String description;
  final int sortOrder;
  final DateTime? startDate;
  final DateTime? dueDate;
  final List<TaskCardRecord> cards;
}

class TaskCardRecord {
  const TaskCardRecord({
    required this.id,
    required this.listId,
    required this.title,
    required this.description,
    required this.status,
    required this.sortOrder,
    this.priority = 'medium',
    this.startDate,
    this.dueDate,
    this.subItems = const [],
    List<CardAttachment>? attachments = const [],
    this.adminComment,
  }) : _attachments = attachments;

  factory TaskCardRecord.fromJson(Map<String, dynamic> json) {
    final rawSubs = json['sub_items'];
    final subs = rawSubs is List
        ? rawSubs.map((e) => TaskSubItem.fromJson(e as Map<String, dynamic>)).toList()
        : <TaskSubItem>[];

    final rawAttachments = json['attachments'];
    final attachments = rawAttachments is List
        ? rawAttachments.map((e) => CardAttachment.fromJson(e as Map<String, dynamic>)).toList()
        : <CardAttachment>[];

    return TaskCardRecord(
      id: json['id'] as String? ?? '',
      listId: json['list_id'] as String? ?? '',
      title: json['title'] as String? ?? '',
      description: json['description'] as String? ?? '',
      status: json['status'] as String? ?? 'pending',
      sortOrder: json['sort_order'] as int? ?? 0,
      priority: json['priority'] as String? ?? 'medium',
      startDate: json['start_date'] != null ? DateTime.tryParse(json['start_date'].toString())?.toLocal() : null,
      dueDate: json['due_date'] != null ? DateTime.tryParse(json['due_date'].toString())?.toLocal() : null,
      subItems: subs,
      attachments: attachments,
      adminComment: json['admin_comment'] as String?,
    );
  }

  final String id;
  final String listId;
  final String title;
  final String description;
  final String status; // "pending" | "in_progress" | "completed"
  final int sortOrder;
  final String priority; // "low" | "medium" | "high" | "urgent"
  final DateTime? startDate;
  final DateTime? dueDate;
  final List<TaskSubItem> subItems;
  final List<CardAttachment>? _attachments;
  final String? adminComment;
  List<CardAttachment> get attachments => _attachments ?? const [];
}

/// CardAttachment represents a file/image/link attached to a task card.
class CardAttachment {
  const CardAttachment({
    required this.id,
    required this.cardId,
    required this.url,
    required this.name,
    required this.type,
    required this.createdAt,
    this.createdBy,
  });

  factory CardAttachment.fromJson(Map<String, dynamic> json) {
    return CardAttachment(
      id: json['id'] as String? ?? '',
      cardId: json['card_id'] as String? ?? '',
      url: json['url'] as String? ?? '',
      name: json['name'] as String? ?? '',
      type: json['type'] as String? ?? 'file', // 'image' | 'file' | 'link'
      createdAt: json['created_at'] != null
          ? DateTime.tryParse(json['created_at'].toString())?.toLocal() ?? DateTime.now()
          : DateTime.now(),
      createdBy: json['created_by'] as String?,
    );
  }

  final String id;
  final String cardId;
  final String url;
  final String name;
  final String type; // 'image' | 'file' | 'link'
  final DateTime createdAt;
  final String? createdBy;
}

class TaskEvent {
  const TaskEvent({
    required this.id,
    required this.taskId,
    required this.userId,
    required this.eventType,
    required this.action,
    this.content,
    required this.createdAt,
    this.userFirstName,
    this.userLastName,
    this.userAvatarUrl,
  });

  factory TaskEvent.fromJson(Map<String, dynamic> json) {
    return TaskEvent(
      id: json['id'] as String? ?? '',
      taskId: json['task_id'] as String? ?? '',
      userId: json['user_id'] as String? ?? '',
      eventType: json['event_type'] as String? ?? '',
      action: json['action'] as String? ?? '',
      content: json['content'] as String?,
      createdAt: json['created_at'] != null 
          ? DateTime.tryParse(json['created_at'].toString())?.toLocal() ?? DateTime.now()
          : DateTime.now(),
      userFirstName: json['user_first_name'] as String?,
      userLastName: json['user_last_name'] as String?,
      userAvatarUrl: json['user_avatar_url'] as String?,
    );
  }

  final String id;
  final String taskId;
  final String userId;
  final String eventType;
  final String action;
  final String? content;
  final DateTime createdAt;
  final String? userFirstName;
  final String? userLastName;
  final String? userAvatarUrl;
}


class BrandRecord {
  const BrandRecord({required this.id, required this.name});

  factory BrandRecord.fromJson(Map<String, dynamic> json) {
    return BrandRecord(
      id: json['id'] as String? ?? '',
      name: json['name'] as String? ?? '',
    );
  }

  final String id;
  final String name;
}

class TaskCategoryRecord {
  const TaskCategoryRecord({required this.id, required this.name});

  factory TaskCategoryRecord.fromJson(Map<String, dynamic> json) {
    return TaskCategoryRecord(
      id: json['id'] as String? ?? '',
      name: json['name'] as String? ?? '',
    );
  }

  final String id;
  final String name;
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

class AttendanceSummary {
  const AttendanceSummary({
    required this.totalEmployees,
    required this.attendedToday,
    required this.lateToday,
  });

  factory AttendanceSummary.fromJson(Map<String, dynamic> json) {
    return AttendanceSummary(
      totalEmployees: json['total_employees'] as int? ?? 0,
      attendedToday: json['attended_today'] as int? ?? 0,
      lateToday: json['late_today'] as int? ?? 0,
    );
  }

  final int totalEmployees;
  final int attendedToday;
  final int lateToday;
}
