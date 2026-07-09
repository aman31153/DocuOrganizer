import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:webview_flutter/webview_flutter.dart';
import 'package:syncfusion_flutter_pdfviewer/pdfviewer.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:http/http.dart' as http;
import 'package:share_plus/share_plus.dart';
import '../models/doc_model.dart';
import '../providers/storage_provider.dart';

class DocViewerScreen extends ConsumerStatefulWidget {
  final DocModel doc;

  const DocViewerScreen({super.key, required this.doc});

  @override
  ConsumerState<DocViewerScreen> createState() => _DocViewerScreenState();
}

class _DocViewerScreenState extends ConsumerState<DocViewerScreen> {
  late String _currentName;
  late bool _isStarred;
  WebViewController? _webViewController;

  @override
  void initState() {
    super.initState();
    _currentName = widget.doc.name;
    _isStarred = widget.doc.isStarred;
    _initWebViewIfNeeded();
  }

  void _initWebViewIfNeeded() {
    final isDrive = widget.doc.url.contains('drive.google.com');
    final isOfficeDoc = [DocType.ppt, DocType.doc, DocType.xls].contains(widget.doc.type);
    final isVideo = widget.doc.type == DocType.video;

    if (isDrive || isOfficeDoc || isVideo) {
      _webViewController = WebViewController()
        ..setJavaScriptMode(JavaScriptMode.unrestricted)
        ..setBackgroundColor(const Color(0x00000000));

      if (isDrive) {
        _webViewController!.loadRequest(Uri.parse(widget.doc.url));
      } else if (isOfficeDoc) {
        final encodedUrl = Uri.encodeComponent(widget.doc.url);
        _webViewController!.loadRequest(Uri.parse('https://docs.google.com/gview?embedded=true&url=$encodedUrl'));
      } else if (isVideo) {
        final html = '''
          <html>
            <body style="margin:0;padding:0;background-color:black;display:flex;justify-content:center;align-items:center;">
              <video width="100%" height="100%" controls autoplay name="media">
                <source src="${widget.doc.url}" type="video/mp4">
              </video>
            </body>
          </html>
        ''';
        _webViewController!.loadHtmlString(html);
      }
    }
  }

