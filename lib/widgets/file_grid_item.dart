import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/doc_model.dart';
import '../providers/google_drive_provider.dart';
import '../providers/sync_provider.dart';

class FileGridItem extends ConsumerWidget {
  final DocModel doc;
  final VoidCallback onTap;
  final VoidCallback? onLongPress;
  final bool isSelected;
  final bool isSelectionMode;

  const FileGridItem({
    super.key,
    required this.doc,
    required this.onTap,
    this.onLongPress,
    this.isSelected = false,
    this.isSelectionMode = false,
  });

  IconData _getFileIcon(DocType type) {
    switch (type) {
      case DocType.pdf: return Icons.picture_as_pdf;
      case DocType.ppt: return Icons.slideshow;
      case DocType.doc: return Icons.description;
      case DocType.xls: return Icons.table_chart;
      case DocType.txt: return Icons.text_snippet;
      case DocType.image: return Icons.image;
      case DocType.video: return Icons.videocam;
      case DocType.folder: return Icons.folder;
      default: return Icons.insert_drive_file;
    }
  }

  Color _getFileColor(DocType type) {
    switch (type) {
      case DocType.pdf: return Colors.red;
      case DocType.ppt: return Colors.orange;
      case DocType.doc: return Colors.blue;
      case DocType.xls: return Colors.green;
      case DocType.image: return Colors.purple;
      case DocType.video: return Colors.deepPurple;
      case DocType.folder: return Colors.amber;
      default: return Colors.grey;
    }
  }

  Future<void> _showRenameDialog(BuildContext context, WidgetRef ref) async {
    final controller = TextEditingController(text: doc.name);
    final result = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Rename File'),
        content: TextField(controller: controller, autofocus: true),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
          TextButton(onPressed: () => Navigator.pop(context, true), child: const Text('Rename')),
        ],
      ),
    );

    if (result == true && controller.text.isNotEmpty && controller.text != doc.name) {
      final newName = controller.text.trim();
      try {
        await ref.read(googleDriveServiceProvider).renameFile(doc.id, newName);
        ref.read(driveFilesNotifierProvider.notifier).loadFiles();
      } catch (e) {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
        }
      }
    }
  }

  void _showDeleteConfirmation(BuildContext context, WidgetRef ref) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete File'),
        content: Text('Are you sure you want to delete ${doc.name}?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
          TextButton(
            onPressed: () async {
              Navigator.pop(context);
              try {
                await ref.read(googleDriveServiceProvider).deleteFile(doc.id);
                ref.read(driveFilesNotifierProvider.notifier).loadFiles();
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('File deleted from Google Drive')),
                  );
                }
              } catch (e) {
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Delete failed: $e')));
                }
              }
            },
            child: const Text('Delete', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final fileColor = _getFileColor(doc.type);
    final fileIcon = _getFileIcon(doc.type);

    return InkWell(
      onTap: onTap,
      onLongPress: onLongPress,
      borderRadius: BorderRadius.circular(12),
      child: Card(
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
          side: BorderSide(color: isSelected ? Colors.blue : Colors.grey.withOpacity(0.2), width: isSelected ? 2 : 1),
        ),
        child: Stack(
          children: [
            Padding(
              padding: const EdgeInsets.all(12.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Icon(fileIcon, color: fileColor, size: 32),
                      if (!isSelectionMode)
                        PopupMenuButton<String>(
                          icon: const Icon(Icons.more_vert, size: 20),
                          onSelected: (value) async {
                            if (value == 'Rename') await _showRenameDialog(context, ref);
                            if (value == 'Delete') _showDeleteConfirmation(context, ref);
                          },
                          itemBuilder: (context) => [
                            const PopupMenuItem(value: 'Rename', child: Text('Rename')),
                            const PopupMenuItem(value: 'Delete', child: Text('Delete')),
                          ],
                        ),
                    ],
                  ),
                  const Spacer(),
                  Text(doc.name, maxLines: 2, overflow: TextOverflow.ellipsis, style: const TextStyle(fontWeight: FontWeight.w500, fontSize: 13)),
                  const SizedBox(height: 4),
                  Text('${doc.size.toStringAsFixed(2)} MB', style: TextStyle(fontSize: 11, color: Colors.grey[600])),
                ],
              ),
            ),
            if (isSelectionMode)
              Positioned(
                top: 4,
                left: 4,
                child: Container(
                  width: 20,
                  height: 20,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: isSelected ? Colors.blue : Colors.white,
                    border: Border.all(color: Colors.grey.shade400, width: 1.5),
                  ),
                  child: isSelected ? const Icon(Icons.check, color: Colors.white, size: 14) : null,
                ),
              ),
          ],
        ),
      ),
    );
  }
}