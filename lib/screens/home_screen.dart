import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/storage_provider.dart';
import '../widgets/storage_usage_card.dart';
import '../widgets/folder_card.dart';
import '../widgets/file_list_tile.dart';
import '../widgets/app_drawer.dart';
import '../models/doc_model.dart';
import 'folder_details_screen.dart';
import 'doc_viewer_screen.dart';
import 'folders_screen.dart';
import 'all_files_screen.dart';
import 'package:documents_organizer/providers/auth_provider.dart';

class HomeScreen extends ConsumerWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final foldersAsync = ref.watch(foldersWithCountsProvider);
    final recentDocsAsync = ref.watch(recentDocsProvider);
    final user = ref.watch(authStateProvider).value;
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    final displayName = user?.displayName ?? 'User';
    final firstName = displayName.split(' ')[0];
    final photoUrl = user?.photoURL;
    final initials = displayName.isNotEmpty ? displayName[0].toUpperCase() : 'U';

    return Scaffold(
      drawer: const AppDrawer(),
      appBar: AppBar(
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
        backgroundColor: Colors.transparent,
        title: const Text(
          'DocuOrganizer',
          style: TextStyle(color: Colors.blue, fontWeight: FontWeight.bold),
        ),
        actions: [
          IconButton(
            icon: Icon(Icons.search, color: isDark ? Colors.white : Colors.black),
            onPressed: () {
              showSearch(context: context, delegate: DocSearchDelegate(ref));
            },
          ),
          IconButton(
            icon: Icon(Icons.notifications_none, color: isDark ? Colors.white : Colors.black),
            onPressed: () {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('No new notifications')),
              );
            },
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: () async {},
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 10),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Hello, $firstName 👋',
                        style: TextStyle(
                          fontSize: 24,
                          fontWeight: FontWeight.bold,
                          color: isDark ? Colors.white : Colors.black,
                        ),
                      ),
                      Text(
                        'All your documents in one place',
                        style: TextStyle(color: isDark ? Colors.grey[400] : Colors.grey),
                      ),
                    ],
                  ),
                ],
              ),
              const SizedBox(height: 24),
              const StorageUsageCard(),
              const SizedBox(height: 24),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'My Folders',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: isDark ? Colors.white : Colors.black,
                    ),
                  ),
                  TextButton(
                    onPressed: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(builder: (context) => const FoldersScreen()),
                      );
                    },
                    child: const Text('View all'),
                  ),
                ],
              ),
              foldersAsync.when(
                data: (folders) => GridView.builder(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 2,
                    crossAxisSpacing: 16,
                    mainAxisSpacing: 16,
                    childAspectRatio: 1.5,
                  ),
                  itemCount: folders.length > 4 ? 4 : folders.length,
                  itemBuilder: (context, index) {
                    final folder = folders[index];
                    return FolderCard(
                      folder: folder,
                      onTap: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => FolderDetailsScreen(
                              folder: folder,
                            ),
                          ),
                        );
                      },
                    );
                  },
                ),
                loading: () => const Center(child: CircularProgressIndicator()),
                error: (err, stack) => Text('Error: $err'),
              ),
              const SizedBox(height: 24),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Recent Files',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: isDark ? Colors.white : Colors.black,
                    ),
                  ),
                  TextButton(
                    onPressed: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(builder: (context) => const AllFilesScreen(showRecentOnly: true)),
                      );
                    },
                    child: const Text('View all'),
                  ),
                ],
              ),
              FutureBuilder<List<DocModel>>(
                future: recentDocsAsync,
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return const Center(child: CircularProgressIndicator());
                  }
                  if (snapshot.hasError) {
                    return Text('Error: ${snapshot.error}');
                  }
                  final docs = (snapshot.data ?? <DocModel>[]).take(4).toList();
                  if (docs.isEmpty) {
                    return const Padding(
                      padding: EdgeInsets.symmetric(vertical: 20),
                      child: Center(child: Text('No recent files yet.')),
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
                        onTap: () async {
                          if (doc.url.contains('drive.google.com')) {
                            final url = Uri.parse(doc.url);
                            if (await canLaunchUrl(url)) {
                              await launchUrl(url, mode: LaunchMode.externalApplication);
                            } else {
                              if (context.mounted) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(content: Text('Could not open file')),
                                );
                              }
                            }
                          } else {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (context) => DocViewerScreen(doc: doc),
                              ),
                            );
                          }
                        },
                      );
                    },
                  );
                },
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class DocSearchDelegate extends SearchDelegate {
  final WidgetRef ref;
  DocSearchDelegate(this.ref);

  @override
  List<Widget>? buildActions(BuildContext context) => [
        IconButton(icon: const Icon(Icons.clear), onPressed: () => query = ''),
      ];

  @override
  Widget? buildLeading(BuildContext context) => IconButton(
        icon: const Icon(Icons.arrow_back),
        onPressed: () => close(context, null),
      );

  @override
  Widget buildResults(BuildContext context) => _buildSearchResults();

  @override
  Widget buildSuggestions(BuildContext context) => _buildSearchResults();

  Widget _buildSearchResults() {
    if (query.isEmpty) return const Center(child: Text('Search for documents'));
    
    final docsAsync = ref.watch(allDocsProvider);
    return docsAsync.when(
      data: (docs) {
        final results = docs.where((doc) => doc.name.toLowerCase().contains(query.toLowerCase())).toList();
        if (results.isEmpty) return const Center(child: Text('No results found'));
        return ListView.builder(
          itemCount: results.length,
          itemBuilder: (context, index) => FileListTile(
            doc: results[index],
            onTap: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (context) => DocViewerScreen(doc: results[index])),
            ),
          ),
        );
      },
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (err, stack) => Text('Error: $err'),
    );
  }
}
