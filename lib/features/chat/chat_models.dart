import 'dart:convert';
import 'package:flutter/material.dart';

class ChatBrandInfo {
  final String slug;
  final String label;
  final String shortLabel;
  final int colorValue;
  final String logoUrl;

  const ChatBrandInfo({
    required this.slug,
    required this.label,
    required this.shortLabel,
    required this.colorValue,
    required this.logoUrl,
  });

  Color get color => Color(colorValue);
}

const Map<String, ChatBrandInfo> kBrandPresets = {
  'terrahome': ChatBrandInfo(
    slug: 'terrahome',
    label: 'Terra Home Studio',
    shortLabel: 'TERRA',
    colorValue: 0xFFB45309,
    logoUrl:
        'https://profile.line-scdn.net/0hoZkjOQ3BMHVWEywMY05PImpWPhghPTY9LnJ6RCMQZ0MsdCQhOn0qGiAbZkV5IXcrPyAqFyBDPEMv',
  ),
  'zenslab': ChatBrandInfo(
    slug: 'zenslab',
    label: 'Zenslab by Woodden',
    shortLabel: 'ZENSLAB',
    colorValue: 0xFF065F46,
    logoUrl:
        'https://profile.line-scdn.net/0hUu_m0PZxClpiFBaHej91DV5RBDcVOgwSGiJHNUcSXTpMLE4MVnIVOBUTXD8cdh4EX3VHbxcdVThK',
  ),
  'emberandash': ChatBrandInfo(
    slug: 'emberandash',
    label: 'Ember and Ash',
    shortLabel: 'EMBER & ASH',
    colorValue: 0xFF9A3412,
    logoUrl:
        'https://profile.line-scdn.net/0ht3VuV_-DKxxrDDUyTHFUS1dJJXEcIi1UEz0xLh1YcCtONGUYVW8xLkZfdXhDaGtDVz5gKhsLJi5C',
  ),
  'wallcraft': ChatBrandInfo(
    slug: 'wallcraft',
    label: 'Wallcraft Thailand',
    shortLabel: 'WALLCRAFT',
    colorValue: 0xFF1E3A8A,
    logoUrl:
        'https://profile.line-scdn.net/0hZi1HvNgdBUYMMRpItjd6ETB0Cyt7HwMOdFMfcigwWXElAkBHZFRCJHo2CyF0AkESMwBCJytiCSRy',
  ),
};

ChatBrandInfo getBrandInfo(String? brandSlug) {
  final slug = (brandSlug ?? 'terrahome').toLowerCase().trim();
  if (kBrandPresets.containsKey(slug)) {
    return kBrandPresets[slug]!;
  }
  return ChatBrandInfo(
    slug: slug,
    label: slug.toUpperCase(),
    shortLabel: slug.toUpperCase(),
    colorValue: 0xFF475569,
    logoUrl: '',
  );
}

const List<String> kQuickReplies = [
  'สวัสดีครับ ยินดีให้บริการครับ มีอะไรให้เราช่วยดูแลวันนี้ครับ?',
  'ขออภัยที่ตอบกลับล่าช้าครับ ทางเรากำลังตรวจสอบข้อมูลให้อยู่นะครับ',
  'ขออนุญาตสอบถามข้อมูลเพิ่มเติม เพื่อประสานงานให้ฝ่ายที่เกี่ยวข้องครับ',
  'สินค้าชิ้นนี้มีพร้อมส่งครับ จัดส่งได้ภายใน 1-2 วันทำการครับ',
  'ขอบคุณที่ติดต่อสอบถามเข้ามาครับ หากมีข้อสงสัยเพิ่มเติมสอบถามได้ตลอดเวลานะครับ',
];

class ChatAgentUser {
  final String id;
  final String firstName;
  final String lastName;
  final String nickname;
  final String? avatarUrl;
  final String role;
  final String department;

  ChatAgentUser({
    required this.id,
    required this.firstName,
    required this.lastName,
    required this.nickname,
    this.avatarUrl,
    required this.role,
    required this.department,
  });

  factory ChatAgentUser.fromJson(Map<String, dynamic> json) {
    return ChatAgentUser(
      id: json['id']?.toString() ?? '',
      firstName: json['first_name'] as String? ?? '',
      lastName: json['last_name'] as String? ?? '',
      nickname: json['nickname'] as String? ?? '',
      avatarUrl: json['avatar_url'] as String?,
      role: json['role'] as String? ?? 'employee',
      department: json['department'] as String? ?? '',
    );
  }

  String get displayName {
    if (nickname.trim().isNotEmpty) return nickname.trim();
    if (firstName.trim().isNotEmpty) return firstName.trim();
    return id.substring(0, 6);
  }

