import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/storage_provider.dart';
import '../models/doc_model.dart';
import 'package:intl/intl.dart';

class TrashScreen extends ConsumerWidget {
  const TrashScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final trashDocsAsync = ref.watch(trashDocsProvider);

    return Scaffold(
      backgroundColor: Colors.grey[50],
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.black),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text(
          'Trash',
          style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold),
        ),
      ),
      body: SafeArea(
        child: trashDocsAsync.when(
          data: (docs) {
          if (docs.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.delete_outline, size: 80, color: Colors.grey[300]),
                  const SizedBox(height: 16),
                  Text(
                    'Trash is empty',
                    style: TextStyle(fontSize: 18, color: Colors.grey[600]),
                  ),
                ],
              ),
            );
          }
          return ListView.builder(
            itemCount: docs.length,
            itemBuilder: (context, index) {
              final doc = docs[index];
              return ListTile(
                leading: const Icon(Icons.insert_drive_file, color: Colors.grey),
                title: Text(doc.name),
                subtitle: Text('Deleted: ${DateFormat('MMM dd, yyyy').format(doc.uploadDate)}'),
                trailing: PopupMenuButton<String>(
                  onSelected: (value) async {
                    if (value == 'Restore') {
                      await ref.read(databaseServiceProvider).restoreDocument(doc.id);
                    } else if (value == 'Delete Permanently') {
                      _showDeletePermanentlyDialog(context, ref, doc);
                    }
                  },
                  itemBuilder: (context) => [
                    const PopupMenuItem(value: 'Restore', child: Text('Restore')),
                    const PopupMenuItem(
                      value: 'Delete Permanently',
                      child: Text('Delete Permanently', style: TextStyle(color: Colors.red)),
                    ),
                  ],
                ),
              );
            },
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (err, stack) => Center(child: Text('Error: $err')),
      ),
      ),
    );
  }

  void _showDeletePermanentlyDialog(BuildContext context, WidgetRef ref, DocModel doc) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Permanently'),
        content: Text('Are you sure you want to permanently delete "${doc.name}"? This action cannot be undone.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
          TextButton(
            onPressed: () async {
              await ref.read(databaseServiceProvider).deleteDocumentPermanently(doc.id);
              if (context.mounted) Navigator.pop(context);
            },
            child: const Text('Delete', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }
}
