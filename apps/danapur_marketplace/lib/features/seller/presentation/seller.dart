import '../../auth/presentation/password_update.dart';
import 'verification_status.dart';
import 'package:flutter/material.dart';
import '../../../core/data/controller.dart';
import '../../../core/data/repository.dart';
import '../../../core/domain/market.dart';
import '../../../core/widgets/common.dart';
import 'forms.dart';
import '../../../core/theme/app_theme.dart';

class SellerDashboard extends StatelessWidget {
  const SellerDashboard({super.key, required this.controller});
  final MarketController controller;
  @override
  Widget build(BuildContext context) {
    if (controller.ownerId == null) {
      return SellerAuth(controller: controller);
    }
    final shop = controller.myShop;
    if (shop == null) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: 18),
          Tag('SELL LOCALLY', icon: Icons.storefront_outlined),
          const SizedBox(height: 20),
          Text(
            'Your local shop.\nOne simple online home.',
            style: Theme.of(context).textTheme.headlineLarge,
          ),
          const SizedBox(height: 16),
          const Text(
            'Add your shop, list products with prices, and let neighbours contact you directly.',
            style: TextStyle(color: muted),
          ),
          const SizedBox(height: 30),
          FilledButton.icon(
            key: const ValueKey('create-shop'),
            onPressed: () => editShop(context, controller),
            icon: const Icon(Icons.add_rounded),
            label: const Text('Create your shop'),
          ),
          const SizedBox(height: 38),
          Wrap(
            spacing: 20,
            runSpacing: 18,
            children: [
              _step(
                '01',
                'Create a shop',
                'Business type, category, address and storefront photo.',
              ),
              _step(
                '02',
                'Verify on WhatsApp',
                'Send your request ID and photo from your business mobile.',
              ),
              _step(
                '03',
                'Get approved',
                'Administrator review unlocks your public shop and products.',
              ),
            ],
          ),
          TextButton(
            onPressed: () => runAction(context, controller.repository.signOut),
            child: const Text('Sign out'),
          ),
          TextButton.icon(
            onPressed: () async {
              if (await confirm(
                    context,
                    'Delete your account?',
                    'Your login account will be permanently deleted. This cannot be undone.',
                  ) &&
                  context.mounted) {
                await runAction(
                  context,
                  controller.repository.deleteAccount,
                  success: 'Account deleted.',
                );
              }
            },
            icon: const Icon(Icons.person_remove_outlined, size: 17),
            label: const Text('Delete account'),
          ),
        ],
      );
    }
    final products =
        controller.snapshot.products.where((p) => p.shopId == shop.id).toList()
          ..sort((a, b) => b.updatedAt.compareTo(a.updatedAt));
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 12),
        Wrap(
          alignment: WrapAlignment.spaceBetween,
          crossAxisAlignment: WrapCrossAlignment.center,
          spacing: 24,
          runSpacing: 18,
          children: [
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'SELLER DASHBOARD',
                  style: TextStyle(
                    color: green,
                    fontSize: 10,
                    letterSpacing: 1.3,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  shop.name,
                  style: Theme.of(context).textTheme.headlineMedium,
                ),
                const SizedBox(height: 5),
                Text(
                  '${shop.area} • ${shop.category} • ${shop.businessType}',
                  style: const TextStyle(color: muted),
                ),
              ],
            ),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                OutlinedButton.icon(
                  onPressed: () => editShop(context, controller, shop),
                  icon: const Icon(Icons.edit_outlined, size: 17),
                  label: const Text('Edit shop'),
                ),
                FilledButton.icon(
                  key: const ValueKey('add-product'),
                  onPressed: () => editProduct(context, controller),
                  icon: const Icon(Icons.add_rounded, size: 18),
                  label: const Text('Add product'),
                ),
              ],
            ),
          ],
        ),
        const SizedBox(height: 24),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Wrap(
              spacing: 28,
              runSpacing: 18,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                _stat('${products.length}', 'Products listed'),
                _stat(
                  '${products.where((p) => p.isAvailable).length}',
                  'In stock',
                ),
                Tag(
                  shop.isPublic
                      ? 'Approved & published'
                      : '${shop.reviewStatus.toUpperCase()} • hidden from buyers',
                  icon: shop.isPublished
                      ? Icons.visibility_outlined
                      : Icons.visibility_off_outlined,
                ),
                TextButton.icon(
                  onPressed: () =>
                      Navigator.pushNamed(context, '/shop/${shop.id}'),
                  icon: const Icon(Icons.open_in_new_rounded, size: 16),
                  label: const Text('Preview shop'),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 20),
        VerificationStatusCard(controller: controller, shop: shop),
        const SizedBox(height: 28),
        Text('Your products', style: Theme.of(context).textTheme.titleLarge),
        const SizedBox(height: 6),
        const Text(
          'Prepare your catalogue now. Buyers see it only while your shop is approved and published.',
          style: TextStyle(color: muted, fontSize: 12),
        ),
        const SizedBox(height: 20),
        if (products.isEmpty)
          EmptyState(
            title: 'Your first product starts here',
            message:
                'Add a name, a clear price and a unit. A photo is optional.',
            action: FilledButton(
              onPressed: () => editProduct(context, controller),
              child: const Text('Add first product'),
            ),
          )
        else
          ...products.map(
            (p) => Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: LayoutBuilder(
                    builder: (_, constraints) {
                      final info = Row(
                        children: [
                          Container(
                            width: 46,
                            height: 46,
                            decoration: BoxDecoration(
                              color: categoryColor(p.category),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Icon(
                              categoryIcon(p.category),
                              color: green,
                              size: 23,
                            ),
                          ),
                          const SizedBox(width: 14),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  p.name,
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  '${money(p.pricePaise)} / ${p.unit}',
                                  style: const TextStyle(
                                    color: green,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                                Text(
                                  p.isAvailable ? 'In stock' : 'Out of stock',
                                  style: const TextStyle(
                                    color: muted,
                                    fontSize: 10,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      );
                      final actions = Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          IconButton(
                            tooltip: 'Edit ${p.name}',
                            onPressed: () =>
                                editProduct(context, controller, p),
                            icon: const Icon(Icons.edit_outlined, size: 20),
                          ),
                          IconButton(
                            tooltip: 'Delete ${p.name}',
                            onPressed: () async {
                              if (await confirm(
                                    context,
                                    'Delete product?',
                                    '${p.name} will be removed from your catalogue.',
                                  ) &&
                                  context.mounted) {
                                await runAction(
                                  context,
                                  () => controller.deleteProduct(p),
                                  success: 'Product deleted.',
                                );
                              }
                            },
                            icon: const Icon(
                              Icons.delete_outline_rounded,
                              color: Color(0xFFB44337),
                              size: 20,
                            ),
                          ),
                        ],
                      );
                      return constraints.maxWidth > 500
                          ? Row(
                              children: [
                                Expanded(child: info),
                                actions,
                              ],
                            )
                          : Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                info,
                                Align(
                                  alignment: Alignment.centerRight,
                                  child: actions,
                                ),
                              ],
                            );
                    },
                  ),
                ),
              ),
            ),
          ),
        const SizedBox(height: 32),
        const Divider(),
        TextButton.icon(
          onPressed: () async {
            if (await confirm(
                  context,
                  'Delete your account?',
                  'Your shop, products and login account will be permanently deleted. Administrator audit history may be retained for security. This cannot be undone.',
                ) &&
                context.mounted) {
              await runAction(
                context,
                controller.repository.deleteAccount,
                success: 'Account deleted.',
              );
            }
          },
          icon: const Icon(Icons.person_remove_outlined, size: 17),
          label: const Text('Delete account'),
        ),
        Wrap(
          spacing: 12,
          children: [
            TextButton.icon(
              onPressed: () =>
                  runAction(context, controller.repository.signOut),
              icon: const Icon(Icons.logout_rounded, size: 17),
              label: const Text('Sign out'),
            ),
            TextButton(
              onPressed: () async {
                if (await confirm(
                      context,
                      'Delete your shop?',
                      'Your shop and all its products will be deleted. This cannot be undone.',
                    ) &&
                    context.mounted) {
                  await runAction(
                    context,
                    controller.deleteMyShop,
                    success: 'Shop deleted.',
                  );
                }
              },
              child: const Text(
                'Delete shop',
                style: TextStyle(color: Color(0xFFB44337)),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _stat(String value, String label) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text(
        value,
        style: const TextStyle(
          fontSize: 24,
          fontWeight: FontWeight.w800,
          color: ink,
        ),
      ),
      Text(label, style: const TextStyle(color: muted, fontSize: 11)),
    ],
  );
  Widget _step(String number, String title, String message) => SizedBox(
    width: 265,
    child: Card(
      child: Padding(
        padding: const EdgeInsets.all(22),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              number,
              style: const TextStyle(
                color: green,
                fontSize: 13,
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 16),
            Text(title, style: const TextStyle(fontWeight: FontWeight.w700)),
            const SizedBox(height: 8),
            Text(message, style: const TextStyle(color: muted, fontSize: 12)),
          ],
        ),
      ),
    ),
  );
}

