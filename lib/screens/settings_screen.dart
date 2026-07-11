import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:file_picker/file_picker.dart';
import '../providers/download_provider.dart';
import '../providers/storage_provider.dart';
import '../providers/sync_provider.dart';
import '../widgets/download_status_panel.dart';

class SettingsScreen extends ConsumerStatefulWidget {
  const SettingsScreen({super.key});

  @override
  ConsumerState<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends ConsumerState<SettingsScreen> {
  bool _notificationsEnabled = true;

  void _showAccountDetails() {
    final user = FirebaseAuth.instance.currentUser;
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Account Details'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Name: Aman Jain', style: TextStyle(fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            Text('Email: ${user?.email ?? "aman.jain@email.com"}'),
            const SizedBox(height: 8),
            const Text('Member Since: Jan 2024'),
            const SizedBox(height: 8),
            const Text('Status: Verified Account', style: TextStyle(color: Colors.green)),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Close')),
        ],
      ),
    );
  }

  void _showCloudStorageDetails() {
    final usedMB = ref.read(totalStorageUsageProvider);
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Cloud Storage'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.cloud_done_outlined, size: 64, color: Colors.blue),
            const SizedBox(height: 16),
            const Text('Service: Cloudinary Premium'),
            const SizedBox(height: 8),
            Text('Used Space: ${usedMB.toStringAsFixed(2)} MB'),
            const Text('Total Limit: 10.00 GB'),
            const SizedBox(height: 16),
            const Text('All files are encrypted and synced across your devices.', 
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 12, color: Colors.grey),
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Close')),
        ],
      ),
    );
  }

  void _showPrivacyInfo() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Privacy & Security'),
        content: const Text(
          'DocuOrganizer uses industry-standard 256-bit encryption to protect your documents. '
          'We do not share your data with third parties. Your documents are stored securely in Cloudinary '
          'and metadata is managed via Firebase.',
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Understood')),
        ],
      ),
    );
  }

  void _showTerms() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Terms of Service'),
        content: const SingleChildScrollView(
          child: Text(
            '1. Acceptance of Terms: By using DocuOrganizer, you agree to these terms.\\n\\n'
            '2. User Responsibility: You are responsible for the documents you upload.\\n\\n'
            '3. Storage: We provide cloud storage but recommend keeping local backups.\\n\\n'
            '4. Termination: We reserve the right to suspend accounts that violate our community guidelines.',
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Close')),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final themeMode = ref.watch(themeModeProvider);
    final isDarkMode = themeMode == ThemeMode.dark;
    final isGoogleDriveSync = ref.watch(googleDriveSyncProvider);

    return Scaffold(
      appBar: AppBar(
        elevation: 0,
        title: const Text('Settings', style: TextStyle(fontWeight: FontWeight.bold)),
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
          _buildSectionHeader('Preferences'),
          SwitchListTile(
            title: const Text('Push Notifications'),
            subtitle: const Text('Receive alerts for file updates'),
            value: _notificationsEnabled,
            onChanged: (val) {
              setState(() => _notificationsEnabled = val);
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text('Notifications ${val ? "enabled" : "disabled"}')),
              );
            },
            secondary: const Icon(Icons.notifications_outlined),
          ),
          SwitchListTile(
            title: const Text('Dark Mode'),
            subtitle: const Text('Switch between light and dark themes'),
            value: isDarkMode,
            onChanged: (val) {
              ref.read(themeModeProvider.notifier).state = val ? ThemeMode.dark : ThemeMode.light;
            },
            secondary: const Icon(Icons.dark_mode_outlined),
          ),
          const Divider(),
          _buildSectionHeader('Storage'),
          ListTile(
            leading: const Icon(Icons.cloud_outlined),
            title: const Text('Cloud Storage'),
            subtitle: const Text('Connected to Cloudinary'),
            trailing: Text(isGoogleDriveSync ? 'Inactive' : 'Active', style: TextStyle(color: isGoogleDriveSync ? Colors.grey : Colors.green, fontWeight: FontWeight.bold)),
            onTap: isGoogleDriveSync ? null : _showCloudStorageDetails,
          ),
          SwitchListTile(
            title: const Text('Sync with Google Drive'),
            subtitle: const Text('Automatically backup to Google Drive'),
            value: ref.watch(googleDriveSyncProvider),
            onChanged: (val) {
              ref.read(googleDriveSyncProvider.notifier).toggle(val);
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text('Google Drive sync ${val ? "enabled" : "disabled"}')),
              );
            },
            secondary: const Icon(Icons.add_to_drive),
          ),
          const Divider(),
          _buildSectionHeader('Downloads'),
          ListTile(
            leading: const Icon(Icons.folder_open_outlined),
            title: const Text('Download Location'),
            subtitle: Text(ref.watch(downloadPathProvider) ?? 'Default'),
            onTap: () async {
              String? selectedDirectory = await FilePicker.getDirectoryPath();

              if (selectedDirectory != null) {
                ref.read(downloadPathProvider.notifier).setPath(selectedDirectory);
              }
            },
          ),
          ListTile(
            leading: const Icon(Icons.cloud_download_outlined),
            title: const Text('Bulk Download from Google Drive'),
            subtitle: const Text('Download multiple files at once'),
            onTap: () {
              // In a real app, this would open a screen to pick files from Google Drive.
              // For this demonstration, we'll trigger a mock download.
              const List<String> mockFileIds = <String>[
                // TODO: Replace with actual file IDs from your Google Drive for testing
              ];
              if (mockFileIds.isNotEmpty) {
                ref.read(downloadProvider.notifier).startBulkDownload(mockFileIds);
              } else {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                      content: Text('No file IDs provided for download test.')),
                );
              }
            },
          ),
          ListTile(
            leading: const Icon(Icons.speed_outlined),
            title: const Text('Concurrent Downloads'),
            subtitle: const Text('Limit simultaneous downloads. Requires restart.'),
            trailing: PopupMenuButton<int>(
              onSelected: (value) {
                if (value != ref.read(maxConcurrentDownloadsProvider)) {
                  ref.read(maxConcurrentDownloadsProvider.notifier).setLimit(value);
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('App restart required for change to take effect.')),
                  );
                }
              },
              initialValue: ref.watch(maxConcurrentDownloadsProvider),
              itemBuilder: (context) => [1, 2, 3, 5, 10].map((limit) {
                return PopupMenuItem<int>(
                  value: limit,
                  child: Text('$limit'),
                );
              }).toList(),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
                child: Text('${ref.watch(maxConcurrentDownloadsProvider)}', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
              ),
            ),
          ),
          const Divider(),
          _buildSectionHeader('ACTIVE DOWNLOADS'),
          const DownloadStatusPanel(),
          const Divider(),
          _buildSectionHeader('Account'),
          ListTile(
            leading: const Icon(Icons.person_outline),
            title: const Text('Account Details'),
            trailing: const Icon(Icons.chevron_right),
            onTap: _showAccountDetails,
          ),
          ListTile(
            leading: const Icon(Icons.lock_outline),
            title: const Text('Privacy & Security'),
            trailing: const Icon(Icons.chevron_right),
            onTap: _showPrivacyInfo,
          ),
          const Divider(),
          _buildSectionHeader('About'),
          const ListTile(
            title: Text('App Version'),
            trailing: Text('1.0.0'),
          ),
          ListTile(
            title: const Text('Terms of Service'),
            onTap: _showTerms,
          ),
          ListTile(
            title: const Text('Privacy Policy'),
            onTap: _showPrivacyInfo,
          ),
        ],
      ),
      ),
    );
  }

  Widget _buildSectionHeader(String title) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 16),
      child: Text(
        title,
        style: const TextStyle(color: Colors.blue, fontWeight: FontWeight.bold, fontSize: 13),
      ),
    );
  }
}
