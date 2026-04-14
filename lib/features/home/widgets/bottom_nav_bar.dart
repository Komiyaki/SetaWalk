import 'package:flutter/material.dart';

class HomeBottomNavBar extends StatelessWidget {
  final VoidCallback onSettingsTap;
  final VoidCallback onMenuTap;

  const HomeBottomNavBar({
    super.key,
    required this.onSettingsTap,
    required this.onMenuTap,
  });

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.of(context).padding.bottom;
    return Container(
      height: 70 + bottomInset,
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(color: Colors.black.withOpacity(0.1), blurRadius: 10),
        ],
      ),
      padding: EdgeInsets.only(bottom: bottomInset),
      child: Row(
        children: [
          Expanded(
            child: InkWell(
              onTap: () {
                FocusScope.of(context).unfocus();
                onSettingsTap();
              },
              borderRadius: BorderRadius.circular(12),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: const [
                  Icon(Icons.settings, color: Colors.grey),
                  SizedBox(height: 4),
                  Text('Settings', style: TextStyle(color: Colors.grey)),
                ],
              ),
            ),
          ),
          Expanded(
            child: InkWell(
              onTap: () => FocusScope.of(context).unfocus(),
              borderRadius: BorderRadius.circular(12),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: const [
                  Icon(Icons.home, color: Colors.green),
                  SizedBox(height: 4),
                  Text('Home', style: TextStyle(color: Colors.green)),
                ],
              ),
            ),
          ),
          Expanded(
            child: InkWell(
              onTap: () {
                FocusScope.of(context).unfocus();
                onMenuTap();
              },
              borderRadius: BorderRadius.circular(12),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: const [
                  Icon(Icons.menu, color: Colors.grey),
                  SizedBox(height: 4),
                  Text('Menu', style: TextStyle(color: Colors.grey)),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}