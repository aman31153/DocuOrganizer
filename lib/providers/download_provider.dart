import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/legacy.dart';
import 'package:googleapis/drive/v3.dart' as drive;
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../providers/storage_provider.dart';
import '../services/google_drive_service.dart';
import '../services/notification_service.dart';
import 'google_drive_provider.dart';

enum DownloadStatus { pending, downloading, completed, failed, canceled }

class DownloadTask {
  final String fileId;
  final String fileName;
  final double progress;
  final DownloadStatus status;

  DownloadTask({
    required this.fileId,
    required this.fileName,
    this.progress = 0.0,
    this.status = DownloadStatus.pending,
  });

  DownloadTask copyWith({
    String? fileName,
    double? progress,
    DownloadStatus? status,
  }) {
    return DownloadTask(
      fileId: fileId,
      fileName: fileName ?? this.fileName,
      progress: progress ?? this.progress,
      status: status ?? this.status,
    );
  }
}

class DownloadNotifier extends StateNotifier<List<DownloadTask>> {
  DownloadNotifier(this.ref) : super([]);

  final Ref ref;
  final _notificationService = NotificationService();

  Future<void> startBulkDownload(List<String> fileIds) async {
    final driveApi = await ref.read(googleDriveServiceProvider).getDriveApi();
    if (driveApi == null) {
      return;
    }

    final List<DownloadTask> newTasks = [];

    for (final fileId in fileIds) {
      // Avoid adding duplicates that are already pending, downloading, or completed.
      if (state.any((task) => task.fileId == fileId && (task.status == DownloadStatus.pending || task.status == DownloadStatus.downloading || task.status == DownloadStatus.completed))) {
        continue;
      }
      try {
        final file =
            await driveApi.files.get(fileId, $fields: 'name') as drive.File;
        newTasks.add(DownloadTask(fileId: fileId, fileName: file.name ?? 'Unknown File'));
      } catch (e) {
        newTasks.add(DownloadTask(fileId: fileId, fileName: 'Failed to get metadata', status: DownloadStatus.failed));
      }
    }
    state = [...state, ...newTasks];

    _downloadFilesConcurrently();
  }

  void _downloadFilesConcurrently() async {
    final driveApi = await ref.read(googleDriveServiceProvider).getDriveApi();
    final downloadPath = await _getDownloadPath();
    final maxConcurrent = ref.read(maxConcurrentDownloadsProvider);

    if (driveApi == null || downloadPath == null) return;

    final queue =
        List<DownloadTask>.from(state.where((t) => t.status == DownloadStatus.pending));
    final running = <Future>[];

    void runNext() {
      while (running.length < maxConcurrent && queue.isNotEmpty) {
        final task = queue.removeAt(0);
        final downloadFuture = _downloadFile(task, driveApi, downloadPath);
        running.add(downloadFuture);
        downloadFuture.whenComplete(() {
          running.remove(downloadFuture);
          runNext();
        });
      }
    }

    runNext();
  }

  Future<void> _downloadFile(
      DownloadTask task, drive.DriveApi driveApi, String downloadPath) async {
    final notificationId = task.fileId.hashCode;
    double lastNotifiedProgress = -1.0;
    state = [ for (final t in state) if (t.fileId == task.fileId) t.copyWith(status: DownloadStatus.downloading) else t ];

    try {
      final media = await driveApi.files.get(task.fileId, downloadOptions: drive.DownloadOptions.fullMedia) as drive.Media;
      final file = File('$downloadPath/${task.fileName}');
      final sink = file.openWrite();

      int received = 0;
      final total = media.length ?? 0;

      await media.stream.map((chunk) {
        received += chunk.length;
        if (total > 0) {
          // Check for cancellation mid-stream
          final currentTaskStatus = state.firstWhere((t) => t.fileId == task.fileId, orElse: () => task).status;
          if (currentTaskStatus == DownloadStatus.canceled) {
            throw Exception('Download Canceled');
          }

          final progress = (received / total).clamp(0.0, 1.0);
          state = [ for (final t in state) if (t.fileId == task.fileId) t.copyWith(progress: progress) else t ];

          // Throttle notification updates
          if (progress - lastNotifiedProgress > 0.1 || progress == 1.0) {
            lastNotifiedProgress = progress;
            _notificationService.showProgressNotification(
              id: notificationId,
              title: task.fileName,
              body: '${(progress * 100).round()}% complete',
              progress: (progress * 100).round(),
              maxProgress: 100,
            );
          }
        }
        return chunk;
      }).pipe(sink);

      // Only update status if it hasn't been canceled in the meantime.
      final currentTask = state.firstWhere((t) => t.fileId == task.fileId, orElse: () => task);
      if (currentTask.status != DownloadStatus.canceled) {
        state = [ for (final t in state) if (t.fileId == task.fileId) t.copyWith(status: DownloadStatus.completed, progress: 1.0) else t ];
        _notificationService.showCompletedNotification(
            id: notificationId,
            title: task.fileName,
            body: 'Download complete');
      }
    } catch (e) {
      final currentTask = state.firstWhere((t) => t.fileId == task.fileId, orElse: () => task);
      if (currentTask.status != DownloadStatus.canceled && e.toString() != 'Exception: Download Canceled') {
        state = [ for (final t in state) if (t.fileId == task.fileId) t.copyWith(status: DownloadStatus.failed) else t ];
        _notificationService.showFailedNotification(
            id: notificationId, title: task.fileName, body: 'Download failed');
      }
    }
  }

