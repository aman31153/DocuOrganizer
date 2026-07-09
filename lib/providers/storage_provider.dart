import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/doc_model.dart';
import '../models/folder_model.dart';
import '../services/realtime_db_service.dart';

final databaseServiceProvider = Provider((ref) => RealtimeDatabaseService());

final foldersStreamProvider = StreamProvider<List<FolderModel>>((ref) {
  return ref.watch(databaseServiceProvider).streamFolders();
});

final docsStreamProvider = StreamProvider.family<List<DocModel>, String?>((ref, folderId) {
  return ref.watch(databaseServiceProvider).streamDocs(folderId);
});

// Everything non-deleted
final allDocsProvider = StreamProvider<List<DocModel>>((ref) {
  return ref.watch(databaseServiceProvider).streamDocs(null);
});

// Trash items
final trashDocsProvider = StreamProvider<List<DocModel>>((ref) {
  return ref.watch(databaseServiceProvider).streamDocs(null, includeDeleted: true);
});

// Limit to top 5 most recent
final recentDocsProvider = StreamProvider<List<DocModel>>((ref) async* {
  final stream = ref.watch(databaseServiceProvider).streamDocs(null);
  yield* stream.map((docs) => docs.take(5).toList());
});

// Files not in any folder (Root files)
final rootDocsProvider = StreamProvider<List<DocModel>>((ref) {
  return ref.watch(databaseServiceProvider).streamDocs('');
});

// Folders with dynamically calculated item counts
final foldersWithCountsProvider = StreamProvider<List<FolderModel>>((ref) async* {
  final foldersAsync = ref.watch(foldersStreamProvider);
  final allDocsAsync = ref.watch(allDocsProvider);
  
  if (foldersAsync.hasValue && allDocsAsync.hasValue) {
    final folders = foldersAsync.value!;
    final docs = allDocsAsync.value!;
    yield folders.map((folder) {
      final count = docs.where((doc) => doc.folderId == folder.id).length;
      return FolderModel(
        id: folder.id,
        name: folder.name,
        itemCount: count,
        color: folder.color,
      );
    }).toList();
  }
});

final totalStorageUsageProvider = Provider<double>((ref) {
  final docs = ref.watch(allDocsProvider).value ?? [];
  return docs.fold(0.0, (total, doc) => total + doc.size);
});

// Theme provider
final themeModeProvider = StateProvider<ThemeMode>((ref) => ThemeMode.light);