  Future<void> _downloadFile() async {
    final url = Uri.parse(widget.doc.url);
    if (await canLaunchUrl(url)) {
      await launchUrl(url, mode: LaunchMode.externalApplication);
    } else {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Could not launch download URL')),
        );
      }
    }
  }

  Future<void> _toggleFavorite() async {
    final newStarred = !_isStarred;
    setState(() {
      _isStarred = newStarred;
    });
    
    try {
      await ref.read(databaseServiceProvider).toggleStarDocument(widget.doc.id, newStarred);
    } catch (e) {
      if (mounted) {
        setState(() {
          _isStarred = !_isStarred;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error updating starred status: $e')),
        );
      }
    }
  }

  void _shareFile() {
    Share.share('Check out this file: $_currentName\n${widget.doc.url}');
  }

  void _showMoreMenu() {
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
                title: const Text('Rename'),
                onTap: () {
                  Navigator.pop(context);
                  _showRenameDialog();
                },
              ),
              ListTile(
                leading: const Icon(Icons.drive_file_move_outlined),
                title: const Text('Move to Folder'),
                onTap: () {
                  Navigator.pop(context);
                  _showMoveDialog();
                },
              ),
              ListTile(
                leading: const Icon(Icons.info_outline),
                title: const Text('Details'),
                onTap: () {
                  Navigator.pop(context);
                  _showDetails();
                },
              ),
              ListTile(
                leading: const Icon(Icons.delete_outline, color: Colors.red),
                title: const Text('Move to Trash', style: TextStyle(color: Colors.red)),
                onTap: () {
                  Navigator.pop(context);
                  _showDeleteConfirmation();
                },
              ),
            ],
          ),
        );
      },
    );
  }

  void _showRenameDialog() {
    final controller = TextEditingController(text: _currentName);
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Rename File'),
        content: TextField(
          controller: controller,
          decoration: const InputDecoration(hintText: 'Enter new name'),
          autofocus: true,
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
          TextButton(
            onPressed: () async {
              final newName = controller.text.trim();
              if (newName.isNotEmpty && newName != _currentName) {
                setState(() {
                  _currentName = newName;
                });
                Navigator.pop(context);
                try {
                  await ref.read(databaseServiceProvider).renameDocument(widget.doc.id, newName);
                } catch (e) {
                  if (mounted) {
                    setState(() {
                      _currentName = widget.doc.name;
                    });
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text('Error renaming file: $e')),
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

  void _showMoveDialog() {
    final foldersAsync = ref.watch(foldersStreamProvider);
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Move to Folder'),
        content: SizedBox(
          width: double.maxFinite,
          child: foldersAsync.when(
            data: (folders) {
              if (folders.isEmpty) return const Text('No folders found. Create one first.');
              return ListView.builder(
                shrinkWrap: true,
                itemCount: folders.length,
                itemBuilder: (context, index) {
                  final folder = folders[index];
                  return ListTile(
                    leading: const Icon(Icons.folder, color: Colors.amber),
                    title: Text(folder.name),
                    onTap: () async {
                      Navigator.pop(context);
                      await ref.read(databaseServiceProvider).moveDocument(widget.doc.id, folder.id);
                      if (mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(content: Text('Moved to ${folder.name}')),
                        );
                      }
                    },
                  );
                },
              );
            },
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (err, stack) => Text('Error: $err'),
          ),
        ),
      ),
    );
  }

  void _showDeleteConfirmation() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Move to Trash'),
        content: Text('Are you sure you want to move "${_currentName}" to trash?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
          TextButton(
            onPressed: () async {
              await ref.read(databaseServiceProvider).trashDocument(widget.doc.id);
              if (mounted) {
                Navigator.pop(context); // Close dialog
                Navigator.pop(context); // Close viewer
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('File moved to trash')),
                );
              }
            },
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Move to Trash'),
          ),
        ],
      ),
    );
  }

  void _showDetails() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('File Details'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Name: $_currentName'),
            Text('Size: ${widget.doc.size.toStringAsFixed(2)} MB'),
            Text('Type: ${widget.doc.type.name.toUpperCase()}'),
            Text('Uploaded: ${widget.doc.uploadDate.toLocal().toString().split('.')[0]}'),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Close')),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
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
          _currentName,
          style: TextStyle(color: isDark ? Colors.white : Colors.black, fontSize: 16),
          overflow: TextOverflow.ellipsis,
        ),
        actions: [
          IconButton(
            icon: Icon(Icons.download_outlined, color: isDark ? Colors.white : Colors.black),
            onPressed: _downloadFile,
          ),
          IconButton(
            icon: Icon(Icons.more_vert, color: isDark ? Colors.white : Colors.black),
            onPressed: _showMoreMenu,
          ),
        ],
      ),
      body: Column(
        children: [
          Expanded(
            child: _buildViewer(),
          ),
          Container(
            padding: const EdgeInsets.symmetric(vertical: 20),
            decoration: BoxDecoration(
              color: theme.cardTheme.color ?? (isDark ? const Color(0xFF1E1E1E) : Colors.white),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.05),
                  blurRadius: 5,
                  offset: const Offset(0, -2),
                ),
              ],
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                _buildViewerAction(Icons.share_outlined, 'Share', _shareFile),
                _buildViewerAction(
                  _isStarred ? Icons.favorite : Icons.favorite_border,
                  'Favorite',
                  _toggleFavorite,
                  color: _isStarred ? Colors.red : null,
                ),
                _buildViewerAction(Icons.open_in_new, 'Open Externally', _downloadFile),
                _buildViewerAction(Icons.more_horiz, 'More', _showMoreMenu),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildViewer() {
    if (widget.doc.url.isEmpty) {
      return const Center(child: Text('No file URL found'));
    }

    if (_webViewController != null) {
      return WebViewWidget(controller: _webViewController!);
    }

    switch (widget.doc.type) {
      case DocType.pdf:
        return SfPdfViewer.network(widget.doc.url);
      
      case DocType.image:
        return Center(
          child: InteractiveViewer(
            child: CachedNetworkImage(
              imageUrl: widget.doc.url,
              placeholder: (context, url) => const CircularProgressIndicator(),
              errorWidget: (context, url, error) => const Icon(Icons.error),
              fit: BoxFit.contain,
            ),
          ),
        );

      case DocType.txt:
        return FutureBuilder<String>(
          future: _fetchText(widget.doc.url),
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Center(child: CircularProgressIndicator());
            }
            if (snapshot.hasError) {
              return Center(child: Text('Error: ${snapshot.error}'));
            }
            return SingleChildScrollView(
              padding: const EdgeInsets.all(20),
              child: Text(snapshot.data ?? 'No content'),
            );
          },
        );

      default:
        return Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.insert_drive_file, size: 80, color: Colors.grey[400]),
              const SizedBox(height: 16),
              const Text(
                'No preview available for this file type.',
                style: TextStyle(color: Colors.grey),
              ),
              const SizedBox(height: 24),
              ElevatedButton(
                onPressed: _downloadFile,
                child: const Text('Open in External App'),
              ),
            ],
          ),
        );
    }
  }

  Future<String> _fetchText(String url) async {
    final response = await http.get(Uri.parse(url));
    if (response.statusCode == 200) {
      return response.body;
    } else {
      throw Exception('Failed to load text file');
    }
  }

  Widget _buildViewerAction(IconData icon, String label, VoidCallback onTap, {Color? color}) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return InkWell(
      onTap: onTap,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: color ?? (isDark ? Colors.grey[300] : Colors.grey[700])),
          const SizedBox(height: 4),
          Text(
            label, 
            style: TextStyle(
              fontSize: 10, 
              color: isDark ? Colors.grey[300] : Colors.grey[700],
            ),
          ),
        ],
      ),
    );
  }
}
