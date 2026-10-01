import 'package:flutter/material.dart';
import '../../models/two_candle_rule_model.dart';

class TwoCandleBuilderWidget extends StatelessWidget {
  final TwoCandleStrategyConfig config;
  final VoidCallback onChanged;

  const TwoCandleBuilderWidget({
    super.key,
    required this.config,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFF131B2A),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFF202C42)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(Icons.candlestick_chart_rounded, color: Color(0xFF00E5FF), size: 18),
              SizedBox(width: 6),
              Text(
                '2-CANDLE SEQUENCE DEFINITION',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 11,
                  fontWeight: FontWeight.w900,
                  letterSpacing: 0.8,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),

          // Two Candle Visual Blocks
          Row(
            children: [
              Expanded(
                child: _candleBox(
                  title: 'CANDLE 1 (DAY -1)',
                  colorType: config.candle1Color,
                  wickType: config.candle1Wick,
                  onColorChange: (val) {
                    config.candle1Color = val;
                    onChanged();
                  },
                  onWickChange: (val) {
                    config.candle1Wick = val;
                    onChanged();
                  },
                ),
              ),
              const Padding(
                padding: EdgeInsets.symmetric(horizontal: 6),
                child: Icon(Icons.arrow_forward_rounded, color: Color(0xFF00E5FF), size: 20),
              ),
              Expanded(
                child: _candleBox(
                  title: 'CANDLE 2 (TRIGGER)',
                  colorType: config.candle2Color,
                  wickType: config.candle2Wick,
                  onColorChange: (val) {
                    config.candle2Color = val;
                    onChanged();
                  },
                  onWickChange: (val) {
                    config.candle2Wick = val;
                    onChanged();
                  },
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),

          // Relation Dropdown
          _dropdownRow<InterCandleRelation>(
            label: 'CANDLE 2 vs CANDLE 1 RELATION',
            value: config.relation,
            items: const {
              InterCandleRelation.higherHigh: 'Candle 2 High > Candle 1 High (HH)',
              InterCandleRelation.higherClose: 'Candle 2 Close > Candle 1 Close',
              InterCandleRelation.breakoutAboveHigh: 'Candle 2 Close > Candle 1 High',
              InterCandleRelation.insideBar: 'Inside Bar (Within Candle 1 Range)',
              InterCandleRelation.bullishEngulfing: 'Bullish Engulfing Body',
              InterCandleRelation.any: 'No Specific Relation',
            },
            onChanged: (v) {
              if (v != null) {
                config.relation = v;
                onChanged();
              }
            },
          ),
          const SizedBox(height: 10),

          // Entry Trigger Dropdown
          _dropdownRow<EntryTriggerType>(
            label: 'ENTRY TRIGGER POINT',
            value: config.entryTrigger,
            items: const {
              EntryTriggerType.breakoutCandle2High: 'Breakout of Candle 2 High (Buy Stop)',
              EntryTriggerType.closeOfCandle2: 'On Candle 2 Close',
              EntryTriggerType.nextBarOpen: 'Next Day Market Open',
            },
            onChanged: (v) {
              if (v != null) {
                config.entryTrigger = v;
                onChanged();
              }
            },
          ),
          const SizedBox(height: 10),

          // Structural SL Dropdown
          _dropdownRow<StructuralStopLossType>(
            label: 'STRUCTURAL STOP LOSS',
            value: config.slType,
            items: const {
              StructuralStopLossType.lowestOfBoth: 'Lowest Low of Candle 1 & 2',
              StructuralStopLossType.candle2Low: 'Low of Candle 2 Only',
              StructuralStopLossType.candle1Low: 'Low of Candle 1 Only',
            },
            onChanged: (v) {
              if (v != null) {
                config.slType = v;
                onChanged();
              }
            },
          ),
        ],
      ),
    );
  }

  Widget _candleBox({
    required String title,
    required CandleColorType colorType,
    required WickBiasType wickType,
    required ValueChanged<CandleColorType> onColorChange,
    required ValueChanged<WickBiasType> onWickChange,
  }) {
    Color displayColor = Colors.grey;
    if (colorType == CandleColorType.bullishGreen) displayColor = const Color(0xFF00E676);
    if (colorType == CandleColorType.bearishRed) displayColor = const Color(0xFFFF5252);

    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: const Color(0xFF0A0F1A),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: displayColor.withOpacity(0.5)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: TextStyle(color: displayColor, fontSize: 9.5, fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          DropdownButtonHideUnderline(
            child: DropdownButton<CandleColorType>(
              value: colorType,
              isExpanded: true,
              dropdownColor: const Color(0xFF0F1726),
              style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold),
              items: const [
                DropdownMenuItem(value: CandleColorType.bullishGreen, child: Text('Green (Bullish)')),
                DropdownMenuItem(value: CandleColorType.bearishRed, child: Text('Red (Bearish)')),
                DropdownMenuItem(value: CandleColorType.any, child: Text('Any Color')),
              ],
              onChanged: (v) => onColorChange(v!),
            ),
          ),
          const SizedBox(height: 4),
          DropdownButtonHideUnderline(
            child: DropdownButton<WickBiasType>(
              value: wickType,
              isExpanded: true,
              dropdownColor: const Color(0xFF0F1726),
              style: const TextStyle(color: Colors.white70, fontSize: 10),
              items: const [
                DropdownMenuItem(value: WickBiasType.any, child: Text('Normal Wick')),
                DropdownMenuItem(value: WickBiasType.longLowerWick, child: Text('Long Lower Wick (>50%)')),
                DropdownMenuItem(value: WickBiasType.longUpperWick, child: Text('Long Upper Wick (>50%)')),
              ],
              onChanged: (v) => onWickChange(v!),
            ),
          ),
        ],
      ),
    );
  }

  Widget _dropdownRow<T>({
    required String label,
    required T value,
    required Map<T, String> items,
    required ValueChanged<T?> onChanged,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: const TextStyle(color: Color(0xFF8896AB), fontSize: 9, fontWeight: FontWeight.bold)),
        const SizedBox(height: 4),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 2),
          decoration: BoxDecoration(
            color: const Color(0xFF0A0F1A),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: const Color(0xFF202C42)),
          ),
          child: DropdownButtonHideUnderline(
            child: DropdownButton<T>(
              value: value,
              isExpanded: true,
              dropdownColor: const Color(0xFF0F1726),
              style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold),
              items: items.entries.map((e) => DropdownMenuItem(value: e.key, child: Text(e.value))).toList(),
              onChanged: onChanged,
            ),
          ),
        ),
      ],
    );
  }
}
