import 'package:flutter/material.dart';

import '../services/google_places_service.dart';

class TurnByTurnPanel extends StatefulWidget {
  final String distance;
  final String duration;
  final List<RouteStep> steps;

  const TurnByTurnPanel({
    super.key,
    required this.distance,
    required this.duration,
    required this.steps,
  });

  @override
  State<TurnByTurnPanel> createState() => _TurnByTurnPanelState();
}

class _TurnByTurnPanelState extends State<TurnByTurnPanel> {
  bool _expanded = false;

  IconData _maneuverIcon(String? maneuver) {
    switch (maneuver) {
      case 'turn-left':
        return Icons.turn_left;
      case 'turn-right':
        return Icons.turn_right;
      case 'turn-slight-left':
        return Icons.turn_slight_left;
      case 'turn-slight-right':
        return Icons.turn_slight_right;
      case 'turn-sharp-left':
        return Icons.turn_sharp_left;
      case 'turn-sharp-right':
        return Icons.turn_sharp_right;
      case 'straight':
      case 'keep-left':
      case 'keep-right':
        return Icons.straight;
      case 'roundabout-left':
        return Icons.roundabout_left;
      case 'roundabout-right':
        return Icons.roundabout_right;
      case 'uturn-left':
        return Icons.u_turn_left;
      case 'uturn-right':
        return Icons.u_turn_right;
      default:
        return Icons.directions_walk;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Material(
      elevation: 4,
      borderRadius: BorderRadius.circular(12),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Header — always visible, tappable to expand
          InkWell(
            onTap: () => setState(() => _expanded = !_expanded),
            borderRadius: BorderRadius.circular(12),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              child: Row(
                children: [
                  const Icon(
                    Icons.directions_walk,
                    size: 18,
                    color: Color(0xFF1A73E8),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    '${widget.distance}  ·  ${widget.duration}',
                    style: const TextStyle(
                      fontWeight: FontWeight.w600,
                      fontSize: 14,
                    ),
                  ),
                  const Spacer(),
                  Icon(
                    _expanded ? Icons.expand_less : Icons.expand_more,
                    size: 20,
                    color: Colors.grey,
                  ),
                ],
              ),
            ),
          ),
          // Expandable steps list
          if (_expanded) ...[
            const Divider(height: 1),
            ConstrainedBox(
              constraints: const BoxConstraints(maxHeight: 260),
              child: ListView.separated(
                shrinkWrap: true,
                padding: const EdgeInsets.symmetric(vertical: 4),
                itemCount: widget.steps.length,
                separatorBuilder: (_, _) =>
                    const Divider(height: 1, indent: 52),
                itemBuilder: (_, index) {
                  final step = widget.steps[index];
                  return ListTile(
                    leading: Icon(
                      _maneuverIcon(step.maneuver),
                      size: 20,
                      color: const Color(0xFF1A73E8),
                    ),
                    title: Text(
                      step.instruction,
                      style: const TextStyle(fontSize: 13),
                    ),
                    trailing: Text(
                      step.distance,
                      style: const TextStyle(
                        fontSize: 12,
                        color: Colors.grey,
                      ),
                    ),
                    dense: true,
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 2,
                    ),
                  );
                },
              ),
            ),
          ],
        ],
      ),
    );
  }
}
