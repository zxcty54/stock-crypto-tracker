import 'package:flutter/material.dart';

import '../../../app/aangan_app.dart';

class AanganBrand extends StatelessWidget {
  const AanganBrand({super.key, this.compact = false});

  final bool compact;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        Container(
          width: compact ? 36 : 42,
          height: compact ? 36 : 42,
          decoration: BoxDecoration(
            color: AanganColors.forest,
            borderRadius: BorderRadius.circular(compact ? 12 : 14),
          ),
          child: Icon(
            Icons.other_houses_rounded,
            color: AanganColors.cream,
            size: compact ? 21 : 25,
          ),
        ),
        const SizedBox(width: 10),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            Text(
              'aangan',
              style: TextStyle(
                color: AanganColors.ink,
                fontSize: compact ? 18 : 20,
                height: 1,
                letterSpacing: -0.9,
                fontWeight: FontWeight.w800,
              ),
            ),
            if (!compact) ...<Widget>[
              const SizedBox(height: 3),
              const Text(
                'BIHAR RENTALS',
                style: TextStyle(
                  color: AanganColors.muted,
                  fontSize: 8,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 1.35,
                ),
              ),
            ],
          ],
        ),
      ],
    );
  }
}

class BackendNotice extends StatelessWidget {
  const BackendNotice({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: const Color(0xFFFFF4DD),
        borderRadius: BorderRadius.circular(13),
        border: Border.all(color: const Color(0xFFF4E0B7)),
      ),
      child: const Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Icon(Icons.info_outline_rounded, size: 17, color: Color(0xFF9A6B1F)),
          SizedBox(width: 8),
          Expanded(
            child: Text(
              'Preview mode · sample homes dikh rahe hain. Real listings, chat aur approvals ke liye Supabase connect karein.',
              style: TextStyle(
                color: Color(0xFF75551F),
                fontSize: 11,
                height: 1.4,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class SectionHeading extends StatelessWidget {
  const SectionHeading({
    super.key,
    required this.title,
    this.subtitle,
    this.trailing,
  });

  final String title;
  final String? subtitle;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: <Widget>[
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Text(
                title,
                style: const TextStyle(
                  color: AanganColors.ink,
                  fontSize: 19,
                  letterSpacing: -0.5,
                  fontWeight: FontWeight.w800,
                ),
              ),
              if (subtitle != null) ...<Widget>[
                const SizedBox(height: 4),
                Text(
                  subtitle!,
                  style: const TextStyle(
                    color: AanganColors.muted,
                    fontSize: 12,
                    height: 1.4,
                  ),
                ),
              ],
            ],
          ),
        ),
        if (trailing != null) trailing!,
      ],
    );
  }
}

class StatusPill extends StatelessWidget {
  const StatusPill({super.key, required this.status});

  final String status;

  @override
  Widget build(BuildContext context) {
    final Color foreground;
    final Color background;
    final String label;
    if (status == 'published') {
      foreground = AanganColors.forest;
      background = AanganColors.paleGreen;
      label = 'LIVE';
    } else if (status == 'rejected') {
      foreground = AanganColors.danger;
      background = const Color(0xFFFBE9E6);
      label = 'NEEDS EDIT';
    } else if (status == 'paused') {
      foreground = AanganColors.muted;
      background = const Color(0xFFEDEFEA);
      label = 'PAUSED';
    } else if (status == 'rented') {
      foreground = const Color(0xFF775F30);
      background = const Color(0xFFF8F0D9);
      label = 'RENTED';
    } else {
      foreground = const Color(0xFF9A6B1F);
      background = const Color(0xFFFFF3D7);
      label = 'IN REVIEW';
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(99),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: foreground,
          fontSize: 9,
          fontWeight: FontWeight.w800,
          letterSpacing: 0.6,
        ),
      ),
    );
  }
}

class EmptyState extends StatelessWidget {
  const EmptyState({
    super.key,
    required this.icon,
    required this.title,
    required this.message,
    this.action,
  });

  final IconData icon;
  final String title;
  final String message;
  final Widget? action;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            Container(
              width: 72,
              height: 72,
              decoration: const BoxDecoration(
                shape: BoxShape.circle,
                color: AanganColors.paleGreen,
              ),
              child: Icon(icon, size: 31, color: AanganColors.forest),
            ),
            const SizedBox(height: 18),
            Text(
              title,
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: AanganColors.ink,
                fontSize: 19,
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              message,
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: AanganColors.muted,
                fontSize: 13,
                height: 1.5,
              ),
            ),
            if (action != null) ...<Widget>[
              const SizedBox(height: 18),
              action!,
            ],
          ],
        ),
      ),
    );
  }
}

class RulePill extends StatelessWidget {
  const RulePill({
    super.key,
    required this.label,
    required this.value,
    this.compact = false,
  });

  final String label;
  final String value;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final Color foreground = value == 'allowed'
        ? AanganColors.forest
        : value == 'not_allowed'
            ? AanganColors.danger
            : const Color(0xFF8B6927);
    final Color background = value == 'allowed'
        ? AanganColors.paleGreen
        : value == 'not_allowed'
            ? const Color(0xFFFBEAE7)
            : const Color(0xFFFFF4DD);

    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: compact ? 9 : 11,
        vertical: compact ? 6 : 8,
      ),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Text(
        '$label · ${value == 'allowed' ? 'Yes' : value == 'not_allowed' ? 'No' : 'Ask'}',
        style: TextStyle(
          color: foreground,
          fontSize: compact ? 10 : 11,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}

class PrimaryButton extends StatelessWidget {
  const PrimaryButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.icon,
    this.isLoading = false,
    this.expand = true,
  });

  final String label;
  final VoidCallback? onPressed;
  final IconData? icon;
  final bool isLoading;
  final bool expand;

  @override
  Widget build(BuildContext context) {
    final button = FilledButton.icon(
      onPressed: isLoading ? null : onPressed,
      icon: isLoading
          ? const SizedBox(
              width: 17,
              height: 17,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                color: Colors.white,
              ),
            )
          : Icon(icon ?? Icons.arrow_forward_rounded, size: 18),
      label: Text(label),
      style: FilledButton.styleFrom(
        backgroundColor: AanganColors.forest,
        foregroundColor: Colors.white,
        minimumSize: const Size(0, 52),
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
        textStyle: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
      ),
    );
    if (!expand) return button;
    return SizedBox(width: double.infinity, child: button);
  }
}
