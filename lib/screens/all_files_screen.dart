import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/doc_model.dart';
import '../providers/storage_provider.dart';
import '../widgets/file_list_tile.dart';
import 'doc_viewer_screen.dart';
import '../widgets/app_drawer.dart';
import 'package:documents_organizer/providers/auth_provider.dart';

class AllFilesScreen extends ConsumerWidget {
  final bool showRecentOnly;

  const AllFilesScreen({super.key, this.showRecentOnly = false});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final rootDocsAsync = ref.watch(rootDocsProvider);
    final recentDocsFuture = ref.watch(recentDocsProvider);
    final user = ref.watch(authStateProvider).value;
    final theme = Theme.of(context);

    final displayName = user?.displayName ?? 'User';
    final photoUrl = user?.photoURL;
    final initials = displayName.isNotEmpty ? displayName[0].toUpperCase() : 'U';

    return Scaffold(
      drawer: const AppDrawer(),
      backgroundColor: theme.scaffoldBackgroundColor,
      appBar: AppBar(
        backgroundColor: theme.appBarTheme.backgroundColor,
        elevation: 0,
        leading: Builder(
          builder: (context) => IconButton(
            icon: photoUrl != null
                ? CircleAvatar(
                    radius: 14,
                    backgroundImage: NetworkImage(photoUrl),
                  )
                : CircleAvatar(
                    radius: 14,
                    backgroundColor: Colors.blue,
                    child: Text(initials, style: const TextStyle(color: Colors.white, fontSize: 10)),
                  ),
            onPressed: () => Scaffold.of(context).openDrawer(),
          ),
        ),
        title: const Text(
          'All Files',
          style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold),
        ),
      ),
      body: showRecentOnly
          ? FutureBuilder<List<DocModel>>(
              future: recentDocsFuture,
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }
                if (snapshot.hasError) {
                  return Center(child: Text('Error: ${snapshot.error}'));
                }

                final docs = snapshot.data ?? <DocModel>[];
                if (docs.isEmpty) {
                  return Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.history, size: 80, color: Colors.grey[300]),
                        const SizedBox(height: 16),
                        Text(
                          'No recent files yet',
                          style: TextStyle(
                            fontSize: 18,
                            color: Colors.grey[600],
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                  );
                }

                return ListView.builder(
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
            )
          : rootDocsAsync.when(
              data: (docs) {
                if (docs.isEmpty) {
                  return Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.folder_open, size: 80, color: Colors.grey[300]),
                        const SizedBox(height: 16),
                        Text(
                          'No files found',
                          style: TextStyle(
                            fontSize: 18,
                            color: Colors.grey[600],
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'Upload documents to see them here',
                          style: TextStyle(color: Colors.grey[500]),
                        ),
                      ],
                    ),
                  );
                }
                return ListView.builder(
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
              error: (err, stack) => Center(child: Text('Error: $err')),
            ),
    );
  }
}
