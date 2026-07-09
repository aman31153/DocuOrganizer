import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/storage_provider.dart';
import '../models/folder_model.dart';
import '../widgets/folder_card.dart';
import 'folder_details_screen.dart';

enum FolderSortBy { name, date, items }

class FoldersScreen extends ConsumerStatefulWidget {
  const FoldersScreen({super.key});

  @override
  ConsumerState<FoldersScreen> createState() => _FoldersScreenState();
}

class _FoldersScreenState extends ConsumerState<FoldersScreen> {
  bool _isGridView = false;
  FolderSortBy _sortBy = FolderSortBy.name;
  bool _isAscending = true;

  void _showCreateFolderDialog() {
    final nameController = TextEditingController();
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('New Folder'),
        content: TextField(
          controller: nameController,
          decoration: const InputDecoration(hintText: 'Folder Name'),
          autofocus: true,
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
          TextButton(
            onPressed: () async {
              final name = nameController.text.trim();
              if (name.isNotEmpty) {
                final newFolder = FolderModel(
                  id: '',
                  name: name,
                  itemCount: 0,
                  color: Colors.blue,
                );
                await ref.read(databaseServiceProvider).addFolder(newFolder);
                if (mounted) Navigator.pop(context);
              }
            },
            child: const Text('Create'),
          ),
        ],
      ),
    );
  }

  List<FolderModel> _sortFolders(List<FolderModel> folders) {
    List<FolderModel> sortedList = List.from(folders);
    sortedList.sort((a, b) {
      int comparison;
      switch (_sortBy) {
        case FolderSortBy.name:
          comparison = a.name.toLowerCase().compareTo(b.name.toLowerCase());
          break;
        case FolderSortBy.date:
          comparison = a.createdAt.compareTo(b.createdAt);
          break;
        case FolderSortBy.items:
          comparison = a.itemCount.compareTo(b.itemCount);
          break;
      }
      return _isAscending ? comparison : -comparison;
    });
    return sortedList;
  }

  @override
  Widget build(BuildContext context) {
    final foldersAsync = ref.watch(foldersWithCountsProvider);

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
          'Folders',
          style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.search, color: Colors.black),
            onPressed: () {
              showSearch(context: context, delegate: FolderSearchDelegate(ref));
            },
          ),
          IconButton(
            icon: Icon(_isGridView ? Icons.list : Icons.grid_view, color: Colors.black),
            onPressed: () {
              setState(() {
                _isGridView = !_isGridView;
              });
            },
          ),
        ],
      ),
      body: SafeArea(
        child: foldersAsync.when(
          data: (folders) {
          if (folders.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.folder_open, size: 80, color: Colors.grey[300]),
                  const SizedBox(height: 16),
                  const Text('No folders created yet', style: TextStyle(color: Colors.grey)),
                ],
              ),
            );
          }

          final sortedFolders = _sortFolders(folders);

          return Padding(
            padding: const EdgeInsets.all(20.0),
            child: Column(
              children: [
                Row(
                  children: [
                    const Text('Sort by: '),
                    PopupMenuButton<FolderSortBy>(
                      initialValue: _sortBy,
                      onSelected: (value) {
                        setState(() {
                          _sortBy = value;
                        });
                      },
                      child: Row(
                        children: [
                          Text(
                            _sortBy == FolderSortBy.name 
                                ? 'Name' 
                                : _sortBy == FolderSortBy.date 
                                    ? 'Date' 
                                    : 'Items',
                            style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.blue),
                          ),
                          const Icon(Icons.keyboard_arrow_down, size: 16, color: Colors.blue),
                        ],
                      ),
                      itemBuilder: (context) => [
                        const PopupMenuItem(value: FolderSortBy.name, child: Text('Name')),
                        const PopupMenuItem(value: FolderSortBy.date, child: Text('Date Created')),
                        const PopupMenuItem(value: FolderSortBy.items, child: Text('Item Count')),
                      ],
                    ),
                    const Spacer(),
                    IconButton(
                      icon: Icon(
                        _isAscending ? Icons.arrow_upward : Icons.arrow_downward,
                        size: 20,
                        color: Colors.blue,
                      ),
                      onPressed: () {
                        setState(() {
                          _isAscending = !_isAscending;
                        });
                      },
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                Expanded(
                  child: _isGridView 
                    ? GridView.builder(
                        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                          crossAxisCount: 2,
                          crossAxisSpacing: 16,
                          mainAxisSpacing: 16,
                          childAspectRatio: 1.3,
                        ),
                        itemCount: sortedFolders.length,
                        itemBuilder: (context, index) => FolderCard(
                          folder: sortedFolders[index],
                          onTap: () => Navigator.push(
                            context,
                            MaterialPageRoute(builder: (context) => FolderDetailsScreen(folder: sortedFolders[index])),
                          ),
                        ),
                      )
                    : ListView.separated(
                        itemCount: sortedFolders.length,
                        separatorBuilder: (context, index) => const SizedBox(height: 12),
                        itemBuilder: (context, index) {
                          final folder = sortedFolders[index];
                          return ListTile(
                            contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                            tileColor: Colors.white,
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                            leading: Icon(Icons.folder, color: folder.color, size: 36),
                            title: Text(folder.name, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                            subtitle: Text('${folder.itemCount} Items', style: const TextStyle(fontSize: 12)),
                            trailing: const Icon(Icons.chevron_right, size: 20),
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
                ),
              ],
            ),
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (err, stack) => Center(child: Text('Error: $err')),
      ),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _showCreateFolderDialog,
        backgroundColor: Colors.blue,
        child: const Icon(Icons.add, color: Colors.white),
      ),
    );
  }
}

class FolderSearchDelegate extends SearchDelegate {
  final WidgetRef ref;
  FolderSearchDelegate(this.ref);

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
    final foldersAsync = ref.watch(foldersWithCountsProvider);
    return foldersAsync.when(
      data: (folders) {
        final results = folders.where((f) => f.name.toLowerCase().contains(query.toLowerCase())).toList();
        if (results.isEmpty) return const Center(child: Text('No folders found'));
        return ListView.builder(
          itemCount: results.length,
          itemBuilder: (context, index) => ListTile(
            leading: Icon(Icons.folder, color: results[index].color),
            title: Text(results[index].name),
            subtitle: Text('${results[index].itemCount} Items'),
            onTap: () {
              close(context, null);
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => FolderDetailsScreen(folder: results[index])),
              );
            },
          ),
        );
      },
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (err, stack) => Text('Error: $err'),
    );
  }
}
