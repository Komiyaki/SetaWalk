import 'package:flutter/material.dart';

import '../models/preferences_data.dart';

class PreferencesDrawer extends StatelessWidget {
  final PreferencesData preferences;
  final ValueChanged<double> onShrinesChanged;
  final ValueChanged<double> onShoppingChanged;
  final ValueChanged<double> onCafesChanged;
  final ValueChanged<double> onParksChanged;
  final ValueChanged<double> onAddedDurationChanged;
  final VoidCallback onSave;

  const PreferencesDrawer({
    super.key,
    required this.preferences,
    required this.onShrinesChanged,
    required this.onShoppingChanged,
    required this.onCafesChanged,
    required this.onParksChanged,
    required this.onAddedDurationChanged,
    required this.onSave,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      elevation: 12,
      borderRadius: const BorderRadius.only(
        topLeft: Radius.circular(20),
        bottomLeft: Radius.circular(20),
      ),
      clipBehavior: Clip.antiAlias,
      color: Colors.white,
      child: SizedBox(
        width: 300,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Center(
                      child: Text(
                        'Preferences',
                        style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold),
                      ),
                    ),
                    const SizedBox(height: 28),
                    _PreferenceSliderRow(
                      label: 'Shrines',
                      value: preferences.shrines,
                      min: 0,
                      max: 5,
                      divisions: 5,
                      onChanged: onShrinesChanged,
                    ),
                    const SizedBox(height: 20),
                    _PreferenceSliderRow(
                      label: 'Shopping',
                      value: preferences.shopping,
                      min: 0,
                      max: 5,
                      divisions: 5,
                      onChanged: onShoppingChanged,
                    ),
                    const SizedBox(height: 20),
                    _PreferenceSliderRow(
                      label: 'Cafes',
                      value: preferences.cafes,
                      min: 0,
                      max: 5,
                      divisions: 5,
                      onChanged: onCafesChanged,
                    ),
                    const SizedBox(height: 20),
                    _PreferenceSliderRow(
                      label: 'Parks',
                      value: preferences.parks,
                      min: 0,
                      max: 5,
                      divisions: 5,
                      onChanged: onParksChanged,
                    ),
                    const SizedBox(height: 20),
                    _PreferenceSliderRow(
                      label: 'Added Duration',
                      value: preferences.addedDuration,
                      min: 50,
                      max: 200,
                      divisions: 15,
                      onChanged: onAddedDurationChanged,
                    ),
                  ],
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
              child: Center(
                child: ElevatedButton(
                  onPressed: onSave,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.deepPurple,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 28,
                      vertical: 14,
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                  child: const Text(
                    'Save',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _PreferenceSliderRow extends StatelessWidget {
  final String label;
  final double value;
  final double min;
  final double max;
  final int divisions;
  final ValueChanged<double> onChanged;

  const _PreferenceSliderRow({
    required this.label,
    required this.value,
    required this.min,
    required this.max,
    required this.divisions,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        SizedBox(
          width: 110,
          child: Text(label, style: const TextStyle(fontSize: 16)),
        ),
        Expanded(
          child: Slider(
            value: value,
            min: min,
            max: max,
            divisions: divisions,
            label: value.round().toString(),
            onChanged: onChanged,
          ),
        ),
      ],
    );
  }
}
