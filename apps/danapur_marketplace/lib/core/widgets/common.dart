import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:url_launcher/url_launcher.dart';
import '../data/repository.dart';
import '../domain/market.dart';
import '../theme/app_theme.dart';

IconData categoryIcon(String category) => switch (category) {
  'Grocery' => Icons.shopping_basket_outlined,
  'Electronics' => Icons.headphones_outlined,
  'Fashion' => Icons.checkroom_outlined,
  'Garments' => Icons.checkroom_outlined,
  'Footwear' => Icons.hiking_outlined,
  'Photography' => Icons.photo_camera_outlined,
  'Mobile & accessories' => Icons.smartphone_outlined,
  'Dairy' => Icons.local_drink_outlined,
  'Beauty & cosmetics' => Icons.spa_outlined,
  'Bags & luggage' => Icons.luggage_outlined,
  'Home' => Icons.chair_outlined,
  'Furniture' => Icons.chair_outlined,
  'Hardware' => Icons.handyman_outlined,
  'Electrical' => Icons.electrical_services_outlined,
  'Building materials' => Icons.construction_outlined,
  'Books & stationery' => Icons.menu_book_outlined,
  'Pharmacy & healthcare' => Icons.local_pharmacy_outlined,
  'Automotive' => Icons.directions_car_outlined,
  'Jewellery' => Icons.diamond_outlined,
  'Fresh produce' => Icons.eco_outlined,
  'Sports & toys' => Icons.sports_basketball_outlined,
  'Food & sweets' => Icons.bakery_dining_outlined,
  _ => Icons.storefront_outlined,
};
Color categoryColor(String category) => switch (category) {
  'Electronics' => const Color(0xFFEEEFF9),
  'Fashion' => const Color(0xFFFBEEE7),
  'Home' => const Color(0xFFECF2F1),
  'Food & sweets' => const Color(0xFFFFF3DC),
  _ => const Color(0xFFEAF1E6),
};
void toast(BuildContext context, String message) {
  if (!context.mounted) {
    return;
  }
  ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
}

Future<void> runAction(
  BuildContext context,
  Future<void> Function() action, {
  String? success,
}) async {
  try {
    await action();
    if (success != null && context.mounted) {
      toast(context, success);
    }
  } catch (e) {
    if (context.mounted) {
      toast(context, friendlyError(e));
    }
  }
}

Future<void> openLink(BuildContext context, Uri uri) async {
  await runAction(context, () async {
    if (!await launchUrl(uri, mode: LaunchMode.externalApplication)) {
      throw const MarketException('Could not open this link on your device.');
    }
  });
}

Future<bool> confirm(
  BuildContext context,
  String title,
  String description,
) async =>
    await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(title),
        content: Text(description),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: const Color(0xFFB44337),
            ),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Delete'),
          ),
        ],
      ),
    ) ??
    false;
void showInfo(BuildContext context, {bool privacy = false}) {
  showDialog<void>(
    context: context,
    builder: (ctx) => AlertDialog(
      title: Text(
        privacy
            ? 'Privacy & marketplace information'
            : 'Your neighbourhood, online',
      ),
      content: SingleChildScrollView(
        child: Text(
          privacy
              ? 'Buyers can browse without an account. Saved products stay on this device. Seller email is used for authentication. Shop business contacts, addresses and product listings become public only after administrator approval and publication. Storefront verification photos are stored privately for the owner and authorised administrators. WhatsApp verification happens in a separate chat governed by WhatsApp policies.\n\nAdministrator photo review is not a government identity, quality or safety certification. Mandi rates are entered by the administrator and show their market date, rate type and unit; old rates are explicitly labelled. Confirm final price, stock and purchase terms with the seller. Cash orders store participant-only address/contact/location. Completed orders create private expenses. This app has no online gateway and does not itself operate deliveries.\n\nYou can delete your shop or account from My shop. Contact the marketplace operator for privacy requests; the operator must supply reviewed privacy and terms pages before public launch.'
              : 'Discover approved Danapur shops, compare product prices, and check administrator-published vegetable and fruit rates. Retailers and wholesalers can apply with a storefront photo. Shops remain private until the administrator checks their photo and WhatsApp proof.\n\nBuyers contact sellers directly; refreshing loads the latest available listings.',
        ),
      ),
      actions: [
        if (!privacy)
          TextButton(
            onPressed: () => showLicensePage(
              context: ctx,
              applicationName: 'Danapur Bazaar',
              applicationVersion: '1.1.0',
            ),
            child: const Text('Open-source licenses'),
          ),
        TextButton(
          onPressed: () => Navigator.pop(ctx),
          child: const Text('Got it'),
        ),
      ],
    ),
  );
}