  Future<String?> _getDownloadPath() async {
    final customPath = ref.read(downloadPathProvider);
    if (customPath != null && customPath.isNotEmpty) {
      final dir = Directory(customPath);
      if (await dir.exists()) {
        return customPath;
      }
    }

    final directory = await getDownloadsDirectory();
    return directory?.path;
  }

  void cancelDownload(String fileId) {
    final taskIndex = state.indexWhere((t) => t.fileId == fileId);
    if (taskIndex == -1) return;

    final task = state[taskIndex];
    if (task.status == DownloadStatus.pending || task.status == DownloadStatus.downloading) {
      final updatedTasks = List<DownloadTask>.from(state);
      updatedTasks[taskIndex] = task.copyWith(status: DownloadStatus.canceled);
      state = updatedTasks;
      _notificationService.cancelNotification(fileId.hashCode);
    }
  }

  void retryDownload(String fileId) {
    final taskIndex = state.indexWhere((t) => t.fileId == fileId);
    if (taskIndex == -1) return;

    final task = state[taskIndex];
    if (task.status == DownloadStatus.failed || task.status == DownloadStatus.canceled) {
      final updatedTasks = List<DownloadTask>.from(state);
      updatedTasks[taskIndex] = task.copyWith(status: DownloadStatus.pending, progress: 0.0);
      state = updatedTasks;
      _downloadFilesConcurrently();
    }
  }

  void clearTask(String fileId) {
    _notificationService.cancelNotification(fileId.hashCode);
    state = state.where((task) => task.fileId != fileId).toList();
  }

  void clearCompletedDownloads() {
    final tasksToClear = state.where((task) => task.status == DownloadStatus.completed);
    for (final task in tasksToClear) {
      _notificationService.cancelNotification(task.fileId.hashCode);
    }
    state = state.where((task) => task.status != DownloadStatus.completed).toList();
  }

  void clearFailedAndCanceledDownloads() {
    final tasksToClear = state.where((task) => task.status == DownloadStatus.failed || task.status == DownloadStatus.canceled);
    for (final task in tasksToClear) {
      _notificationService.cancelNotification(task.fileId.hashCode);
    }
    state = state.where((task) => task.status != DownloadStatus.failed && task.status != DownloadStatus.canceled).toList();
  }
}

final downloadProvider =
    StateNotifierProvider<DownloadNotifier, List<DownloadTask>>((ref) {
  return DownloadNotifier(ref);
});

class DownloadPathNotifier extends StateNotifier<String?> {
  DownloadPathNotifier() : super(null);

  Future<void> setPath(String path) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('download_path', path);
    state = path;
  }
}

class MaxConcurrentDownloadsNotifier extends StateNotifier<int> {
  MaxConcurrentDownloadsNotifier() : super(3);

  Future<void> setLimit(int limit) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt('max_concurrent_downloads', limit);
    state = limit;
  }
}

final downloadPathProvider = StateNotifierProvider<DownloadPathNotifier, String?>((ref) {
  return DownloadPathNotifier();
});

final maxConcurrentDownloadsProvider = StateNotifierProvider<MaxConcurrentDownloadsNotifier, int>((ref) {
  return MaxConcurrentDownloadsNotifier();
});