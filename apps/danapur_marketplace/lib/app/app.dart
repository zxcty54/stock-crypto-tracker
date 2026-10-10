import '../features/auth/presentation/password_update.dart';
import '../features/mandi/presentation/mandi_screen.dart';
import '../features/admin/presentation/admin_screen.dart';
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import '../core/data/controller.dart';
import '../core/domain/market.dart';
import '../features/catalog/presentation/catalog.dart';
import '../core/widgets/common.dart';
import '../features/seller/presentation/seller.dart';
import '../core/theme/app_theme.dart';

class DanapurApp extends StatefulWidget {
  const DanapurApp({super.key, required this.controller});
  final MarketController controller;
  @override
  State<DanapurApp> createState() => _DanapurAppState();
}

class _DanapurAppState extends State<DanapurApp> {
  @override
  void initState() {
    super.initState();
    unawaited(widget.controller.reload());
  }

  @override
  void dispose() {
    widget.controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => MaterialApp(
    title: 'Danapur Bazaar — local shops, listed prices',
    debugShowCheckedModeBanner: false,
    theme: marketTheme(),
    onGenerateRoute: (settings) {
      final path = Uri.tryParse(settings.name ?? '/')?.pathSegments ?? [];
      Widget page;
      if (path.isEmpty) {
        page = AppShell(controller: widget.controller);
      } else if (path.length == 1 && path[0] == 'admin') {
        page = Scaffold(
          appBar: AppBar(title: const Brand(small: true)),
          body: SingleChildScrollView(
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: AdminScreen(controller: widget.controller),
            ),
          ),
        );
      } else if (path.length == 1 && path[0] == 'mandi') {
        page = Scaffold(
          appBar: AppBar(title: const Text('Danapur Mandi')),
          body: SingleChildScrollView(
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: MandiScreen(controller: widget.controller),
            ),
          ),
        );
      } else if (path.length == 2 && path[0] == 'shop') {
        page = ShopPage(shopId: path[1], controller: widget.controller);
      } else if (path.length == 2 && path[0] == 'product') {
        page = ProductPage(productId: path[1], controller: widget.controller);
      } else {
        page = Scaffold(
          appBar: AppBar(title: const Brand(small: true)),
          body: EmptyState(
            title: 'Page not found',
            message: 'This marketplace link is not valid.',
            action: Builder(
              builder: (ctx) => FilledButton(
                onPressed: () =>
                    Navigator.pushNamedAndRemoveUntil(ctx, '/', (_) => false),
                child: const Text('Explore Danapur'),
              ),
            ),
          ),
        );
      }
      return MaterialPageRoute<void>(settings: settings, builder: (_) => page);
    },
  );
}

class AppShell extends StatefulWidget {
  const AppShell({super.key, required this.controller});
  final MarketController controller;
  @override
  State<AppShell> createState() => _AppShellState();
}

class _AppShellState extends State<AppShell> {
  final _search = TextEditingController();
  final _scroll = ScrollController();
  int _tab = 0;
  String? _category, _area;
  ProductSort _sort = ProductSort.newest;
  MarketController get market => widget.controller;
  @override
  void initState() {
    super.initState();
    _search.addListener(_searchChanged);
  }

  void _searchChanged() {
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    _search.removeListener(_searchChanged);
    _search.dispose();
    _scroll.dispose();
    super.dispose();
  }

  void _setTab(int tab) {
    FocusManager.instance.primaryFocus?.unfocus();
    setState(() {
      _tab = tab;
      _search.clear();
      _category = null;
      _area = null;
      _sort = ProductSort.newest;
    });
    if (_scroll.hasClients) _scroll.jumpTo(0);
  }

