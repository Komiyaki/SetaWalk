import 'dart:math' as math;
import 'package:flutter/material.dart';

class MapCompass extends StatelessWidget {
  final double bearing;
  final VoidCallback onTap;

  const MapCompass({
    super.key,
    required this.bearing,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white,
      elevation: 4,
      shape: const CircleBorder(),
      child: InkWell(
        onTap: onTap,
        customBorder: const CircleBorder(),
        child: SizedBox(
          width: 48,
          height: 48,
          child: Center(
            child: Transform.rotate(
              angle: -bearing * math.pi / 180,
              child: const Icon(
                Icons.navigation,
                size: 28,
                color: Colors.red,
              ),
            ),
          ),
        ),
      ),
    );
  }
}