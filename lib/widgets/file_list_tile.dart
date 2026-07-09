import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/doc_model.dart';
import '../providers/storage_provider.dart';
import 'package:intl/intl.dart';

import '../services/google_drive_service.dart';
import '../providers/google_drive_provider.dart';
import '../providers/sync_provider.dart';

class FileListTile extends ConsumerStatefulWidget {
  final DocModel doc;
  final VoidCallback onTap;
  final VoidCallback? onLongPress;
  final bool isSelected;
  final bool isSelectionMode;

  const FileListTile({
    super.key,
    required this.doc,
    required this.onTap,
    this.onLongPress,
    this.isSelected = false,
    this.isSelectionMode = false,
  });

  @override
  ConsumerState<FileListTile> createState() => _FileListTileState();
}

class _FileListTileState extends ConsumerState<FileListTile> {
  late String _localName;

  @override
  void initState() {
    super.initState();
    _localName = widget.doc.name;
  }

  @override
  void didUpdateWidget(FileListTile oldWidget) {
    super.didUpdateWidget(oldWidget);
    // Only update local state if the incoming doc name actually changed in the DB
    if (widget.doc.name != oldWidget.doc.name) {
      setState(() {
        _localName = widget.doc.name;
      });
    }
  }

  IconData _getFileIcon() {
    switch (widget.doc.type) {
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

  Color _getFileColor() {
    switch (widget.doc.type) {
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

  Future<void> _showRenameDialog() async {
    final controller = TextEditingController(text: _localName);
    final result = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Rename File'),
        content: TextField(
          controller: controller,
          decoration: const InputDecoration(hintText: 'New Name'),
          autofocus: true,
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
          TextButton(onPressed: () => Navigator.pop(context, true), child: const Text('Rename')),
        ],
      ),
    );

    if (result == true && controller.text.isNotEmpty && controller.text != _localName) {
      final newName = controller.text.trim();
      setState(() {
        _localName = newName; // Update UI immediately
      });
      try {
        if (widget.doc.url.contains('drive.google.com')) {
          await ref.read(googleDriveServiceProvider).renameFile(widget.doc.id, newName);
          ref.read(driveFilesNotifierProvider.notifier).loadFiles();
        } else {
          await ref.read(databaseServiceProvider).renameDocument(widget.doc.id, newName);
        }
      } catch (e) {
        if (mounted) {
          setState(() { _localName = widget.doc.name; }); // Rollback on error
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
        }
      }
    }
  }

  void _showMoveDialog() {
    final folders = ref.read(foldersStreamProvider).value ?? [];
    
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Move to Folder'),
        content: SizedBox(
          width: double.maxFinite,
          child: folders.isEmpty 
            ? const Text('No folders available.') 
            : ListView.builder(
                shrinkWrap: true,
                itemCount: folders.length,
                itemBuilder: (context, index) {
                  final folder = folders[index];
                  if (folder.id == widget.doc.folderId) return const SizedBox.shrink();
                  
                  return ListTile(
                    leading: const Icon(Icons.folder, color: Colors.amber),
                    title: Text(folder.name),
                    onTap: () async {
                      Navigator.pop(context);
                      try {
                        await ref.read(databaseServiceProvider).moveDocument(widget.doc.id, folder.id);
                        if (mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(content: Text('Moved "${_localName}" to ${folder.name}')),
                          );
                        }
                      } catch (e) {
                        if (mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Move failed: $e')));
                        }
                      }
                    },
                  );
                },
              ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final selectedColor = isDark ? Colors.blue.withOpacity(0.3) : Colors.blue.withOpacity(0.1);

    return Material(
      color: widget.isSelected ? selectedColor : Colors.transparent,
      child: ListTile(
        onTap: widget.onTap,
        onLongPress: widget.onLongPress,
        leading: widget.isSelectionMode
            ? CircleAvatar(
                backgroundColor: widget.isSelected ? Colors.blue : Colors.grey.shade300,
                child: widget.isSelected
                    ? const Icon(Icons.check, color: Colors.white)
                    : Icon(_getFileIcon(), color: _getFileColor(), size: 20),
              )
            : Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: _getFileColor().withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(_getFileIcon(), color: _getFileColor()),
              ),
        title: Text(
          _localName,
          style: const TextStyle(fontWeight: FontWeight.w500, fontSize: 14),
        ),
        subtitle: Text(
          '${DateFormat('MMM dd, yyyy').format(widget.doc.uploadDate)} • ${widget.doc.size.toStringAsFixed(2)} MB',
          style: TextStyle(fontSize: 12, color: Colors.grey[600]),
        ),
        trailing: widget.isSelectionMode
            ? null
            : PopupMenuButton<String>(
                icon: const Icon(Icons.more_vert),
                onSelected: (value) async {
                  if (widget.doc.url.contains('drive.google.com')) {
                    switch (value) {
                      case 'Rename':
                        await _showRenameDialog();
                        break;
                      case 'Delete':
                        _showDeleteConfirmation();
                        break;
                    }
                    return;
                  }
                  switch (value) {
                    case 'Rename':
                      await _showRenameDialog();
                      break;
                    case 'Move':
                      _showMoveDialog();
                      break;
                    case 'Star':
                      await ref.read(databaseServiceProvider).toggleStarDocument(widget.doc.id, !widget.doc.isStarred);
                      break;
                    case 'Delete':
                      _showDeleteConfirmation();
                      break;
                  }
                },
                itemBuilder: (context) {
                  if (widget.doc.url.contains('drive.google.com')) {
                    return [
                      const PopupMenuItem(value: 'Rename', child: Text('Rename')),
                      const PopupMenuItem(value: 'Delete', child: Text('Delete')),
                    ];
                  }
                  return [
                    PopupMenuItem(
                      value: 'Star',
                      child: Row(
                        children: [
                          Icon(widget.doc.isStarred ? Icons.star : Icons.star_border, color: Colors.amber),
                          const SizedBox(width: 8),
                          Text(widget.doc.isStarred ? 'Unstar' : 'Star'),
                        ],
                      ),
                    ),
                    const PopupMenuItem(
                      value: 'Move',
                      child: Row(
                        children: [const Icon(Icons.drive_file_move_outlined, size: 20), const SizedBox(width: 8), const Text('Move to Folder')],
                      ),
                    ),
                    const PopupMenuItem(value: 'Rename', child: Text('Rename')),
                    const PopupMenuItem(value: 'Delete', child: Text('Delete')),
                  ];
                },
              ),
      ),
    );
  }

  void _showDeleteConfirmation() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete File'),
        content: Text('Are you sure you want to delete $_localName?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
          TextButton(
            onPressed: () async {
              Navigator.pop(context);
              if (widget.doc.url.contains('drive.google.com')) {
                try {
                  await ref.read(googleDriveServiceProvider).deleteFile(widget.doc.id);
                  ref.read(driveFilesNotifierProvider.notifier).loadFiles();
                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('File deleted from Google Drive')),
                    );
                  }
                } catch (e) {
                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Delete failed: $e')));
                  }
                }
              } else {
                await ref.read(databaseServiceProvider).trashDocument(widget.doc.id);
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('File moved to trash')),
                  );
                }
              }
            },
            child: Text(
              widget.doc.folderId == 'drive' ? 'Delete' : 'Move to Trash',
              style: const TextStyle(color: Colors.red),
            ),
          ),
        ],
      ),
    );
  }
}
