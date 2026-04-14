import 'package:flutter/material.dart';

class SearchCard extends StatelessWidget {
  final TextEditingController startController;
  final TextEditingController destinationController;
  final FocusNode startFocusNode;
  final FocusNode destinationFocusNode;
  final ValueChanged<String> onStartChanged;
  final ValueChanged<String> onDestinationChanged;
  final ValueChanged<String> onStartSubmitted;
  final ValueChanged<String> onDestinationSubmitted;
  final VoidCallback onClearStart;
  final VoidCallback onClearDestination;
  final VoidCallback onUseCurrentLocation;
  final VoidCallback onSwap;

  const SearchCard({
    super.key,
    required this.startController,
    required this.destinationController,
    required this.startFocusNode,
    required this.destinationFocusNode,
    required this.onStartChanged,
    required this.onDestinationChanged,
    required this.onStartSubmitted,
    required this.onDestinationSubmitted,
    required this.onClearStart,
    required this.onClearDestination,
    required this.onUseCurrentLocation,
    required this.onSwap,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: const [
          BoxShadow(blurRadius: 8, offset: Offset(0, 2), color: Colors.black12),
        ],
      ),
      child: Stack(
        children: [
          // Two fields with a thin divider — no extra spacing
          Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              SizedBox(
                height: 56,
                child: TextField(
                  controller: startController,
                  focusNode: startFocusNode,
                  textInputAction: TextInputAction.next,
                  textAlignVertical: TextAlignVertical.center,
                  onChanged: onStartChanged,
                  onSubmitted: onStartSubmitted,
                  decoration: InputDecoration(
                    hintText: 'Choose starting point',
                    prefixIcon: const Icon(Icons.radio_button_checked),
                    suffixIcon: startController.text.isNotEmpty
                        ? IconButton(
                            icon: const Icon(Icons.close),
                            onPressed: onClearStart,
                          )
                        : IconButton(
                            icon: const Icon(Icons.my_location, size: 20),
                            onPressed: onUseCurrentLocation,
                            tooltip: 'Use current location',
                          ),
                    border: InputBorder.none,
                    contentPadding: EdgeInsets.zero,
                  ),
                ),
              ),
              const Divider(height: 1),
              SizedBox(
                height: 56,
                child: TextField(
                  controller: destinationController,
                  focusNode: destinationFocusNode,
                  textInputAction: TextInputAction.search,
                  textAlignVertical: TextAlignVertical.center,
                  onChanged: onDestinationChanged,
                  onSubmitted: onDestinationSubmitted,
                  decoration: InputDecoration(
                    hintText: 'Choose destination',
                    prefixIcon: const Icon(Icons.location_on),
                    suffixIcon: destinationController.text.isNotEmpty
                        ? IconButton(
                            icon: const Icon(Icons.close),
                            onPressed: onClearDestination,
                          )
                        : null,
                    border: InputBorder.none,
                    contentPadding: EdgeInsets.zero,
                  ),
                ),
              ),
            ],
          ),
          // Swap button floats over the divider without affecting field heights
          Positioned(
            right: 12,
            top: 43, // centers the 26px button on the divider at y=56
            child: Container(
              height: 26,
              width: 26,
              decoration: BoxDecoration(
                color: Colors.white,
                shape: BoxShape.circle,
                border: Border.all(color: Colors.grey.shade300),
              ),
              child: InkWell(
                borderRadius: BorderRadius.circular(13),
                onTap: onSwap,
                child: const Icon(Icons.swap_vert, size: 16),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
