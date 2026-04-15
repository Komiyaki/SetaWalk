import 'package:flutter/material.dart';

class HomeBottomNavBar extends StatefulWidget {
  final bool canGo;
  final bool isNavigating;
  final bool isLoadingRoute;
  final VoidCallback onSettingsTap;
  final VoidCallback onGoTap;
  final VoidCallback onStopTap;
  final VoidCallback onPreferencesTap;

  const HomeBottomNavBar({
    super.key,
    required this.canGo,
    required this.isNavigating,
    required this.isLoadingRoute,
    required this.onSettingsTap,
    required this.onGoTap,
    required this.onStopTap,
    required this.onPreferencesTap,
  });

  @override
  State<HomeBottomNavBar> createState() => _HomeBottomNavBarState();
}

class _HomeBottomNavBarState extends State<HomeBottomNavBar>
    with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;
  late Animation<double> _anim;

  Color _fromColor = Colors.grey.shade400;
  Color _toColor = Colors.grey.shade400;

  Color _pillColorFor(HomeBottomNavBar w) {
    if (w.isNavigating) return Colors.red.shade600;
    if (w.canGo) return Colors.green.shade600;
    return Colors.grey.shade400;
  }

  Color _shadowColorFor(Color pill) {
    if (pill == Colors.red.shade600) return Colors.red.withValues(alpha: 0.5);
    if (pill == Colors.green.shade600) return Colors.green.withValues(alpha: 0.5);
    return Colors.black.withValues(alpha: 0.2);
  }

  @override
  void initState() {
    super.initState();
    _toColor = _pillColorFor(widget);
    _fromColor = _toColor;

    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 500),
      value: 1.0, // start fully transitioned so first build is a solid colour
    );
    _anim = CurvedAnimation(parent: _ctrl, curve: Curves.easeOutCubic);
  }

  @override
  void didUpdateWidget(HomeBottomNavBar oldWidget) {
    super.didUpdateWidget(oldWidget);
    final next = _pillColorFor(widget);
    if (next != _toColor) {
      _fromColor = _toColor;
      _toColor = next;
      _ctrl.forward(from: 0);
    }
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.of(context).padding.bottom;
    final enabled = widget.canGo || widget.isNavigating;

    return Padding(
      padding: EdgeInsets.only(
        bottom: bottomInset + 16,
        left: 48,
        right: 48,
      ),
      child: AnimatedBuilder(
        animation: _anim,
        builder: (context, child) {
          final t = _anim.value;
          final left = (0.5 - t * 0.5).clamp(0.0, 1.0);
          final right = (0.5 + t * 0.5).clamp(0.0, 1.0);

          // Interpolate shadow colour so the glow transitions in sync
          final shadow = Color.lerp(
            _shadowColorFor(_fromColor),
            _shadowColorFor(_toColor),
            t,
          )!;

          final decoration = BoxDecoration(
            gradient: LinearGradient(
              // Hard stops: new colour starts as a centred sliver
              // and fans out to both edges as t → 1
              colors: [_fromColor, _toColor, _toColor, _fromColor],
              stops: [left, left, right, right],
            ),
            borderRadius: BorderRadius.circular(50),
            boxShadow: [
              BoxShadow(
                color: shadow,
                blurRadius: 20,
                spreadRadius: 1,
                offset: const Offset(0, 4),
              ),
            ],
          );

          return Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
            decoration: decoration,
            child: child,
          );
        },
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: [
            _PillIconButton(
              icon: Icons.settings,
              onTap: () {
                FocusScope.of(context).unfocus();
                widget.onSettingsTap();
              },
            ),
            _CenterButton(
              isNavigating: widget.isNavigating,
              isLoading: widget.isLoadingRoute,
              enabled: enabled,
              onTap: enabled && !widget.isLoadingRoute
                  ? () {
                      FocusScope.of(context).unfocus();
                      if (widget.isNavigating) {
                        widget.onStopTap();
                      } else {
                        widget.onGoTap();
                      }
                    }
                  : null,
            ),
            _PillIconButton(
              icon: Icons.favorite,
              onTap: () {
                FocusScope.of(context).unfocus();
                widget.onPreferencesTap();
              },
            ),
          ],
        ),
      ),
    );
  }
}

class _PillIconButton extends StatelessWidget {
  final IconData icon;
  final VoidCallback onTap;

  const _PillIconButton({required this.icon, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(30),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Icon(icon, color: Colors.white, size: 26),
      ),
    );
  }
}

class _CenterButton extends StatelessWidget {
  final bool isNavigating;
  final bool isLoading;
  final bool enabled;
  final VoidCallback? onTap;

  const _CenterButton({
    required this.isNavigating,
    required this.isLoading,
    required this.enabled,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 450),
        curve: Curves.easeOutCubic,
        width: 60,
        height: 60,
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: enabled ? 0.25 : 0.12),
          shape: BoxShape.circle,
        ),
        child: Center(
          child: isLoading
              ? const SizedBox(
                  width: 24,
                  height: 24,
                  child: CircularProgressIndicator(
                    strokeWidth: 2.5,
                    color: Colors.white,
                  ),
                )
              : AnimatedSwitcher(
                  duration: const Duration(milliseconds: 300),
                  transitionBuilder: (child, animation) => ScaleTransition(
                    scale: animation,
                    child: FadeTransition(opacity: animation, child: child),
                  ),
                  child: Icon(
                    isNavigating ? Icons.stop : Icons.directions_walk,
                    key: ValueKey(isNavigating),
                    color: Colors.white.withValues(alpha: enabled ? 1.0 : 0.45),
                    size: 30,
                  ),
                ),
        ),
      ),
    );
  }
}
