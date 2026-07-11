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

  Future<void> saveRecentDocument(DocModel doc, {String? userId}) async {
    final targetPath = userId != null ? 'users/$userId/recent_documents' : 'recent_documents';
    final ref = _db.ref(targetPath);
    final docRef = ref.child(doc.id);
    final now = DateTime.now().toUtc().toIso8601String();
    final payload = {
      'id': doc.id,
      'name': doc.name,
      'type': doc.type.index,
      'size': doc.size,
      'uploadDate': doc.uploadDate.toUtc().toIso8601String(),
      'url': doc.url,
      'folderId': doc.folderId,
      'isStarred': doc.isStarred,
      'isDeleted': doc.isDeleted,
      'lastOpenedAt': now,
    };

    final existing = await docRef.get();
    if (existing.exists) {
      await docRef.update({'lastOpenedAt': now});
    } else {
      await docRef.set(payload);
    }

    final snapshot = await ref.get();
    if (snapshot.exists) {
      final items = snapshot.children.toList();
      if (items.length > 10) {
        final sortedItems = items
            .map((child) => MapEntry(child, child.child('lastOpenedAt').value?.toString() ?? ''))
            .toList()
          ..sort((a, b) => a.value.compareTo(b.value));
        final extras = items.length - 10;
        for (var i = 0; i < extras; i++) {
          final keyToRemove = sortedItems[i].key.key;
          if (keyToRemove != null) {
            await ref.child(keyToRemove).remove();
          }
        }
      }
    }
  }

  Stream<List<DocModel>> streamRecentDocuments({String? userId}) {
    final ref = userId != null ? _db.ref('users/$userId/recent_documents') : _db.ref('recent_documents');
    return ref.onValue.map((event) {
      final data = event.snapshot.value as Map<dynamic, dynamic>?;
      if (data == null) return [];

      final list = data.entries.map((e) {
        final map = Map<String, dynamic>.from(e.value as Map);
        return DocModel.fromMap({...map, 'id': map['id'] ?? e.key});
      }).toList();

      list.sort((a, b) {
        final aOpened = a.lastOpenedAt ?? a.uploadDate;
        final bOpened = b.lastOpenedAt ?? b.uploadDate;
        return bOpened.compareTo(aOpened);
      });

      return list.take(10).toList();
    });
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
