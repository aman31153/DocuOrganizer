import 'package:firebase_database/firebase_database.dart';
import '../models/doc_model.dart';
import '../models/folder_model.dart';

class RealtimeDatabaseService {
  final FirebaseDatabase _db = FirebaseDatabase.instance;

  // Folder operations
  Stream<List<FolderModel>> streamFolders() {
    return _db.ref('folders').onValue.map((event) {
      final data = event.snapshot.value as Map<dynamic, dynamic>?;
      if (data == null) return [];
      return data.entries.map((e) {
        final map = Map<String, dynamic>.from(e.value as Map);
        return FolderModel.fromMap({...map, 'id': e.key});
      }).toList();
    });
  }

  Future<void> addFolder(FolderModel folder) async {
    final newRef = _db.ref('folders').push();
    await newRef.set(folder.toMap());
  }

  Future<void> renameFolder(String id, String newName) {
    return _db.ref('folders').child(id).update({'name': newName});
  }

  Future<void> deleteFolder(String id) async {
    await _db.ref('folders').child(id).remove();
    final docsSnapshot = await _db.ref('documents').orderByChild('folderId').equalTo(id).get();
    if (docsSnapshot.exists) {
      final updates = <String, dynamic>{};
      for (final doc in docsSnapshot.children) {
        updates['${doc.key}/folderId'] = '';
      }
      await _db.ref('documents').update(updates);
    }
  }

  // Document operations
  Stream<List<DocModel>> streamDocs(String? folderId, {bool includeDeleted = false}) {
    Query query = _db.ref('documents');
    if (folderId != null) {
      query = query.orderByChild('folderId').equalTo(folderId);
    }
    
    return query.onValue.map((event) {
      final data = event.snapshot.value as Map<dynamic, dynamic>?;
      if (data == null) return [];
      var list = data.entries.map((e) {
        final map = Map<String, dynamic>.from(e.value as Map);
        return DocModel.fromMap({...map, 'id': e.key});
      }).toList();
      
      if (!includeDeleted) {
        list = list.where((doc) => !doc.isDeleted).toList();
      } else {
        list = list.where((doc) => doc.isDeleted).toList();
      }
      
      list.sort((a, b) => b.uploadDate.compareTo(a.uploadDate));
      return list;
    });
  }

  Future<void> addDocument(DocModel doc) async {
    final newRef = _db.ref('documents').push();
    await newRef.set(doc.toMap());
  }

  Future<void> trashDocument(String id) {
    return _db.ref('documents').child(id).update({'isDeleted': true});
  }

  Future<void> restoreDocument(String id) {
    return _db.ref('documents').child(id).update({'isDeleted': false});
  }

  Future<void> deleteDocumentPermanently(String id) {
    return _db.ref('documents').child(id).remove();
  }

  Future<void> renameDocument(String id, String newName) {
    return _db.ref('documents').child(id).update({'name': newName});
  }

  Future<void> toggleStarDocument(String id, bool isStarred) {
    return _db.ref('documents').child(id).update({'isStarred': isStarred});
  }

  Future<void> moveDocument(String id, String folderId) {
    return _db.ref('documents').child(id).update({'folderId': folderId});
  }
}
