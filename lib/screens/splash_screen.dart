import 'package:flutter/material.dart';

import '../config/app_theme.dart';

class SplashScreen extends StatelessWidget {
  const SplashScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: DecoratedBox(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Color(0xFF0D4F43), AppTheme.primary, Color(0xFF2B8B76)],
          ),
        ),
        child: const Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              _ParkingLogo(size: 98),
              SizedBox(height: 24),
              Text(
                'SmartParking',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 30,
                  fontWeight: FontWeight.w800,
                  letterSpacing: -0.6,
                ),
              ),
              SizedBox(height: 8),
              Text(
                'Boş yer, doğru zaman, kolay park.',
                style: TextStyle(color: Color(0xFFD8F0EA), fontSize: 15),
              ),
              SizedBox(height: 36),
              SizedBox(
                width: 30,
                height: 30,
                child: CircularProgressIndicator(
                  color: Colors.white,
                  strokeWidth: 3,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ParkingLogo extends StatelessWidget {
  const _ParkingLogo({required this.size});

  final double size;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(size * 0.28),
        boxShadow: const [
          BoxShadow(color: Color(0x33000000), blurRadius: 24, offset: Offset(0, 12)),
        ],
      ),
      child: const Icon(Icons.local_parking_rounded, size: 62, color: AppTheme.primary),
    );
  }
}
