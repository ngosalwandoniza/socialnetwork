import 'package:flutter/material.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';

class SocialBadge extends StatelessWidget {
  final double gravity;
  
  const SocialBadge({super.key, required this.gravity});

  @override
  Widget build(BuildContext context) {
    String label = '';
    Color color = Colors.transparent;
    IconData icon;

    if (gravity >= 4.6) {
      label = 'Local Legend';
      color = const Color(0xFFFFD700); // Premium Gold
      icon = FontAwesomeIcons.crown;
    } else if (gravity >= 3.6) {
      label = 'Vibe Master';
      color = const Color(0xFFC084FC); // Vibrant Purple
      icon = FontAwesomeIcons.boltLightning;
    } else if (gravity >= 2.1) {
      label = 'Rising Star';
      color = const Color(0xFF60A5FA); // Bright Blue
      icon = FontAwesomeIcons.rocket;
    } else {
      return const SizedBox.shrink();
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withOpacity(0.12),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withOpacity(0.4), width: 1),
        boxShadow: [
          BoxShadow(
            color: color.withOpacity(0.1),
            blurRadius: 4,
            spreadRadius: 0,
          ),
        ],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          FaIcon(icon, size: 10, color: color),
          const SizedBox(width: 5),
          Text(
            label.toUpperCase(),
            style: TextStyle(
              color: color,
              fontSize: 9,
              fontWeight: FontWeight.w900,
              letterSpacing: 0.8,
            ),
          ),
        ],
      ),
    );
  }
}

class StreakBadge extends StatelessWidget {
  final int count;
  
  const StreakBadge({super.key, required this.count});

  @override
  Widget build(BuildContext context) {
    if (count <= 0) return const SizedBox.shrink();

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            const Color(0xFFF97316).withOpacity(0.2), // Orange
            const Color(0xFFEF4444).withOpacity(0.2), // Red
          ],
        ),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFFF97316).withOpacity(0.3)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const FaIcon(
            FontAwesomeIcons.fireFlameCurved,
            size: 10,
            color: Color(0xFFF97316),
          ),
          const SizedBox(width: 5),
          Text(
            count.toString(),
            style: const TextStyle(
              color: Color(0xFFF97316),
              fontSize: 11,
              fontWeight: FontWeight.w900,
            ),
          ),
        ],
      ),
    );
  }
}

class GravityIndicator extends StatelessWidget {
  final double gravity;
  
  const GravityIndicator({super.key, required this.gravity});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text(
          gravity.toStringAsFixed(1),
          style: const TextStyle(
            fontSize: 24,
            fontWeight: FontWeight.bold,
            color: Colors.white,
          ),
        ),
        const Text(
          'SOCIAL GRAVITY',
          style: TextStyle(
            fontSize: 8,
            color: Colors.white70,
            letterSpacing: 1.2,
          ),
        ),
      ],
    );
  }
}
