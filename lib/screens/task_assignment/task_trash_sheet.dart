part of '../admin_tasks_page.dart';

class _TaskTrashSheet extends StatefulWidget {
  const _TaskTrashSheet({required this.service, required this.onRestored});

  final AuthFlowService service;
  final Future<void> Function() onRestored;

  @override
  State<_TaskTrashSheet> createState() => _TaskTrashSheetState();
}

class _TaskTrashSheetState extends State<_TaskTrashSheet> {
  bool _loading = true;
  String? _error;
  String? _restoringId;
  List<TaskRecord> _tasks = const [];

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final tasks = await widget.service.getTrashTasks();
      tasks.sort(
        (a, b) =>
            (b.deletedAt ?? b.createdAt).compareTo(a.deletedAt ?? a.createdAt),
      );
      if (!mounted) return;
      setState(() {
        _tasks = tasks;
        _loading = false;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _error = error.toString();
        _loading = false;
      });
    }
  }

  Future<void> _restore(TaskRecord task) async {
    setState(() => _restoringId = task.id);
    try {
      await widget.service.restoreTask(task.id);
      if (!mounted) return;
      setState(
        () => _tasks = _tasks.where((item) => item.id != task.id).toList(),
      );
      await widget.onRestored();
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('กู้คืนงานสำเร็จ')));
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('กู้คืนงานไม่สำเร็จ: $error')));
    } finally {
      if (mounted) setState(() => _restoringId = null);
    }
  }

  @override
  Widget build(BuildContext context) {
    return FractionallySizedBox(
      heightFactor: 0.78,
      child: Material(
        color: Colors.white,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
        clipBehavior: Clip.antiAlias,
        child: Column(
          children: [
            Container(
              height: 56,
              padding: const EdgeInsets.only(left: 16, right: 8),
              decoration: const BoxDecoration(
                color: Color(0xFFF8FAFC),
                border: Border(bottom: BorderSide(color: Color(0xFFE2E8F0))),
              ),
              child: Row(
                children: [
                  const Icon(
                    Icons.delete_outline_rounded,
                    color: Color(0xFFEF4444),
                    size: 21,
                  ),
                  const SizedBox(width: 8),
                  const Expanded(
                    child: Text(
                      'ถังขยะงานหลัก (30 วัน)',
                      style: TextStyle(
                        color: workText,
                        fontSize: 14,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                  IconButton(
                    key: const Key('close-task-trash'),
                    onPressed: () => Navigator.pop(context),
                    icon: const Icon(Icons.close_rounded, color: workMuted),
                  ),
                ],
              ),
            ),
            Expanded(child: _buildContent()),
          ],
        ),
      ),
    );
  }

  Widget _buildContent() {
    if (_loading) {
      return const Center(child: CircularProgressIndicator(strokeWidth: 2));
    }
    if (_error != null) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.cloud_off_rounded, color: workMuted, size: 34),
            const SizedBox(height: 8),
            const Text('โหลดถังขยะไม่สำเร็จ'),
            const SizedBox(height: 8),
            TextButton(onPressed: _load, child: const Text('ลองใหม่')),
          ],
        ),
      );
    }
    if (_tasks.isEmpty) {
      return const Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.delete_sweep_outlined,
              color: Color(0xFFCBD5E1),
              size: 42,
            ),
            SizedBox(height: 8),
            Text(
              'ไม่มีงานในถังขยะ',
              style: TextStyle(color: workMuted, fontSize: 12),
            ),
          ],
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: _load,
      child: ListView.separated(
        padding: const EdgeInsets.all(14),
        itemCount: _tasks.length,
        separatorBuilder: (_, _) => const SizedBox(height: 8),
        itemBuilder: (context, index) {
          final task = _tasks[index];
          final deletedAt = task.deletedAt ?? task.createdAt;
          final elapsed = DateTime.now().difference(deletedAt).inDays;
          final remaining = (30 - elapsed).clamp(0, 30);
          final restoring = _restoringId == task.id;
          return Container(
            padding: const EdgeInsets.all(11),
            decoration: BoxDecoration(
              color: const Color(0xFFF8FAFC),
              border: Border.all(color: const Color(0xFFE2E8F0)),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        task.title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: workText,
                          fontSize: 12.5,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      const SizedBox(height: 5),
                      Wrap(
                        spacing: 8,
                        runSpacing: 4,
                        children: [
                          Text(
                            'ลบ ${DateFormat('dd/MM/yyyy').format(deletedAt)}',
                            style: const TextStyle(
                              color: workMuted,
                              fontSize: 10,
                            ),
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 7,
                              vertical: 2,
                            ),
                            decoration: BoxDecoration(
                              color: remaining <= 5
                                  ? const Color(0xFFFEF2F2)
                                  : const Color(0xFFEFF6FF),
                              borderRadius: BorderRadius.circular(99),
                            ),
                            child: Text(
                              'เหลือ $remaining วัน',
                              style: TextStyle(
                                color: remaining <= 5
                                    ? const Color(0xFFDC2626)
                                    : workBlue,
                                fontSize: 9.5,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                OutlinedButton(
                  key: Key('restore-task-${task.id}'),
                  onPressed: restoring ? null : () => _restore(task),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: workBlue,
                    minimumSize: const Size(0, 36),
                    padding: const EdgeInsets.symmetric(horizontal: 11),
                    side: const BorderSide(color: Color(0xFFBFDBFE)),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(9),
                    ),
                  ),
                  child: restoring
                      ? const SizedBox(
                          width: 14,
                          height: 14,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Text(
                          'กู้คืน',
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}
