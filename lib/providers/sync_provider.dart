import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/legacy.dart';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/doc_model.dart';
import '../models/drive_result_model.dart';
import '../services/google_drive_service.dart';
import '../providers/google_drive_provider.dart';
import 'storage_provider.dart';

final sharedPreferencesProvider = Provider<SharedPreferences>((ref) {
  throw UnimplementedError('Initialize this provider in ProviderScope overrides');
});

class GoogleDriveSyncNotifier extends StateNotifier<bool> {
  final SharedPreferences _prefs;
  static const _key = 'google_drive_sync_enabled';

  GoogleDriveSyncNotifier(this._prefs) : super(_prefs.getBool(_key) ?? false);

  void toggle(bool value) {
    state = value;
    _prefs.setBool(_key, value);
  }
}

final googleDriveSyncProvider = StateNotifierProvider<GoogleDriveSyncNotifier, bool>((ref) {
  final prefs = ref.watch(sharedPreferencesProvider);
  return GoogleDriveSyncNotifier(prefs);
});

final googleDriveUsageProvider = FutureProvider<Map<String, double>>((ref) async {
  ref.watch(allDocsProvider);

  final service = ref.read(googleDriveServiceProvider);
  final data = await service.getStorageUsageBytes();
  if (data == null) {
    return {'usage': 0.0, 'limit': 15.0 * 1024};
  }
  return {
    'usage': data['usage']! / (1024 * 1024),
    'limit': data['limit']! / (1024 * 1024)
  };
});

final homeDriveFilesProvider = FutureProvider<List<DocModel>>((ref) async {
  final service = ref.watch(googleDriveServiceProvider);
  final result = await service.listDriveFiles(
    query: "trashed = false",
    orderBy: 'modifiedTime desc',
  );
  return result.files.isEmpty ? <DocModel>[] : result.files.take(5).toList();
});

enum DriveViewType { list, grid }

class DriveFilesState {
  final List<DocModel> files;
  final String? nextPageToken;
  final bool isLoading;
  final bool isLoadingMore;
  final String currentFilter;
  final String? error;
  final String sortOrder;
  final DriveViewType viewType;
  final bool isSelectionMode;
  final Set<String> selectedFileIds;

  DriveFilesState({
    this.files = const [],
    this.nextPageToken,
    this.isLoading = false,
    this.isLoadingMore = false,
    this.currentFilter = 'All files',
    this.error,
    this.sortOrder = 'modifiedTime desc',
    this.viewType = DriveViewType.list,
    this.isSelectionMode = false,
    this.selectedFileIds = const {},
  });

  DriveFilesState copyWith({
    List<DocModel>? files,
    String? nextPageToken,
    bool? isLoading,
    bool? isLoadingMore,
    String? currentFilter,
    String? error,
    String? sortOrder,
    DriveViewType? viewType,
    bool? isSelectionMode,
    Set<String>? selectedFileIds,
  }) {
    // Note: We need a way to explicitly set nextPageToken or error to null.
    // In this simple implementation, if we pass an empty string to error, we treat it as null.
    return DriveFilesState(
      files: files ?? this.files,
      nextPageToken: nextPageToken == '' ? null : (nextPageToken ?? this.nextPageToken),
      isLoading: isLoading ?? this.isLoading,
      isLoadingMore: isLoadingMore ?? this.isLoadingMore,
      currentFilter: currentFilter ?? this.currentFilter,
      error: error == '' ? null : (error ?? this.error),
      sortOrder: sortOrder ?? this.sortOrder,
      viewType: viewType ?? this.viewType,
      isSelectionMode: isSelectionMode ?? this.isSelectionMode,
      selectedFileIds: selectedFileIds ?? this.selectedFileIds,
    );
  }
}

class DriveFilesNotifier extends StateNotifier<DriveFilesState> {
  final GoogleDriveService _service;
  final Ref _ref;

  DriveFilesNotifier(this._service, this._ref) : super(DriveFilesState()) {
    loadFiles();
  }

  Future<void> loadFiles() async {
    state = state.copyWith(isLoading: true, error: '');
    final query = _buildQuery(state.currentFilter);
    try {
      final DrivePaginatedResult result = await _service.listDriveFiles(pageToken: null, query: query, orderBy: state.sortOrder);
      
      state = state.copyWith(
        files: result.files,
        nextPageToken: result.nextPageToken ?? '',
        isLoading: false,
      );
    } catch (e) {
      state = state.copyWith(isLoading: false, error: e.toString());
    }
  }

