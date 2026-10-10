import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class MarketIndexCard extends StatelessWidget {
  final String title;
  final String points;
  final String change;
  final bool isBullish;

  const MarketIndexCard({
    super.key,
    required this.title,
    required this.points,
    required this.change,
    required this.isBullish,
  });

  @override
  Widget build(BuildContext context) {
    final color = isBullish ? const Color(0xFF00E676) : const Color(0xFFFF5252);
    return Container(
      width: 140,
      margin: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFF131B2A),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFF202C42)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(title, style: const TextStyle(fontSize: 11, color: Color(0xFF8896AB), fontWeight: FontWeight.w600)),
          const SizedBox(height: 4),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(points, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: Colors.white)),
              Text(change, style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: color)),
            ],
          ),
        ],
      ),
    );
  }
}
