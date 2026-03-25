import 'package:flutter/material.dart';

class HomeBottomNavBar extends StatelessWidget {
  final VoidCallback onMenuTap;

  const HomeBottomNavBar({
    super.key,
    required this.onMenuTap,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 70,
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(color: Colors.black.withOpacity(0.1), blurRadius: 10),
        ],
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          InkWell(
            onTap: () {},
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
          InkWell(
            onTap: () {},
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
          InkWell(
            onTap: onMenuTap,
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
        ],
      ),
    );
  }
}
