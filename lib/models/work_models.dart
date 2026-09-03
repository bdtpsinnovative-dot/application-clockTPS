import 'dart:convert';

class AttendanceRecord {
  const AttendanceRecord({
    this.id = '',
    required this.date,
    required this.status,
    required this.userId,
    this.checkInAt,
    this.checkOutAt,
    this.workStartTime = '09:00',
    this.workEndTime = '18:00',
    this.isWorkday = true,
    this.isOffsite = false,
    this.lateMinutes = 0,
    this.locationName = '',
    this.checkOutLocationName = '',
  });

  factory AttendanceRecord.fromJson(Map<String, dynamic> json) {
    return AttendanceRecord(
      id: json['id'] as String? ?? '',
      date: DateTime.parse(json['date'] as String),
      status: json['status'] as String? ?? 'no_record',
      userId: json['user_id'] as String? ?? '',
      checkInAt: _tryDate(json['check_in_at']),
      checkOutAt: _tryDate(json['check_out_at']),
      workStartTime: json['work_start_time'] as String? ?? '09:00',
      workEndTime: json['work_end_time'] as String? ?? '18:00',
      isWorkday: json['is_workday'] as bool? ?? true,
      isOffsite: json['is_offsite'] as bool? ?? false,
      lateMinutes: (json['late_minutes'] as num?)?.toInt() ?? 0,
      locationName: json['location_name'] as String? ?? '',
      checkOutLocationName: json['check_out_location_name'] as String? ?? '',
    );
  }

