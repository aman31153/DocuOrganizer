import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:file_picker/file_picker.dart';
import '../models/doc_model.dart';
import '../models/folder_model.dart';
import '../services/cloudinary_service.dart';
import '../services/google_drive_service.dart';
import '../providers/google_drive_provider.dart';
import '../providers/storage_provider.dart';
import '../providers/sync_provider.dart';

class CreateNewSheet extends ConsumerStatefulWidget {
  final String? folderId;
  const CreateNewSheet({super.key, this.folderId});

  @override
  ConsumerState<CreateNewSheet> createState() => _CreateNewSheetState();
}

class _CreateNewSheetState extends ConsumerState<CreateNewSheet> {
  bool _isUploading = false;

  Future<void> _createFolder() async {
    final nameController = TextEditingController();
    final result = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('New Folder'),
        content: TextField(
          controller: nameController,
          decoration: const InputDecoration(hintText: 'Folder Name'),
          autofocus: true,
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Create'),
          ),
        ],
      ),
    );

    if (result == true && nameController.text.isNotEmpty) {
      final newFolder = FolderModel(
        id: '', 
        name: nameController.text,
        itemCount: 0,
        color: Colors.blue,
      );
      await ref.read(databaseServiceProvider).addFolder(newFolder);
      if (mounted) Navigator.pop(context);
    }
  }

  Future<void> _uploadFile() async {
    final result = await FilePicker.platform.pickFiles();

    if (result != null && result.files.single.path != null) {
      setState(() => _isUploading = true);

      try {
        final file = File(result.files.single.path!);
        final fileName = result.files.single.name;
        final fileSize = result.files.single.size / (1024 * 1024); 
        
        final isGoogleDriveSync = ref.read(googleDriveSyncProvider);
        String? url;

        if (isGoogleDriveSync) {
          final googleDriveService = ref.read(googleDriveServiceProvider);
          
          url = await googleDriveService.uploadFile(file, fileName);
        } else {
          final cloudinaryService = CloudinaryService();
          url = await cloudinaryService.uploadFile(file);
        }

        if (url != null) {
          final doc = DocModel(
            id: '',
            name: fileName,
            type: _getDocType(fileName),
            size: fileSize,
            uploadDate: DateTime.now(),
            url: url,
            folderId: widget.folderId ?? '',
          );
          await ref.read(databaseServiceProvider).addDocument(doc);
          
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('File uploaded successfully!')),
            );
            Navigator.pop(context);
          }
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Upload failed: $e')),
          );
        }
      } finally {
        if (mounted) setState(() => _isUploading = false);
      }
    }
  }

  DocType _getDocType(String fileName) {
    final ext = fileName.split('.').last.toLowerCase();
    switch (ext) {
      case 'pdf': return DocType.pdf;
      case 'ppt':
      case 'pptx': return DocType.ppt;
      case 'doc':
      case 'docx': return DocType.doc;
      case 'xls':
      case 'xlsx': return DocType.xls;
      case 'txt': return DocType.txt;
      case 'jpg':
      case 'jpeg':
      case 'png':
      case 'gif': return DocType.image;
      default: return DocType.other;
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Container(
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(32)),
      ),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Stack(
            children: [
              Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Center(
                    child: Container(
                      width: 40, height: 4,
                      decoration: BoxDecoration(
                        color: isDark ? Colors.grey[700] : Colors.grey[300], 
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                  ),
                  const SizedBox(height: 24),
                  Text(
                    'Create New', 
                    style: TextStyle(
                      fontSize: 20, 
                      fontWeight: FontWeight.bold,
                      color: isDark ? Colors.white : Colors.black,
                    ),
                  ),
                  const SizedBox(height: 24),
                  _buildOption(Icons.folder_outlined, Colors.orange, 'Folder', 'Create a new folder', _createFolder),
                  _buildOption(Icons.upload_outlined, Colors.blue, 'Upload File', 'Upload documents from device', _uploadFile),
                  _buildOption(Icons.qr_code_scanner, Colors.green, 'Scan Document', 'Scan and save as PDF', () {}),
                  _buildOption(Icons.description_outlined, Colors.blueAccent, 'Text Document', 'Create a new text file', () {}),
                  _buildOption(Icons.table_chart_outlined, Colors.greenAccent, 'Spreadsheet', 'Create a new spreadsheet', () {}),
                  _buildOption(Icons.slideshow_outlined, Colors.orangeAccent, 'Presentation', 'Create a new presentation', () {}),
                  const SizedBox(height: 16),
                  SizedBox(
                    width: double.infinity,
                    child: TextButton(
                      onPressed: () => Navigator.pop(context),
                      child: const Text('Cancel', style: TextStyle(color: Colors.blue, fontSize: 16)),
                    ),
                  ),
                ],
              ),
              if (_isUploading)
                const Positioned.fill(
                  child: Center(
                    child: CircularProgressIndicator(),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildOption(IconData icon, Color color, String title, String subtitle, VoidCallback onTap) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return ListTile(
      leading: Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: color.withOpacity(0.1),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Icon(icon, color: color),
      ),
      title: Text(
        title, 
        style: TextStyle(
          fontWeight: FontWeight.bold,
          color: isDark ? Colors.white : Colors.black,
        ),
      ),
      subtitle: Text(
        subtitle, 
        style: TextStyle(
          fontSize: 12, 
          color: isDark ? Colors.grey[400] : Colors.grey[600],
        ),
      ),
      onTap: _isUploading ? null : onTap,
    );
  }
}
