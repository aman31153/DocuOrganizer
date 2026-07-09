import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class DriveStatusCard extends StatelessWidget {
  final AsyncValue<Map<String, double>> driveUsageAsync;
  final AsyncValue<Map<String, double>> storageBreakdownAsync;

  const DriveStatusCard({
    super.key,
    required this.driveUsageAsync,
    required this.storageBreakdownAsync,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

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
}

Widget _buildHorizontalProgressBar(double totalMB, double img, double vid, double doc, double oth, double used) {
  if (totalMB <= 0) return const SizedBox(height: 8);

  final double imgPct = img / totalMB;
  final double vidPct = vid / totalMB;
  final double docPct = doc / totalMB;
  final double othPct = oth / totalMB;

  final double accounted = img + vid + doc + oth;
  double unaccounted = used - accounted;
  if (unaccounted < 0) unaccounted = 0;
  final double unaccountedPct = unaccounted / totalMB;

  return ClipRRect(
    borderRadius: BorderRadius.circular(4),
    child: LayoutBuilder(builder: (context, constraints) {
      final maxWidth = constraints.maxWidth;
      return Container(
        height: 8,
        width: double.infinity,
        color: Colors.grey.shade300,
        child: Stack(
          children: [
            _buildAnimatedSegment(0, maxWidth * imgPct, Colors.amber),
            _buildAnimatedSegment(maxWidth * imgPct, maxWidth * vidPct, Colors.red),
            _buildAnimatedSegment(maxWidth * (imgPct + vidPct), maxWidth * docPct, Colors.blue),
            _buildAnimatedSegment(maxWidth * (imgPct + vidPct + docPct), maxWidth * othPct, Colors.grey),
            _buildAnimatedSegment(maxWidth * (imgPct + vidPct + docPct + othPct), maxWidth * unaccountedPct, Colors.grey.shade400),
          ],
        ),
      );
    }),
  );
}

Widget _buildAnimatedSegment(double left, double width, Color color) {
  return AnimatedPositioned(
    duration: const Duration(milliseconds: 500),
    curve: Curves.easeInOut,
    left: left,
    child: AnimatedContainer(
      duration: const Duration(milliseconds: 500),
      curve: Curves.easeInOut,
      width: width < 0 ? 0 : width,
      height: 8,
      color: color,
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