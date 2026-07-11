import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/download_provider.dart';

class DownloadsScreen extends ConsumerStatefulWidget {
  const DownloadsScreen({super.key});

  @override
  ConsumerState<DownloadsScreen> createState() => _DownloadsScreenState();
}

class _DownloadsScreenState extends ConsumerState<DownloadsScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _tabController.addListener(() {
      if (mounted) {
        setState(() {});
      }
    });
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final allTasks = ref.watch(downloadProvider);
    final hasCompleted = allTasks.any((t) => t.status == DownloadStatus.completed);
    final hasFailed = allTasks.any((t) => t.status == DownloadStatus.failed || t.status == DownloadStatus.canceled);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Downloads'),
        actions: [
          if (_tabController.index == 1 && hasCompleted)
            IconButton(
              icon: const Icon(Icons.delete_sweep_outlined),
              tooltip: 'Clear All Completed',
              onPressed: () => _confirmClearAll(
                context,
                'Completed',
                () => ref
                    .read(downloadProvider.notifier)
                    .clearCompletedDownloads(),
              ),
            ),
          if (_tabController.index == 2 && hasFailed)
            IconButton(
              icon: const Icon(Icons.delete_sweep_outlined),
              tooltip: 'Clear All Failed',
              onPressed: () => _confirmClearAll(
                context,
                'Failed & Canceled',
                () => ref
                    .read(downloadProvider.notifier)
                    .clearFailedAndCanceledDownloads(),
              ),
            ),
        ],
        bottom: TabBar(
          controller: _tabController,
          tabs: const [
            Tab(text: 'IN PROGRESS'),
            Tab(text: 'COMPLETED'),
            Tab(text: 'FAILED'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _buildDownloadsList(
              [DownloadStatus.pending, DownloadStatus.downloading]),
          _buildDownloadsList([DownloadStatus.completed]),
          _buildDownloadsList([DownloadStatus.failed, DownloadStatus.canceled]),
        ],
      ),
    );
  }

  void _confirmClearAll(
      BuildContext context, String category, VoidCallback onConfirm) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Clear All $category?'),
        content:
            Text('This will remove all downloads from the "$category" list.'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              onConfirm();
            },
            child: const Text('Clear All', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }

  Widget _buildDownloadsList(List<DownloadStatus> statuses) {
    final allTasks = ref.watch(downloadProvider);
    final tasks =
        allTasks.where((task) => statuses.contains(task.status)).toList();

    if (tasks.isEmpty) {
      return Center(
        child: Text(
          'No downloads in this category.',
          style: Theme.of(context)
              .textTheme
              .bodyMedium
              ?.copyWith(color: Colors.grey),
        ),
      );
    }

    return ListView.builder(
      itemCount: tasks.length,
      itemBuilder: (context, index) {
        final task = tasks[index];
        return _DownloadTaskTile(task: task);
      },
    );
  }
}

class _DownloadTaskTile extends ConsumerWidget {
  final DownloadTask task;

  const _DownloadTaskTile({required this.task});

  IconData _getFileIcon(String fileName) {
    final ext = fileName.split('.').last.toLowerCase();
    switch (ext) {
      case 'pdf':
        return Icons.picture_as_pdf;
      case 'ppt':
      case 'pptx':
        return Icons.slideshow;
      case 'doc':
      case 'docx':
        return Icons.description;
      case 'xls':
      case 'xlsx':
        return Icons.table_chart;
      case 'txt':
        return Icons.text_snippet;
      case 'jpg':
      case 'jpeg':
      case 'png':
      case 'gif':
        return Icons.image;
      case 'mp4':
      case 'mov':
      case 'avi':
        return Icons.videocam;
      default:
        return Icons.insert_drive_file;
    }
  }

  Color _getStatusColor(DownloadStatus status) {
    switch (status) {
      case DownloadStatus.completed:
        return Colors.green;
      case DownloadStatus.failed:
        return Colors.red;
      case DownloadStatus.canceled:
        return Colors.orange;
      default:
        return Colors.grey;
    }
  }

  Widget _buildActionButtons(BuildContext context, WidgetRef ref) {
    switch (task.status) {
      case DownloadStatus.pending:
      case DownloadStatus.downloading:
        return IconButton(
          icon: const Icon(Icons.cancel_outlined),
          tooltip: 'Cancel',
          onPressed: () =>
              ref.read(downloadProvider.notifier).cancelDownload(task.fileId),
        );
      case DownloadStatus.failed:
      case DownloadStatus.canceled:
        return Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            IconButton(
              icon: const Icon(Icons.refresh),
              tooltip: 'Retry',
              onPressed: () =>
                  ref.read(downloadProvider.notifier).retryDownload(task.fileId),
            ),
            IconButton(
              icon: const Icon(Icons.clear),
              tooltip: 'Clear',
              onPressed: () =>
                  ref.read(downloadProvider.notifier).clearTask(task.fileId),
            ),
          ],
        );
      case DownloadStatus.completed:
        return IconButton(
          icon: const Icon(Icons.clear),
          tooltip: 'Clear',
          onPressed: () =>
              ref.read(downloadProvider.notifier).clearTask(task.fileId),
        );
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return ListTile(
      leading: Icon(_getFileIcon(task.fileName)),
      title: Text(task.fileName, maxLines: 1, overflow: TextOverflow.ellipsis),
      subtitle: (task.status == DownloadStatus.downloading)
          ? LinearProgressIndicator(value: task.progress)
          : Text(
              task.status.toString().split('.').last.toUpperCase(),
              style: TextStyle(
                  fontSize: 12,
                  color: _getStatusColor(task.status),
                  fontWeight: FontWeight.bold),
            ),
      trailing: _buildActionButtons(context, ref),
    );
  }
}