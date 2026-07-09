import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/folder_model.dart';
import '../widgets/file_list_tile.dart';
import '../widgets/create_new_sheet.dart';
import '../providers/storage_provider.dart';
import 'doc_viewer_screen.dart';

class FolderDetailsScreen extends ConsumerStatefulWidget {
  final FolderModel folder;

  const FolderDetailsScreen({
    super.key,
    required this.folder,
  });

  @override
  ConsumerState<FolderDetailsScreen> createState() => _FolderDetailsScreenState();
}

class _FolderDetailsScreenState extends ConsumerState<FolderDetailsScreen> {
  late String _currentFolderName;

  @override
  void initState() {
    super.initState();
    _currentFolderName = widget.folder.name;
  }

  void _showCreateNewSheet(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => CreateNewSheet(folderId: widget.folder.id),
    );
  }

  void _showFolderMoreMenu() {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) {
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                leading: const Icon(Icons.edit_outlined),
                title: const Text('Rename Folder'),
                onTap: () {
                  Navigator.pop(context);
                  _showRenameFolderDialog();
                },
              ),
              ListTile(
                leading: const Icon(Icons.delete_outline, color: Colors.red),
                title: const Text('Delete Folder', style: TextStyle(color: Colors.red)),
                onTap: () {
                  Navigator.pop(context);
                  _showDeleteFolderConfirmation();
                },
              ),
            ],
          ),
        );
      },
    );
  }

  void _showRenameFolderDialog() {
    final controller = TextEditingController(text: _currentFolderName);
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Rename Folder'),
        content: TextField(
          controller: controller,
          decoration: const InputDecoration(hintText: 'Enter new folder name'),
          autofocus: true,
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
          TextButton(
            onPressed: () async {
              final newName = controller.text.trim();
              if (newName.isNotEmpty && newName != _currentFolderName) {
                setState(() {
                  _currentFolderName = newName;
                });
                Navigator.pop(context);
                try {
                  await ref.read(databaseServiceProvider).renameFolder(widget.folder.id, newName);
                } catch (e) {
                  if (mounted) {
                    setState(() {
                      _currentFolderName = widget.folder.name;
                    });
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text('Error renaming folder: $e')),
                    );
                  }
                }
              } else {
                Navigator.pop(context);
              }
            },
            child: const Text('Rename'),
          ),
        ],
      ),
    );
  }

  void _showDeleteFolderConfirmation() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Folder'),
        content: Text('Are you sure you want to delete "$_currentFolderName"? Files inside will be moved to Recent.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
          TextButton(
            onPressed: () async {
              await ref.read(databaseServiceProvider).deleteFolder(widget.folder.id);
              if (mounted) {
                Navigator.pop(context);
                Navigator.pop(context);
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Folder deleted')),
                );
              }
            },
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final docsAsync = ref.watch(docsStreamProvider(widget.folder.id));
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      appBar: AppBar(
        backgroundColor: theme.appBarTheme.backgroundColor,
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.arrow_back, color: isDark ? Colors.white : Colors.black),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          _currentFolderName,
          style: TextStyle(
            color: isDark ? Colors.white : Colors.black, 
            fontWeight: FontWeight.bold,
          ),
        ),
        actions: [
          IconButton(
            icon: Icon(Icons.more_horiz, color: isDark ? Colors.white : Colors.black),
            onPressed: _showFolderMoreMenu,
          ),
        ],
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          child: Column(
            children: [
            const SizedBox(height: 20),
            Center(
              child: Column(
                children: [
                  Icon(Icons.folder, color: widget.folder.color, size: 100),
                  const SizedBox(height: 12),
                  Text(
                    _currentFolderName,
                    style: TextStyle(
                      fontSize: 20, 
                      fontWeight: FontWeight.bold,
                      color: isDark ? Colors.white : Colors.black,
                    ),
                  ),
                  docsAsync.when(
                    data: (docs) => Text(
                      '${docs.length} Items',
                      style: TextStyle(color: isDark ? Colors.grey[400] : Colors.grey[600]),
                    ),
                    loading: () => Text('... Items', style: TextStyle(color: isDark ? Colors.grey[400] : Colors.grey[600])),
                    error: (_, __) => Text('0 Items', style: TextStyle(color: isDark ? Colors.grey[400] : Colors.grey[600])),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  _buildActionButton(Icons.cloud_upload_outlined, 'Upload', () => _showCreateNewSheet(context)),
                  _buildActionButton(Icons.drive_file_rename_outline, 'Rename', _showRenameFolderDialog),
                  _buildActionButton(Icons.share_outlined, 'Share', () {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Folder sharing coming soon')),
                    );
                  }),
                  _buildActionButton(Icons.more_horiz, 'More', _showFolderMoreMenu),
                ],
              ),
            ),
            const SizedBox(height: 24),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Row(
                children: [
                  Text(
                    'Files',
                    style: TextStyle(
                      fontSize: 18, 
                      fontWeight: FontWeight.bold,
                      color: isDark ? Colors.white : Colors.black,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            docsAsync.when(
              data: (docs) {
                if (docs.isEmpty) {
                  return Center(
                    child: Padding(
                      padding: const EdgeInsets.only(top: 40),
                      child: Text(
                        'No files in this folder',
                        style: TextStyle(color: isDark ? Colors.grey[400] : Colors.grey[600]),
                      ),
                    ),
                  );
                }
                return ListView.builder(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: docs.length,
                  itemBuilder: (context, index) {
                    final doc = docs[index];
                    return FileListTile(
                      doc: doc,
                      onTap: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => DocViewerScreen(doc: doc),
                          ),
                        );
                      },
                    );
                  },
                );
              },
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (err, stack) => Text('Error: $err', style: const TextStyle(color: Colors.red)),
            ),
            const SizedBox(height: 80),
          ],
        ),
      ),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _showCreateNewSheet(context),
        backgroundColor: Colors.blue,
        child: const Icon(Icons.add, color: Colors.white),
      ),
    );
  }

  Widget _buildActionButton(IconData icon, String label, VoidCallback onTap) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return InkWell(
      onTap: onTap,
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: theme.cardTheme.color ?? (isDark ? const Color(0xFF1E1E1E) : Colors.white),
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.05),
                  blurRadius: 5,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Icon(icon, color: Colors.blue),
          ),
          const SizedBox(height: 8),
          Text(
            label,
            style: TextStyle(
              fontSize: 12, 
              fontWeight: FontWeight.w500,
              color: isDark ? Colors.white : Colors.black,
            ),
          ),
        ],
      ),
    );
  }
}
