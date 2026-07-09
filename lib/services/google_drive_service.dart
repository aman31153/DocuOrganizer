import 'package:shared_preferences/shared_preferences.dart';
import 'dart:io';
import 'package:flutter/foundation.dart';
import '../models/drive_result_model.dart';
import '../models/doc_model.dart';
import 'package:googleapis/drive/v3.dart' as drive;
import 'package:google_sign_in/google_sign_in.dart';
import 'package:extension_google_sign_in_as_googleapis_auth/extension_google_sign_in_as_googleapis_auth.dart';

class GoogleDriveService {
  final GoogleSignIn _googleSignIn;
  
  GoogleDriveService(this._googleSignIn);

  Future<drive.DriveApi?> _getDriveApi() async {
    var client = await _googleSignIn.authenticatedClient();
    if (client == null) {
      try {
        final account = await _googleSignIn.signInSilently();
        if (account != null) {
          client = await _googleSignIn.authenticatedClient();
        }
      } catch (e) {
        debugPrint('Silent sign in failed: $e');
      }
    }

    if (client == null) return null;
    return drive.DriveApi(client);
  }

  Future<String?> uploadFile(File file, String fileName) async {
    try {
      final driveApi = await _getDriveApi();
      if (driveApi == null) {
        throw Exception("Not authenticated with Google. Please log out and log in again to grant Drive permissions.");
      }

      final driveFile = drive.File();
      driveFile.name = fileName;
      
      final media = drive.Media(file.openRead(), file.lengthSync());
      
      final result = await driveApi.files.create(
        driveFile, 
        uploadMedia: media,
        $fields: 'id, webViewLink, webContentLink',
      );
      
      return result.webViewLink ?? result.webContentLink ?? result.id;
    } catch (e) {
      debugPrint('Google Drive Upload Exception: $e');
      rethrow;
    }
  }

  Future<Map<String, double>?> getStorageUsageBytes() async {
    try {
      final driveApi = await _getDriveApi();
      if (driveApi == null) return null;
      
      final about = await driveApi.about.get($fields: "storageQuota");
      final quota = about.storageQuota;
      if (quota != null) {
        final usage = double.tryParse(quota.usage ?? '0') ?? 0.0;
        final limit = double.tryParse(quota.limit ?? '0') ?? 0.0;
        return {'usage': usage, 'limit': limit};
      }
      return null;
    } catch (e) {
      debugPrint('Google Drive Quota Exception: $e');
      return null;
    }
  }

  Future<DrivePaginatedResult> listDriveFiles({String? pageToken, String query = '', String? orderBy}) async {
    try {
      final driveApi = await _getDriveApi();
      if (driveApi == null) return DrivePaginatedResult([], null);
      
      String finalQuery = "trashed = false";
      if (query.isNotEmpty) {
        finalQuery += " and ($query)";
      }
      
      final fileList = await driveApi.files.list(
        $fields: 'nextPageToken, files(id, name, mimeType, size, quotaBytesUsed, createdTime, webViewLink, parents)',
        q: finalQuery,
        pageSize: 10,
        orderBy: orderBy,
        pageToken: pageToken,
      );
      
      final List<DocModel> docs = (fileList.files ?? []).map((file) {
        final sizeBytes = double.tryParse(file.quotaBytesUsed ?? file.size ?? '0') ?? 0.0;
        final sizeMB = sizeBytes / (1024 * 1024);
        
        return DocModel(
          id: file.id ?? '',
          name: file.name ?? 'Unknown',
          type: _getDocTypeFromMime(file.mimeType ?? ''),
          size: sizeMB,
          uploadDate: file.createdTime ?? DateTime.now(),
          url: file.webViewLink ?? '',
          folderId: file.parents?.first ?? 'root',
        );
      }).toList();
      
      return DrivePaginatedResult(docs, fileList.nextPageToken);
    } catch (e) {
      debugPrint('Google Drive List Exception: $e');
      return DrivePaginatedResult([], null);
    }
  }


