import 'package:flutter/material.dart';
import '../../../core/domain/market.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/common.dart';

class CategoryGallery extends StatefulWidget {
  const CategoryGallery({
    super.key,
    required this.selected,
    required this.onSelect,
  });
  final String? selected;
  final ValueChanged<String?> onSelect;
  @override
  State<CategoryGallery> createState() => _CategoryGalleryState();
}

class _CategoryGalleryState extends State<CategoryGallery> {
  bool _expanded = false;
  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (ctx, box) {
      final popular = [
        'Grocery',
        'Electronics',
        'Garments',
        'Footwear',
        'Fresh produce',
        'Hardware',
        'Furniture',
        'Photography',
      ];
      final entries = _expanded ? categories : popular;
      final columns = box.maxWidth < 400
          ? 3
          : box.maxWidth < 650
          ? 4
          : box.maxWidth < 950
          ? 6
          : 8;
      final width = (box.maxWidth - (columns - 1) * 10) / columns;
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  'Browse by category',
                  style: Theme.of(ctx).textTheme.titleLarge,
                ),
              ),
              TextButton(
                onPressed: () => setState(() => _expanded = !_expanded),
                child: Text(
                  _expanded ? 'Show popular' : 'All ${categories.length}',
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 10,
            runSpacing: 12,
            children: entries.map((category) {
              final active = widget.selected == category;
              return SizedBox(
                width: width,
                child: Material(
                  color: active ? green : Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  child: InkWell(
                    key: ValueKey('category-$category'),
                    onTap: () => widget.onSelect(category),
                    borderRadius: BorderRadius.circular(16),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 16,
                      ),
                      child: Column(
                        children: [
                          Container(
                            width: 42,
                            height: 42,
                            decoration: BoxDecoration(
                              color: active
                                  ? Colors.white.withValues(alpha: 0.15)
                                  : categoryColor(category),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Icon(
                              categoryIcon(category),
                              size: 23,
                              color: active ? Colors.white : green,
                            ),
                          ),
                          const SizedBox(height: 10),
                          Text(
                            category,
                            textAlign: TextAlign.center,
                            maxLines: 3,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w700,
                              color: active ? Colors.white : ink,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              );
            }).toList(),
          ),
          if (widget.selected != null)
            TextButton.icon(
              key: const ValueKey('category-all'),
              onPressed: () => widget.onSelect(null),
              icon: const Icon(Icons.close, size: 16),
              label: Text('Clear ${widget.selected} filter'),
            ),
        ],
      );
    },
  );
}
