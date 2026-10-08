import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:hazard_warning_app/core/widgets/common_widgets.dart';

class ManualLocationScreen extends StatefulWidget {
  const ManualLocationScreen({super.key});

  @override
  State<ManualLocationScreen> createState() => _ManualLocationScreenState();
}

class _ManualLocationScreenState extends State<ManualLocationScreen> {
  final _labelCtrl = TextEditingController(
    text: 'Kelani river bank, Kolonnawa',
  );
  final _latCtrl = TextEditingController(text: '6.9382');
  final _lngCtrl = TextEditingController(text: '79.9012');

  @override
  void dispose() {
    _labelCtrl.dispose();
    _latCtrl.dispose();
    _lngCtrl.dispose();
    super.dispose();
  }

  void _save() {
    final lat = double.tryParse(_latCtrl.text.trim());
    final lng = double.tryParse(_lngCtrl.text.trim());
    if (lat == null || lng == null || _labelCtrl.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Enter a label and valid coordinates')),
      );
      return;
    }
    context.pop({'label': _labelCtrl.text.trim(), 'lat': lat, 'lng': lng});
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              ScreenHeader(
                title: 'Manual location',
                subtitle: 'Override GPS when signal is weak',
                onBack: () => context.pop(),
              ),
              const SizedBox(height: 24),
              TextField(
                controller: _labelCtrl,
                decoration: const InputDecoration(
                  labelText: 'Place description',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: _latCtrl,
                keyboardType: const TextInputType.numberWithOptions(
                  decimal: true,
                ),
                decoration: const InputDecoration(
                  labelText: 'Latitude (° N)',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: _lngCtrl,
                keyboardType: const TextInputType.numberWithOptions(
                  decimal: true,
                ),
                decoration: const InputDecoration(
                  labelText: 'Longitude (° E)',
                  border: OutlineInputBorder(),
                ),
              ),
              const Spacer(),
              PrimaryActionButton(label: 'Use this location', onPressed: _save),
            ],
          ),
        ),
      ),
    );
  }
}