  Future<void> clearStorageBreakdownCache() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('drive_storage_last_update');
  }

  Future<Map<String, double>> calculateStorageBreakdown() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final lastUpdate = prefs.getInt('drive_storage_last_update') ?? 0;
      final now = DateTime.now().millisecondsSinceEpoch;
      
      if (now - lastUpdate < 3600000) {
        return {
          'videoSize': prefs.getDouble('drive_video_size') ?? 0.0,
          'docSize': prefs.getDouble('drive_doc_size') ?? 0.0,
          'imageSize': prefs.getDouble('drive_image_size') ?? 0.0,
          'othersSize': prefs.getDouble('drive_others_size') ?? 0.0,
        };
      }

      final driveApi = await _getDriveApi();
      if (driveApi == null) return {'videoSize': 0.0, 'docSize': 0.0, 'imageSize': 0.0, 'othersSize': 0.0};
      
      double videoSize = 0;
      double docSize = 0;
      double imageSize = 0;
      double othersSize = 0;
      String? pageToken;
      int pageCount = 0;
      
      do {
        final fileList = await driveApi.files.list(
          $fields: 'nextPageToken, files(mimeType, size, quotaBytesUsed)',
          q: "mimeType != 'application/vnd.google-apps.folder' and trashed = false",
          pageSize: 1000,
          pageToken: pageToken,
        );
        
        for (var file in (fileList.files ?? [])) {
          final sizeBytes = double.tryParse(file.quotaBytesUsed ?? file.size ?? '0') ?? 0.0;
          final type = _getDocTypeFromMime(file.mimeType ?? '');
          if (type == DocType.video) videoSize += sizeBytes;
          else if (type == DocType.doc || type == DocType.pdf || type == DocType.txt || type == DocType.ppt || type == DocType.xls) docSize += sizeBytes;
          else if (type == DocType.image) imageSize += sizeBytes;
          else othersSize += sizeBytes;
        }
        
        pageToken = fileList.nextPageToken;
        pageCount++;
      } while (pageToken != null && pageCount < 5);
      
      final videoSizeMB = videoSize / (1024 * 1024);
      final docSizeMB = docSize / (1024 * 1024);
      final imageSizeMB = imageSize / (1024 * 1024);
      final othersSizeMB = othersSize / (1024 * 1024);

      final result = {
        'videoSize': videoSizeMB,
        'docSize': docSizeMB,
        'imageSize': imageSizeMB,
        'othersSize': othersSizeMB,
      };
      
      prefs.setDouble('drive_video_size', videoSizeMB);
      prefs.setDouble('drive_doc_size', docSizeMB);
      prefs.setDouble('drive_image_size', imageSizeMB);
      prefs.setDouble('drive_others_size', othersSizeMB);
      prefs.setInt('drive_storage_last_update', now);
      
      return result;
    } catch (e) {
      debugPrint('Google Drive Breakdown Exception: $e');
      return {'videoSize': 0.0, 'docSize': 0.0, 'imageSize': 0.0, 'othersSize': 0.0};
    }
  }


  Future<void> deleteFile(String fileId) async {
    try {
      final driveApi = await _getDriveApi();
      if (driveApi == null) return;
      await driveApi.files.delete(fileId);
    } catch (e) {
      debugPrint('Google Drive Delete Exception: $e');
      rethrow;
    }
  }

  Future<void> moveFiles(Map<String, String> filesToMove, String newParentId) async {
    try {
      final driveApi = await _getDriveApi();
      if (driveApi == null) return;

      final futures = filesToMove.entries.map((entry) {
        final fileId = entry.key;
        final oldParentId = entry.value;
        // A file must have at least one parent, so we can't remove the last one without adding a new one.
        return driveApi.files.update(drive.File(), fileId, addParents: newParentId, removeParents: oldParentId);
      });

      await Future.wait(futures);
    } catch (e) {
      debugPrint('Google Drive Batch Move Exception: $e');
      rethrow;
    }
  }

  Future<void> deleteFiles(List<String> fileIds) async {
    try {
      final driveApi = await _getDriveApi();
      if (driveApi == null) return;

      // The Dart client library doesn't have a great batching API out of the box for this.
      // We'll just loop and send requests in parallel.
      final deleteFutures = fileIds.map((id) => driveApi.files.delete(id));
      await Future.wait(deleteFutures);
    } catch (e) {
      debugPrint('Google Drive Batch Delete Exception: $e');
      rethrow;
    }
  }

  Future<void> renameFile(String fileId, String newName) async {
    try {
      final driveApi = await _getDriveApi();
      if (driveApi == null) return;
      final driveFile = drive.File();
      driveFile.name = newName;
      await driveApi.files.update(driveFile, fileId);
    } catch (e) {
      debugPrint('Google Drive Rename Exception: $e');
      rethrow;
    }
  }

  DocType _getDocTypeFromMime(String mimeType) {
    if (mimeType == 'application/vnd.google-apps.folder') return DocType.folder;
    if (mimeType.contains('pdf')) return DocType.pdf;
    if (mimeType.contains('presentation') || mimeType.contains('powerpoint')) return DocType.ppt;
    if (mimeType.contains('document') || mimeType.contains('word')) return DocType.doc;
    if (mimeType.contains('spreadsheet') || mimeType.contains('excel')) return DocType.xls;
    if (mimeType.contains('text')) return DocType.txt;
    if (mimeType.contains('image')) return DocType.image;
    if (mimeType.contains('video')) return DocType.video;
    return DocType.other;
  }
}
