import 'dart:io' show File;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:hazard_warning_app/core/data/seed_data.dart';
import 'package:hazard_warning_app/core/models/models.dart';
import 'package:hazard_warning_app/core/state/app_state.dart';
import 'package:hazard_warning_app/core/theme/app_theme.dart';
import 'package:hazard_warning_app/core/widgets/common_widgets.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';

class SubmitHazardReportScreen extends StatefulWidget {
  const SubmitHazardReportScreen({super.key});

  @override
  State<SubmitHazardReportScreen> createState() =>
      _SubmitHazardReportScreenState();
}

class _SubmitHazardReportScreenState extends State<SubmitHazardReportScreen> {
  HazardCategory _category = HazardCategory.risingRiver;
  String? _photoPath;
  GeoCoordinate _coordinates = const GeoCoordinate(
    latitude: 6.9382,
    longitude: 79.9012,
  );
  String _locationLabel = 'Kelani river bank, Kolonnawa';
  bool _busy = false;

  Future<void> _pickPhoto() async {
    final picker = ImagePicker();
    final file = await picker.pickImage(
      source: ImageSource.camera,
      imageQuality: 85,
    );
    if (file != null) setState(() => _photoPath = file.path);
  }

  Future<void> _submit() async {
    setState(() => _busy = true);
    final state = context.read<AppState>();
    final report = await state.submitGroundReport(
      category: _category,
      areaLabel: SeedData.defaultArea,
      locationLabel: _locationLabel,
      coordinates: _coordinates,
      photoPath: _photoPath,
    );
    if (!mounted) return;
    setState(() => _busy = false);
    context.go('/citizen/report/submitted/${report.id}');
  }

  @override
  Widget build(BuildContext context) {
    final online = context.watch<AppState>().online;

    return Scaffold(
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.only(bottom: 32),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              ScreenHeader(
                title: 'Report hazard',
                subtitle: SeedData.defaultArea,
                onBack: () => context.pop(),
              ),
              if (!online) ...[
                const SizedBox(height: 16),
                const OfflineBanner(),
              ],
              const SizedBox(height: 24),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const SectionTitle('Photo of the hazard'),
                    _PhotoPreview(path: _photoPath),
                    const SizedBox(height: 12),
                    OutlinedButton.icon(
                      onPressed: _pickPhoto,
                      style: OutlinedButton.styleFrom(
                        minimumSize: const Size(double.infinity, 52),
                        side: const BorderSide(color: AppColors.accentBlue),
                        foregroundColor: AppColors.accentBlue,
                      ),
                      icon: const Icon(Icons.photo_camera_outlined),
                      label: Text(
                        _photoPath == null ? 'Add photo' : 'Replace photo',
                      ),
                    ),
                    const SizedBox(height: 28),
                    const SectionTitle('What are you reporting?'),
                    ...HazardCategory.values.map((category) {
                      final selected = category == _category;
                      return Padding(
                        padding: const EdgeInsets.only(bottom: 10),
                        child: Material(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(16),
                          child: InkWell(
                            borderRadius: BorderRadius.circular(16),
                            onTap: () => setState(() => _category = category),
                            child: Container(
                              padding: const EdgeInsets.all(16),
                              decoration: BoxDecoration(
                                borderRadius: BorderRadius.circular(16),
                                border: Border.all(
                                  color: selected
                                      ? AppColors.accentBlue
                                      : AppColors.borderGrey,
                                  width: selected ? 2 : 1,
                                ),
                              ),
                              child: Row(
                                children: [
                                  Icon(
                                    category.icon,
                                    color: AppColors.accentBlue,
                                  ),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: Text(
                                      category.label,
                                      style: const TextStyle(
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                  ),
                                  Icon(
                                    selected
                                        ? Icons.check_circle_rounded
                                        : Icons.circle_outlined,
                                    color: selected
                                        ? AppColors.accentBlue
                                        : AppColors.borderGrey,
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      );
                    }),
                    const SizedBox(height: 28),
                    const SectionTitle('Location'),
                    Container(
                      height: 140,
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: AppColors.borderGrey),
                        gradient: const LinearGradient(
                          colors: [Color(0xFFE2E8F0), Color(0xFFCBD5E1)],
                        ),
                      ),
                      child: const Center(
                        child: Icon(
                          Icons.location_on,
                          color: AppColors.severityHigh,
                          size: 40,
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        const Icon(
                          Icons.check_circle,
                          color: AppColors.successGreen,
                          size: 20,
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text(
                                'GPS location attached',
                                style: TextStyle(fontWeight: FontWeight.w700),
                              ),
                              Text(
                                _coordinates.formatted,
                                style: Theme.of(context).textTheme.bodySmall,
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    TextButton.icon(
                      onPressed: () async {
                        final result = await context.push<Map<String, dynamic>>(
                          '/citizen/report/manual-location',
                        );
                        if (result != null) {
                          setState(() {
                            _locationLabel = result['label'] as String;
                            _coordinates = GeoCoordinate(
                              latitude: result['lat'] as double,
                              longitude: result['lng'] as double,
                            );
                          });
                        }
                      },
                      icon: const Icon(Icons.edit_outlined, size: 18),
                      label: const Text('Enter location manually'),
                    ),
                    const SizedBox(height: 28),
                    PrimaryActionButton(
                      label: 'Submit report',
                      icon: Icons.send_rounded,
                      busy: _busy,
                      onPressed: _submit,
                    ),
                    const SizedBox(height: 12),
                    Center(
                      child: Text(
                        'Your report is queued as Pending until a duty officer verifies it.',
                        textAlign: TextAlign.center,
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _PhotoPreview extends StatelessWidget {
  const _PhotoPreview({this.path});

  final String? path;

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(16),
          child: Container(
            height: 180,
            width: double.infinity,
            color: const Color(0xFFCBD5E1),
            child: path != null
                ? (kIsWeb
                      ? Image.network(path!, fit: BoxFit.cover)
                      : Image.file(File(path!), fit: BoxFit.cover))
                : const Icon(
                    Icons.image_outlined,
                    size: 48,
                    color: Colors.white70,
                  ),
          ),
        ),
        if (path != null)
          Positioned(
            left: 12,
            bottom: 12,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                color: Colors.black87,
                borderRadius: BorderRadius.circular(999),
              ),
              child: const Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.check, color: Colors.white, size: 16),
                  SizedBox(width: 4),
                  Text(
                    'Photo attached',
                    style: TextStyle(color: Colors.white, fontSize: 12),
                  ),
                ],
              ),
            ),
          ),
      ],
    );
  }
}