  Future<void> loadNextPage() async {
    if (state.isLoadingMore || state.nextPageToken == null || state.nextPageToken!.isEmpty) return;
    
    state = state.copyWith(isLoadingMore: true);
    final query = _buildQuery(state.currentFilter);
    try {
      final DrivePaginatedResult result = await _service.listDriveFiles(pageToken: state.nextPageToken, query: query, orderBy: state.sortOrder);
      
      state = state.copyWith(
        files: [...state.files, ...result.files],
        nextPageToken: result.nextPageToken ?? '',
        isLoadingMore: false,
      );
    } catch (e) {
      state = state.copyWith(isLoadingMore: false, error: e.toString());
    }
  }

  void setFilter(String filter) {
    if (state.currentFilter == filter) return;
    state = state.copyWith(currentFilter: filter);
    loadFiles();
  }

  void setSortOrder(String sortOrder) {
    if (state.sortOrder == sortOrder) return;
    state = state.copyWith(sortOrder: sortOrder);
    loadFiles();
  }

  void setViewType(DriveViewType viewType) {
    if (state.viewType == viewType) return;
    state = state.copyWith(viewType: viewType);
  }

  void toggleFileSelection(String fileId) {
    final newSelectedIds = Set<String>.from(state.selectedFileIds);
    if (newSelectedIds.contains(fileId)) {
      newSelectedIds.remove(fileId);
    } else {
      newSelectedIds.add(fileId);
    }

    state = state.copyWith(
      selectedFileIds: newSelectedIds,
      isSelectionMode: newSelectedIds.isNotEmpty,
    );
  }

  void selectAllFiles() {
    final allFileIds = state.files.map((f) => f.id).toSet();
    state = state.copyWith(selectedFileIds: allFileIds);
  }

  void clearSelection() {
    state = state.copyWith(
      selectedFileIds: {},
      isSelectionMode: false,
    );
  }

  Future<void> moveSelectedFiles(String newParentId) async {
    final filesToMove = <String, String>{};
    final selectedIds = state.selectedFileIds;

    for (final file in state.files) {
      if (selectedIds.contains(file.id)) {
        // Don't try to move a file into its own parent
        if (file.folderId != newParentId) {
          filesToMove[file.id] = file.folderId;
        }
      }
    }

    if (filesToMove.isEmpty) {
      clearSelection();
      return;
    }

    // Optimistically remove files from the current view.
    final newFiles = state.files.where((f) => !filesToMove.keys.contains(f.id)).toList();
    state = state.copyWith(files: newFiles, selectedFileIds: {}, isSelectionMode: false);

    try {
      await _service.moveFiles(filesToMove, newParentId);
    } catch (e) {
      debugPrint('Failed to move files: $e');
      loadFiles(); // Reload to show correct state on error
    }
  }

  Future<void> deleteSelectedFiles() async {
    final idsToDelete = List<String>.from(state.selectedFileIds);
    if (idsToDelete.isEmpty) return;

    final newFiles = state.files.where((f) => !idsToDelete.contains(f.id)).toList();
    state = state.copyWith(files: newFiles, selectedFileIds: {}, isSelectionMode: false);

    try {
      await _service.deleteFiles(idsToDelete);
      _ref.invalidate(googleDriveUsageProvider);
      _ref.invalidate(driveStorageBreakdownProvider);
    } catch (e) {
      debugPrint('Failed to delete files: $e');
    }
  }

  String _buildQuery(String filter) {
    switch (filter) {
      case 'Images':
        return "mimeType contains 'image/'";
      case 'Videos':
        return "mimeType contains 'video/'";
      case 'Documents':
        return "mimeType contains 'application/vnd.google-apps.document' or mimeType contains 'application/pdf' or mimeType contains 'text/'";
      case 'Spreadsheets':
        return "mimeType contains 'application/vnd.google-apps.spreadsheet'";
      case 'Folders':
        return "mimeType = 'application/vnd.google-apps.folder'";
      case 'Others':
        return "mimeType != 'application/vnd.google-apps.folder' and not mimeType contains 'image/' and not mimeType contains 'video/' and not mimeType contains 'application/vnd.google-apps.document' and not mimeType contains 'application/pdf' and not mimeType contains 'text/' and not mimeType contains 'application/vnd.google-apps.spreadsheet'";
      default:
        return '';
    }
  }
}

final driveFilesNotifierProvider = StateNotifierProvider<DriveFilesNotifier, DriveFilesState>((ref) {
  final service = ref.watch(googleDriveServiceProvider);
  return DriveFilesNotifier(service, ref);
});

final driveStorageBreakdownProvider = FutureProvider<Map<String, double>>((ref) async {
  final service = ref.watch(googleDriveServiceProvider);
  return await service.calculateStorageBreakdown();
});