class Brand extends StatelessWidget {
  const Brand({super.key, this.small = false});
  final bool small;
  @override
  Widget build(BuildContext context) => Row(
    mainAxisSize: MainAxisSize.min,
    children: [
      Container(
        width: small ? 34 : 42,
        height: small ? 34 : 42,
        decoration: BoxDecoration(
          color: green,
          borderRadius: BorderRadius.circular(13),
        ),
        child: Icon(
          Icons.storefront_rounded,
          color: Colors.white,
          size: small ? 21 : 26,
        ),
      ),
      const SizedBox(width: 10),
      Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            'danapur',
            style: TextStyle(
              color: ink,
              fontSize: small ? 19 : 22,
              fontWeight: FontWeight.w800,
              height: 1.1,
            ),
          ),
          const Text(
            'BAZAAR',
            style: TextStyle(
              color: green,
              fontSize: 9,
              letterSpacing: 3,
              fontWeight: FontWeight.w800,
            ),
          ),
        ],
      ),
    ],
  );
}

class Tag extends StatelessWidget {
  const Tag(
    this.text, {
    super.key,
    this.color = green,
    this.background = const Color(0xFFEAF4EC),
    this.icon,
  });
  final String text;
  final Color color, background;
  final IconData? icon;
  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
    decoration: BoxDecoration(
      color: background,
      borderRadius: BorderRadius.circular(7),
    ),
    child: Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (icon != null) ...[
          Icon(icon, size: 12, color: color),
          const SizedBox(width: 4),
        ],
        Text(
          text,
          style: TextStyle(
            fontSize: 10,
            color: color,
            fontWeight: FontWeight.w700,
          ),
        ),
      ],
    ),
  );
}

class EmptyState extends StatelessWidget {
  const EmptyState({
    super.key,
    required this.title,
    required this.message,
    this.action,
    this.icon = Icons.shopping_bag_outlined,
  });
  final String title, message;
  final Widget? action;
  final IconData icon;
  @override
  Widget build(BuildContext context) => Container(
    width: double.infinity,
    padding: const EdgeInsets.symmetric(vertical: 48, horizontal: 24),
    child: Column(
      children: [
        CircleAvatar(
          radius: 34,
          backgroundColor: const Color(0xFFEAF1E6),
          child: Icon(icon, color: green, size: 32),
        ),
        const SizedBox(height: 18),
        Text(
          title,
          style: Theme.of(context).textTheme.titleLarge,
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 8),
        Text(
          message,
          textAlign: TextAlign.center,
          style: const TextStyle(color: muted),
        ),
        if (action != null) ...[const SizedBox(height: 22), action!],
      ],
    ),
  );
}

class ProductArt extends StatelessWidget {
  const ProductArt({super.key, required this.product, this.height});
  final Product product;
  final double? height;
  @override
  Widget build(BuildContext context) {
    Widget placeholder() => Padding(
      padding: const EdgeInsets.all(18),
      child: SvgPicture.asset(
        'assets/illustrations/${product.illustration}.svg',
        fit: BoxFit.contain,
        placeholderBuilder: (_) =>
            Icon(categoryIcon(product.category), size: 62, color: green),
      ),
    );
    Widget art = placeholder();
    final url = product.imageUrl;
    if (url != null && url.isNotEmpty) {
      if (url.startsWith('data:image/')) {
        try {
          art = Image.memory(
            base64Decode(url.split(',').last),
            fit: BoxFit.cover,
            errorBuilder: (_, _, _) => placeholder(),
          );
        } catch (_) {
          art = placeholder();
        }
      } else if (Uri.tryParse(url)?.scheme == 'https') {
        art = Image.network(
          url,
          fit: BoxFit.cover,
          errorBuilder: (_, _, _) => placeholder(),
          loadingBuilder: (_, child, progress) => progress == null
              ? child
              : const Center(child: CircularProgressIndicator(strokeWidth: 2)),
        );
      }
    }
    return Container(
      height: height,
      width: double.infinity,
      color: categoryColor(product.category),
      child: art,
    );
  }
}

class MarketFooter extends StatelessWidget {
  const MarketFooter({super.key});
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(top: 40, bottom: 20),
    child: Column(
      children: [
        const Divider(),
        const SizedBox(height: 14),
        Wrap(
          alignment: WrapAlignment.spaceBetween,
          crossAxisAlignment: WrapCrossAlignment.center,
          spacing: 28,
          runSpacing: 6,
          children: [
            const Text(
              'Made for Danapur. Built around local shops.',
              style: TextStyle(fontSize: 11, color: muted),
            ),
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextButton(
                  onPressed: () => showInfo(context),
                  child: const Text('About'),
                ),
                TextButton(
                  onPressed: () => showInfo(context, privacy: true),
                  child: const Text('Privacy'),
                ),
              ],
            ),
          ],
        ),
        const Text(
          'Listed prices are seller-provided. Confirm before buying.',
          style: TextStyle(fontSize: 10, color: muted),
        ),
      ],
    ),
  );
}

String updatedLabel(DateTime date) {
  const months = [
    'Jan',
    'Feb',
    'Mar',
    'Apr',
    'May',
    'Jun',
    'Jul',
    'Aug',
    'Sep',
    'Oct',
    'Nov',
    'Dec',
  ];
  final local = date.toLocal();
  return '${local.day} ${months[local.month - 1]} ${local.year}';
}