  String get fullName {
    final name = '$firstName $lastName'.trim();
    if (name.isEmpty) return displayName;
    if (nickname.trim().isNotEmpty) return '$name ($nickname)';
    return name;
  }
}

class ChatCareGroup {
  final String id;
  final String name;
  final List<String> agentIds;
  final List<String> customerIds;

  ChatCareGroup({
    required this.id,
    required this.name,
    required this.agentIds,
    this.customerIds = const [],
  });

  factory ChatCareGroup.fromJson(Map<String, dynamic> json) {
    List<String> aIds = [];
    if (json['agent_ids'] is List) {
      aIds = (json['agent_ids'] as List).map((e) => e.toString()).toList();
    }
    List<String> cIds = [];
    if (json['customer_ids'] is List) {
      cIds = (json['customer_ids'] as List).map((e) => e.toString()).toList();
    }

    return ChatCareGroup(
      id: json['id']?.toString() ?? '',
      name: json['name'] as String? ?? 'กลุ่มแชท',
      agentIds: aIds,
      customerIds: cIds,
    );
  }
}

class ChatConversation {
  final String id;
  final String platform; // line, facebook, instagram
  final String brand; // terrahome, zenslab, wallcraft, emberandash
  final String customerName;
  final String? customerAvatar;
  final String? externalUserId;
  final String? assignedTo;
  final String? assignedToName;
  final int unreadCount;
  final String? lastMessageText;
  final DateTime? lastMessageAt;
  final String status; // active, resolved
  final Map<String, dynamic> metadata;

  ChatConversation({
    required this.id,
    required this.platform,
    required this.brand,
    required this.customerName,
    this.customerAvatar,
    this.externalUserId,
    this.assignedTo,
    this.assignedToName,
    this.unreadCount = 0,
    this.lastMessageText,
    this.lastMessageAt,
    this.status = 'active',
    this.metadata = const {},
  });

  factory ChatConversation.fromJson(Map<String, dynamic> json) {
    Map<String, dynamic> meta = {};
    if (json['metadata'] is Map) {
      meta = Map<String, dynamic>.from(json['metadata'] as Map);
    } else if (json['metadata'] is String) {
      try {
        meta = Map<String, dynamic>.from(jsonDecode(json['metadata']) as Map);
      } catch (_) {}
    }

    DateTime? lastMsgAt;
    if (json['last_message_at'] != null) {
      lastMsgAt = DateTime.tryParse(json['last_message_at'].toString())?.toLocal();
    }

    return ChatConversation(
      id: json['id']?.toString() ?? '',
      platform: (json['platform'] as String? ?? 'line').toLowerCase(),
      brand: (json['brand'] as String? ?? 'terrahome').toLowerCase(),
      customerName: json['customer_name'] as String? ?? 'ลูกค้า',
      customerAvatar: json['customer_avatar'] as String?,
      externalUserId: (json['platform_user_id'] ?? json['external_user_id']) as String?,
      assignedTo: json['assigned_to'] as String?,
      assignedToName: (json['assigned_name'] ?? json['assigned_to_name']) as String?,
      unreadCount: (json['unread_count'] as num?)?.toInt() ?? 0,
      lastMessageText: (json['last_message'] ?? json['last_message_text']) as String?,
      lastMessageAt: lastMsgAt,
      status: (json['status'] as String? ?? 'active').toLowerCase(),
      metadata: meta,
    );
  }

  ChatConversation copyWith({
    String? customerName,
    String? assignedTo,
    String? assignedToName,
    int? unreadCount,
    String? lastMessageText,
    DateTime? lastMessageAt,
    String? status,
    Map<String, dynamic>? metadata,
  }) {
    return ChatConversation(
      id: id,
      platform: platform,
      brand: brand,
      customerName: customerName ?? this.customerName,
      customerAvatar: customerAvatar,
      externalUserId: externalUserId,
      assignedTo: assignedTo ?? this.assignedTo,
      assignedToName: assignedToName ?? this.assignedToName,
      unreadCount: unreadCount ?? this.unreadCount,
      lastMessageText: lastMessageText ?? this.lastMessageText,
      lastMessageAt: lastMessageAt ?? this.lastMessageAt,
      status: status ?? this.status,
      metadata: metadata ?? this.metadata,
    );
  }

  bool get isActive => status == 'active';
  bool get isResolved => status == 'resolved';

