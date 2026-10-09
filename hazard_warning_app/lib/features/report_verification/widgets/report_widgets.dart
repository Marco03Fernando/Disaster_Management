import 'dart:io' show File;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:hazard_warning_app/core/models/models.dart';
import 'package:hazard_warning_app/core/theme/app_theme.dart';

/// Icon + label + value row used on report detail cards.
class ReportInfoRow extends StatelessWidget {
  const ReportInfoRow({
    super.key,
    required this.icon,
    required this.label,
    required this.value,
    this.last = false,
    this.valueColor,
  });

  final IconData icon;
  final String label;
  final String value;
  final bool last;
  final Color? valueColor;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(bottom: last ? 0 : 16),
      child: MergeSemantics(
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, size: 20, color: AppColors.textGrey),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(label, style: Theme.of(context).textTheme.bodySmall),
                  const SizedBox(height: 2),
                  Text(
                    value,
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      fontWeight: FontWeight.w600,
                      color: valueColor,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Tinted inline message (offline, error, info) in the app's banner style.
class ReviewNotice extends StatelessWidget {
  const ReviewNotice({
    super.key,
    required this.icon,
    required this.message,
    this.title,
    this.background = AppColors.lightBlueBg,
    this.foreground = AppColors.primaryBlue,
    this.action,
  });

  const ReviewNotice.offline({
    super.key,
    required this.message,
    this.title = "You're offline",
    this.action,
  }) : icon = Icons.wifi_off_rounded,
       background = AppColors.offlineBanner,
       foreground = AppColors.offlineText;

  const ReviewNotice.error({
    super.key,
    required this.message,
    this.title,
    this.action,
  }) : icon = Icons.error_outline_rounded,
       background = AppColors.dangerSoft,
       foreground = AppColors.severityHigh;

  final IconData icon;
  final String? title;
  final String message;
  final Color background;
  final Color foreground;
  final Widget? action;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      liveRegion: true,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: background,
          borderRadius: BorderRadius.circular(16),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, color: foreground),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (title != null) ...[
                    Text(
                      title!,
                      style: Theme.of(context).textTheme.titleMedium
                          ?.copyWith(color: foreground),
                    ),
                    const SizedBox(height: 4),
                  ],
                  Text(
                    message,
                    style: Theme.of(context).textTheme.bodySmall
                        ?.copyWith(color: foreground),
                  ),
                  if (action != null) ...[const SizedBox(height: 8), action!],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Centered icon, title and message for loading/empty/error screens.
class ReviewStateView extends StatelessWidget {
  const ReviewStateView({
    super.key,
    required this.icon,
    required this.title,
    required this.message,
    this.color = AppColors.primaryBlue,
    this.action,
  });

  final IconData icon;
  final String title;
  final String message;
  final Color color;
  final Widget? action;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 72,
              height: 72,
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(23),
              ),
              child: Icon(icon, color: color, size: 36),
            ),
            const SizedBox(height: 16),
            Text(
              title,
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 4),
            Text(
              message,
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodySmall,
            ),
            if (action != null) ...[const SizedBox(height: 20), action!],
          ],
        ),
      ),
    );
  }
}

/// Report photo from Firebase Storage, or from this device if it has not been
/// uploaded yet, with a clear placeholder when neither is available.
class ReportPhotoView extends StatelessWidget {
  const ReportPhotoView({super.key, required this.report, this.height = 220});

  final HazardReport report;
  final double height;

  Widget? _image() {
    final url = report.photoUrl;
    if (url != null) {
      return Image.network(
        url,
        fit: BoxFit.cover,
        loadingBuilder: (context, child, progress) => progress == null
            ? child
            : const Center(child: CircularProgressIndicator(strokeWidth: 2)),
        errorBuilder: (_, _, _) => const _PhotoPlaceholder(
          icon: Icons.broken_image_outlined,
          message: 'Photo could not be loaded',
        ),
      );
    }
    final path = report.photoPath;
    if (path == null) return null;
    if (kIsWeb) return Image.network(path, fit: BoxFit.cover);
    final file = File(path);
    if (!file.existsSync()) return null;
    return Image.file(file, fit: BoxFit.cover);
  }

  @override
  Widget build(BuildContext context) {
    final image = _image();
    final placeholder = _PhotoPlaceholder(
      icon: report.photoPending
          ? Icons.cloud_upload_outlined
          : Icons.hide_image_outlined,
      message: report.photoPending
          ? "Photo is still uploading from the reporter's device"
          : 'No photo attached',
    );
    return Semantics(
      image: true,
      label: image == null
          ? placeholder.message
          : 'Photo of the reported hazard. Double tap to enlarge.',
      child: ClipRRect(
        borderRadius: BorderRadius.circular(22),
        child: Container(
          height: height,
          width: double.infinity,
          color: const Color(0xFFCBD5E1),
          child: image == null
              ? placeholder
              : GestureDetector(
                  onTap: () => showDialog<void>(
                    context: context,
                    builder: (context) => Dialog(
                      clipBehavior: Clip.antiAlias,
                      insetPadding: const EdgeInsets.all(16),
                      child: InteractiveViewer(child: _image()!),
                    ),
                  ),
                  child: image,
                ),
        ),
      ),
    );
  }
}

class _PhotoPlaceholder extends StatelessWidget {
  const _PhotoPlaceholder({required this.icon, required this.message});

  final IconData icon;
  final String message;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 40, color: Colors.white),
            const SizedBox(height: 8),
            Text(
              message,
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
