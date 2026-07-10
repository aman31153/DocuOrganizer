import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/legacy.dart';
import '../models/doc_model.dart';
import '../services/google_drive_service.dart';
import 'auth_provider.dart';

final googleDriveServiceProvider = Provider((ref) {
  return GoogleDriveService(ref.watch(googleSignInProvider));
});

final googleDriveFilesProvider = FutureProvider<List<DocModel>>((ref) async {
  final service = ref.watch(googleDriveServiceProvider);
  final result = await service.listDriveFiles();
  return result.files;
});

final googleDriveStorageProvider = FutureProvider<Map<String, double>?>((ref) async {
  final service = ref.watch(googleDriveServiceProvider);
  return await service.getStorageUsageBytes();
});

final googleDriveFilterProvider = StateProvider<String>((ref) => 'All');
