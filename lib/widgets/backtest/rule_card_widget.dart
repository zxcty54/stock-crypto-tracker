import 'package:flutter/material.dart';
import '../../models/price_action_strategy.dart';

class RuleCardWidget extends StatelessWidget {
  final PriceActionRule rule;
  final int index;
  final bool canDelete;
  final VoidCallback onDelete;
  final VoidCallback onChanged;

  const RuleCardWidget({
    super.key,
    required this.rule,
    required this.index,
    required this.canDelete,
    required this.onDelete,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFF131B2A),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFF202C42)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'TRIGGER CONDITION #${index + 1}',
                style: const TextStyle(
                  color: Color(0xFF00E5FF),
                  fontSize: 10,
                  fontWeight: FontWeight.w900,
                  letterSpacing: 0.8,
                ),
              ),
              if (canDelete)
                InkWell(
                  onTap: onDelete,
                  child: const Icon(Icons.remove_circle_outline, color: Color(0xFFFF5252), size: 18),
                ),
            ],
          ),
          const SizedBox(height: 10),
          Wrap(
            spacing: 6,
            runSpacing: 8,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              // 1. Source Dropdown
              _dropdown<CandleField>(
                value: rule.sourceField,
                items: const {
                  CandleField.close: 'Close',
                  CandleField.high: 'High',
                  CandleField.low: 'Low',
                  CandleField.open: 'Open',
                },
                onChanged: (v) {
                  if (v != null) {
                    rule.sourceField = v;
                    onChanged();
                  }
                },
              ),

              // 2. Operator Dropdown
              _dropdown<ConditionOperator>(
                value: rule.operator,
                items: const {
                  ConditionOperator.crossesAbove: 'Crosses Above',
                  ConditionOperator.isGreaterThan: 'Higher Than',
                  ConditionOperator.isLessThan: 'Lower Than',
                  ConditionOperator.insideBar: 'Inside Bar Setup',
                  ConditionOperator.hammerPinBar: 'Hammer / PinBar',
                },
                onChanged: (v) {
                  if (v != null) {
                    rule.operator = v;
                    onChanged();
                  }
                },
              ),

              // 3. Target Dropdown
              if (rule.operator != ConditionOperator.insideBar &&
                  rule.operator != ConditionOperator.hammerPinBar)
                _dropdown<BenchmarkTarget>(
                  value: rule.targetField,
                  items: {
                    BenchmarkTarget.nBarHigh: '${rule.lookbackPeriod}-Bar High',
                    BenchmarkTarget.nBarLow: '${rule.lookbackPeriod}-Bar Low',
                    BenchmarkTarget.prevHigh: 'Prev High',
                    BenchmarkTarget.prevLow: 'Prev Low',
                    BenchmarkTarget.prevClose: 'Prev Close',
                  },
                  onChanged: (v) {
                    if (v != null) {
                      rule.targetField = v;
                      onChanged();
                    }
                  },
                ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _dropdown<T>({
    required T value,
    required Map<T, String> items,
    required ValueChanged<T?> onChanged,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
      decoration: BoxDecoration(
        color: const Color(0xFF0F172A),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: const Color(0xFF202C42)),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<T>(
          value: value,
          dropdownColor: const Color(0xFF0F172A),
          icon: const Icon(Icons.keyboard_arrow_down_rounded, size: 16, color: Color(0xFF8896AB)),
          style: const TextStyle(color: Colors.white, fontSize: 11.5, fontWeight: FontWeight.bold),
          items: items.entries
              .map((e) => DropdownMenuItem(value: e.key, child: Text(e.value)))
              .toList(),
          onChanged: onChanged,
        ),
      ),
    );
  }
}
