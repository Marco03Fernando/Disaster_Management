import 'dart:io' show File;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:hazard_warning_app/core/data/seed_data.dart';
import 'package:hazard_warning_app/core/models/models.dart';
import 'package:hazard_warning_app/core/state/app_state.dart';
import 'package:hazard_warning_app/core/theme/app_theme.dart';
import 'package:hazard_warning_app/core/widgets/common_widgets.dart';
import 'package:hazard_warning_app/features/citizen/report_submission_rules.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';

class SubmitHazardReportScreen extends StatefulWidget {
  const SubmitHazardReportScreen({super.key});

  @override
  State<SubmitHazardReportScreen> createState() =>
      _SubmitHazardReportScreenState();
}

enum _PhotoAction { camera, gallery, remove }

enum _DuplicateChoice { view, submit }

class _SubmitHazardReportScreenState extends State<SubmitHazardReportScreen> {
  /// No default: the citizen must choose, so a report is never filed under a
  /// hazard type they did not pick.
  HazardCategory? _category;
  String? _photoPath;
  GeoCoordinate _coordinates = const GeoCoordinate(
    latitude: 6.9382,
    longitude: 79.9012,
  );
  String _locationLabel = 'Kelani river bank, Kolonnawa';
  bool _manualLocation = false;
  bool _busy = false;

  /// Set after the first submit attempt so errors show from then on.
  bool _attempted = false;

  /// One ID per form, so retrying after an error never creates a second
  /// report for the same submission.
  final _draftId = newReportId();
  final _formKey = GlobalKey<FormState>();
  final _categoryKey = GlobalKey();
  final _descriptionKey = GlobalKey();
  final _phoneKey = GlobalKey();
  final _notesCtrl = TextEditingController();
  final _nameCtrl = TextEditingController();
  final _phoneCtrl = TextEditingController();

  @override
  void initState() {
    super.initState();
    _recoverLostPhoto();
  }

  @override
  void dispose() {
    _notesCtrl.dispose();
    _nameCtrl.dispose();
    _phoneCtrl.dispose();
    super.dispose();
  }

  bool get _hasInput =>
      _category != null ||
      _photoPath != null ||
      _manualLocation ||
      _notesCtrl.text.trim().isNotEmpty ||
      _nameCtrl.text.trim().isNotEmpty ||
      _phoneCtrl.text.trim().isNotEmpty;

  /// Android may close the app while the camera is open; recover the photo
  /// it took instead of losing it.
  Future<void> _recoverLostPhoto() async {
    if (kIsWeb || defaultTargetPlatform != TargetPlatform.android) return;
    try {
      final response = await ImagePicker().retrieveLostData();
      if (!mounted || response.isEmpty) return;
      final file = response.file;
      if (file != null) {
        setState(() => _photoPath = file.path);
      } else if (response.exception != null) {
        _showMessage(describePhotoError(response.exception!, fromCamera: true));
      }
    } catch (_) {
      // Nothing to recover.
    }
  }

