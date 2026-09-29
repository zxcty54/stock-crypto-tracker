import 'package:flutter/material.dart';

class NewsCard extends StatelessWidget {
  final dynamic item;
  const NewsCard({super.key, required this.item});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF131B2A),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFF202C42)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: const Color(0xFF223048),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  item['source'] ?? 'Market Wire',
                  style: const TextStyle(fontSize: 11, color: Color(0xFF00E5FF), fontWeight: FontWeight.w600),
                ),
              ),
              const Spacer(),
              const Text('Live', style: TextStyle(color: Color(0xFF8896AB), fontSize: 11)),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            item['title'] ?? 'No Title',
            style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Colors.white),
          ),
          const SizedBox(height: 6),
          Text(
            item['body'] ?? '',
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(fontSize: 12, color: Color(0xFF8896AB)),
          ),
        ],
      ),
    );
  }
}
