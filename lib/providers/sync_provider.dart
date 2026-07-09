import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/doc_model.dart';
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

class DriveFilesState {
  final List<DocModel> files;
  final String? nextPageToken;
  final bool isLoading;
  final bool isLoadingMore;
  final String currentFilter;
  final String? error;

  DriveFilesState({
    this.files = const [],
    this.nextPageToken,
    this.isLoading = false,
    this.isLoadingMore = false,
    this.currentFilter = 'All files',
    this.error,
  });

  DriveFilesState copyWith({
    List<DocModel>? files,
    String? nextPageToken,
    bool? isLoading,
    bool? isLoadingMore,
    String? currentFilter,
    String? error,
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
    );
  }
}

class DriveFilesNotifier extends StateNotifier<DriveFilesState> {
  final GoogleDriveService _service;

  DriveFilesNotifier(this._service) : super(DriveFilesState()) {
    loadFiles();
  }

  Future<void> loadFiles() async {
    state = state.copyWith(isLoading: true, error: '');
    final query = _buildQuery(state.currentFilter);
    final result = await _service.listDriveFiles(pageToken: null, query: query);
    
    state = state.copyWith(
      files: result.files,
      nextPageToken: result.nextPageToken ?? '',
      isLoading: false,
    );
  }

  Future<void> loadNextPage() async {
    if (state.isLoadingMore || state.nextPageToken == null || state.nextPageToken!.isEmpty) return;
    
    state = state.copyWith(isLoadingMore: true);
    final query = _buildQuery(state.currentFilter);
    final result = await _service.listDriveFiles(pageToken: state.nextPageToken, query: query);
    
    state = state.copyWith(
      files: [...state.files, ...result.files],
      nextPageToken: result.nextPageToken ?? '',
      isLoadingMore: false,
    );
  }

  void setFilter(String filter) {
    if (state.currentFilter == filter) return;
    state = state.copyWith(currentFilter: filter);
    loadFiles();
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
  return DriveFilesNotifier(service);
});

final driveStorageBreakdownProvider = FutureProvider<Map<String, double>>((ref) async {
  final service = ref.watch(googleDriveServiceProvider);
  return await service.calculateStorageBreakdown();
});


