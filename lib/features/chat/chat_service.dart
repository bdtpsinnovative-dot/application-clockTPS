import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import '../../models/app_user.dart';
import 'chat_models.dart';

class ChatService {
  ChatService._();
  static final ChatService instance = ChatService._();

  static const String _supabaseUrl = 'https://gshppxgvdrmbfcxsxeph.supabase.co';
  static const String _supabaseAnonKey =
      'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6ImdzaHBweGd2ZHJtYmZjeHN4ZXBoIiwicm9sZSI6ImFub24iLCJpYXQiOjE3OTIwMjQzODAsImV4cCI6MjEwNzYwMDM4MH0.lhpLOeb7oY0e-ZCIgSBgzHfPAgAzK8eqFgUPg9te8XM';
  static const String _outboundWebhookUrl =
      'https://bddevelopment.app.n8n.cloud/webhook/send-chat';

  Map<String, String> get _headers => {
        'apikey': _supabaseAnonKey,
        'Authorization': 'Bearer $_supabaseAnonKey',
        'Content-Type': 'application/json',
        'Prefer': 'return=representation',
      };

  /// Check whether the current user has permission to access Chat
  Future<bool> checkUserChatAccess(AppUser? user) async {
    if (user == null) return false;

    // 1. Admin or Manager role always allowed
    final role = user.role.toLowerCase();
    if (role == 'admin' || role == 'manager' || role == 'owner') {
      return true;
    }

    // 2. Sales / Marketing department or position
    final dept = user.department.toLowerCase();
    final pos = user.position.toLowerCase();
    if (dept.contains('sale') ||
        dept.contains('marketing') ||
        pos.contains('sale') ||
        pos.contains('ขาย')) {
      return true;
    }

    // 3. Query settings table for chat_access_users list
    try {
      final uri = Uri.parse(
          '$_supabaseUrl/rest/v1/settings?key=eq.chat_access_users&select=value');
      final res = await http.get(uri, headers: _headers);
      if (res.statusCode == 200) {
        final list = jsonDecode(res.body);
        if (list is List && list.isNotEmpty) {
          final rawVal = list[0]['value'];
          dynamic parsed = rawVal;
          if (rawVal is String) {
            try {
              parsed = jsonDecode(rawVal);
            } catch (_) {}
          }
          if (parsed is List) {
            final uid = user.id.toString();
            final hasMatch = parsed.any((item) {
              if (item is Map) {
                final uId = item['user_id']?.toString();
                final isEnabled = item['is_enabled'] != false;
                return uId == uid && isEnabled;
              }
              return false;
            });
            if (hasMatch) return true;
          }
        }
      }
    } catch (e) {
      debugPrint('Check chat access error: $e');
    }

    return false;
  }

  /// Get total unread conversations count for the bottom bar badge
  Future<int> fetchUnreadCount({String? currentUserId}) async {
    try {
      final uri = Uri.parse(
          '$_supabaseUrl/rest/v1/chat_conversations?select=unread_count&unread_count=gt.0');
      final res = await http.get(uri, headers: _headers);
      if (res.statusCode == 200) {
        final list = jsonDecode(res.body) as List;
        int total = 0;
        for (final item in list) {
          total += (item['unread_count'] as num?)?.toInt() ?? 0;
        }
        return total;
      }
    } catch (e) {
      debugPrint('Fetch unread count error: $e');
    }
    return 0;
  }

  /// Fetch conversations list
  Future<List<ChatConversation>> fetchConversations({
    String filter = 'all', // all, mine, unassigned
    String? brand,
    String? currentUserId,
    String? searchQuery,
  }) async {
    try {
      String query = '$_supabaseUrl/rest/v1/chat_conversations?select=*&order=last_message_at.desc.nullslast';
      if (brand != null && brand.isNotEmpty && brand != 'all') {
        query += '&brand=eq.$brand';
      }

      final uri = Uri.parse(query);
      final res = await http.get(uri, headers: _headers);

      if (res.statusCode == 200) {
        final list = jsonDecode(res.body) as List;
        List<ChatConversation> convs =
            list.map((item) => ChatConversation.fromJson(item as Map<String, dynamic>)).toList();

        // Client-side filtering for assign status & search query
        if (filter == 'mine' && currentUserId != null && currentUserId.isNotEmpty) {
          convs = convs.where((c) {
            return c.assignedTo == currentUserId || c.assignedAgentIds.contains(currentUserId);
          }).toList();
        } else if (filter == 'unassigned') {
          convs = convs.where((c) => !c.isAssigned).toList();
        }

        if (searchQuery != null && searchQuery.trim().isNotEmpty) {
          final q = searchQuery.trim().toLowerCase();
          convs = convs.where((c) {
            return c.customerName.toLowerCase().contains(q) ||
                (c.lastMessageText ?? '').toLowerCase().contains(q) ||
                c.brand.toLowerCase().contains(q);
          }).toList();
        }

        return convs;
      }
    } catch (e) {
      debugPrint('Error fetching conversations: $e');
    }
    return [];
  }

