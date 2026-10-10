import 'package:flutter/material.dart';
import '../data/controller.dart';
import '../models/market.dart';
import 'common.dart';
import 'theme.dart';

class ProductCard extends StatelessWidget {
  const ProductCard({super.key, required this.product, required this.shop, required this.controller});
  final Product product;
  final Shop shop;
  final MarketController controller;
  @override
  Widget build(BuildContext context) {
    final saved = controller.savedIds.contains(product.id);
    return Card(clipBehavior: Clip.antiAlias, child: InkWell(
      onTap: () => Navigator.pushNamed(context, '/product/${product.id}'),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Stack(children: [
          ProductArt(product: product, height: 160),
          Positioned(top: 9, right: 9, child: IconButton(
            key: ValueKey('save-${product.id}'), tooltip: saved ? 'Unsave ${product.name}' : 'Save ${product.name}',
            style: IconButton.styleFrom(backgroundColor: Colors.white, minimumSize: const Size(38, 38)),
            onPressed: () => runAction(context, () => controller.toggleSaved(product.id)),
            icon: Icon(saved ? Icons.favorite_rounded : Icons.favorite_border_rounded, size: 19, color: saved ? green : muted))),
          if (!product.isAvailable) const Positioned(left: 10, bottom: 10,
            child: Tag('Out of stock', color: Color(0xFF8A5A36), background: Color(0xFFFFF6E7))),
        ]),
        Expanded(child: Padding(padding: const EdgeInsets.all(14), child: Column(
          crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(product.category.toUpperCase(), maxLines: 1, overflow: TextOverflow.ellipsis,
              style: const TextStyle(color: muted, fontSize: 9, fontWeight: FontWeight.w700, letterSpacing: .8)),
            const SizedBox(height: 6),
            Text(product.name, maxLines: 2, overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700, height: 1.4)),
            const SizedBox(height: 8),
            Wrap(spacing: 7, crossAxisAlignment: WrapCrossAlignment.center, children: [
              Text(money(product.pricePaise), style: const TextStyle(color: ink, fontSize: 18, fontWeight: FontWeight.w800)),
              if (product.mrpPaise != null && product.mrpPaise! > product.pricePaise)
                Text(money(product.mrpPaise!), style: const TextStyle(color: muted, fontSize: 10, decoration: TextDecoration.lineThrough)),
            ]),
            Text('/ ${product.unit}', maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 10, color: muted)),
            const Spacer(), const Divider(height: 17),
            Row(children: [const Icon(Icons.storefront_outlined, size: 13, color: green), const SizedBox(width: 5),
              Expanded(child: Text(shop.name, maxLines: 1, overflow: TextOverflow.ellipsis,
                style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w600)))]),
            const SizedBox(height: 3),
            Text(shop.isExample ? 'Example listing • ${shop.area}' : shop.area,
              maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 9, color: muted)),
          ]))),
      ]),
    ));
  }
}
class ProductGrid extends StatelessWidget {
  const ProductGrid({super.key, required this.products, required this.controller});
  final List<Product> products;
  final MarketController controller;
  @override
  Widget build(BuildContext context) => LayoutBuilder(builder: (ctx, constraints) {
    final count = constraints.maxWidth >= 1050 ? 4 : constraints.maxWidth >= 760 ? 3 : constraints.maxWidth >= 300 ? 2 : 1;
    final shops = {for (final shop in controller.snapshot.shops) shop.id: shop};
    return GridView.builder(shrinkWrap: true, physics: const NeverScrollableScrollPhysics(),
      itemCount: products.length,
      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(crossAxisCount: count,
        mainAxisSpacing: 18, crossAxisSpacing: constraints.maxWidth < 600 ? 12 : 20,
        mainAxisExtent: constraints.maxWidth < 600 ? 382 : 366),
      itemBuilder: (_, index) => ProductCard(product: products[index], shop: shops[products[index].shopId]!, controller: controller));
  });
}
class ShopCard extends StatelessWidget {
  const ShopCard({super.key, required this.shop, required this.controller});
  final Shop shop;
  final MarketController controller;
  @override
  Widget build(BuildContext context) => Card(child: InkWell(
    borderRadius: BorderRadius.circular(18), onTap: () => Navigator.pushNamed(context, '/shop/${shop.id}'),
    child: Padding(padding: const EdgeInsets.all(22), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Row(children: [
        Container(width: 54, height: 54, decoration: BoxDecoration(color: categoryColor(shop.category), borderRadius: BorderRadius.circular(15)),
          child: Icon(categoryIcon(shop.category), color: green, size: 27)),
        const Spacer(), Tag(shop.isExample ? 'Example shop' : shop.category),
      ]),
      const SizedBox(height: 18), Text(shop.name, maxLines: 1, overflow: TextOverflow.ellipsis,
        style: Theme.of(context).textTheme.titleMedium),
      const SizedBox(height: 7), Row(children: [const Icon(Icons.location_on_outlined, color: muted, size: 14),
        const SizedBox(width: 4), Expanded(child: Text(shop.area, style: const TextStyle(color: muted, fontSize: 12)))]),
      const Spacer(), const Divider(),
      Row(children: [
        Text('${controller.snapshot.products.where((p) => p.shopId == shop.id).length} products listed', style: const TextStyle(fontSize: 11, color: muted)),
        const Spacer(), const Icon(Icons.arrow_forward_rounded, color: green, size: 19),
      ]),
    ])),
  ));
}
class ShopGrid extends StatelessWidget {
  const ShopGrid({super.key, required this.shops, required this.controller});
  final List<Shop> shops;
  final MarketController controller;
  @override
  Widget build(BuildContext context) => LayoutBuilder(builder: (_, constraints) => GridView.builder(
    shrinkWrap: true, physics: const NeverScrollableScrollPhysics(), itemCount: shops.length,
    gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(crossAxisCount: constraints.maxWidth >= 900 ? 3 : constraints.maxWidth >= 620 ? 2 : 1,
      mainAxisSpacing: 18, crossAxisSpacing: 18, mainAxisExtent: 230),
    itemBuilder: (_, index) => ShopCard(shop: shops[index], controller: controller)));
}

