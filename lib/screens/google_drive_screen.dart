import 'dart:io';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:percent_indicator/circular_percent_indicator.dart';
import '../providers/sync_provider.dart';
import '../models/doc_model.dart';
import '../widgets/file_list_tile.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';
import '../services/google_drive_service.dart';
import '../services/auth_service.dart';
import '../widgets/app_drawer.dart';
import 'package:documents_organizer/providers/auth_provider.dart';
import '../providers/google_drive_provider.dart';
import 'doc_viewer_screen.dart';

class GoogleDriveScreen extends ConsumerStatefulWidget {
  const GoogleDriveScreen({super.key});

  @override
  ConsumerState<GoogleDriveScreen> createState() => _GoogleDriveScreenState();
}

class _GoogleDriveScreenState extends ConsumerState<GoogleDriveScreen> {
  final List<String> _filters = ['All files', 'Documents', 'Spreadsheets', 'Images', 'Videos'];
  final ScrollController _scrollController = ScrollController();
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
              showSearch(context: context, delegate: GoogleDriveSearchDelegate(ref));
            },
          ),
          PopupMenuButton<String>(
            icon: Icon(Icons.more_vert, color: isDark ? Colors.white : Colors.black),
            onSelected: (value) async {
              if (value == 'refresh') {
                await ref.read(driveFilesNotifierProvider.notifier).loadFiles();
                await ref.read(googleDriveServiceProvider).clearStorageBreakdownCache();
                ref.invalidate(googleDriveUsageProvider);
                ref.invalidate(driveStorageBreakdownProvider);
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
        onRefresh: () async {
          await ref.read(driveFilesNotifierProvider.notifier).loadFiles();
          await ref.read(googleDriveServiceProvider).clearStorageBreakdownCache();
          ref.invalidate(googleDriveUsageProvider);
          ref.invalidate(driveStorageBreakdownProvider);
        },
        child: SingleChildScrollView(
          controller: _scrollController,
          physics: const AlwaysScrollableScrollPhysics(),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildDriveStatusCard(driveUsageAsync, storageBreakdownAsync, isDark),
              const SizedBox(height: 16),
              _buildFilterChips(driveState.currentFilter),
              const SizedBox(height: 16),
              _buildFileListHeader(),
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

  Widget _buildDriveStatusCard(AsyncValue<Map<String, double>> driveUsageAsync, AsyncValue<Map<String, double>> storageBreakdownAsync, bool isDark) {
    return driveUsageAsync.when(
      data: (usage) {
        return storageBreakdownAsync.when(
          data: (breakdown) {
            final usedMB = usage['usage'] ?? 0.0;
            final totalMB = usage['limit'] ?? (15 * 1024);
            
            final usedGB = usedMB / 1024;
            final totalGB = totalMB / 1024;
            
            String planText = '';
            if (totalGB >= 1024) {
              planText = '${(totalGB / 1024).toStringAsFixed(0)} TB';
            } else {
              planText = '${totalGB.toStringAsFixed(0)} GB';
            }
            
            String usedText = '';
            if (usedGB >= 1024) {
              usedText = '${(usedGB / 1024).toStringAsFixed(2)} TB';
            } else {
              usedText = '${usedGB.toStringAsFixed(2)} GB';
            }

            final imageSize = breakdown['imageSize'] ?? 0.0;
            final videoSize = breakdown['videoSize'] ?? 0.0;
            final docSize = breakdown['docSize'] ?? 0.0;
            final othersSize = breakdown['othersSize'] ?? 0.0;

            return Container(
              color: isDark ? const Color(0xFF121212) : const Color(0xFFEEEEEE),
              width: double.infinity,
              padding: const EdgeInsets.symmetric(vertical: 24, horizontal: 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  Text(
                    'Your current plan includes $planText of storage',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w500,
                      color: isDark ? Colors.white : Colors.black87,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 24),
                  Container(
                    padding: const EdgeInsets.all(24),
                    decoration: BoxDecoration(
                      color: isDark ? const Color(0xFF1E1E1E) : Colors.white,
                      borderRadius: BorderRadius.circular(24),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.05),
                          blurRadius: 10,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text('Storage used', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w500, color: isDark ? Colors.white : Colors.black87)),
                            Text('$usedText of $planText', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w500, color: isDark ? Colors.white : Colors.black87)),
                          ],
                        ),
                        const SizedBox(height: 16),
                        _buildHorizontalProgressBar(totalMB, imageSize, videoSize, docSize, othersSize, usedMB),
                        const SizedBox(height: 24),
                        _buildListStorageInfoRow('Images', _formatMB(imageSize), Colors.amber),
                        const SizedBox(height: 16),
                        _buildListStorageInfoRow('Videos', _formatMB(videoSize), Colors.red),
                        const SizedBox(height: 16),
                        _buildListStorageInfoRow('Documents', _formatMB(docSize), Colors.blue),
                        const SizedBox(height: 16),
                        _buildListStorageInfoRow('Others', _formatMB(othersSize), Colors.grey),
                      ],
                    ),
                  ),
                ],
              ),
            );
          },
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (_, __) => const Center(child: Text('Error loading stats')),
        );
      },
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (_, __) => const Center(child: Text('Error loading usage')),
    );
  }

  Widget _buildHorizontalProgressBar(double totalMB, double img, double vid, double doc, double oth, double used) {
    if (totalMB == 0) return const SizedBox();
    
    // Scale everything relative to total used so it fills the bar if totalMB is huge, or scale relative to totalMB?
    // In Google's design, the grey bar represents total limit, and the colored segments fill it up.
    
    double imgPct = img / totalMB;
    double vidPct = vid / totalMB;
    double docPct = doc / totalMB;
    double othPct = oth / totalMB;
    
    // The grey part is what's left of the used portion. The un-colored used portion.
    double accounted = img + vid + doc + oth;
    double unaccounted = used - accounted;
    if (unaccounted < 0) unaccounted = 0;
    double unaccountedPct = unaccounted / totalMB;
    
    double remainingPct = (totalMB - used) / totalMB;
    if (remainingPct < 0) remainingPct = 0;

    return ClipRRect(
      borderRadius: BorderRadius.circular(4),
      child: Container(
        height: 8,
        width: double.infinity,
        child: Row(
          children: [
            if (imgPct > 0) Expanded(flex: (imgPct * 1000).toInt(), child: Container(color: Colors.amber)),
            if (vidPct > 0) Expanded(flex: (vidPct * 1000).toInt(), child: Container(color: Colors.red)),
            if (docPct > 0) Expanded(flex: (docPct * 1000).toInt(), child: Container(color: Colors.blue)),
            if (othPct > 0) Expanded(flex: (othPct * 1000).toInt(), child: Container(color: Colors.grey)),
            if (unaccountedPct > 0) Expanded(flex: (unaccountedPct * 1000).toInt(), child: Container(color: Colors.grey.shade400)),
            if (remainingPct > 0) Expanded(flex: (remainingPct * 1000).toInt(), child: Container(color: Colors.grey.shade300)),
          ],
        ),
      ),
    );
  }

  Widget _buildListStorageInfoRow(String label, String value, Color color) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Row(
          children: [
            Container(
              width: 10,
              height: 10,
              decoration: BoxDecoration(color: color, shape: BoxShape.circle),
            ),
            const SizedBox(width: 12),
            Text(label, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w400)),
          ],
        ),
        Text(value, style: const TextStyle(fontWeight: FontWeight.w500, fontSize: 16)),
      ],
    );
  }

  String _formatMB(double mb) {
    if (mb >= 1024) return '${(mb / 1024).toStringAsFixed(1)} GB';
    return '${mb.toStringAsFixed(1)} MB';
  }

  Widget _buildStorageInfoRow(String label, String value, Color color) {
    return Row(
      children: [
        Container(
          width: 8,
          height: 8,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Text(label, style: const TextStyle(color: Colors.grey, fontSize: 12)),
        ),
        Text(value, style: const TextStyle(fontWeight: FontWeight.w500, fontSize: 12)),
      ],
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

  Widget _buildFileListHeader() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            children: [
              Text('Last modified', style: TextStyle(color: Colors.grey[600], fontSize: 12)),
              const Icon(Icons.arrow_drop_down, color: Colors.grey, size: 20),
            ],
          ),
          Icon(Icons.view_list, color: Colors.grey[600], size: 20),
        ],
      ),
    );
  }

  Widget _buildFileList(DriveFilesState state) {
    if (state.isLoading && state.files.isEmpty) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(40.0),
          child: CircularProgressIndicator(),
        ),
      );
    }
    
    if (state.error != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(40.0),
          child: Text('Error loading files: ${state.error}'),
        ),
      );
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
        ListView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: state.files.length,
          itemBuilder: (context, index) {
            final doc = state.files[index];
            return FileListTile(
              doc: doc,
              onTap: () async {
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
              },
            );
          },
        ),
        if (state.isLoadingMore)
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 20),
            child: CircularProgressIndicator(),
          ),
      ],
    );
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
