import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../models/app_user.dart';
import '../../models/work_models.dart';
import '../../services/auth_flow_service.dart';
import 'project_detail_style.dart';
import 'project_media_url.dart';

class DeliverableCommentSection extends StatefulWidget {
  const DeliverableCommentSection({
    super.key,
    required this.service,
    required this.taskId,
    required this.deliverableId,
    this.isReadOnly = false,
  });

  final AuthFlowService service;
  final String taskId;
  final String deliverableId;
  final bool isReadOnly;

  @override
  State<DeliverableCommentSection> createState() =>
      _DeliverableCommentSectionState();
}

class _DeliverableCommentSectionState extends State<DeliverableCommentSection> {
  final TextEditingController _controller = TextEditingController();
  final FocusNode _focusNode = FocusNode();
  List<TaskEventRecord> _comments = const [];
  bool _loading = true;
  bool _sending = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadComments();
  }

  @override
  void dispose() {
    _controller.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  Future<void> _loadComments() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final events = await widget.service.getTaskEvents(
        widget.taskId,
        listId: widget.deliverableId,
      );
      if (!mounted) return;
      setState(() {
        _comments = events
            .where((event) => event.eventType == 'comment')
            .toList(growable: false);
        _loading = false;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = error.toString().replaceFirst('Exception: ', '');
      });
    }
  }

  Future<void> _sendComment() async {
    final content = _controller.text.trim();
    if (content.isEmpty || _sending) return;
    setState(() {
      _sending = true;
      _error = null;
    });
    try {
      final created = await widget.service.addTaskComment(
        widget.taskId,
        content,
        listId: widget.deliverableId,
      );
      if (!mounted) return;
      setState(() {
        _comments = [created, ..._comments];
        _controller.clear();
        _sending = false;
      });
      _focusNode.requestFocus();
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _sending = false;
        _error = error.toString().replaceFirst('Exception: ', '');
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Icon(
              Icons.chat_bubble_outline_rounded,
              size: ProjectDetailStyle.iconSmall,
              color: ProjectDetailStyle.accent,
            ),
            const SizedBox(width: 7),
            const Expanded(
              child: Text(
                'ความคิดเห็น',
                style: TextStyle(
                  color: ProjectDetailStyle.ink,
                  fontSize: 14,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
            if (!_loading)
              Text(
                '${_comments.length}',
                style: const TextStyle(
                  color: ProjectDetailStyle.muted,
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                ),
              ),
          ],
        ),
        const SizedBox(height: 12),
        if (!widget.isReadOnly) ...[
          _CommentComposer(
            controller: _controller,
            focusNode: _focusNode,
            currentUser: widget.service.currentUser,
            baseUrl: widget.service.baseUrl,
            sending: _sending,
            onSend: _sendComment,
          ),
          const SizedBox(height: 14),
        ],
        if (_error != null) ...[
          _CommentError(message: _error!, onRetry: _loadComments),
          const SizedBox(height: 12),
        ],
        if (_loading)
          const _CommentLoading()
        else if (_comments.isEmpty)
          const _CommentEmpty()
        else
          for (final comment in _comments)
            _CommentItem(
              key: ValueKey(comment.id),
              comment: comment,
              baseUrl: widget.service.baseUrl,
            ),
      ],
    );
  }
}

class _CommentComposer extends StatelessWidget {
  const _CommentComposer({
    required this.controller,
    required this.focusNode,
    required this.currentUser,
    required this.baseUrl,
    required this.sending,
    required this.onSend,
  });

  final TextEditingController controller;
  final FocusNode focusNode;
  final AppUser? currentUser;
  final String baseUrl;
  final bool sending;
  final VoidCallback onSend;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(10, 8, 6, 8),
      decoration: BoxDecoration(
        color: ProjectDetailStyle.surface,
        borderRadius: BorderRadius.circular(ProjectDetailStyle.cardRadius),
        border: Border.all(color: ProjectDetailStyle.line),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          _CommentAvatar(
            name: currentUser?.fullName ?? 'ผู้ใช้',
            avatarUrl: currentUser?.avatarUrl,
            baseUrl: baseUrl,
            size: 28,
          ),
          const SizedBox(width: 9),
          Expanded(
            child: TextField(
              controller: controller,
              focusNode: focusNode,
              minLines: 1,
              maxLines: 4,
              textInputAction: TextInputAction.newline,
              style: const TextStyle(
                color: ProjectDetailStyle.ink,
                fontSize: 12.5,
                height: 1.45,
              ),
              decoration: const InputDecoration(
                hintText: 'เขียนความคิดเห็น…',
                hintStyle: TextStyle(
                  color: ProjectDetailStyle.muted,
                  fontSize: 12.5,
                ),
                isDense: true,
                filled: false,
                contentPadding: EdgeInsets.symmetric(vertical: 6),
                border: InputBorder.none,
                enabledBorder: InputBorder.none,
                focusedBorder: InputBorder.none,
              ),
              onSubmitted: (_) => onSend(),
            ),
          ),
          SizedBox(
            width: ProjectDetailStyle.tapTarget,
            height: ProjectDetailStyle.tapTarget,
            child: IconButton(
              tooltip: 'ส่งความคิดเห็น',
              onPressed: sending ? null : onSend,
              iconSize: ProjectDetailStyle.iconSmall,
              visualDensity: VisualDensity.compact,
              style: IconButton.styleFrom(
                backgroundColor: ProjectDetailStyle.accent,
                foregroundColor: Colors.white,
                disabledBackgroundColor: ProjectDetailStyle.accentSoft,
                disabledForegroundColor: ProjectDetailStyle.muted,
              ),
              icon: sending
                  ? const SizedBox(
                      width: 14,
                      height: 14,
                      child: CircularProgressIndicator(
                        color: Colors.white,
                        strokeWidth: 2,
                      ),
                    )
                  : const Icon(Icons.arrow_upward_rounded),
            ),
          ),
        ],
      ),
    );
  }
}