  void _clearFilters() {
    setState(() {
      _search.clear();
      _category = null;
      _area = null;
      _sort = ProductSort.newest;
    });
  }

  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: market,
    builder: (ctx, _) {
      final small = MediaQuery.sizeOf(ctx).width < 980;
      final products = filterProducts(
        market.snapshot,
        query: _search.text,
        category: _category,
        area: _area,
        sort: _sort,
        savedIds: _tab == 2 ? market.savedIds : null,
      );
      final words = _search.text
          .trim()
          .toLowerCase()
          .split(RegExp(r'\s+'))
          .where((w) => w.isNotEmpty);
      final shops = market.publicShops
          .where(
            (s) =>
                (_category == null || s.category == _category) &&
                (_area == null || s.area == _area) &&
                words.every(
                  '${s.name} ${s.area} ${s.description} ${s.category}'
                      .toLowerCase()
                      .contains,
                ),
          )
          .toList();
      final savedCount = filterProducts(
        market.snapshot,
        savedIds: market.savedIds,
      ).length;
      return Scaffold(
        backgroundColor: canvas,
        body: SafeArea(
          child: Column(
            children: [
              Container(
                color: Colors.white,
                child: Center(
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 1280),
                    child: Padding(
                      padding: EdgeInsets.symmetric(
                        horizontal: small ? 20 : 32,
                        vertical: small ? 14 : 20,
                      ),
                      child: Row(
                        children: [
                          InkWell(
                            onTap: () => _setTab(0),
                            borderRadius: BorderRadius.circular(10),
                            child: Brand(small: small),
                          ),
                          if (!small) ...[
                            const SizedBox(width: 28),
                            Container(width: 1, height: 30, color: line),
                            const SizedBox(width: 22),
                            const Icon(
                              Icons.location_on_outlined,
                              size: 18,
                              color: green,
                            ),
                            const SizedBox(width: 5),
                            const Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Danapur, Bihar',
                                  style: TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                                Text(
                                  'Your local marketplace',
                                  style: TextStyle(fontSize: 10, color: muted),
                                ),
                              ],
                            ),
                          ],
                          const Spacer(),
                          if (!small) ...[
                            _nav('Explore', 0),
                            _nav('Shops', 1),
                            _nav('Mandi', 4),
                            _nav(
                              'Saved${savedCount > 0 ? ' ($savedCount)' : ''}',
                              2,
                            ),
                            const SizedBox(width: 14),
                            FilledButton.icon(
                              key: const ValueKey('seller-nav'),
                              onPressed: () => _setTab(3),
                              icon: const Icon(
                                Icons.storefront_outlined,
                                size: 17,
                              ),
                              label: Text(
                                market.myShop == null
                                    ? 'List your shop'
                                    : 'My shop',
                              ),
                            ),
                            const SizedBox(width: 4),
                          ] else
                            const Tag(
                              'DANAPUR',
                              icon: Icons.location_on_outlined,
                            ),
                          PopupMenuButton<String>(
                            tooltip: 'Marketplace menu',
                            icon: const Icon(
                              Icons.more_vert_rounded,
                              color: muted,
                            ),
                            onSelected: (value) async {
                              if (value == 'refresh') {
                                await market.reload();
                              }
                              if (value == 'about' && ctx.mounted) {
                                showInfo(ctx);
                              }
                              if (value == 'admin') _setTab(5);
                            },
                            itemBuilder: (_) => [
                              const PopupMenuItem(
                                value: 'refresh',
                                child: Text('Refresh listings'),
                              ),
                              const PopupMenuItem(
                                value: 'about',
                                child: Text('About marketplace'),
                              ),
                              const PopupMenuItem(
                                value: 'admin',
                                child: Text('Admin panel'),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
              if (market.loading) const LinearProgressIndicator(minHeight: 2),
              Expanded(
                child: RefreshIndicator(
                  onRefresh: market.reload,
                  child: SingleChildScrollView(
                    controller: _scroll,
                    physics: const AlwaysScrollableScrollPhysics(),
                    child: Center(
                      child: ConstrainedBox(
                        constraints: const BoxConstraints(maxWidth: 1280),
                        child: Padding(
                          padding: EdgeInsets.fromLTRB(
                            small ? 20 : 32,
                            24,
                            small ? 20 : 32,
                            0,
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              if (market.error != null)
                                EmptyState(
                                  title: 'Could not load the marketplace',
                                  message: market.error!,
                                  icon: Icons.cloud_off_outlined,
                                  action: FilledButton.icon(
                                    onPressed: market.reload,
                                    icon: const Icon(Icons.refresh),
                                    label: const Text('Try again'),
                                  ),
                                )
                              else if (market.repository.needsPasswordUpdate)
                                PasswordUpdatePanel(controller: market)
                              else if (_tab == 4)
                                MandiScreen(controller: market)
                              else if (_tab == 5)
                                AdminScreen(controller: market)
                              else if (_tab == 3)
                                SellerDashboard(controller: market)
                              else ...[
                                if (_tab == 0) ...[
                                  _hero(small),
                                  const SizedBox(height: 24),
                                ] else ...[
                                  const SizedBox(height: 12),
                                  Text(
                                    _tab == 1
                                        ? 'Meet your local shops'
                                        : 'Your saved finds',
                                    style: Theme.of(
                                      ctx,
                                    ).textTheme.headlineMedium,
                                  ),
                                  const SizedBox(height: 8),
                                  Text(
                                    _tab == 1
                                        ? 'A little closer to the shops around you.'
                                        : 'Keep good finds handy. Saved on this device.',
                                    style: const TextStyle(color: muted),
                                  ),
                                  const SizedBox(height: 24),
                                ],
                                TextField(
                                  key: const ValueKey('market-search'),
                                  controller: _search,
                                  decoration: InputDecoration(
                                    hintText: _tab == 1
                                        ? 'Search shops or neighbourhoods…'
                                        : 'Search products, shops or neighbourhoods…',
                                    prefixIcon: const Icon(
                                      Icons.search_rounded,
                                      color: green,
                                    ),
                                    suffixIcon: _search.text.isEmpty
                                        ? null
                                        : IconButton(
                                            tooltip: 'Clear search',
                                            onPressed: _search.clear,
                                            icon: const Icon(
                                              Icons.close_rounded,
                                            ),
                                          ),
                                  ),
                                  textInputAction: TextInputAction.search,
                                  onSubmitted: (_) => FocusManager
                                      .instance
                                      .primaryFocus
                                      ?.unfocus(),
                                ),
                                const SizedBox(height: 22),
                                SingleChildScrollView(
                                  scrollDirection: Axis.horizontal,
                                  child: Row(
                                    children: [
                                      _categoryChip(null),
                                      ...categories.map(_categoryChip),
                                    ],
                                  ),
                                ),
                                const SizedBox(height: 26),
                                Wrap(
                                  alignment: WrapAlignment.spaceBetween,
                                  crossAxisAlignment: WrapCrossAlignment.center,
                                  spacing: 24,
                                  runSpacing: 12,
                                  children: [
                                    Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          _tab == 1
                                              ? 'Shops around you'
                                              : _tab == 2
                                              ? 'Saved products'
                                              : 'Find something local',
                                          style: Theme.of(
                                            ctx,
                                          ).textTheme.titleLarge,
                                        ),
                                        const SizedBox(height: 4),
                                        Text(
                                          '${_tab == 1 ? shops.length : products.length} ${_tab == 1 ? 'shops' : 'products'} • approved shop listings',
                                          style: const TextStyle(
                                            color: muted,
                                            fontSize: 11,
                                          ),
                                        ),
                                      ],
                                    ),
                                    Wrap(
                                      spacing: 12,
                                      runSpacing: 8,
                                      crossAxisAlignment:
                                          WrapCrossAlignment.center,
                                      children: [
                                        Container(
                                          padding: const EdgeInsets.symmetric(
                                            horizontal: 12,
                                          ),
                                          decoration: BoxDecoration(
                                            color: Colors.white,
                                            border: Border.all(color: line),
                                            borderRadius: BorderRadius.circular(
                                              10,
                                            ),
                                          ),
                                          child: DropdownButtonHideUnderline(
                                            child: DropdownButton<String>(
                                              value: _area,
                                              hint: const Text(
                                                'All Danapur',
                                                style: TextStyle(fontSize: 12),
                                              ),
                                              icon: const Icon(
                                                Icons.keyboard_arrow_down,
                                                size: 18,
                                              ),
                                              items: [
                                                const DropdownMenuItem<String>(
                                                  value: null,
                                                  child: Text(
                                                    'All Danapur',
                                                    style: TextStyle(
                                                      fontSize: 12,
                                                    ),
                                                  ),
                                                ),
                                                ...areas.map(
                                                  (a) => DropdownMenuItem(
                                                    value: a,
                                                    child: Text(
                                                      a,
                                                      style: const TextStyle(
                                                        fontSize: 12,
                                                      ),
                                                    ),
                                                  ),
                                                ),
                                              ],
                                              onChanged: (a) =>
                                                  setState(() => _area = a),
                                            ),
                                          ),
                                        ),
                                        if (_tab != 1)
                                          Container(
                                            padding: const EdgeInsets.symmetric(
                                              horizontal: 12,
                                            ),
                                            decoration: BoxDecoration(
                                              color: Colors.white,
                                              border: Border.all(color: line),
                                              borderRadius:
                                                  BorderRadius.circular(10),
                                            ),
                                            child: DropdownButtonHideUnderline(
                                              child:
                                                  DropdownButton<ProductSort>(
                                                    value: _sort,
                                                    icon: const Icon(
                                                      Icons.keyboard_arrow_down,
                                                      size: 18,
                                                    ),
                                                    items: const [
                                                      DropdownMenuItem(
                                                        value:
                                                            ProductSort.newest,
                                                        child: Text(
                                                          'Newest first',
                                                          style: TextStyle(
                                                            fontSize: 12,
                                                          ),
                                                        ),
                                                      ),
                                                      DropdownMenuItem(
                                                        value: ProductSort
                                                            .priceLow,
                                                        child: Text(
                                                          'Price: low to high',
                                                          style: TextStyle(
                                                            fontSize: 12,
                                                          ),
                                                        ),
                                                      ),
                                                      DropdownMenuItem(
                                                        value: ProductSort
                                                            .priceHigh,
                                                        child: Text(
                                                          'Price: high to low',
                                                          style: TextStyle(
                                                            fontSize: 12,
                                                          ),
                                                        ),
                                                      ),
                                                    ],
                                                    onChanged: (s) => setState(
                                                      () => _sort = s!,
                                                    ),
                                                  ),
                                            ),
                                          ),
                                      ],
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 22),
                                if (_tab == 1 && shops.isNotEmpty)
                                  ShopGrid(shops: shops, controller: market)
                                else if (_tab != 1 && products.isNotEmpty)
                                  ProductGrid(
                                    products: products,
                                    controller: market,
                                  )
                                else
                                  EmptyState(
                                    title: _tab == 2 && market.savedIds.isEmpty
                                        ? 'No saved finds yet'
                                        : 'No matching listings',
                                    message:
                                        _tab == 2 && market.savedIds.isEmpty
                                        ? 'Tap a heart on a product to save it here.'
                                        : 'Try another search, neighbourhood or category.',
                                    action: TextButton(
                                      onPressed: _tab == 2
                                          ? () => _setTab(0)
                                          : _clearFilters,
                                      child: Text(
                                        _tab == 2
                                            ? 'Explore products'
                                            : 'Clear filters',
                                      ),
                                    ),
                                  ),
                              ],
                              const MarketFooter(),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
        bottomNavigationBar: small
            ? NavigationBar(
                selectedIndex: const [0, 1, 4, 2, 3].indexOf(_tab).clamp(0, 4),
                onDestinationSelected: (index) =>
                    _setTab(const [0, 1, 4, 2, 3][index]),
                height: 72,
                backgroundColor: Colors.white,
                destinations: const [
                  NavigationDestination(
                    icon: Icon(Icons.grid_view_outlined),
                    selectedIcon: Icon(Icons.grid_view_rounded),
                    label: 'Explore',
                  ),
                  NavigationDestination(
                    icon: Icon(Icons.storefront_outlined),
                    label: 'Shops',
                  ),
                  NavigationDestination(
                    icon: Icon(Icons.eco_outlined),
                    selectedIcon: Icon(Icons.eco_rounded),
                    label: 'Mandi',
                  ),
                  NavigationDestination(
                    icon: Icon(Icons.favorite_border_rounded),
                    selectedIcon: Icon(Icons.favorite_rounded),
                    label: 'Saved',
                  ),
                  NavigationDestination(
                    icon: Icon(Icons.person_outline_rounded),
                    label: 'My shop',
                  ),
                ],
              )
            : null,
      );
    },
  );
  Widget _nav(String title, int tab) => Padding(
    padding: const EdgeInsets.symmetric(horizontal: 2),
    child: TextButton(
      key: ValueKey('nav-$tab'),
      onPressed: () => _setTab(tab),
      style: TextButton.styleFrom(
        foregroundColor: _tab == tab ? green : muted,
        textStyle: TextStyle(
          fontFamily: 'Manrope',
          fontSize: 12,
          fontWeight: _tab == tab ? FontWeight.w800 : FontWeight.w600,
        ),
      ),
      child: Text(title),
    ),
  );
  Widget _categoryChip(String? category) => Padding(
    padding: const EdgeInsets.only(right: 10),
    child: ChoiceChip(
      key: ValueKey('category-${category ?? 'all'}'),
      selected: _category == category,
      showCheckmark: false,
      selectedColor: green,
      backgroundColor: Colors.white,
      side: BorderSide(color: _category == category ? green : line),
      avatar: Icon(
        category == null ? Icons.apps_rounded : categoryIcon(category),
        size: 17,
        color: _category == category ? Colors.white : green,
      ),
      label: Text(
        category ?? 'Everything',
        style: TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w600,
          color: _category == category ? Colors.white : ink,
        ),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      onSelected: (_) => setState(() => _category = category),
    ),
  );
  Widget _hero(bool small) => Container(
    width: double.infinity,
    padding: EdgeInsets.all(small ? 24 : 32),
    decoration: BoxDecoration(
      color: const Color(0xFFEBF1E4),
      borderRadius: BorderRadius.circular(24),
      border: Border.all(color: const Color(0xFFE1E9D9)),
    ),
    child: LayoutBuilder(
      builder: (context, constraints) {
        final text = Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Tag(
              'YOUR NEIGHBOURHOOD, ONLINE',
              background: Color(0xFFDCE9D5),
              icon: Icons.location_on_outlined,
            ),
            const SizedBox(height: 18),
            Text(
              'Danapur ki dukaan,\nab online.',
              style: TextStyle(
                fontSize: small ? 32 : 44,
                fontWeight: FontWeight.w800,
                color: ink,
                height: 1.2,
                letterSpacing: -1.1,
              ),
            ),
            const SizedBox(height: 14),
            const Text(
              'Approved shops. Retailers and wholesalers.\nLocal products and daily mandi price updates.',
              style: TextStyle(
                color: Color(0xFF526B57),
                fontSize: 13,
                height: 1.7,
              ),
            ),
            const SizedBox(height: 22),
            Wrap(
              spacing: 18,
              runSpacing: 9,
              children: [
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(
                      Icons.storefront_outlined,
                      color: green,
                      size: 16,
                    ),
                    const SizedBox(width: 6),
                    Text(
                      '${market.publicShops.length} approved shops',
                      style: const TextStyle(
                        color: green,
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
                const Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.chat_bubble_outline_rounded,
                      color: green,
                      size: 16,
                    ),
                    SizedBox(width: 6),
                    Text(
                      'Direct shop contact',
                      style: TextStyle(
                        color: green,
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ],
        );
        return constraints.maxWidth >= 740
            ? Row(
                children: [
                  Expanded(flex: 6, child: text),
                  Expanded(
                    flex: 5,
                    child: SvgPicture.asset(
                      'assets/illustrations/market.svg',
                      height: 246,
                      fit: BoxFit.contain,
                    ),
                  ),
                ],
              )
            : text;
      },
    ),
  );
}
