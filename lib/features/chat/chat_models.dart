import 'dart:convert';

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
      metadata: meta,
    );
  }

  bool get isAssigned => (assignedTo != null && assignedTo!.isNotEmpty) ||
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

  String? get assignedGroupName => metadata['assigned_group_name'] as String?;
}

class ChatMessage {
  final String id;
  final String conversationId;
  final String senderType; // customer, agent, bot, system
  final String? senderId;
  final String? senderName;
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

    return ChatMessage(
      id: json['id']?.toString() ?? '',
      conversationId: json['conversation_id']?.toString() ?? '',
      senderType: (json['sender_type'] as String? ?? 'customer').toLowerCase(),
      senderId: json['sender_id'] as String?,
      senderName: json['sender_name'] as String?,
      messageType: (json['message_type'] as String? ?? 'text').toLowerCase(),
      content: json['content'] as String? ?? '',
      mediaUrl: json['media_url'] as String?,
      createdAt: created,
      metadata: meta,
    );
  }

  bool get isCustomer => senderType == 'customer';
  bool get isAgent => senderType == 'agent';
  bool get isSystem => senderType == 'system' || senderType == 'bot';
  bool get isImage => messageType == 'image' || (mediaUrl != null && mediaUrl!.isNotEmpty);
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