  final String id;
  final DateTime date;
  final String status;
  final String userId;
  final DateTime? checkInAt;
  final DateTime? checkOutAt;
  final String workStartTime;
  final String workEndTime;
  final bool isWorkday;
  final bool isOffsite;
  final int lateMinutes;
  final String locationName;
  final String checkOutLocationName;
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
    return urlStr
        .split(',')
        .map((s) => s.trim())
        .where((s) => s.isNotEmpty)
        .toList();
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
    this.assignedByName = '',
    required this.title,
    required this.description,
    required this.dueDate,
    required this.status,
    this.assignedBy,
    this.brandId,
    this.categoryId,
    this.subItems = const [],
    required this.createdAt,
    this.cardTotal = 0,
    this.cardDone = 0,
    this.assigneeIds = const [],
    this.isStarred = false,
    this.priority = 'medium',
    this.deletedAt,
  });

  factory TaskRecord.fromJson(Map<String, dynamic> json) {
    final rawSubs = json['sub_items'];
    final subs = rawSubs is List
        ? rawSubs
              .map((e) => TaskSubItem.fromJson(e as Map<String, dynamic>))
              .toList()
        : <TaskSubItem>[];

    final rawAssignees = json['assignee_ids'];
    final assigneeList = rawAssignees is List
        ? rawAssignees.map((e) => e.toString()).toList()
        : <String>[];

    return TaskRecord(
      id: json['id'] as String? ?? '',
      assignedTo: json['assigned_to'] as String? ?? '',
      assignedToName: json['assigned_to_name'] as String? ?? '',
      assignedByName: json['assigned_by_name'] as String? ?? '',
      title: json['title'] as String? ?? '',
      description: json['description'] as String? ?? '',
      dueDate: json['due_date'] == null
          ? DateTime.now()
          : (DateTime.tryParse(json['due_date'].toString())?.toLocal() ??
              DateTime.now()),
      status: json['status'] as String? ?? 'pending',
      assignedBy: json['assigned_by'] as String?,
      brandId: json['brand_id'] as String?,
      categoryId: json['category_id'] as String?,
      subItems: subs,
      createdAt: json['created_at'] == null
          ? DateTime.now()
          : (DateTime.tryParse(json['created_at'].toString())?.toLocal() ??
              DateTime.now()),
      cardTotal: (json['card_total'] as num?)?.toInt() ?? 0,
      cardDone: (json['card_done'] as num?)?.toInt() ?? 0,
      assigneeIds: assigneeList,
      isStarred: json['is_starred'] as bool? ?? false,
      priority: json['priority'] as String? ?? 'medium',
      deletedAt: json['deleted_at'] == null
          ? null
          : DateTime.tryParse(json['deleted_at'].toString())?.toLocal(),
    );
  }

  final String id;
  final String assignedTo;
  final String assignedToName;
  final String assignedByName;
  final String title;
  final String description;
  final DateTime dueDate;
  final String status; // "pending" | "in_progress" | "completed"
  final String? assignedBy;
  final String? brandId;
  final String? categoryId;
  final List<TaskSubItem> subItems;
  final DateTime createdAt;
  final int cardTotal;
  final int cardDone;
  final List<String> assigneeIds;
  final bool isStarred;
  final String priority;
  final DateTime? deletedAt;
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
        ? rawVerifications
              .map(
                (e) => SubItemVerification.fromJson(e as Map<String, dynamic>),
              )
              .toList()
        : <SubItemVerification>[];

    return TaskSubItem(
      id: json['id'] as String? ?? '',
      taskId: json['task_id'] as String? ?? '',
      cardId: json['card_id'] as String?,
      title: json['title'] as String? ?? '',
      isDone: json['is_done'] as bool? ?? false,
      status: json['status'] as String? ?? 'pending',
      sortOrder: json['sort_order'] as int? ?? 0,
      startDate: json['start_date'] != null
          ? DateTime.tryParse(json['start_date'] as String)?.toLocal()
          : null,
      dueDate: json['due_date'] != null
          ? DateTime.tryParse(json['due_date'] as String)?.toLocal()
          : null,
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
      createdAt: json['created_at'] != null
          ? DateTime.parse(json['created_at'] as String).toLocal()
          : DateTime.now(),
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
    this.priority = 'medium',
    this.status = 'in_progress',
    this.adminComment = '',
    this.attachments = const [],
    this.assigneeIds = const [],
    this.assignees = const [],
    this.cards = const [],
    this.projectName,
  });

  factory TaskListRecord.fromJson(Map<String, dynamic> json) {
    final rawCards = json['cards'];
    final cardsList = rawCards is List
        ? rawCards
              .map((e) => TaskCardRecord.fromJson(e as Map<String, dynamic>))
              .toList()
        : <TaskCardRecord>[];
    final rawAttachments = json['attachments'];
    final attachments = rawAttachments is List
        ? rawAttachments
              .whereType<Map>()
              .map(
                (item) => TaskListAttachment.fromJson(
                  Map<String, dynamic>.from(item),
                ),
              )
              .toList()
        : <TaskListAttachment>[];
    final rawAssigneeIds = json['assignee_ids'];
    final rawAssignees = json['assignees'];

    return TaskListRecord(
      id: json['id'] as String? ?? '',
      taskId: json['task_id'] as String? ?? '',
      name: json['name'] as String? ?? '',
      description: json['description'] as String? ?? '',
      sortOrder: json['sort_order'] as int? ?? 0,
      startDate: json['start_date'] != null
          ? DateTime.tryParse(json['start_date'] as String)?.toLocal()
          : null,
      dueDate: json['due_date'] != null
          ? DateTime.tryParse(json['due_date'] as String)?.toLocal()
          : null,
      priority: json['priority'] as String? ?? 'medium',
      status: json['status'] as String? ?? 'in_progress',
      adminComment: json['admin_comment'] as String? ?? '',
      attachments: attachments,
      assigneeIds: rawAssigneeIds is List
          ? rawAssigneeIds.map((id) => id.toString()).toList()
          : const [],
      assignees: rawAssignees is List
          ? rawAssignees
                .whereType<Map>()
                .map(
                  (item) =>
                      UserSummary.fromJson(Map<String, dynamic>.from(item)),
                )
                .toList()
          : const [],
      cards: cardsList,
      projectName: json['project_name'] as String?,
    );
  }

  final String id;
  final String taskId;
  final String name;
  final String description;
  final int sortOrder;
  final DateTime? startDate;
  final DateTime? dueDate;
  final String priority;
  final String status;
  final String adminComment;
  final List<TaskListAttachment> attachments;
  final List<String> assigneeIds;
  final List<UserSummary> assignees;
  final String? projectName;

  /// Legacy task cards are retained for data compatibility but are no longer
  /// part of the employee-facing Project → Deliverable experience.
  final List<TaskCardRecord> cards;
}

