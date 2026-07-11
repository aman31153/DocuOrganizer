import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../services/auth_service.dart';
import 'all_files_screen.dart';
import 'starred_files_screen.dart';
import 'folders_screen.dart';
import 'trash_screen.dart';
import 'downloads_screen.dart';
import 'settings_screen.dart';
import 'help_support_screen.dart';
import '../widgets/storage_usage_card.dart';
import 'package:documents_organizer/providers/auth_provider.dart';
import '../providers/google_drive_provider.dart';
import '../providers/sync_provider.dart';

class ProfileScreen extends ConsumerWidget {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(authStateProvider).value;
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    
    final displayName = user?.displayName ?? 'User';
    final email = user?.email ?? 'No email';
    final photoUrl = user?.photoURL;
    final initials = displayName.isNotEmpty ? displayName[0].toUpperCase() : 'U';

    return Scaffold(
      appBar: AppBar(
        title: const Text('Profile', style: TextStyle(fontWeight: FontWeight.bold)),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: Column(
            children: [
            photoUrl != null
                ? CircleAvatar(
                    radius: 50,
                    backgroundImage: NetworkImage(photoUrl),
                  )
                : CircleAvatar(
                    radius: 50,
                    backgroundColor: Colors.blue,
                    child: Text(initials, style: const TextStyle(fontSize: 32, color: Colors.white, fontWeight: FontWeight.bold)),
                  ),
            const SizedBox(height: 16),
            Text(
              displayName, 
              style: TextStyle(
                fontSize: 22, 
                fontWeight: FontWeight.bold,
                color: isDark ? Colors.white : Colors.black,
              ),
            ),
            Text(
              email, 
              style: TextStyle(color: isDark ? Colors.grey[400] : Colors.grey),
            ),
            const SizedBox(height: 30),
            const StorageUsageCard(),
            const SizedBox(height: 30),
            _buildProfileOption(
              context,
              Icons.folder_outlined,
              'My Documents',
              onTap: () => Navigator.push(context, MaterialPageRoute(builder: (context) => const AllFilesScreen())),
            ),
            _buildProfileOption(
              context,
              Icons.create_new_folder_outlined,
              'Folders',
              onTap: () => Navigator.push(context, MaterialPageRoute(builder: (context) => const FoldersScreen())),
            ),
            _buildProfileOption(
              context,
              Icons.star_outline,
              'Starred',
              onTap: () => Navigator.push(context, MaterialPageRoute(builder: (context) => const StarredFilesScreen())),
            ),
            _buildProfileOption(
              context,
              Icons.delete_outline,
              'Trash',
              onTap: () => Navigator.push(context, MaterialPageRoute(builder: (context) => const TrashScreen())),
            ),
            _buildProfileOption(
              context,
              Icons.download_for_offline_outlined,
              'Downloads',
              onTap: () => Navigator.push(context, MaterialPageRoute(builder: (context) => const DownloadsScreen())),
            ),
            const Divider(height: 40),
            _buildProfileOption(
              context,
              Icons.settings_outlined,
              'Settings',
              onTap: () => Navigator.push(context, MaterialPageRoute(builder: (context) => const SettingsScreen())),
            ),
            _buildProfileOption(
              context,
              Icons.help_outline,
              'Help & Support',
              onTap: () => Navigator.push(context, MaterialPageRoute(builder: (context) => const HelpSupportScreen())),
            ),
            const SizedBox(height: 20),
            ListTile(
              leading: const Icon(Icons.logout, color: Colors.red),
              title: const Text('Logout', style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold)),
              onTap: () => _showLogoutDialog(context, ref),
            ),
          ],
        ),
      ),
      ),
    );
  }

  Widget _buildProfileOption(BuildContext context, IconData icon, String title, {required VoidCallback onTap}) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return ListTile(
      leading: Icon(icon, color: isDark ? Colors.grey[400] : Colors.grey[700]),
      title: Text(
        title, 
        style: TextStyle(
          fontWeight: FontWeight.w500,
          color: isDark ? Colors.white : Colors.black,
        ),
      ),
      trailing: Icon(Icons.chevron_right, size: 20, color: isDark ? Colors.grey[600] : Colors.grey),
      onTap: onTap,
    );
  }

  void _showLogoutDialog(BuildContext context, WidgetRef ref) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Logout'),
        content: const Text('Are you sure you want to logout?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
          TextButton(
            onPressed: () async {
              await ref.read(authServiceProvider).signOut();
              await ref.read(googleDriveServiceProvider).clearSession();
              ref.invalidate(googleDriveFilesProvider);
              ref.invalidate(googleDriveStorageProvider);
              ref.invalidate(googleDriveUsageProvider);
              ref.invalidate(driveStorageBreakdownProvider);
              ref.invalidate(driveFilesNotifierProvider);
              if (context.mounted) {
                Navigator.pop(context);
              }
            },
            child: const Text('Logout', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }
}