class _CommentItem extends StatelessWidget {
  const _CommentItem({super.key, required this.comment, required this.baseUrl});

  final TaskEventRecord comment;
  final String baseUrl;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _CommentAvatar(
            name: comment.userFullName,
            avatarUrl: comment.userAvatarUrl,
            baseUrl: baseUrl,
            size: 30,
          ),
          const SizedBox(width: 9),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        comment.userFullName,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: ProjectDetailStyle.ink,
                          fontSize: 11.5,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      DateFormat(
                        'dd MMM • HH:mm',
                        'th',
                      ).format(comment.createdAt),
                      style: const TextStyle(
                        color: ProjectDetailStyle.muted,
                        fontSize: 9.5,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 5),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 11,
                    vertical: 9,
                  ),
                  decoration: BoxDecoration(
                    color: ProjectDetailStyle.soft,
                    borderRadius: const BorderRadius.only(
                      topRight: Radius.circular(10),
                      bottomLeft: Radius.circular(10),
                      bottomRight: Radius.circular(10),
                    ),
                  ),
                  child: Text(
                    comment.content,
                    style: const TextStyle(
                      color: ProjectDetailStyle.ink,
                      fontSize: 12.5,
                      height: 1.5,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _CommentAvatar extends StatelessWidget {
  const _CommentAvatar({
    required this.name,
    required this.avatarUrl,
    required this.baseUrl,
    required this.size,
  });

  final String name;
  final String? avatarUrl;
  final String baseUrl;
  final double size;

  @override
  Widget build(BuildContext context) {
    final resolvedUrl = resolveProjectMediaUrl(avatarUrl, baseUrl);
    final initial = name.trim().isEmpty
        ? '?'
        : name.trim().characters.first.toUpperCase();
    return ClipOval(
      child: SizedBox(
        width: size,
        height: size,
        child: ColoredBox(
          color: ProjectDetailStyle.accentSoft,
          child: Stack(
            fit: StackFit.expand,
            children: [
              Center(
                child: Text(
                  initial,
                  style: TextStyle(
                    color: ProjectDetailStyle.accent,
                    fontSize: size * 0.36,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
              if (resolvedUrl.isNotEmpty)
                Image.network(
                  resolvedUrl,
                  fit: BoxFit.cover,
                  errorBuilder: (_, _, _) => const SizedBox.shrink(),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _CommentLoading extends StatelessWidget {
  const _CommentLoading();

  @override
  Widget build(BuildContext context) {
    return const Padding(
      padding: EdgeInsets.symmetric(vertical: 18),
      child: Center(
        child: SizedBox(
          width: 18,
          height: 18,
          child: CircularProgressIndicator(
            strokeWidth: 2,
            color: ProjectDetailStyle.accent,
          ),
        ),
      ),
    );
  }
}

class _CommentEmpty extends StatelessWidget {
  const _CommentEmpty();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 18),
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: ProjectDetailStyle.surface,
        borderRadius: BorderRadius.circular(ProjectDetailStyle.controlRadius),
        border: Border.all(color: ProjectDetailStyle.line),
      ),
      child: const Text(
        'ยังไม่มีความคิดเห็น เริ่มพูดคุยเกี่ยวกับงานนี้ได้เลย',
        textAlign: TextAlign.center,
        style: TextStyle(color: ProjectDetailStyle.muted, fontSize: 11.5),
      ),
    );
  }
}

class _CommentError extends StatelessWidget {
  const _CommentError({required this.message, required this.onRetry});

  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(11, 8, 5, 8),
      decoration: BoxDecoration(
        color: ProjectDetailStyle.dangerSoft,
        borderRadius: BorderRadius.circular(ProjectDetailStyle.controlRadius),
        border: Border.all(
          color: ProjectDetailStyle.danger.withValues(alpha: 0.2),
        ),
      ),
      child: Row(
        children: [
          const Icon(
            Icons.error_outline_rounded,
            size: ProjectDetailStyle.iconSmall,
            color: ProjectDetailStyle.danger,
          ),
          const SizedBox(width: 7),
          Expanded(
            child: Text(
              message,
              style: const TextStyle(
                color: ProjectDetailStyle.danger,
                fontSize: 10.5,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          TextButton(
            onPressed: onRetry,
            style: TextButton.styleFrom(
              minimumSize: const Size(0, ProjectDetailStyle.tapTarget),
              padding: const EdgeInsets.symmetric(horizontal: 8),
              visualDensity: VisualDensity.compact,
              textStyle: const TextStyle(
                fontSize: 10.5,
                fontWeight: FontWeight.w700,
              ),
            ),
            child: const Text('ลองใหม่'),
          ),
        ],
      ),
    );
  }
}