class DetailShell extends StatelessWidget {
  const DetailShell({super.key, required this.controller, required this.child});
  final MarketController controller;
  final Widget child;
  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(backgroundColor: Colors.white, surfaceTintColor: Colors.transparent,
      title: const Brand(small: true), actions: [
        IconButton(tooltip: 'Refresh listings', onPressed: controller.reload, icon: const Icon(Icons.refresh_rounded)),
        const SizedBox(width: 8),
      ]),
    body: Column(children: [
      if (controller.isDemo) DemoBanner(controller: controller),
      Expanded(child: SingleChildScrollView(child: Center(child: ConstrainedBox(constraints: const BoxConstraints(maxWidth: 1160),
        child: Padding(padding: const EdgeInsets.all(24), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [child, MarketFooter(demo: controller.isDemo)])))))),
    ]),
  );
}
class ShopPage extends StatelessWidget {
  const ShopPage({super.key, required this.shopId, required this.controller});
  final String shopId;
  final MarketController controller;
  @override
  Widget build(BuildContext context) => ListenableBuilder(listenable: controller, builder: (ctx, _) {
    final shop = controller.visibleShop(shopId);
    if (shop == null) return DetailShell(controller: controller, child: EmptyState(
      title: controller.loading ? 'Loading shop…' : 'Shop not available',
      message: controller.error ?? 'This shop may be unpublished or removed.',
      action: TextButton(onPressed: controller.reload, child: const Text('Refresh'))));
    final products = controller.snapshot.products.where((p) => p.shopId == shop.id).toList();
    return DetailShell(controller: controller, child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      const SizedBox(height: 18),
      Wrap(spacing: 8, children: [Tag(shop.category), if (shop.isExample) const Tag('Fictional example', color: muted, background: line),
        if (!shop.isPublished) const Tag('Private preview', color: Color(0xFF826021), background: Color(0xFFFFF5D9))]),
      const SizedBox(height: 18), Text(shop.name, style: Theme.of(ctx).textTheme.headlineMedium),
      const SizedBox(height: 12), if (shop.description.isNotEmpty) Text(shop.description),
      const SizedBox(height: 18),
      Row(crossAxisAlignment: CrossAxisAlignment.start, children: [const Icon(Icons.location_on_outlined, color: green, size: 20),
        const SizedBox(width: 8), Expanded(child: Text('${shop.address}\n${shop.area}, Danapur, Bihar'))]),
      if (shop.hours.isNotEmpty) ...[const SizedBox(height: 10), Text('Opening hours: ${shop.hours}', style: const TextStyle(color: muted))],
      const SizedBox(height: 20),
      Wrap(spacing: 10, runSpacing: 10, children: [
        FilledButton.icon(onPressed: shop.phone.isEmpty ? null : () => openLink(ctx, whatsappUri(shop)),
          icon: const Icon(Icons.chat_bubble_outline_rounded, size: 18), label: const Text('WhatsApp shop')),
        OutlinedButton.icon(onPressed: shop.phone.isEmpty ? null : () => openLink(ctx, Uri(scheme: 'tel', path: '+91${shop.phone}')),
          icon: const Icon(Icons.call_outlined, size: 18), label: Text(shop.phone.isEmpty ? 'Example — no contact' : 'Call shop')),
        OutlinedButton.icon(onPressed: shop.isExample ? null : () => openLink(ctx, Uri.https('www.google.com', '/maps/search/',
          {'api': '1', 'query': '${shop.address}, ${shop.area}, Danapur, Bihar'})),
          icon: const Icon(Icons.directions_outlined, size: 18), label: const Text('Directions')),
      ]),
      const SizedBox(height: 18), Text(shop.isExample ? 'Sample data, not a real shop.' : 'Self-reported shop details • Updated ${updatedLabel(shop.updatedAt)}',
        style: const TextStyle(color: muted, fontSize: 11)),
      const SizedBox(height: 34), const Divider(), const SizedBox(height: 22),
      Text('Products at this shop', style: Theme.of(ctx).textTheme.titleLarge), const SizedBox(height: 20),
      if (products.isEmpty) const EmptyState(title: 'Products coming next', message: 'This seller has not added products yet.')
      else ProductGrid(products: products, controller: controller),
    ]));
  });
}
class ProductPage extends StatelessWidget {
  const ProductPage({super.key, required this.productId, required this.controller});
  final String productId;
  final MarketController controller;
  @override
  Widget build(BuildContext context) => ListenableBuilder(listenable: controller, builder: (ctx, _) {
    final product = controller.visibleProduct(productId);
    final shop = product == null ? null : controller.visibleShop(product.shopId);
    if (product == null || shop == null) return DetailShell(controller: controller, child: EmptyState(
      title: controller.loading ? 'Loading product…' : 'Product not available', message: controller.error ?? 'This listing may be removed or its shop unpublished.'));
    final details = Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Tag(product.category), const SizedBox(height: 16), Text(product.name, style: Theme.of(ctx).textTheme.headlineMedium),
      const SizedBox(height: 18), Wrap(spacing: 12, crossAxisAlignment: WrapCrossAlignment.center, children: [
        Text(money(product.pricePaise), style: const TextStyle(fontSize: 34, fontWeight: FontWeight.w800, color: green)),
        if (product.mrpPaise != null && product.mrpPaise! > product.pricePaise)
          Text('MRP ${money(product.mrpPaise!)}', style: const TextStyle(color: muted, decoration: TextDecoration.lineThrough)),
      ]),
      Text('Listed price / ${product.unit}', style: const TextStyle(color: muted)),
      const SizedBox(height: 18), Tag(product.isAvailable ? 'Listed as in stock' : 'Out of stock',
        color: product.isAvailable ? green : const Color(0xFF8A5A36),
        background: product.isAvailable ? const Color(0xFFEAF4EC) : const Color(0xFFFFF5D9)),
      const SizedBox(height: 22), if (product.description.isNotEmpty) Text(product.description),
      const SizedBox(height: 16), Card(child: ListTile(
        leading: const Icon(Icons.storefront_outlined, color: green), title: Text(shop.name), subtitle: Text(shop.area),
        trailing: const Icon(Icons.arrow_forward_rounded, size: 18),
        onTap: () => Navigator.pushNamed(ctx, '/shop/${shop.id}'))),
      const SizedBox(height: 22), Wrap(spacing: 10, runSpacing: 10, children: [
        FilledButton.icon(onPressed: shop.phone.isEmpty ? null : () => openLink(ctx, whatsappUri(shop, product)),
          icon: const Icon(Icons.chat_bubble_outline_rounded, size: 18), label: Text(shop.phone.isEmpty ? 'Example listing — contact disabled' : 'Enquire on WhatsApp')),
        OutlinedButton.icon(onPressed: () => runAction(ctx, () => controller.toggleSaved(product.id)),
          icon: Icon(controller.savedIds.contains(product.id) ? Icons.favorite : Icons.favorite_border, size: 18),
          label: Text(controller.savedIds.contains(product.id) ? 'Saved' : 'Save product')),
      ]),
      const SizedBox(height: 18), Text(shop.isExample ? 'Fictional example product and price.' : 'Updated ${updatedLabel(product.updatedAt)} • Confirm price and availability with the shop.',
        style: const TextStyle(fontSize: 11, color: muted)),
      const SizedBox(height: 10), const Text('Discovery only. No in-app checkout, payment or delivery.', style: TextStyle(fontSize: 11, color: muted)),
    ]);
    return DetailShell(controller: controller, child: LayoutBuilder(builder: (_, constraints) {
      final picture = ClipRRect(borderRadius: BorderRadius.circular(24), child: Stack(children: [
        ProductArt(product: product, height: constraints.maxWidth < 720 ? 280 : 420),
        if (product.imageUrl == null) const Positioned(left: 16, bottom: 16, child: Tag('Illustration, not a product photo', color: muted, background: Colors.white)),
      ]));
      return Padding(padding: const EdgeInsets.only(top: 24), child: constraints.maxWidth >= 720
        ? Row(crossAxisAlignment: CrossAxisAlignment.start, children: [Expanded(child: picture), const SizedBox(width: 38), Expanded(child: details)])
        : Column(crossAxisAlignment: CrossAxisAlignment.start, children: [picture, const SizedBox(height: 28), details]));
    }));
  });
}