class TaskListAttachment {
  const TaskListAttachment({
    required this.name,
    required this.url,
    required this.type,
  });

  factory TaskListAttachment.fromJson(Map<String, dynamic> json) {
    return TaskListAttachment(
      name: json['name'] as String? ?? '',
      url: json['url'] as String? ?? '',
      type: json['type'] as String? ?? 'file',
    );
  }

  final String name;
  final String url;
  final String type;

  Map<String, dynamic> toJson() => {'name': name, 'url': url, 'type': type};
}

class TaskCardRecord {
  TaskCardRecord({
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
    this.assigneeIds = const [],
    this.assignees = const [],
  }) : _attachments = attachments;

  factory TaskCardRecord.fromJson(Map<String, dynamic> json) {
    final rawSubs = json['sub_items'];
    final subs = rawSubs is List
        ? rawSubs
              .map((e) => TaskSubItem.fromJson(e as Map<String, dynamic>))
              .toList()
        : <TaskSubItem>[];

    final rawAttachments = json['attachments'];
    final attachments = rawAttachments is List
        ? rawAttachments
              .map((e) => CardAttachment.fromJson(e as Map<String, dynamic>))
              .toList()
        : <CardAttachment>[];

    final rawAssigneesJson = json['assignees'];
    final rawAssignees = rawAssigneesJson is List
        ? rawAssigneesJson
              .map((e) => UserSummary.fromJson(e as Map<String, dynamic>))
              .toList()
        : <UserSummary>[];

    final rawAssigneeIdsJson = json['assignee_ids'];
    final rawAssigneeIds = rawAssigneeIdsJson is List
        ? rawAssigneeIdsJson.map((e) => e.toString()).toList()
        : rawAssignees.map((e) => e.id).toList();

    return TaskCardRecord(
      id: json['id'] as String? ?? '',
      listId: json['list_id'] as String? ?? '',
      title: json['title'] as String? ?? '',
      description: json['description'] as String? ?? '',
      status: json['status'] as String? ?? 'pending',
      sortOrder: json['sort_order'] as int? ?? 0,
      priority: json['priority'] as String? ?? 'medium',
      startDate: json['start_date'] != null
          ? DateTime.tryParse(json['start_date'].toString())?.toLocal()
          : null,
      dueDate: json['due_date'] != null
          ? DateTime.tryParse(json['due_date'].toString())?.toLocal()
          : null,
      subItems: subs,
      attachments: attachments,
      adminComment: json['admin_comment'] as String?,
      assigneeIds: rawAssigneeIds,
      assignees: rawAssignees,
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
  List<String> assigneeIds;
  List<UserSummary> assignees;

  List<CardAttachment> get attachments => _attachments ?? const [];
}

/// A lightweight representation of a user for cards/comments
class UserSummary {
  const UserSummary({
    required this.id,
    required this.firstName,
    required this.lastName,
    required this.position,
    this.nickname,
    this.avatarUrl,
  });

  factory UserSummary.fromJson(Map<String, dynamic> json) {
    return UserSummary(
      id: json['id'] as String? ?? '',
      firstName: json['first_name'] as String? ?? '',
      lastName: json['last_name'] as String? ?? '',
      position: json['position'] as String? ?? '',
      nickname: json['nickname'] as String?,
      avatarUrl: json['avatar_url'] as String?,
    );
  }

  final String id;
  final String firstName;
  final String lastName;
  final String position;
  final String? nickname;
  final String? avatarUrl;

  String get displayName {
    if (nickname != null && nickname!.trim().isNotEmpty) {
      return nickname!.trim();
    }
    return firstName;
  }

  String get fullName => '$firstName $lastName';

  String? get resolvedAvatarUrl {
    if (avatarUrl == null || avatarUrl!.trim().isEmpty) return null;
    final url = avatarUrl!.trim();
    if (url.startsWith('r2://')) {
      return url.replaceFirst(
        'r2://',
        'https://pub-2a877f7cc07b481ca09dec82cb240465.r2.dev/',
      );
    }
    return url;
  }
}

/// A comment or immutable activity item attached to a project deliverable.
class TaskEventRecord {
  const TaskEventRecord({
    required this.id,
    required this.taskId,
    required this.userId,
    required this.eventType,
    required this.action,
    required this.content,
    required this.createdAt,
    this.listId,
    this.userFirstName = '',
    this.userLastName = '',
    this.userAvatarUrl,
  });

  factory TaskEventRecord.fromJson(Map<String, dynamic> json) {
    return TaskEventRecord(
      id: json['id']?.toString() ?? '',
      taskId: json['task_id']?.toString() ?? '',
      listId: json['list_id']?.toString(),
      userId: json['user_id']?.toString() ?? '',
      eventType: json['event_type'] as String? ?? 'system',
      action: json['action'] as String? ?? '',
      content: json['content'] as String? ?? '',
      createdAt:
          DateTime.tryParse(json['created_at']?.toString() ?? '')?.toLocal() ??
          DateTime.now(),
      userFirstName: json['user_first_name'] as String? ?? '',
      userLastName: json['user_last_name'] as String? ?? '',
      userAvatarUrl: json['user_avatar_url'] as String?,
    );
  }

  final String id;
  final String taskId;
  final String? listId;
  final String userId;
  final String eventType;
  final String action;
  final String content;
  final DateTime createdAt;
  final String userFirstName;
  final String userLastName;
  final String? userAvatarUrl;

  String get userFullName {
    final name = '$userFirstName $userLastName'.trim();
    return name.isEmpty ? 'ผู้ใช้' : name;
  }
}

/// A rich-text comment on a task card
class CardComment {
  const CardComment({
    required this.id,
    required this.cardId,
    required this.authorId,
    required this.contentDelta,
    required this.plainText,
    required this.isEdited,
    required this.createdAt,
    required this.updatedAt,
    this.author,
    this.mentionedUserIds = const [],
    this.attachments = const [],
  });

  factory CardComment.fromJson(Map<String, dynamic> json) {
    final rawMentions = json['mentioned_user_ids'];
    final mentions = rawMentions is List
        ? rawMentions.map((e) => e.toString()).toList()
        : <String>[];

    final rawAttachments = json['attachments'];
    final attachments = rawAttachments is List
        ? rawAttachments
              .map((e) => CommentAttachment.fromJson(e as Map<String, dynamic>))
              .toList()
        : <CommentAttachment>[];

    return CardComment(
      id: json['id'] as String? ?? '',
      cardId: json['card_id'] as String? ?? '',
      authorId: json['author_id'] as String? ?? '',
      contentDelta: json['content_delta'], // Passed directly for Quill
      plainText: json['plain_text'] as String? ?? '',
      isEdited: json['is_edited'] as bool? ?? false,
      createdAt: json['created_at'] != null
          ? DateTime.parse(json['created_at'].toString()).toLocal()
          : DateTime.now(),
      updatedAt: json['updated_at'] != null
          ? DateTime.parse(json['updated_at'].toString()).toLocal()
          : DateTime.now(),
      author: json['author'] != null
          ? UserSummary.fromJson(json['author'] as Map<String, dynamic>)
          : null,
      mentionedUserIds: mentions,
      attachments: attachments,
    );
  }

  final String id;
  final String cardId;
  final String authorId;
  final dynamic contentDelta; // JSON representation of Quill Delta
  final String plainText;
  final bool isEdited;
  final DateTime createdAt;
  final DateTime updatedAt;

  // Joined fields
  final UserSummary? author;
  final List<String> mentionedUserIds;
  final List<CommentAttachment> attachments;
}

/// An attachment specifically inside a comment
class CommentAttachment {
  const CommentAttachment({
    required this.id,
    required this.commentId,
    required this.url,
    required this.name,
    required this.type,
    this.sizeBytes,
    required this.createdAt,
  });

  factory CommentAttachment.fromJson(Map<String, dynamic> json) {
    return CommentAttachment(
      id: json['id'] as String? ?? '',
      commentId: json['comment_id'] as String? ?? '',
      url: json['url'] as String? ?? '',
      name: json['name'] as String? ?? '',
      type: json['type'] as String? ?? 'file',
      sizeBytes: json['size_bytes'] != null
          ? int.tryParse(json['size_bytes'].toString())
          : null,
      createdAt: json['created_at'] != null
          ? DateTime.parse(json['created_at'].toString()).toLocal()
          : DateTime.now(),
    );
  }

  final String id;
  final String commentId;
  final String url;
  final String name;
  final String type; // "image" | "file"
  final int? sizeBytes;
  final DateTime createdAt;
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
          ? DateTime.tryParse(json['created_at'].toString())?.toLocal() ??
                DateTime.now()
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

class BrandRecord {
  const BrandRecord({
    required this.id,
    required this.name,
    this.responsibleUserIds = const [],
    this.responsibilities = const [],
    this.hasTypedResponsibilities = false,
  });

  factory BrandRecord.fromJson(Map<String, dynamic> json) {
    final typedResponsibilities = (json['responsibilities'] as List? ?? [])
        .whereType<Map>()
        .map(
          (item) => BrandResponsibilityRecord.fromJson(
            Map<String, dynamic>.from(item),
          ),
        )
        .where((item) => item.userId.isNotEmpty)
        .toList(growable: false);
    return BrandRecord(
      id: json['id'] as String? ?? '',
      name: json['name'] as String? ?? '',
      responsibleUserIds: (json['responsible_user_ids'] as List? ?? [])
          .map((item) => item.toString())
          .where((id) => id.isNotEmpty)
          .toList(growable: false),
      responsibilities: typedResponsibilities,
      hasTypedResponsibilities: json['responsibilities'] is List,
    );
  }

  final String id;
  final String name;
  final List<String> responsibleUserIds;
  final List<BrandResponsibilityRecord> responsibilities;
  final bool hasTypedResponsibilities;
}

class BrandResponsibilityRecord {
  const BrandResponsibilityRecord({required this.userId, required this.type});

  factory BrandResponsibilityRecord.fromJson(Map<String, dynamic> json) {
    return BrandResponsibilityRecord(
      userId: json['user_id'] as String? ?? '',
      type: json['responsibility_type'] as String? ?? 'bd',
    );
  }

  final String userId;
  final String type;
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
    this.attendanceId = '',
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
    this.workStartTime = '09:00',
    this.workEndTime = '18:00',
    this.lateMinutes = 0,
    this.locationName = '',
    this.checkOutLocationName = '',
    this.isOffsite = false,
  });

  factory AdminHistoryRecord.fromJson(Map<String, dynamic> json) {
    return AdminHistoryRecord(
      attendanceId: json['attendance_id'] as String? ?? '',
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
      workStartTime: json['work_start_time'] as String? ?? '09:00',
      workEndTime: json['work_end_time'] as String? ?? '18:00',
      lateMinutes: (json['late_minutes'] as num?)?.toInt() ?? 0,
      locationName: json['location_name'] as String? ?? '',
      checkOutLocationName: json['check_out_location_name'] as String? ?? '',
      isOffsite: json['is_offsite'] as bool? ?? false,
    );
  }

  final String attendanceId;
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
  final String workStartTime;
  final String workEndTime;
  final int lateMinutes;
  final String locationName;
  final String checkOutLocationName;
  final bool isOffsite;
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
