import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_quill/flutter_quill.dart' as quill;
import 'package:flutter_svg/flutter_svg.dart';
import 'package:timeago/timeago.dart' as timeago;
import 'package:file_picker/file_picker.dart' as fp;
import 'package:flutter_image_compress/flutter_image_compress.dart';
import 'package:path_provider/path_provider.dart';
import '../models/work_models.dart';
import '../services/auth_flow_service.dart';
import 'work_ui.dart';

const _threadInk = Color(0xFF172033);
const _threadMuted = Color(0xFF64748B);
const _threadLine = Color(0xFFDCE7F5);
const _threadAccent = Color(0xFF2563EB);
const _threadSurface = Color(0xFFF8FAFC);
const _commentR2PublicBase =
    'https://pub-2a877f7cc07b481ca09dec82cb240465.r2.dev/';

String resolveCommentMediaUrl(String? url, String baseUrl) {
  final value = url?.trim() ?? '';
  if (value.isEmpty) return '';
  if (value.startsWith('r2://')) {
    return value.replaceFirst('r2://', _commentR2PublicBase);
  }
  if (value.startsWith('okpr2://')) {
    return value.replaceFirst('okpr2://', _commentR2PublicBase);
  }
  if (value.startsWith('http://') || value.startsWith('https://')) {
    return value;
  }
  if (value.startsWith('/')) return '$baseUrl$value';
  return '$baseUrl/$value';
}

String resolveCommentAvatarUrl(String? url, String baseUrl) {
  return resolveCommentMediaUrl(url, baseUrl);
}

dynamic _resolveCommentDeltaMedia(dynamic delta, String baseUrl) {
  if (delta is! List) return delta;
  return delta.map((operation) {
    if (operation is! Map) return operation;
    final resolvedOperation = Map<String, dynamic>.from(operation);
    final insert = resolvedOperation['insert'];
    if (insert is Map && insert['image'] is String) {
      resolvedOperation['insert'] = {
        ...Map<String, dynamic>.from(insert),
        'image': resolveCommentMediaUrl(insert['image'] as String, baseUrl),
      };
    }
    return resolvedOperation;
  }).toList(growable: false);
}

class CardCommentSection extends StatefulWidget {
  final AuthFlowService service;
  final String cardId;
  final String taskId;
  final bool isReadOnly;
  final bool dockComposer;
  final ScrollController? parentScrollController;

  const CardCommentSection({
    super.key,
    required this.service,
    required this.cardId,
    required this.taskId,
    this.isReadOnly = false,
    this.dockComposer = true,
    this.parentScrollController,
  });

  @override
  State<CardCommentSection> createState() => _CardCommentSectionState();
}