class SellerAuth extends StatefulWidget {
  const SellerAuth({super.key, required this.controller});
  final MarketController controller;
  @override
  State<SellerAuth> createState() => _SellerAuthState();
}

class _SellerAuthState extends State<SellerAuth> {
  final _form = GlobalKey<FormState>();
  final _email = TextEditingController(), _password = TextEditingController();
  bool _signup = false, _busy = false, _hide = true;
  String? _error, _message;
  @override
  void dispose() {
    _email.dispose();
    _password.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_form.currentState!.validate()) {
      return;
    }
    setState(() {
      _busy = true;
      _error = null;
      _message = null;
    });
    try {
      if (_signup) {
        final confirmation = await widget.controller.repository.signUp(
          _email.text,
          _password.text,
        );
        if (confirmation && mounted) {
          setState(() {
            _message =
                'Check your email to confirm your account, then sign in here.';
            _signup = false;
            _password.clear();
          });
        }
      } else {
        await widget.controller.repository.signIn(_email.text, _password.text);
      }
      await widget.controller.reload();
    } catch (e) {
      if (mounted) {
        setState(() => _error = friendlyError(e));
      }
    } finally {
      if (mounted) {
        setState(() => _busy = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) =>
      widget.controller.repository.needsPasswordUpdate
      ? PasswordUpdatePanel(controller: widget.controller)
      : Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 460),
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 30),
              child: Card(
                child: Padding(
                  padding: const EdgeInsets.all(28),
                  child: Form(
                    key: _form,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Icon(
                          Icons.storefront_outlined,
                          color: green,
                          size: 36,
                        ),
                        const SizedBox(height: 20),
                        Text(
                          _signup
                              ? 'Start selling locally'
                              : 'Welcome to Danapur Bazaar',
                          style: Theme.of(context).textTheme.titleLarge,
                        ),
                        const SizedBox(height: 8),
                        const Text(
                          'Sign in to manage your shop and prices. Buyers do not need an account.',
                          style: TextStyle(color: muted, fontSize: 12),
                        ),
                        const SizedBox(height: 24),
                        TextFormField(
                          controller: _email,
                          keyboardType: TextInputType.emailAddress,
                          autofillHints: const [AutofillHints.email],
                          decoration: const InputDecoration(labelText: 'Email'),
                          validator: (v) =>
                              RegExp(
                                r'^[^\s@]+@[^\s@]+\.[^\s@]+$',
                              ).hasMatch((v ?? '').trim())
                              ? null
                              : 'Enter a valid email.',
                        ),
                        const SizedBox(height: 18),
                        TextFormField(
                          controller: _password,
                          obscureText: _hide,
                          decoration: InputDecoration(
                            labelText: 'Password',
                            suffixIcon: IconButton(
                              tooltip: _hide
                                  ? 'Show password'
                                  : 'Hide password',
                              onPressed: () => setState(() => _hide = !_hide),
                              icon: Icon(
                                _hide
                                    ? Icons.visibility_outlined
                                    : Icons.visibility_off_outlined,
                              ),
                            ),
                          ),
                          validator: (v) =>
                              (v ?? '').length < (_signup ? 10 : 1)
                              ? (_signup
                                    ? 'Use at least 10 characters.'
                                    : 'Enter your password.')
                              : null,
                        ),
                        if (_error != null)
                          Padding(
                            padding: const EdgeInsets.only(top: 16),
                            child: Text(
                              _error!,
                              style: const TextStyle(color: Color(0xFFB44337)),
                            ),
                          ),
                        if (_message != null)
                          Padding(
                            padding: const EdgeInsets.only(top: 16),
                            child: Text(
                              _message!,
                              style: const TextStyle(color: green),
                            ),
                          ),
                        if (!_signup)
                          Align(
                            alignment: Alignment.centerRight,
                            child: TextButton(
                              onPressed: _busy
                                  ? null
                                  : () async {
                                      final email = _email.text.trim();
                                      if (!RegExp(
                                        r'^[^\s@]+@[^\s@]+\.[^\s@]+$',
                                      ).hasMatch(email)) {
                                        setState(
                                          () => _error =
                                              'Enter your email above first.',
                                        );
                                        return;
                                      }
                                      setState(() {
                                        _busy = true;
                                        _error = null;
                                      });
                                      try {
                                        await widget.controller.repository
                                            .requestPasswordReset(email);
                                        if (mounted) {
                                          setState(
                                            () => _message =
                                                'If an account exists, a password-reset email will arrive. Open its link to set a new password.',
                                          );
                                        }
                                      } catch (error) {
                                        if (mounted) {
                                          setState(
                                            () => _error = friendlyError(error),
                                          );
                                        }
                                      } finally {
                                        if (mounted) {
                                          setState(() => _busy = false);
                                        }
                                      }
                                    },
                              child: const Text('Forgot password?'),
                            ),
                          ),
                        const SizedBox(height: 24),
                        SizedBox(
                          width: double.infinity,
                          child: FilledButton(
                            onPressed: _busy ? null : _submit,
                            child: Text(
                              _busy
                                  ? 'Please wait…'
                                  : _signup
                                  ? 'Create account'
                                  : 'Sign in',
                            ),
                          ),
                        ),
                        const SizedBox(height: 12),
                        Center(
                          child: TextButton(
                            onPressed: _busy
                                ? null
                                : () => setState(() {
                                    _signup = !_signup;
                                    _error = null;
                                    _message = null;
                                  }),
                            child: Text(
                              _signup
                                  ? 'Already have an account? Sign in'
                                  : 'New here? Create a seller account',
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        );
}
