import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:percent_indicator/linear_percent_indicator.dart';
import '../providers/storage_provider.dart';
import '../providers/sync_provider.dart';

class StorageUsageCard extends ConsumerWidget {
  const StorageUsageCard({super.key});

  String formatStorage(double valueInMB) {
    if (valueInMB < 1024) {
      return '${valueInMB.toStringAsFixed(2)} MB';
    } else if (valueInMB < 1024 * 1024) {
      return '${(valueInMB / 1024).toStringAsFixed(2)} GB';
    } else {
      return '${(valueInMB / (1024 * 1024)).toStringAsFixed(2)} TB';
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isGoogleDrive = ref.watch(googleDriveSyncProvider);
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    double usedMB = 0;
    double totalMB = 10.0 * 1024;
    String serviceName = 'Cloudinary Storage';

    if (isGoogleDrive) {
      final driveUsage = ref.watch(googleDriveUsageProvider);
      usedMB = driveUsage.value?['usage'] ?? 0.0;
      totalMB = driveUsage.value?['limit'] ?? (15.0 * 1024);
      serviceName = 'Google Drive Storage';
      
      final localUsedMB = ref.watch(totalStorageUsageProvider);
      if (usedMB < localUsedMB) {
        usedMB = localUsedMB;
      }
    } else {
      usedMB = ref.watch(totalStorageUsageProvider);
      totalMB = 10.0 * 1024;
      serviceName = 'Cloudinary Storage';
    }

    String displayUsage = '${formatStorage(usedMB)} / ${formatStorage(totalMB)}';
    
    // Calculate percentage based on limit
    double percent = totalMB > 0 ? usedMB / totalMB : 0.0;
    if (percent > 1.0) percent = 1.0;
    if (percent < 0.0) percent = 0.0;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: theme.cardTheme.color,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(isDark ? 0.3 : 0.05),
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
              Text(
                serviceName,
                style: TextStyle(
                  fontWeight: FontWeight.w500,
                  fontSize: 14,
                  color: isDark ? Colors.grey[400] : Colors.black54,
                ),
              ),
              Text(
                displayUsage,
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 14,
                  color: isDark ? Colors.white : Colors.black,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          LinearPercentIndicator(
            lineHeight: 8.0,
            percent: percent,
            backgroundColor: isDark ? Colors.grey[800] : Colors.grey[200],
            progressColor: Colors.blue,
            barRadius: const Radius.circular(4),
            padding: EdgeInsets.zero,
            animation: true,
            animateFromLastPercent: true,
            animationDuration: 1000,
          ),
          const SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                '${(percent * 100).toStringAsFixed(2)}%',
                style: TextStyle(
                  fontSize: 12,
                  color: isDark ? Colors.grey[400] : Colors.black54,
                  fontWeight: FontWeight.w500,
                ),
              ),
              if (isGoogleDrive)
                Text(
                  'Available: ${formatStorage(totalMB - usedMB)}',
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.blue,
                    fontWeight: FontWeight.w500,
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }
}