  bool get isAssigned =>
      (assignedTo != null && assignedTo!.isNotEmpty) ||
      (metadata['assigned_agent_ids'] is List && (metadata['assigned_agent_ids'] as List).isNotEmpty) ||
      (metadata['assigned_group_id'] != null && metadata['assigned_group_id'].toString().isNotEmpty);

  List<String> get assignedAgentIds {
    final raw = metadata['assigned_agent_ids'];
    if (raw is List) {
      return raw.map((e) => e.toString()).toList();
    }
    if (assignedTo != null && assignedTo!.isNotEmpty) {
      return [assignedTo!];
    }
    return [];
  }

  String? get assignedGroupId => metadata['assigned_group_id']?.toString();
  String? get assignedGroupName => metadata['assigned_group_name'] as String?;
}

class ChatMessage {
  final String id;
  final String conversationId;
  final String senderType; // customer, agent, bot, system
  final String? senderId;
  final String? senderName;
  final String? senderAvatar;
  final String messageType; // text, image, sticker, file
  final String content;
  final String? mediaUrl;
  final DateTime createdAt;
  final Map<String, dynamic> metadata;

  ChatMessage({
    required this.id,
    required this.conversationId,
    required this.senderType,
    this.senderId,
    this.senderName,
    this.senderAvatar,
    this.messageType = 'text',
    required this.content,
    this.mediaUrl,
    required this.createdAt,
    this.metadata = const {},
  });

  factory ChatMessage.fromJson(Map<String, dynamic> json) {
    Map<String, dynamic> meta = {};
    if (json['metadata'] is Map) {
      meta = Map<String, dynamic>.from(json['metadata'] as Map);
    } else if (json['metadata'] is String) {
      try {
        meta = Map<String, dynamic>.from(jsonDecode(json['metadata']) as Map);
      } catch (_) {}
    }

    DateTime created = DateTime.now();
    if (json['created_at'] != null) {
      created = DateTime.tryParse(json['created_at'].toString())?.toLocal() ?? DateTime.now();
    }

    String? media = (json['media_url'] ?? json['image_url']) as String?;
    if ((media == null || media.isEmpty) && meta['media_url'] != null) {
      media = meta['media_url']?.toString();
    }
    if ((media == null || media.isEmpty) && meta['url'] != null) {
      media = meta['url']?.toString();
    }

    return ChatMessage(
      id: json['id']?.toString() ?? '',
      conversationId: json['conversation_id']?.toString() ?? '',
      senderType: (json['sender_type'] as String? ?? 'customer').toLowerCase(),
      senderId: json['sender_id'] as String?,
      senderName: json['sender_name'] as String?,
      senderAvatar: json['sender_avatar'] as String?,
      messageType: (json['message_type'] as String? ?? 'text').toLowerCase(),
      content: json['content'] as String? ?? '',
      mediaUrl: media,
      createdAt: created,
      metadata: meta,
    );
  }

  bool get isCustomer => senderType == 'customer';
  bool get isAgent => senderType == 'agent';
  bool get isSystem => senderType == 'system' || senderType == 'bot';
  bool get isSticker => messageType == 'sticker';
  bool get isImage {
    if (messageType == 'image' || messageType == 'sticker') return true;
    final m = (mediaUrl ?? '').toLowerCase();
    if (m.isNotEmpty) {
      if (m.contains('.jpg') ||
          m.contains('.jpeg') ||
          m.contains('.png') ||
          m.contains('.webp') ||
          m.contains('.gif') ||
          m.contains('scontent') ||
          m.contains('fbcdn') ||
          m.contains('line.me')) {
        return true;
      }
    }
    if (content.startsWith('📷')) return true;
    return false;
  }

  bool get isFile => messageType == 'file' && !isImage;
}

class ChatChannel {
  final String id;
  final String brandSlug;
  final String brandName;
  final String platform;
  final String channelName;
  final bool isActive;
  final String? brandLogo;
  final String? outboundWebhookUrl;

  ChatChannel({
    required this.id,
    required this.brandSlug,
    required this.brandName,
    required this.platform,
    required this.channelName,
    this.isActive = true,
    this.brandLogo,
    this.outboundWebhookUrl,
  });

  factory ChatChannel.fromJson(Map<String, dynamic> json) {
    return ChatChannel(
      id: json['id']?.toString() ?? '',
      brandSlug: json['brand_slug'] as String? ?? '',
      brandName: json['brand_name'] as String? ?? '',
      platform: json['platform'] as String? ?? 'line',
      channelName: json['channel_name'] as String? ?? '',
      isActive: json['is_active'] as bool? ?? true,
      brandLogo: json['brand_logo'] as String?,
      outboundWebhookUrl: json['outbound_webhook_url'] as String?,
    );
  }
}