  void _showMessage(String text) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(text)));
  }

  Future<void> _pickPhoto() async {
    final action = await showModalBottomSheet<_PhotoAction>(
      context: context,
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.photo_camera_outlined),
              title: const Text('Take a photo'),
              onTap: () => Navigator.pop(context, _PhotoAction.camera),
            ),
            ListTile(
              leading: const Icon(Icons.photo_library_outlined),
              title: const Text('Choose from gallery'),
              onTap: () => Navigator.pop(context, _PhotoAction.gallery),
            ),
            if (_photoPath != null)
              ListTile(
                leading: const Icon(
                  Icons.delete_outline_rounded,
                  color: AppColors.severityHigh,
                ),
                title: const Text('Remove photo'),
                onTap: () => Navigator.pop(context, _PhotoAction.remove),
              ),
          ],
        ),
      ),
    );
    if (action == null) return;
    if (action == _PhotoAction.remove) {
      setState(() => _photoPath = null);
      return;
    }
    final fromCamera = action == _PhotoAction.camera;
    try {
      final file = await ImagePicker().pickImage(
        source: fromCamera ? ImageSource.camera : ImageSource.gallery,
        imageQuality: 85,
        maxWidth: 1920,
      );
      if (file != null && mounted) setState(() => _photoPath = file.path);
    } catch (e) {
      if (!mounted) return;
      _showMessage(describePhotoError(e, fromCamera: fromCamera));
    }
  }

  String? _trimmed(TextEditingController c) {
    final t = c.text.trim();
    return t.isEmpty ? null : t;
  }

  /// Validates every field and scrolls to the first one with a problem.
  bool _validate() {
    setState(() => _attempted = true);
    final fieldsValid = _formKey.currentState!.validate();
    final categoryError = validateHazardCategory(_category);
    if (fieldsValid && categoryError == null) return true;

    final firstInvalid = categoryError != null
        ? _categoryKey
        : validateDescription(_notesCtrl.text) != null
        ? _descriptionKey
        : _phoneKey;
    final target = firstInvalid.currentContext;
    if (target != null) {
      Scrollable.ensureVisible(
        target,
        duration: const Duration(milliseconds: 300),
        alignment: 0.1,
      );
    }
    _showMessage('Please complete the highlighted fields.');
    return false;
  }

  /// Asks before filing a second report of the same type the citizen sent a
  /// few minutes ago. Similar reports are never blocked.
  Future<bool> _confirmNotDuplicate(AppState state) async {
    final earlier = recentOwnReport(
      category: _category!,
      myReports: state.myReports,
      now: DateTime.now(),
    );
    if (earlier == null) return true;
    final minutes = DateTime.now().difference(earlier.submittedAt).inMinutes;
    final when = minutes < 1 ? 'just now' : '$minutes min ago';
    final choice = await showDialog<_DuplicateChoice>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Already reported?'),
        content: Text(
          'You reported a ${earlier.category.label.toLowerCase()} $when '
          '(${earlier.id}). Submit a new report only if this is a different '
          'place or the situation has changed.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, _DuplicateChoice.view),
            child: const Text('View earlier report'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, _DuplicateChoice.submit),
            child: const Text('Submit anyway'),
          ),
        ],
      ),
    );
    if (choice == _DuplicateChoice.view && mounted) {
      context.push('/citizen/reports/${earlier.id}');
    }
    return choice == _DuplicateChoice.submit;
  }

  Future<void> _submit() async {
    if (_busy || !_validate()) return;
    final state = context.read<AppState>();
    if (!await _confirmNotDuplicate(state) || !mounted) return;
    setState(() => _busy = true);
    try {
      final report = await state.submitGroundReport(
        id: _draftId,
        category: _category!,
        areaLabel: SeedData.defaultArea,
        locationLabel: _locationLabel,
        coordinates: _coordinates,
        photoPath: _photoPath,
        notes: _trimmed(_notesCtrl),
        contact: ReporterContact(
          name: _trimmed(_nameCtrl),
          phone: _trimmed(_phoneCtrl),
        ),
      );
      if (!mounted) return;
      setState(() => _busy = false);
      context.go('/citizen/report/submitted/${report.id}');
    } catch (e) {
      if (!mounted) return;
      setState(() => _busy = false);
      _showMessage(
        'Report not sent. ${describeSubmissionError(e)} '
        'Your details are still here.',
      );
    }
  }

  Future<void> _confirmLeave() async {
    if (_busy) return;
    if (!_hasInput) {
      Navigator.of(context).pop();
      return;
    }
    final discard = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Discard this report?'),
        content: const Text('The details you entered will be lost.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Keep editing'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            style: TextButton.styleFrom(
              foregroundColor: AppColors.severityHigh,
            ),
            child: const Text('Discard'),
          ),
        ],
      ),
    );
    if (discard == true && mounted) Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final online = context.watch<AppState>().online;
    final categoryError = _attempted ? validateHazardCategory(_category) : null;

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) _confirmLeave();
      },
      child: Scaffold(
        body: SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.only(bottom: 32),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                ScreenHeader(
                  title: 'Report hazard',
                  subtitle: SeedData.defaultArea,
                  onBack: () => Navigator.maybePop(context),
                ),
                if (!online) ...[
                  const SizedBox(height: 16),
                  const OfflineBanner(),
                ],
                const SizedBox(height: 24),
                IgnorePointer(
                  ignoring: _busy,
                  child: Form(
                    key: _formKey,
                    autovalidateMode: _attempted
                        ? AutovalidateMode.onUserInteraction
                        : AutovalidateMode.disabled,
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 20),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const SectionTitle('Photo of the hazard (optional)'),
                          _PhotoPreview(path: _photoPath),
                          const SizedBox(height: 12),
                          OutlinedButton.icon(
                            onPressed: _pickPhoto,
                            style: OutlinedButton.styleFrom(
                              minimumSize: const Size(double.infinity, 52),
                              side: const BorderSide(
                                color: AppColors.accentBlue,
                              ),
                              foregroundColor: AppColors.accentBlue,
                            ),
                            icon: const Icon(Icons.photo_camera_outlined),
                            label: Text(
                              _photoPath == null
                                  ? 'Add photo'
                                  : 'Replace or remove photo',
                            ),
                          ),
                          const SizedBox(height: 28),
                          SectionTitle(
                            'What are you reporting?',
                            key: _categoryKey,
                          ),
                          ...HazardCategory.values.map(
                            (category) => _CategoryTile(
                              category: category,
                              selected: category == _category,
                              hasError: categoryError != null,
                              onTap: () => setState(() => _category = category),
                            ),
                          ),
                          if (categoryError != null) _FieldError(categoryError),
                          const SizedBox(height: 28),
                          const SectionTitle('Location'),
                          ExcludeSemantics(
                            child: Container(
                              height: 140,
                              decoration: BoxDecoration(
                                borderRadius: BorderRadius.circular(16),
                                border: Border.all(color: AppColors.borderGrey),
                                gradient: const LinearGradient(
                                  colors: [
                                    Color(0xFFE2E8F0),
                                    Color(0xFFCBD5E1),
                                  ],
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
                          ),
                          const SizedBox(height: 12),
                          Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Icon(
                                _manualLocation
                                    ? Icons.check_circle
                                    : Icons.info_outline_rounded,
                                color: _manualLocation
                                    ? AppColors.successGreen
                                    : AppColors.textGrey,
                                size: 20,
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      _manualLocation
                                          ? 'Location entered manually'
                                          : 'Approximate area location '
                                                '(not GPS)',
                                      style: const TextStyle(
                                        fontWeight: FontWeight.w700,
                                      ),
                                    ),
                                    Text(
                                      '$_locationLabel · '
                                      '${_coordinates.formatted}',
                                      style: Theme.of(context)
                                          .textTheme
                                          .bodySmall,
                                    ),
                                    if (!_manualLocation)
                                      Text(
                                        'Enter the location manually if you '
                                        'know where the hazard is.',
                                        style: Theme.of(context)
                                            .textTheme
                                            .bodySmall,
                                      ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                          TextButton.icon(
                            onPressed: () async {
                              final result = await context
                                  .push<Map<String, dynamic>>(
                                    '/citizen/report/manual-location',
                                  );
                              if (result != null) {
                                setState(() {
                                  _manualLocation = true;
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
                          const SectionTitle('Describe what you see'),
                          TextFormField(
                            key: _descriptionKey,
                            controller: _notesCtrl,
                            minLines: 3,
                            maxLines: 6,
                            maxLength: ReportFormRules.maxDescriptionLength,
                            textCapitalization: TextCapitalization.sentences,
                            validator: validateDescription,
                            decoration: const InputDecoration(
                              labelText: 'Description (required)',
                              alignLabelWithHint: true,
                              hintText:
                                  'e.g. Water is over the road and rising near '
                                  'the bridge',
                              border: OutlineInputBorder(),
                            ),
                          ),
                          const SizedBox(height: 20),
                          const SectionTitle('Your contact (optional)'),
                          Text(
                            'Only DMC duty officers can see this, in case they '
                            'need to call you about the hazard.',
                            style: Theme.of(context).textTheme.bodySmall,
                          ),
                          const SizedBox(height: 12),
                          TextFormField(
                            controller: _nameCtrl,
                            textCapitalization: TextCapitalization.words,
                            maxLength: ReportFormRules.maxNameLength,
                            decoration: const InputDecoration(
                              labelText: 'Name',
                              prefixIcon: Icon(Icons.person_outline_rounded),
                              border: OutlineInputBorder(),
                              counterText: '',
                            ),
                          ),
                          const SizedBox(height: 12),
                          TextFormField(
                            key: _phoneKey,
                            controller: _phoneCtrl,
                            keyboardType: TextInputType.phone,
                            maxLength: ReportFormRules.maxPhoneLength,
                            validator: validatePhone,
                            decoration: const InputDecoration(
                              labelText: 'Phone number',
                              prefixIcon: Icon(Icons.phone_outlined),
                              border: OutlineInputBorder(),
                              counterText: '',
                            ),
                          ),
                          const SizedBox(height: 28),
                        ],
                      ),
                    ),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  child: Column(
                    children: [
                      PrimaryActionButton(
                        label: 'Submit report',
                        icon: Icons.send_rounded,
                        busy: _busy,
                        onPressed: _submit,
                      ),
                      const SizedBox(height: 12),
                      Center(
                        child: Text(
                          _busy
                              ? 'Sending your report…'
                              : 'Your report is queued as Pending until a '
                                    'duty officer verifies it.',
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
      ),
    );
  }
}

class _CategoryTile extends StatelessWidget {
  const _CategoryTile({
    required this.category,
    required this.selected,
    required this.hasError,
    required this.onTap,
  });

  final HazardCategory category;
  final bool selected;
  final bool hasError;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final borderColor = selected
        ? AppColors.accentBlue
        : hasError
        ? AppColors.severityHigh
        : AppColors.borderGrey;
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      // Screen readers announce the choice as a selectable option.
      child: Semantics(
        button: true,
        selected: selected,
        inMutuallyExclusiveGroup: true,
        child: Material(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          child: InkWell(
            borderRadius: BorderRadius.circular(16),
            onTap: onTap,
            child: Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: borderColor, width: selected ? 2 : 1),
              ),
              child: Row(
                children: [
                  Icon(category.icon, color: AppColors.accentBlue),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      category.label,
                      style: const TextStyle(fontWeight: FontWeight.w600),
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
      ),
    );
  }
}

class _FieldError extends StatelessWidget {
  const _FieldError(this.message);

  final String message;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      liveRegion: true,
      child: Padding(
        padding: const EdgeInsets.only(left: 12, top: 2),
        child: Text(
          message,
          style: Theme.of(context).textTheme.bodySmall
              ?.copyWith(color: Theme.of(context).colorScheme.error),
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
    return Semantics(
      image: true,
      label: path == null ? 'No photo added' : 'Photo of the hazard attached',
      child: ExcludeSemantics(
        child: Stack(
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
                          : Image.file(
                              File(path!),
                              fit: BoxFit.cover,
                              errorBuilder: (_, _, _) => const Icon(
                                Icons.broken_image_outlined,
                                size: 48,
                                color: Colors.white70,
                              ),
                            ))
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
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 6,
                  ),
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
        ),
      ),
    );
  }
}
