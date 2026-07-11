import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/download_provider.dart';

class DownloadStatusPanel extends ConsumerWidget {
  const DownloadStatusPanel({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final downloads = ref.watch(downloadProvider);

    if (downloads.isEmpty) {
      return const ListTile(
        dense: true,
        leading: Icon(Icons.download_done_outlined, color: Colors.grey),
        title: Text('No active downloads'),
        subtitle: Text('Start a bulk download from Google Drive.'),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: downloads.map((task) {
        return ListTile(
          dense: true,
          leading: _buildStatusIcon(task.status),
          title: Text(task.fileName,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontSize: 14)),
          subtitle: task.status == DownloadStatus.downloading
              ? Padding(
                  padding: const EdgeInsets.only(top: 4.0, right: 16.0),
                  child: LinearProgressIndicator(
                    value: task.progress,
                    backgroundColor: Colors.grey[300],
                  ),
                )
              : Text('Status: ${task.status.name}',
                  style: const TextStyle(fontSize: 12)),
          trailing: Text('${(task.progress * 100).toStringAsFixed(0)}%'),
        );
      }).toList(),
    );
  }

  Widget _buildStatusIcon(DownloadStatus status) {
    switch (status) {
      case DownloadStatus.pending:
        return const Icon(Icons.schedule_outlined, color: Colors.grey);
      case DownloadStatus.downloading:
        return const SizedBox(
            width: 24, height: 24, child: CircularProgressIndicator(strokeWidth: 2.5));
      case DownloadStatus.completed:
        return const Icon(Icons.check_circle_outline, color: Colors.green);
      case DownloadStatus.failed:
        return const Icon(Icons.error_outline, color: Colors.red);
      default:
        return const Icon(Icons.help_outline, color: Colors.grey);
    }
  }
}