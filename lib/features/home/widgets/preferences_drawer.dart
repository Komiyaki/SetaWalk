import 'dart:async';

import 'package:flutter/material.dart';

import '../models/preferences_data.dart';
import '../utils/poi_tag_style.dart';

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
                      snackLabel: (v) => 'Set to see $v shrine${v == 1 ? '' : 's'}',
                      value: preferences.shrines,
                      min: 0,
                      max: 5,
                      divisions: 5,
                      accentColor:
                          PoiTagStyle.colorForTagId(PoiTagStyle.placeOfWorship),
                      onChanged: onShrinesChanged,
                    ),
                    const SizedBox(height: 20),
                    _PreferenceSliderRow(
                      label: 'Shopping',
                      snackLabel: (v) => 'Set to see $v shopping spot${v == 1 ? '' : 's'}',
                      value: preferences.shopping,
                      min: 0,
                      max: 5,
                      divisions: 5,
                      accentColor: PoiTagStyle.colorForTagId(PoiTagStyle.shopping),
                      onChanged: onShoppingChanged,
                    ),
                    const SizedBox(height: 20),
                    _PreferenceSliderRow(
                      label: 'Cafes',
                      snackLabel: (v) => 'Set to see $v cafe${v == 1 ? '' : 's'}',
                      value: preferences.cafes,
                      min: 0,
                      max: 5,
                      divisions: 5,
                      accentColor: PoiTagStyle.colorForTagId(PoiTagStyle.eating),
                      onChanged: onCafesChanged,
                    ),
                    const SizedBox(height: 20),
                    _PreferenceSliderRow(
                      label: 'Parks',
                      snackLabel: (v) => 'Set to see $v park${v == 1 ? '' : 's'}',
                      value: preferences.parks,
                      min: 0,
                      max: 5,
                      divisions: 5,
                      accentColor: PoiTagStyle.colorForTagId(PoiTagStyle.park),
                      onChanged: onParksChanged,
                    ),
                    const SizedBox(height: 20),
                    _PreferenceSliderRow(
                      label: 'Duration',
                      snackLabel: (v) => 'Extra walk time set to $v%',
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

class _PreferenceSliderRow extends StatefulWidget {
  final String label;
  final String Function(int) snackLabel;
  final double value;
  final double min;
  final double max;
  final int divisions;
  final Color? accentColor;
  final ValueChanged<double> onChanged;

  const _PreferenceSliderRow({
    required this.label,
    required this.snackLabel,
    required this.value,
    required this.min,
    required this.max,
    required this.divisions,
    this.accentColor,
    required this.onChanged,
  });

  @override
  State<_PreferenceSliderRow> createState() => _PreferenceSliderRowState();
}

class _PreferenceSliderRowState extends State<_PreferenceSliderRow> {
  String _message = '';
  bool _visible = false;
  Timer? _hideTimer;

  void _showMessage(int value) {
    _hideTimer?.cancel();
    setState(() {
      _message = widget.snackLabel(value);
      _visible = true;
    });
    _hideTimer = Timer(const Duration(milliseconds: 1400), () {
      if (mounted) setState(() => _visible = false);
    });
  }

  @override
  void dispose() {
    _hideTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final accent = widget.accentColor;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            SizedBox(
              width: 110,
              child: Row(
                children: [
                  if (accent != null) ...[
                    Container(
                      width: 10,
                      height: 10,
                      decoration: BoxDecoration(
                        color: accent,
                        shape: BoxShape.circle,
                      ),
                    ),
                    const SizedBox(width: 8),
                  ],
                  Expanded(
                    child: Text(widget.label, style: const TextStyle(fontSize: 16)),
                  ),
                ],
              ),
            ),
            Expanded(
              child: SliderTheme(
                data: accent == null
                    ? SliderTheme.of(context)
                    : SliderTheme.of(context).copyWith(
                        activeTrackColor: accent,
                        inactiveTrackColor: accent.withOpacity(0.25),
                        thumbColor: accent,
                        overlayColor: accent.withOpacity(0.12),
                        valueIndicatorColor: accent,
                      ),
                child: Slider(
                  value: widget.value,
                  min: widget.min,
                  max: widget.max,
                  divisions: widget.divisions,
                  label: widget.value.round().toString(),
                  onChanged: widget.onChanged,
                  onChangeEnd: (v) => _showMessage(v.round()),
                ),
              ),
            ),
          ],
        ),
        AnimatedOpacity(
          opacity: _visible ? 1.0 : 0.0,
          duration: const Duration(milliseconds: 300),
          child: Padding(
            padding: const EdgeInsets.only(left: 110, bottom: 2),
            child: Text(
              _message,
              style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
            ),
          ),
        ),
      ],
    );
  }
}
