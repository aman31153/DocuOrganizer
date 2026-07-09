import 'dart:io';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shimmer/shimmer.dart';
import '../providers/sync_provider.dart';
import '../models/doc_model.dart';
import '../widgets/file_grid_item.dart';
import '../widgets/file_list_tile.dart';
import 'package:url_launcher/url_launcher.dart';
import '../widgets/app_drawer.dart';
import 'package:documents_organizer/providers/auth_provider.dart';
import '../providers/google_drive_provider.dart';
import '../widgets/drive_status_card.dart';
import 'doc_viewer_screen.dart';

class GoogleDriveScreen extends ConsumerStatefulWidget {
  const GoogleDriveScreen({super.key});

  @override
  ConsumerState<GoogleDriveScreen> createState() => _GoogleDriveScreenState();
}

class _GoogleDriveScreenState extends ConsumerState<GoogleDriveScreen> {
  final List<String> _filters = ['All files', 'Documents', 'Spreadsheets', 'Images', 'Videos'];
  final ScrollController _scrollController = ScrollController();
  final Map<String, String> _sortOptions = {
    'modifiedTime desc': 'Last modified (Newest)',
    'modifiedTime asc': 'Last modified (Oldest)',
    'name asc': 'Name (A-Z)',
    'name desc': 'Name (Z-A)',
    'quotaBytesUsed desc': 'Size (Largest)',
    'quotaBytesUsed asc': 'Size (Smallest)',
  };
  bool _isUploading = false;

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_onScroll);
  }

  void _onScroll() {
    if (_scrollController.position.pixels >= _scrollController.position.maxScrollExtent - 200) {
      ref.read(driveFilesNotifierProvider.notifier).loadNextPage();
    }
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _uploadToDrive() async {
    final result = await FilePicker.platform.pickFiles();
    if (result != null && result.files.single.path != null) {
      setState(() => _isUploading = true);
      try {
        final file = File(result.files.single.path!);
        final fileName = result.files.single.name;
        await ref.read(googleDriveServiceProvider).uploadFile(file, fileName);
        ref.read(driveFilesNotifierProvider.notifier).loadFiles();
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('File uploaded to Google Drive')),
          );
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

  Future<void> _refreshData() async {
    // We can run these in parallel
    await Future.wait([
      ref.read(driveFilesNotifierProvider.notifier).loadFiles(),
      ref.read(googleDriveServiceProvider).clearStorageBreakdownCache(),
    ]);
    // Invalidate providers to trigger a refetch
    ref.invalidate(googleDriveUsageProvider);
    ref.invalidate(driveStorageBreakdownProvider);
  }

  AppBar _buildSelectionAppBar(DriveFilesState state, BuildContext context) {
    final notifier = ref.read(driveFilesNotifierProvider.notifier);
    final selectedCount = state.selectedFileIds.length;
    final allSelected = selectedCount > 0 && selectedCount == state.files.length;

    return AppBar(
      leading: IconButton(
        icon: const Icon(Icons.close),
        onPressed: () => notifier.clearSelection(),
      ),
      title: Text('$selectedCount selected'),
      actions: [
        IconButton(
          icon: Icon(allSelected ? Icons.deselect : Icons.select_all),
          onPressed: () {
            if (allSelected) {
              notifier.clearSelection();
            } else {
              notifier.selectAllFiles();
            }
          },
          tooltip: allSelected ? 'Deselect All' : 'Select All',
        ),
        IconButton(
          icon: const Icon(Icons.drive_file_move_outline),
          onPressed: selectedCount > 0 ? () => _showBulkMoveDialog(context, selectedCount) : null,
          tooltip: 'Move Selected',
        ),
        IconButton(
          icon: const Icon(Icons.download_outlined),
          onPressed: selectedCount > 0
              ? () {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Bulk download not implemented yet.')),
                  );
                }
              : null,
          tooltip: 'Download Selected',
        ),
        IconButton(
          icon: const Icon(Icons.delete_outline),
          onPressed: selectedCount > 0 ? () => _confirmDeleteSelected(context, selectedCount) : null,
          tooltip: 'Delete Selected',
        ),
      ],
    );
  }

  void _showBulkMoveDialog(BuildContext context, int count) async {
    final service = ref.read(googleDriveServiceProvider);
    // This could be paginated, but for now, let's get a reasonable number.
    final result = await service.listDriveFiles(query: "mimeType = 'application/vnd.google-apps.folder'");
    final folders = result.files;

    if (!mounted) return;

    final selectedFolderId = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Move to...'),
        content: SizedBox(
          width: double.maxFinite,
          child: ListView.builder(
            shrinkWrap: true,
            itemCount: folders.length,
            itemBuilder: (context, index) {
              final folder = folders[index];
              return ListTile(
                leading: const Icon(Icons.folder_open, color: Colors.amber),
                title: Text(folder.name),
                onTap: () => Navigator.of(context).pop(folder.id),
              );
            },
          ),
        ),
        actions: [TextButton(onPressed: () => Navigator.of(context).pop(), child: const Text('Cancel'))],
      ),
    );

    if (selectedFolderId != null) {
      await ref.read(driveFilesNotifierProvider.notifier).moveSelectedFiles(selectedFolderId);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$count files moved.')));
      }
    }
  }

  void _confirmDeleteSelected(BuildContext context, int count) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Delete $count files?'),
        content: const Text('This will permanently delete the selected files from your Google Drive.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
          TextButton(
            onPressed: () async {
              Navigator.pop(context);
              await ref.read(driveFilesNotifierProvider.notifier).deleteSelectedFiles();
              if (mounted) {
                ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$count files deleted')));
              }
            },
            child: const Text('Delete', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final driveState = ref.watch(driveFilesNotifierProvider);
    final storageBreakdownAsync = ref.watch(driveStorageBreakdownProvider);
    final driveUsageAsync = ref.watch(googleDriveUsageProvider);
    
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    final user = ref.watch(authStateProvider).value;
    final displayName = user?.displayName ?? 'User';
    final photoUrl = user?.photoURL;
    final initials = displayName.isNotEmpty ? displayName[0].toUpperCase() : 'U';

    return Scaffold(
      drawer: driveState.isSelectionMode ? null : const AppDrawer(),
      appBar: driveState.isSelectionMode
          ? _buildSelectionAppBar(driveState, context)
          : AppBar(
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
                    showSearch(context: context, delegate: GoogleDriveSearchDelegate(ref));
                  },
                ),
                PopupMenuButton<String>(
                  icon: Icon(Icons.more_vert, color: isDark ? Colors.white : Colors.black),
                  onSelected: (value) async {
                    if (value == 'refresh') {
                      await _refreshData();
                    } else if (value == 'settings') {
                      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Settings not implemented yet')));
                    }
                  },
                  itemBuilder: (BuildContext context) => <PopupMenuEntry<String>>[
                    const PopupMenuItem<String>(
                      value: 'refresh',
                      child: Text('Refresh Drive'),
                    ),
                    const PopupMenuItem<String>(
                      value: 'settings',
                      child: Text('Settings'),
                    ),
                  ],
                ),
              ],
            ),
      body: RefreshIndicator(
        onRefresh: _refreshData,
        child: SingleChildScrollView(
          controller: _scrollController,
          physics: const AlwaysScrollableScrollPhysics(),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              DriveStatusCard(
                driveUsageAsync: driveUsageAsync,
                storageBreakdownAsync: storageBreakdownAsync,
              ),
              const SizedBox(height: 16),
              _buildFilterChips(driveState.currentFilter),
              const SizedBox(height: 16),
              _buildFileListHeader(driveState.sortOrder, driveState.viewType),
              _buildFileList(driveState),
            ],
          ),
        ),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _isUploading ? null : _uploadToDrive,
        backgroundColor: Colors.blue,
        child: _isUploading 
          ? const CircularProgressIndicator(color: Colors.white)
          : const Icon(Icons.upload, color: Colors.white),
      ),
    );
  }

  Widget _buildFilterChips(String currentFilter) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Row(
        children: _filters.map((filter) {
          final isSelected = currentFilter == filter;
          return Padding(
            padding: const EdgeInsets.only(right: 8),
            child: FilterChip(
              label: Text(filter),
              selected: isSelected,
              onSelected: (selected) {
                ref.read(driveFilesNotifierProvider.notifier).setFilter(filter);
              },
              backgroundColor: Colors.transparent,
              selectedColor: Colors.blue,
              checkmarkColor: Colors.white,
              labelStyle: TextStyle(
                color: isSelected ? Colors.white : Colors.grey[600],
                fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                fontSize: 12,
              ),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(20),
                side: BorderSide(color: isSelected ? Colors.blue : Colors.grey[300]!),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _buildFileListHeader(String currentSortOrder, DriveViewType viewType) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          PopupMenuButton<String>(
            onSelected: (value) {
              ref.read(driveFilesNotifierProvider.notifier).setSortOrder(value);
            },
            itemBuilder: (context) => _sortOptions.entries.map((entry) {
              return PopupMenuItem<String>(
                value: entry.key,
                child: Text(entry.value),
              );
            }).toList(),
            child: Row(
              children: [
                Text(_sortOptions[currentSortOrder] ?? 'Sort by', style: TextStyle(color: Colors.grey[600], fontSize: 12)),
                const Icon(Icons.arrow_drop_down, color: Colors.grey, size: 20),
              ],
            ),
          ),
          IconButton(
            icon: Icon(viewType == DriveViewType.list ? Icons.grid_view : Icons.view_list, color: Colors.grey[600], size: 20),
            onPressed: () {
              final newViewType = viewType == DriveViewType.list ? DriveViewType.grid : DriveViewType.list;
              ref.read(driveFilesNotifierProvider.notifier).setViewType(newViewType);
            },
            tooltip: viewType == DriveViewType.list ? 'Grid View' : 'List View',
          ),
        ],
      ),
    );
  }

  Widget _buildShimmerEffect(DriveViewType viewType) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final baseColor = isDark ? Colors.grey[800]! : Colors.grey[300]!;
    final highlightColor = isDark ? Colors.grey[700]! : Colors.grey[100]!;

    if (viewType == DriveViewType.grid) {
      return Shimmer.fromColors(
        baseColor: baseColor,
        highlightColor: highlightColor,
        child: GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          padding: const EdgeInsets.all(16),
          itemCount: 8,
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 2,
            crossAxisSpacing: 16,
            mainAxisSpacing: 16,
            childAspectRatio: 1.0,
          ),
          itemBuilder: (_, __) => Container(
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
            ),
          ),
        ),
      );
    }

    return _buildListShimmer(baseColor, highlightColor);
  }

  Widget _buildListShimmer(Color baseColor, Color highlightColor) {
     return Shimmer.fromColors(
      baseColor: baseColor,
      highlightColor: highlightColor,
      child: ListView.builder(
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        itemCount: 10,
        itemBuilder: (_, __) => Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 12.0),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: <Widget>[
              Container(
                width: 48.0,
                height: 48.0,
                decoration: const BoxDecoration(color: Colors.white, shape: BoxShape.circle),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Container(width: double.infinity, height: 12.0, color: Colors.white),
                    const SizedBox(height: 8),
                    Container(width: MediaQuery.of(context).size.width * 0.6, height: 10.0, color: Colors.white),
                  ],
                ),
              )
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildFileList(DriveFilesState state) {
    if (state.isLoading && state.files.isEmpty) {
      return _buildShimmerEffect(state.viewType);
    }
    
    if (state.error != null) {
      // Only show a full-screen error if this is the initial load and it failed.
      if (state.files.isEmpty) {
        return Center(
          child: Padding(
            padding: const EdgeInsets.all(40.0),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.error_outline, color: Colors.red, size: 50),
                const SizedBox(height: 16),
                const Text('Failed to load files', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                const SizedBox(height: 8),
                Text('Please check your connection and try again.', style: TextStyle(color: Colors.grey[600]), textAlign: TextAlign.center),
                const SizedBox(height: 24),
                ElevatedButton.icon(
                  onPressed: () => ref.read(driveFilesNotifierProvider.notifier).loadFiles(),
                  icon: const Icon(Icons.refresh),
                  label: const Text('Retry'),
                  style: ElevatedButton.styleFrom(
                    foregroundColor: Colors.white, backgroundColor: Colors.blue,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                  ),
                ),
              ],
            ),
          ),
        );
      }
    }

    if (state.files.isEmpty) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(40.0),
          child: Text('No files found in Google Drive'),
        ),
      );
    }

    return Column(
      children: [
        AnimatedSwitcher(
          duration: const Duration(milliseconds: 300),
          transitionBuilder: (child, animation) => FadeTransition(opacity: animation, child: child),
          child: state.viewType == DriveViewType.grid
              ? GridView.builder(
                  key: const ValueKey('grid'),
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  padding: const EdgeInsets.all(16),
                  itemCount: state.files.length,
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 2,
                    crossAxisSpacing: 16,
                    mainAxisSpacing: 16,
                    childAspectRatio: 1.0,
                  ),
                  itemBuilder: (context, index) {
                    final doc = state.files[index];
                    return FileGridItem(
                      doc: doc,
                      isSelected: state.selectedFileIds.contains(doc.id),
                      isSelectionMode: state.isSelectionMode,
                      onTap: () {
                        if (state.isSelectionMode) {
                          ref.read(driveFilesNotifierProvider.notifier).toggleFileSelection(doc.id);
                        } else {
                          _openFile(doc);
                        }
                      },
                      onLongPress: () {
                        ref.read(driveFilesNotifierProvider.notifier).toggleFileSelection(doc.id);
                      },
                    );
                  },
                )
              : ListView.builder(
                  key: const ValueKey('list'),
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: state.files.length,
                  itemBuilder: (context, index) {
                    final doc = state.files[index];
                    return FileListTile(
                      doc: doc,
                      isSelected: state.selectedFileIds.contains(doc.id),
                      isSelectionMode: state.isSelectionMode,
                      onTap: () {
                        if (state.isSelectionMode) {
                          ref.read(driveFilesNotifierProvider.notifier).toggleFileSelection(doc.id);
                        } else {
                          _openFile(doc);
                        }
                      },
                      onLongPress: () {
                        ref.read(driveFilesNotifierProvider.notifier).toggleFileSelection(doc.id);
                      },
                    );
                  },
                ),
        ),
        _buildPaginationIndicator(state),
      ],
    );
  }

  Future<void> _openFile(DocModel doc) async {
    // For Google Drive files, they often need special handling or can be opened in a webview.
    // For this screen, let's stick to launching externally as it was.
    // The DocViewerScreen handles more complex previews.
    final url = Uri.parse(doc.url);
    if (await canLaunchUrl(url)) {
      await launchUrl(url, mode: LaunchMode.externalApplication);
    } else {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Could not open file')),
        );
      }
    }
  }

  Widget _buildPaginationIndicator(DriveFilesState state) {
    if (state.isLoadingMore) {
      return const Padding(padding: EdgeInsets.symmetric(vertical: 20), child: CircularProgressIndicator());
    } else if (state.error != null && state.files.isNotEmpty) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 16),
        child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
          Text('Could not load more files.', style: TextStyle(color: Colors.red[700])),
          TextButton(onPressed: () => ref.read(driveFilesNotifierProvider.notifier).loadNextPage(), child: const Text('Retry'))
        ]),
      );
    }
    return const SizedBox.shrink();
  }
}


class GoogleDriveSearchDelegate extends SearchDelegate {
  final WidgetRef ref;
  GoogleDriveSearchDelegate(this.ref);

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
    if (query.isEmpty) return const Center(child: Text('Search Google Drive'));
    
    final safeQuery = query.replaceAll("'", "\\'");
    
    return FutureBuilder(
      future: ref.read(googleDriveServiceProvider).listDriveFiles(query: "name contains '$safeQuery'"),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        if (snapshot.hasError) {
          return Center(child: Text('Error: ${snapshot.error}'));
        }
        final results = snapshot.data?.files ?? [];
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
    );
  }
}
