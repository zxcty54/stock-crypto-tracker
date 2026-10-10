import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../../core/data/controller.dart';
import '../../../core/domain/market.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/common.dart';

class VerificationStatusCard extends StatelessWidget {
  const VerificationStatusCard({
    super.key,
    required this.controller,
    required this.shop,
  });
  final MarketController controller;
  final Shop shop;
  @override
  Widget build(BuildContext context) {
    final approved = shop.reviewStatus == 'approved';
    final phone = controller.snapshot.settings.verificationPhone;
    final canWhatsapp = validatePhone(phone) == null;
    final title = switch (shop.reviewStatus) {
      'approved' => 'Shop photo review approved',
      'rejected' => 'Changes required before approval',
      'suspended' => 'Shop suspended by administrator',
      _ => 'Awaiting shop verification',
    };
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(22),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  approved ? Icons.fact_check_outlined : Icons.pending_actions,
                  color: green,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    title,
                    style: const TextStyle(
                      fontWeight: FontWeight.w800,
                      fontSize: 16,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Text(
              approved
                  ? 'Your shop can be shown publicly while publication is enabled. Editing the shop name, address, category, mobile, business type or verification photo sends it back for review. Approval is a manual photo review, not government identity certification.'
                  : 'Your shop and products are hidden from buyers. The administrator reviews your uploaded storefront/signboard photo and request, then approves or rejects it. WhatsApp is optional if the operator requests extra evidence.',
              style: const TextStyle(color: muted, fontSize: 12, height: 1.6),
            ),
            if (shop.reviewNote.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(top: 12),
                child: Text(
                  'Administrator note: ${shop.reviewNote}',
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            const SizedBox(height: 14),
            SelectableText(
              'Request ID: ${shop.id}',
              style: const TextStyle(fontSize: 11, color: muted),
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 10,
              runSpacing: 10,
              children: [
                if (!approved && shop.reviewStatus != 'suspended')
                  FilledButton.icon(
                    key: const ValueKey('verification-whatsapp'),
                    onPressed: canWhatsapp
                        ? () => openLink(
                            context,
                            verificationWhatsappUri(shop, phone),
                          )
                        : null,
                    icon: const Icon(Icons.chat_outlined, size: 18),
                    label: const Text('Send proof on WhatsApp'),
                  ),
                TextButton.icon(
                  onPressed: () async {
                    await Clipboard.setData(ClipboardData(text: shop.id));
                    if (context.mounted) {
                      toast(context, 'Request ID copied.');
                    }
                  },
                  icon: const Icon(Icons.copy_outlined, size: 16),
                  label: const Text('Copy request ID'),
                ),
              ],
            ),
            if (!approved && !canWhatsapp)
              const Padding(
                padding: EdgeInsets.only(top: 10),
                child: Text(
                  'Your private application is saved for administrator review. WhatsApp contact is optional and becomes available when the operator configures it.',
                  style: TextStyle(color: muted, fontSize: 11),
                ),
              ),
            if (!approved)
              const Padding(
                padding: EdgeInsets.only(top: 10),
                child: Text(
                  'WhatsApp opens with your request details. Attach the shop photo manually; this app does not read or automatically attach WhatsApp photos.',
                  style: TextStyle(color: muted, fontSize: 11),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