class _CardCommentSectionState extends State<CardCommentSection>
    with WidgetsBindingObserver {
  final quill.QuillController _controller = quill.QuillController.basic();
  final FocusNode _editorFocusNode = FocusNode();
  final ScrollController _editorScrollController = ScrollController();
  final GlobalKey _composerKey = GlobalKey();
  Timer? _keyboardRevealTimer;
  final OverlayPortalController _composerPortalController =
      OverlayPortalController();
  List<CardComment> _comments = [];
  bool _isLoading = true;
  bool _isSending = false;
  bool _canSend = false;
  bool _isComposerFocused = false;
  double _dockedComposerHeight = 112;

  // Mentions, Autocomplete & Upload fields
  List<UserSummary> _members = [];
  bool _showMentionsList = false;
  String _mentionQuery = '';
  int _mentionIndex = -1;
  final List<String> _mentionedUserIds = [];
  final List<Map<String, dynamic>> _pendingAttachments = [];
  bool _isUploadingImage = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    timeago.setLocaleMessages('th', timeago.ThMessages());
    _controller.addListener(_handleEditorChanged);
    _editorFocusNode.addListener(_handleEditorFocusChanged);
    _loadComments();
    _loadMembers();
    if (!widget.isReadOnly && widget.dockComposer) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _showDockedComposer();
      });
    }
  }

  void _showDockedComposer() {
    if (!mounted ||
        widget.isReadOnly ||
        _composerPortalController.isShowing) {
      return;
    }
    _composerPortalController.show();
    _scheduleComposerSizeSync();
  }

  void _scheduleComposerSizeSync() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || !widget.dockComposer) return;
      final composerBox =
          _composerKey.currentContext?.findRenderObject() as RenderBox?;
      if (composerBox == null || !composerBox.hasSize) return;
      final measuredHeight = composerBox.size.height;
      if ((measuredHeight - _dockedComposerHeight).abs() < 0.5) return;
      setState(() => _dockedComposerHeight = measuredHeight);
    });
  }

  Future<void> _loadMembers() async {
    try {
      final members = await widget.service.getTaskMembers(widget.taskId);
      if (mounted) {
        setState(() {
          _members = members;
        });
      }
    } catch (e) {
      debugPrint('Error loading members: $e');
    }
  }

  void _handleEditorChanged() {
    final plainText = _controller.document.toPlainText();
    final canSend = plainText.trim().isNotEmpty;
    if (canSend != _canSend && mounted) {
      setState(() => _canSend = canSend);
    } else if (mounted) {
      setState(() {});
    }
    _checkMentions(plainText);
    _scheduleComposerSizeSync();
  }

  void _checkMentions(String text) {
    final selection = _controller.selection;
    if (!selection.isValid || !selection.isCollapsed) {
      if (_showMentionsList) setState(() => _showMentionsList = false);
      return;
    }

    final caretPos = selection.extentOffset;
    if (caretPos <= 0) {
      if (_showMentionsList) setState(() => _showMentionsList = false);
      return;
    }

    // Find the last '@' before the caret position
    final textBeforeCaret = text.substring(0, caretPos);
    final lastAt = textBeforeCaret.lastIndexOf('@');

    if (lastAt != -1) {
      // Check if there is a space before '@', or it is at the start
      if (lastAt == 0 || textBeforeCaret[lastAt - 1] == ' ' || textBeforeCaret[lastAt - 1] == '\n') {
        // Query text is between '@' and caret
        final query = textBeforeCaret.substring(lastAt + 1);
        // If there's a space after '@', stop showing mentions
        if (!query.contains(' ')) {
          setState(() {
            _showMentionsList = true;
            _mentionQuery = query;
            _mentionIndex = lastAt;
          });
          return;
        }
      }
    }

    if (_showMentionsList) {
      setState(() {
        _showMentionsList = false;
        _mentionQuery = '';
        _mentionIndex = -1;
      });
    }
  }

  void _insertAtSymbol() {
    final selection = _controller.selection;
    final offset = selection.isValid ? selection.extentOffset : _controller.document.length;
    _controller.replaceText(offset, 0, '@', TextSelection.collapsed(offset: offset + 1));
    _editorFocusNode.requestFocus();
  }

  void _toggleTextAttribute(quill.Attribute attribute) {
    final attributes = _controller.getSelectionStyle().attributes;
    final isActive = attributes.containsKey(attribute.key);
    _controller.formatSelection(
      isActive ? quill.Attribute.clone(attribute, null) : attribute,
    );
    _editorFocusNode.requestFocus();
  }

  bool _hasTextAttribute(quill.Attribute attribute) {
    return _controller.getSelectionStyle().attributes.containsKey(attribute.key);
  }

  void _selectMemberToMention(UserSummary member) {
    if (_mentionIndex == -1) return;

    final selection = _controller.selection;
    final caretPos = selection.extentOffset;

    final replacement = '@${member.fullName} ';
    final lengthToReplace = caretPos - _mentionIndex;

    _controller.replaceText(_mentionIndex, lengthToReplace, replacement, TextSelection.collapsed(offset: _mentionIndex + replacement.length));

    if (!_mentionedUserIds.contains(member.id)) {
      _mentionedUserIds.add(member.id);
    }

    setState(() {
      _showMentionsList = false;
      _mentionQuery = '';
      _mentionIndex = -1;
    });

    _editorFocusNode.requestFocus();
  }

  Future<void> _pickAndUploadCommentImage() async {
    try {
      final result = await fp.FilePicker.pickFiles(
        type: fp.FileType.image,
        allowMultiple: false,
      );

      if (result != null && result.files.single.path != null) {
        final filePath = result.files.single.path!;
        File file = File(filePath);
        final fileName = result.files.single.name;
        final fileSize = result.files.single.size;

        setState(() {
          _isUploadingImage = true;
          _isSending = true;
        });

        // Convert to WebP
        try {
          final tempDir = await getTemporaryDirectory();
          final targetPath = '${tempDir.path}/temp_${DateTime.now().millisecondsSinceEpoch}.webp';

          final compressedFile = await FlutterImageCompress.compressAndGetFile(
            file.absolute.path,
            targetPath,
            format: CompressFormat.webp,
            quality: 85,
          );

          if (compressedFile != null) {
            file = File(compressedFile.path);
          }
        } catch (e) {
          debugPrint('Image compression failed: $e');
        }

        final uploadedUrl = await widget.service.uploadImage(file);
        final displayUrl = resolveCommentMediaUrl(
          uploadedUrl,
          widget.service.baseUrl,
        );

        final index = _controller.selection.isValid
            ? _controller.selection.extentOffset
            : _controller.document.length;

        _controller.document.insert(index, '\n');
        _controller.document.insert(index + 1, quill.BlockEmbed.image(displayUrl));
        _controller.document.insert(index + 2, '\n');
        _controller.updateSelection(
          TextSelection.collapsed(offset: index + 3),
          quill.ChangeSource.local,
        );

        _pendingAttachments.add({
          'url': uploadedUrl,
          'name': fileName,
          'type': 'image',
          'size_bytes': fileSize,
        });

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('อัปโหลดรูปภาพสำเร็จ'),
              backgroundColor: Colors.green,
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('อัปโหลดรูปภาพล้มเหลว: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isUploadingImage = false;
          _isSending = false;
        });
      }
    }
  }

  List<UserSummary> _filteredMembers() {
    if (_mentionQuery.isEmpty) return _members;
    final query = _mentionQuery.toLowerCase();
    return _members.where((m) {
      final name = m.fullName.toLowerCase();
      return name.contains(query);
    }).toList();
  }

  Widget _buildMentionsDropdown() {
    final filtered = _filteredMembers();
    return Container(
      constraints: const BoxConstraints(maxHeight: 160),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFE2E8F0)),
        boxShadow: const [
          BoxShadow(
            color: Color(0x1A000000),
            blurRadius: 12,
            offset: Offset(0, -4),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(12),
        child: ListView.builder(
          shrinkWrap: true,
          padding: const EdgeInsets.symmetric(vertical: 4),
          itemCount: filtered.length,
          itemBuilder: (context, idx) {
            final member = filtered[idx];
            final name = member.fullName;
            return InkWell(
              onTap: () => _selectMemberToMention(member),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                child: Row(
                  children: [
                    _buildAvatar(
                      name: name,
                      avatarUrl: member.avatarUrl,
                      radius: 12,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        name,
                        style: const TextStyle(
                          fontSize: 12.5,
                          fontWeight: FontWeight.w600,
                          color: workText,
                        ),
                      ),
                    ),
                    Text(
                      member.position,
                      style: const TextStyle(
                        fontSize: 11,
                        color: workMuted,
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        ),
      ),
    );
  }

  void _handleEditorFocusChanged() {
    if (mounted) {
      setState(() => _isComposerFocused = _editorFocusNode.hasFocus);
    }
    if (_editorFocusNode.hasFocus) {
      _scheduleRevealComposer();
    }
  }

  @override
  void didChangeMetrics() {
    if (mounted) {
      setState(() {});
    }
    if (_editorFocusNode.hasFocus) {
      _scheduleRevealComposer();
    }
  }

  void _scheduleRevealComposer() {
    _keyboardRevealTimer?.cancel();
    WidgetsBinding.instance.addPostFrameCallback((_) => _revealComposer());
    _keyboardRevealTimer = Timer(const Duration(milliseconds: 240), () {
      if (!mounted || !_editorFocusNode.hasFocus) {
        return;
      }
      setState(() {});
      WidgetsBinding.instance.addPostFrameCallback((_) => _revealComposer());
    });
  }

  Future<void> _revealComposer() async {
    final composerContext = _composerKey.currentContext;
    if (!mounted || !_editorFocusNode.hasFocus || composerContext == null) {
      return;
    }

    final parentController = widget.parentScrollController;
    final composerBox = composerContext.findRenderObject() as RenderBox?;
    if (parentController != null &&
        parentController.hasClients &&
        composerBox != null) {
      final mediaQuery = MediaQuery.of(composerContext);
      final keyboardTop = mediaQuery.size.height - mediaQuery.viewInsets.bottom;
      final composerBottom = composerBox
          .localToGlobal(Offset(0, composerBox.size.height))
          .dy;
      final overlap = composerBottom - keyboardTop + 20;

      if (overlap > 0) {
        final position = parentController.position;
        final target = (position.pixels + overlap).clamp(
          position.minScrollExtent,
          position.maxScrollExtent,
        );
        parentController.jumpTo(target);
        return;
      }
    }

    await Scrollable.ensureVisible(
      composerContext,
      duration: const Duration(milliseconds: 220),
      curve: Curves.easeOutCubic,
      alignment: 0.35,
    );
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _keyboardRevealTimer?.cancel();
    _controller.removeListener(_handleEditorChanged);
    _editorFocusNode.removeListener(_handleEditorFocusChanged);
    _controller.dispose();
    _editorFocusNode.dispose();
    _editorScrollController.dispose();
    super.dispose();
  }

  Future<void> _loadComments() async {
    try {
      final comments = await widget.service.getCardComments(widget.cardId);
      if (mounted) {
        setState(() {
          _comments = comments;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('โหลดคอมเมนต์ล้มเหลว')));
      }
    }
  }

  Future<void> _sendComment() async {
    final plainText = _controller.document.toPlainText().trim();
    if (plainText.isEmpty) return;

    final contentDelta = jsonEncode(_controller.document.toDelta().toJson());

    setState(() => _isSending = true);
    try {
      final finalMentionedIds = _mentionedUserIds.where((uid) {
        final member = _members.firstWhere(
          (m) => m.id == uid,
          orElse: () => const UserSummary(id: '', firstName: '', lastName: '', position: ''),
        );
        if (member.id.isEmpty) return false;
        final name = member.fullName;
        return plainText.contains('@$name');
      }).toList();

      final newComment = await widget.service.createCardComment(
        widget.cardId,
        jsonDecode(contentDelta), // send as JSON list
        plainText,
        finalMentionedIds,
        _pendingAttachments,
      );

      if (mounted) {
        setState(() {
          _comments.insert(0, newComment);
          _controller.clear();
          _mentionedUserIds.clear();
          _pendingAttachments.clear();
          _isSending = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isSending = false);
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('ส่งคอมเมนต์ล้มเหลว')));
      }
    }
  }

  Widget _buildAvatar({
    required String name,
    String? avatarUrl,
    double radius = 17,
  }) {
    final resolvedAvatarUrl = resolveCommentAvatarUrl(
      avatarUrl,
      widget.service.baseUrl,
    );
    final hasAvatar = resolvedAvatarUrl.isNotEmpty;
    final initial = name.trim().isEmpty ? '?' : name.trim()[0].toUpperCase();

    return Container(
      padding: const EdgeInsets.all(2),
      decoration: BoxDecoration(
        color: Colors.white,
        shape: BoxShape.circle,
        border: Border.all(color: _threadLine),
        boxShadow: const [
          BoxShadow(
            color: Color(0x0D172033),
            blurRadius: 8,
            offset: Offset(0, 2),
          ),
        ],
      ),
      child: ClipOval(
        child: SizedBox(
          width: radius * 2,
          height: radius * 2,
          child: ColoredBox(
            color: const Color(0xFFE8F0FF),
            child: Stack(
              fit: StackFit.expand,
              children: [
                Center(
                  child: Text(
                    initial,
                    style: const TextStyle(
                      color: _threadAccent,
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                if (hasAvatar)
                  if (resolvedAvatarUrl.toLowerCase().contains('.svg') || resolvedAvatarUrl.toLowerCase().contains('/svg'))
                    SvgPicture.network(
                      resolvedAvatarUrl,
                      fit: BoxFit.cover,
                    )
                  else
                    Image.network(
                      resolvedAvatarUrl,
                      fit: BoxFit.cover,
                      headers: const {
                        'User-Agent': 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36',
                      },
                      errorBuilder: (context, error, stackTrace) =>
                          const SizedBox.shrink(),
                    ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildAttachment(CommentAttachment attachment) {
    final isImage = attachment.type == 'image';
    final mediaUrl = resolveCommentMediaUrl(
      attachment.url,
      widget.service.baseUrl,
    );
    if (isImage && mediaUrl.isNotEmpty) {
      return ClipRRect(
        borderRadius: BorderRadius.circular(10),
        child: Container(
          width: 180,
          height: 112,
          color: _threadSurface,
          child: Image.network(
            mediaUrl,
            fit: BoxFit.cover,
            errorBuilder: (context, error, stackTrace) => const Center(
              child: Icon(
                Icons.broken_image_outlined,
                color: _threadMuted,
                size: 22,
              ),
            ),
          ),
        ),
      );
    }
    return Container(
      constraints: const BoxConstraints(maxWidth: 190),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: _threadSurface,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 28,
            height: 28,
            decoration: BoxDecoration(
              color: isImage
                  ? const Color(0xFFE8F0FF)
                  : const Color(0xFFFFF3E8),
              borderRadius: BorderRadius.circular(7),
            ),
            child: Icon(
            Icons.insert_drive_file_outlined,
            size: 16,
              color: const Color(0xFFEA580C),
            ),
          ),
          const SizedBox(width: 8),
          Flexible(
            child: Text(
              attachment.name.isEmpty ? 'ไฟล์แนบ' : attachment.name,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                color: _threadInk,
                fontSize: 11.5,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCommentItem(CardComment comment, {required bool isLast}) {
    quill.QuillController? readOnlyController;
    try {
      if (comment.contentDelta != null) {
        final doc = quill.Document.fromJson(
          _resolveCommentDeltaMedia(
            comment.contentDelta,
            widget.service.baseUrl,
          ),
        );
        readOnlyController = quill.QuillController(
          document: doc,
          selection: const TextSelection.collapsed(offset: 0),
          readOnly: true,
        );
      }
    } catch (e) {
      debugPrint('Error parsing comment delta: $e');
    }

    final author = comment.author;
    final authorName = author?.fullName ?? 'Unknown';
    final avatarUrl = author?.avatarUrl;

    return Padding(
      padding: EdgeInsets.only(bottom: isLast ? 4 : 18),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 38,
            child: Stack(
              clipBehavior: Clip.none,
              alignment: Alignment.topCenter,
              children: [
                if (!isLast)
                  const Positioned(
                    top: 38,
                    bottom: -22,
                    child: SizedBox(
                      width: 2,
                      child: ColoredBox(color: _threadLine),
                    ),
                  ),
                _buildAvatar(name: authorName, avatarUrl: avatarUrl),
              ],
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Wrap(
                  crossAxisAlignment: WrapCrossAlignment.center,
                  spacing: 7,
                  runSpacing: 2,
                  children: [
                    Text(
                      authorName,
                      style: const TextStyle(
                        color: _threadInk,
                        fontWeight: FontWeight.w700,
                        fontSize: 13,
                      ),
                    ),
                    Text(
                      timeago.format(comment.createdAt, locale: 'th'),
                      style: const TextStyle(
                        color: _threadMuted,
                        fontSize: 10.5,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    if (comment.isEdited)
                      const Text(
                        'แก้ไขแล้ว',
                        style: TextStyle(
                          color: _threadMuted,
                          fontSize: 10.5,
                          fontStyle: FontStyle.italic,
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 5),
                readOnlyController != null
                    ? quill.QuillEditor.basic(
                        controller: readOnlyController,
                        config: const quill.QuillEditorConfig(
                          embedBuilders: [CustomImageEmbedBuilder()],
                          showCursor: false,
                          scrollable: false,
                          padding: EdgeInsets.zero,
                          customStyles: quill.DefaultStyles(
                            paragraph: quill.DefaultTextBlockStyle(
                              TextStyle(
                                color: _threadInk,
                                fontSize: 13,
                                height: 1.45,
                              ),
                              quill.HorizontalSpacing.zero,
                              quill.VerticalSpacing.zero,
                              quill.VerticalSpacing.zero,
                              null,
                            ),
                          ),
                        ),
                      )
                    : Text(
                        comment.plainText,
                        style: const TextStyle(
                          color: _threadInk,
                          fontSize: 13,
                          height: 1.45,
                        ),
                      ),
                if (comment.attachments.isNotEmpty) ...[
                  const SizedBox(height: 9),
                  Wrap(
                    spacing: 7,
                    runSpacing: 7,
                    children: comment.attachments
                        .map(_buildAttachment)
                        .toList(growable: false),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDockedComposer(BuildContext overlayContext) {
    final currentUser = widget.service.currentUser;
    final currentUserName = currentUser?.fullName ?? 'คุณ';
    final currentUserAvatar = currentUser?.avatarUrl;
    final keyboardInset = MediaQuery.viewInsetsOf(overlayContext).bottom;

    return Positioned(
      left: 0,
      right: 0,
      bottom: keyboardInset,
      child: Material(
        key: _composerKey,
        color: Colors.transparent,
        child: SafeArea(
          top: false,
          bottom: keyboardInset == 0,
          child: Container(
            padding: const EdgeInsets.fromLTRB(16, 9, 12, 8),
            decoration: const BoxDecoration(
              color: Colors.white,
              border: Border(
                top: BorderSide(color: Color(0xFFE2E8F0)),
              ),
              boxShadow: [
                BoxShadow(
                  color: Color(0x120F172A),
                  blurRadius: 14,
                  offset: Offset(0, -4),
                ),
              ],
            ),
            child: Stack(
              clipBehavior: Clip.none,
              children: [
                Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    quill.QuillEditor.basic(
                      controller: _controller,
                      focusNode: _editorFocusNode,
                      scrollController: _editorScrollController,
                      config: quill.QuillEditorConfig(
                        embedBuilders: const [CustomImageEmbedBuilder()],
                        placeholder: 'ถามคำถามหรือโพสต์อัปเดต...',
                        padding: const EdgeInsets.symmetric(vertical: 3),
                        minHeight: 34,
                        maxHeight: 92,
                        customStyles: const quill.DefaultStyles(
                          paragraph: quill.DefaultTextBlockStyle(
                            TextStyle(
                              color: _threadInk,
                              fontSize: 13.5,
                              height: 1.35,
                            ),
                            quill.HorizontalSpacing.zero,
                            quill.VerticalSpacing.zero,
                            quill.VerticalSpacing.zero,
                            null,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 5),
                    Row(
                      children: [
                        _ComposerIconButton(
                          icon: Icons.image_outlined,
                          tooltip: 'แนบรูปภาพ',
                          onPressed: _isUploadingImage
                              ? null
                              : _pickAndUploadCommentImage,
                        ),
                        const SizedBox(width: 2),
                        _ComposerIconButton(
                          icon: Icons.format_bold_rounded,
                          tooltip: 'ตัวหนา',
                          isActive: _hasTextAttribute(quill.Attribute.bold),
                          onPressed: () =>
                              _toggleTextAttribute(quill.Attribute.bold),
                        ),
                        const SizedBox(width: 2),
                        _ComposerIconButton(
                          icon: Icons.format_italic_rounded,
                          tooltip: 'ตัวเอียง',
                          isActive: _hasTextAttribute(quill.Attribute.italic),
                          onPressed: () =>
                              _toggleTextAttribute(quill.Attribute.italic),
                        ),
                        const SizedBox(width: 2),
                        _ComposerIconButton(
                          icon: Icons.format_list_bulleted_rounded,
                          tooltip: 'รายการหัวข้อ',
                          isActive: _hasTextAttribute(quill.Attribute.ul),
                          onPressed: () =>
                              _toggleTextAttribute(quill.Attribute.ul),
                        ),
                        const SizedBox(width: 2),
                        _ComposerIconButton(
                          icon: Icons.alternate_email_rounded,
                          tooltip: 'กล่าวถึงสมาชิก',
                          onPressed: _insertAtSymbol,
                        ),
                        const Spacer(),
                        _buildAvatar(
                          name: currentUserName,
                          avatarUrl: currentUserAvatar,
                          radius: 13,
                        ),
                        const SizedBox(width: 7),
                        SizedBox(
                          width: 34,
                          height: 34,
                          child: IconButton.filled(
                            tooltip: 'ส่งคอมเมนต์',
                            onPressed: _isSending || !_canSend
                                ? null
                                : _sendComment,
                            style: IconButton.styleFrom(
                              backgroundColor: _threadAccent,
                              disabledBackgroundColor:
                                  const Color(0xFFE2E8F0),
                              foregroundColor: Colors.white,
                              disabledForegroundColor: _threadMuted,
                              padding: EdgeInsets.zero,
                            ),
                            icon: _isSending
                                ? const SizedBox(
                                    width: 13,
                                    height: 13,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                      color: Colors.white,
                                    ),
                                  )
                                : const Icon(
                                    Icons.arrow_upward_rounded,
                                    size: 17,
                                  ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
                if (_showMentionsList && _filteredMembers().isNotEmpty)
                  Positioned(
                    left: 0,
                    right: 0,
                    bottom: 42,
                    child: _buildMentionsDropdown(),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final currentUser = widget.service.currentUser;
    final currentUserName = currentUser?.fullName ?? 'คุณ';
    final currentUserAvatar = currentUser?.avatarUrl;

    return OverlayPortal(
      controller: _composerPortalController,
      overlayChildBuilder: _buildDockedComposer,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
        Row(
          children: [
            Container(
              width: 34,
              height: 34,
              decoration: BoxDecoration(
                color: const Color(0xFFE8F0FF),
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Icon(
                Icons.forum_outlined,
                color: _threadAccent,
                size: 18,
              ),
            ),
            const SizedBox(width: 10),
            const Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'กิจกรรมและคอมเมนต์',
                    style: TextStyle(
                      color: _threadInk,
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  SizedBox(height: 1),
                  Text(
                    'ติดตามการพูดคุยและความคืบหน้าของงาน',
                    style: TextStyle(color: _threadMuted, fontSize: 10.5),
                  ),
                ],
              ),
            ),
            if (!_isLoading && _comments.isNotEmpty)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: _threadSurface,
                  borderRadius: BorderRadius.circular(999),
                  border: Border.all(color: const Color(0xFFE2E8F0)),
                ),
                child: Text(
                  '${_comments.length} รายการ',
                  style: const TextStyle(
                    color: _threadMuted,
                    fontSize: 10,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
          ],
        ),
        const SizedBox(height: 16),

        // Comment Composer
        if (!widget.dockComposer && !widget.isReadOnly)
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: const EdgeInsets.only(top: 3),
                child: _buildAvatar(
                  name: currentUserName,
                  avatarUrl: currentUserAvatar,
                  radius: 15,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Stack(
                  clipBehavior: Clip.none,
                  children: [
                    AnimatedContainer(
                      key: _composerKey,
                      duration: const Duration(milliseconds: 160),
                      curve: Curves.easeOutCubic,
                      decoration: BoxDecoration(
                        color: Colors.white,
                        border: Border.all(
                          color: _isComposerFocused
                              ? _threadAccent
                              : const Color(0xFFDCE3ED),
                          width: _isComposerFocused ? 1.4 : 1,
                        ),
                        borderRadius: BorderRadius.circular(14),
                        boxShadow: _isComposerFocused
                            ? const [
                                BoxShadow(
                                  color: Color(0x142563EB),
                                  blurRadius: 14,
                                  offset: Offset(0, 4),
                                ),
                              ]
                            : const [
                                BoxShadow(
                                  color: Color(0x08172033),
                                  blurRadius: 8,
                                  offset: Offset(0, 2),
                                ),
                              ],
                      ),
                      child: Column(
                        children: [
                          Padding(
                            padding: const EdgeInsets.fromLTRB(13, 10, 13, 8),
                            child: quill.QuillEditor.basic(
                              controller: _controller,
                              focusNode: _editorFocusNode,
                              scrollController: _editorScrollController,
                              config: quill.QuillEditorConfig(
                                embedBuilders: const [CustomImageEmbedBuilder()],
                                placeholder: 'เขียนคอมเมนต์ หรือใช้ @ เพื่อพูดถึง',
                                padding: EdgeInsets.zero,
                                minHeight: 46,
                                maxHeight: 112,
                                customStyles: const quill.DefaultStyles(
                                  paragraph: quill.DefaultTextBlockStyle(
                                    TextStyle(
                                      color: _threadInk,
                                      fontSize: 13,
                                      height: 1.4,
                                    ),
                                    quill.HorizontalSpacing.zero,
                                    quill.VerticalSpacing.zero,
                                    quill.VerticalSpacing.zero,
                                    null,
                                  ),
                                ),
                              ),
                            ),
                          ),
                          const Divider(height: 1, color: Color(0xFFEDF1F6)),
                          SizedBox(
                            height: 46,
                            child: Row(
                              children: [
                                Expanded(
                                  child: ClipRRect(
                                    borderRadius: const BorderRadius.only(
                                      bottomLeft: Radius.circular(13),
                                    ),
                                    child: quill.QuillSimpleToolbar(
                                      controller: _controller,
                                      config: const quill.QuillSimpleToolbarConfig(
                                        multiRowsDisplay: false,
                                        toolbarSize: 40,
                                        color: Colors.transparent,
                                        showDividers: false,
                                        showFontFamily: false,
                                        showFontSize: false,
                                        showColorButton: false,
                                        showBackgroundColorButton: false,
                                        showCodeBlock: false,
                                        showInlineCode: false,
                                        showSearchButton: false,
                                        showSubscript: false,
                                        showSuperscript: false,
                                        showUndo: false,
                                        showRedo: false,
                                        showDirection: false,
                                        showIndent: false,
                                        showQuote: false,
                                        showClearFormat: false,
                                        showStrikeThrough: false,
                                        showHeaderStyle: false,
                                        showListCheck: false,
                                      ),
                                    ),
                                  ),
                                ),
                                IconButton(
                                  icon: const Icon(
                                    Icons.alternate_email_rounded,
                                    color: workBlue,
                                    size: 19,
                                  ),
                                  tooltip: 'กล่าวถึง (@)',
                                  onPressed: _insertAtSymbol,
                                  visualDensity: VisualDensity.compact,
                                  padding: EdgeInsets.zero,
                                ),
                                _isUploadingImage
                                    ? const Padding(
                                        padding: EdgeInsets.symmetric(horizontal: 10),
                                        child: SizedBox(
                                          width: 16,
                                          height: 16,
                                          child: CircularProgressIndicator(
                                            strokeWidth: 2,
                                            color: workBlue,
                                          ),
                                        ),
                                      )
                                    : IconButton(
                                        icon: const Icon(
                                          Icons.image_outlined,
                                          color: workBlue,
                                          size: 19,
                                        ),
                                        tooltip: 'แนบรูปภาพ',
                                        onPressed: _pickAndUploadCommentImage,
                                        visualDensity: VisualDensity.compact,
                                        padding: EdgeInsets.zero,
                                      ),
                                const SizedBox(width: 4),
                                Padding(
                                  padding: const EdgeInsets.only(right: 6),
                                  child: IconButton.filled(
                                    tooltip: 'ส่งคอมเมนต์',
                                    onPressed: _isSending || !_canSend
                                        ? null
                                        : _sendComment,
                                    style: IconButton.styleFrom(
                                      backgroundColor: _threadAccent,
                                      disabledBackgroundColor: const Color(
                                        0xFFE2E8F0,
                                      ),
                                      foregroundColor: Colors.white,
                                      disabledForegroundColor: _threadMuted,
                                      minimumSize: const Size(34, 34),
                                      maximumSize: const Size(34, 34),
                                      padding: EdgeInsets.zero,
                                    ),
                                    icon: _isSending && !_isUploadingImage
                                        ? const SizedBox(
                                            width: 14,
                                            height: 14,
                                            child: CircularProgressIndicator(
                                              strokeWidth: 2,
                                              color: Colors.white,
                                            ),
                                          )
                                        : const Icon(
                                            Icons.arrow_upward_rounded,
                                            size: 17,
                                          ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                    if (_showMentionsList && _filteredMembers().isNotEmpty)
                      Positioned(
                        left: 0,
                        right: 0,
                        bottom: 48,
                        child: _buildMentionsDropdown(),
                      ),
                  ],
                ),
              ),
            ],
          ),
        if (_isLoading)
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 18),
            child: Center(
              child: SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: _threadAccent,
                ),
              ),
            ),
          )
        else if (_comments.isEmpty)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 18),
            decoration: BoxDecoration(
              color: _threadSurface,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: const Color(0xFFE8EDF4)),
            ),
            child: const Row(
              children: [
                Icon(
                  Icons.chat_bubble_outline_rounded,
                  color: _threadMuted,
                  size: 18,
                ),
                SizedBox(width: 10),
                Expanded(
                  child: Text(
                    'ยังไม่มีการพูดคุย เริ่มคอมเมนต์เพื่ออัปเดตทีมได้เลย',
                    style: TextStyle(
                      color: _threadMuted,
                      fontSize: 11.5,
                      height: 1.35,
                    ),
                  ),
                ),
              ],
            ),
          )
        else
          ListView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            padding: EdgeInsets.zero,
            itemCount: _comments.length,
            itemBuilder: (context, index) {
              return _buildCommentItem(
                _comments[index],
                isLast: index == _comments.length - 1,
              );
            },
          ),
        if (!widget.isReadOnly && widget.dockComposer)
          SizedBox(
            key: const ValueKey('comment-composer-scroll-clearance'),
            height: _dockedComposerHeight + 16,
          ),
        SizedBox(
          height: _isComposerFocused
              ? MediaQuery.viewInsetsOf(context).bottom + 16
              : 0,
        ),
        ],
      ),
    );
  }
}

class _ComposerIconButton extends StatelessWidget {
  const _ComposerIconButton({
    required this.icon,
    required this.tooltip,
    required this.onPressed,
    this.isActive = false,
  });

  final IconData icon;
  final String tooltip;
  final VoidCallback? onPressed;
  final bool isActive;

  @override
  Widget build(BuildContext context) {
    return IconButton(
      tooltip: tooltip,
      onPressed: onPressed,
      visualDensity: VisualDensity.compact,
      constraints: const BoxConstraints.tightFor(width: 34, height: 34),
      padding: EdgeInsets.zero,
      style: IconButton.styleFrom(
        backgroundColor: isActive ? const Color(0xFFEFF6FF) : Colors.transparent,
        foregroundColor: isActive ? _threadAccent : _threadMuted,
        disabledForegroundColor: const Color(0xFFCBD5E1),
      ),
      icon: Icon(icon, size: 19),
    );
  }
}

class CustomImageEmbedBuilder extends quill.EmbedBuilder {
  const CustomImageEmbedBuilder();

  @override
  String get key => 'image';

  @override
  Widget build(BuildContext context, quill.EmbedContext embedContext) {
    final imageUrl = embedContext.node.value.data as String;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: Align(
        alignment: Alignment.centerLeft,
        child: GestureDetector(
          onTap: () {
            showDialog(
              context: context,
              barrierColor: Colors.black87,
              builder: (context) => Dialog(
                backgroundColor: Colors.transparent,
                insetPadding: EdgeInsets.zero,
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    InteractiveViewer(
                      child: Image.network(imageUrl, fit: BoxFit.contain),
                    ),
                    Positioned(
                      top: 40,
                      right: 20,
                      child: IconButton(
                        icon: const Icon(Icons.close, color: Colors.white, size: 32),
                        onPressed: () => Navigator.of(context).pop(),
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
          child: ClipRRect(
            borderRadius: BorderRadius.circular(8.0),
            child: Image.network(
              imageUrl,
              height: 70,
              width: 70,
              fit: BoxFit.cover,
              errorBuilder: (context, error, stackTrace) => Container(
                height: 70,
                width: 70,
                color: Colors.grey[200],
                padding: const EdgeInsets.all(16),
                child: const Icon(Icons.broken_image, color: Colors.grey),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