  /// Fetch messages for a specific conversation
  Future<List<ChatMessage>> fetchMessages(String convId) async {
    try {
      final uri = Uri.parse(
          '$_supabaseUrl/rest/v1/chat_messages?conversation_id=eq.$convId&order=created_at.asc');
      final res = await http.get(uri, headers: _headers);

      if (res.statusCode == 200) {
        final list = jsonDecode(res.body) as List;
        return list
            .map((item) => ChatMessage.fromJson(item as Map<String, dynamic>))
            .toList();
      }
    } catch (e) {
      debugPrint('Error fetching messages: $e');
    }
    return [];
  }

  /// Mark conversation as read
  Future<void> markAsRead(String convId) async {
    try {
      final uri = Uri.parse('$_supabaseUrl/rest/v1/chat_conversations?id=eq.$convId');
      await http.patch(
        uri,
        headers: _headers,
        body: jsonEncode({'unread_count': 0}),
      );
    } catch (e) {
      debugPrint('Error marking as read: $e');
    }
  }

  /// Send message to conversation
  Future<ChatMessage?> sendMessage({
    required ChatConversation conversation,
    required String content,
    required String senderId,
    required String senderName,
    String? senderAvatar,
    String? mediaUrl,
    String messageType = 'text',
  }) async {
    try {
      // 1. Insert into chat_messages
      final insertUri = Uri.parse('$_supabaseUrl/rest/v1/chat_messages');
      final msgBody = {
        'conversation_id': conversation.id,
        'sender_type': 'agent',
        'sender_id': senderId,
        'sender_name': senderName,
        'sender_avatar': senderAvatar ?? '',
        'message_type': messageType,
        'content': content,
        'media_url': mediaUrl ?? '',
        'status': 'sent',
        'created_at': DateTime.now().toUtc().toIso8601String(),
        'metadata': {
          'sender_id': senderId,
          'sender_name': senderName,
        },
      };

      final insertRes = await http.post(
        insertUri,
        headers: _headers,
        body: jsonEncode(msgBody),
      );

      ChatMessage? createdMsg;
      if (insertRes.statusCode == 201 || insertRes.statusCode == 200) {
        final data = jsonDecode(insertRes.body);
        if (data is List && data.isNotEmpty) {
          createdMsg = ChatMessage.fromJson(data[0]);
        }
      }

      // 2. Update chat_conversations last_message & last_message_at
      final convUri =
          Uri.parse('$_supabaseUrl/rest/v1/chat_conversations?id=eq.${conversation.id}');
      final convUpdate = {
        'last_message': content,
        'last_message_at': DateTime.now().toUtc().toIso8601String(),
        'status': 'active',
      };
      // Auto-assign to responding agent if unassigned
      if (!conversation.isAssigned) {
        convUpdate['assigned_to'] = senderId;
        convUpdate['assigned_name'] = senderName;
      }
      await http.patch(convUri, headers: _headers, body: jsonEncode(convUpdate));

      // 3. Trigger Outbound Webhook to n8n (so n8n pushes to LINE/Facebook API)
      try {
        final webhookUri = Uri.parse(_outboundWebhookUrl);
        await http.post(
          webhookUri,
          headers: {'Content-Type': 'application/json'},
          body: jsonEncode({
            'conversation_id': conversation.id,
            'platform': conversation.platform,
            'platform_user_id': conversation.externalUserId ?? '',
            'brand': conversation.brand.isEmpty ? 'terrahome' : conversation.brand,
            'content': content,
            'media_url': mediaUrl ?? '',
            'message_id': createdMsg?.id ?? '',
            'sender_id': senderId,
            'sender_name': senderName,
            'sender_avatar': senderAvatar ?? '',
            'metadata': conversation.metadata,
          }),
        );
      } catch (webhookErr) {
        debugPrint('n8n outbound webhook error: $webhookErr');
      }

      return createdMsg;
    } catch (e) {
      debugPrint('Error sending message: $e');
      return null;
    }
  }

  /// Assign conversation to agent
  Future<bool> assignConversation({
    required String convId,
    required String agentId,
    required String agentName,
  }) async {
    try {
      final uri = Uri.parse('$_supabaseUrl/rest/v1/chat_conversations?id=eq.$convId');
      final res = await http.patch(
        uri,
        headers: _headers,
        body: jsonEncode({
          'assigned_to': agentId,
          'assigned_name': agentName,
          'metadata': {
            'assigned_at': DateTime.now().toUtc().toIso8601String(),
            'assigned_agent_ids': [agentId],
          },
        }),
      );
      return res.statusCode == 200 || res.statusCode == 204;
    } catch (e) {
      debugPrint('Error assigning conversation: $e');
      return false;
    }
  }
}
