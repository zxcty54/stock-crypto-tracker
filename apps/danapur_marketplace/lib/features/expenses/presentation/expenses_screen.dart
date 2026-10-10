import 'package:flutter/material.dart';
import '../../../core/data/controller.dart';
import '../../../core/data/repository.dart';
import '../../../core/domain/market.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/common.dart';
import '../../mandi/domain/mandi.dart';
import '../../orders/domain/commerce.dart';
import '../../seller/presentation/forms.dart';
import '../../seller/presentation/seller.dart';

class ExpensesScreen extends StatefulWidget {
  const ExpensesScreen({super.key, required this.controller});
  final MarketController controller;
  @override
  State<ExpensesScreen> createState() => _ExpensesScreenState();
}

class _ExpensesScreenState extends State<ExpensesScreen> {
  DateTime _month = indiaNow();
  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: widget.controller,
    builder: (ctx, _) {
      final market = widget.controller;
      if (market.ownerId == null) {
        return SellerAuth(controller: market);
      }
      final rows =
          market.snapshot.expenses
              .where(
                (e) =>
                    e.date.year == _month.year && e.date.month == _month.month,
              )
              .toList()
            ..sort((a, b) => b.date.compareTo(a.date));
      final total = rows.fold<int>(0, (sum, e) => sum + e.amountPaise);
      final breakdown = <String, int>{};
      for (final e in rows) {
        breakdown[e.category] = (breakdown[e.category] ?? 0) + e.amountPaise;
      }
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Tag(
            'PERSONAL EXPENSE MANAGER',
            icon: Icons.account_balance_wallet_outlined,
          ),
          const SizedBox(height: 16),
          Text(
            'Know your spending',
            style: Theme.of(ctx).textTheme.headlineLarge,
          ),
          const SizedBox(height: 8),
          const Text(
            'Completed orders are recorded once. Cancelled/open orders do not count. Manual expenses are editable; order totals stay linked to their immutable order.',
            style: TextStyle(color: muted, fontSize: 12),
          ),
          const SizedBox(height: 24),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '${_month.year}-${_month.month.toString().padLeft(2, '0')} total',
                    style: const TextStyle(color: muted),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    money(total),
                    style: const TextStyle(
                      fontSize: 30,
                      fontWeight: FontWeight.w800,
                      color: green,
                    ),
                  ),
                  const SizedBox(height: 14),
                  Wrap(
                    spacing: 10,
                    runSpacing: 8,
                    children: [
                      OutlinedButton.icon(
                        onPressed: () async {
                          final now = indiaNow();
                          final chosen = await showDatePicker(
                            context: ctx,
                            initialDate: DateTime(_month.year, _month.month, 1),
                            firstDate: DateTime(2020),
                            lastDate: DateTime(now.year, now.month, now.day),
                          );
                          if (chosen != null && mounted) {
                            setState(() => _month = chosen);
                          }
                        },
                        icon: const Icon(Icons.calendar_month_outlined),
                        label: const Text('Choose month'),
                      ),
                      FilledButton.icon(
                        onPressed: () => showDialog<void>(
                          context: ctx,
                          barrierDismissible: false,
                          builder: (_) => ExpenseForm(controller: market),
                        ),
                        icon: const Icon(Icons.add),
                        label: const Text('Add expense'),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 18),
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: breakdown.entries
                .map((entry) => Tag('${entry.key}: ${money(entry.value)}'))
                .toList(),
          ),
          const SizedBox(height: 20),
          if (rows.isEmpty)
            const EmptyState(
              title: 'No expenses this month',
              message:
                  'Complete an order or add a manual expense to start your record.',
            ),
          ...rows.map(
            (e) => Card(
              child: Padding(
                padding: const EdgeInsets.all(18),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Wrap(
                      spacing: 10,
                      runSpacing: 6,
                      children: [
                        Text(
                          money(e.amountPaise),
                          style: const TextStyle(
                            fontWeight: FontWeight.w800,
                            color: green,
                            fontSize: 18,
                          ),
                        ),
                        Tag(e.category),
                        if (e.isSample) const Tag('TEST RECORD'),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Text(
                      '${mandiDateKey(e.date)} • ${e.orderId == null ? 'Manual expense' : 'Completed order'}',
                      style: const TextStyle(color: muted, fontSize: 11),
                    ),
                    if (e.note.isNotEmpty)
                      Text(e.note, style: const TextStyle(fontSize: 12)),
                    if (e.orderId == null)
                      Wrap(
                        children: [
                          TextButton(
                            onPressed: () => showDialog<void>(
                              context: ctx,
                              builder: (_) =>
                                  ExpenseForm(controller: market, expense: e),
                            ),
                            child: const Text('Edit'),
                          ),
                          TextButton(
                            onPressed: () async {
                              if (await confirm(
                                    ctx,
                                    'Delete manual expense?',
                                    'This removes only your manual expense, not an order.',
                                  ) &&
                                  ctx.mounted) {
                                await runAction(ctx, () async {
                                  await market.repository.deleteExpense(e);
                                  await market.reload();
                                });
                              }
                            },
                            child: const Text('Delete'),
                          ),
                        ],
                      ),
                  ],
                ),
              ),
            ),
          ),
        ],
      );
    },
  );
}

class ExpenseForm extends StatefulWidget {
  const ExpenseForm({super.key, required this.controller, this.expense});
  final MarketController controller;
  final PersonalExpense? expense;
  @override
  State<ExpenseForm> createState() => _ExpenseFormState();
}

class _ExpenseFormState extends State<ExpenseForm> {
  final _form = GlobalKey<FormState>();
  late final TextEditingController _amount, _category, _note;
  late DateTime _date;
  bool _busy = false;
  String? _error;
  @override
  void initState() {
    super.initState();
    final e = widget.expense;
    _amount = TextEditingController(
      text: e == null ? '' : priceInput(e.amountPaise),
    );
    _category = TextEditingController(text: e?.category ?? 'Personal');
    _note = TextEditingController(text: e?.note);
    final now = indiaNow();
    _date = e?.date ?? DateTime(now.year, now.month, now.day);
  }

  @override
  void dispose() {
    _amount.dispose();
    _category.dispose();
    _note.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!_form.currentState!.validate()) {
      return;
    }
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await widget.controller.repository.saveExpense(
        widget.expense?.id,
        parsePrice(_amount.text)!,
        _category.text,
        _note.text,
        _date,
      );
      await widget.controller.reload();
      if (mounted) {
        Navigator.pop(context);
      }
    } catch (error) {
      if (mounted) {
        setState(() => _error = friendlyError(error));
      }
    } finally {
      if (mounted) {
        setState(() => _busy = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) => FormSheet(
    title: widget.expense == null
        ? 'Add personal expense'
        : 'Edit personal expense',
    subtitle:
        'Private to your account. No bank account or payment gateway is connected.',
    onSave: _save,
    busy: _busy,
    error: _error,
    saveLabel: 'Save expense',
    body: Form(
      key: _form,
      child: Column(
        children: [
          TextFormField(
            controller: _amount,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            decoration: const InputDecoration(
              labelText: 'Amount *',
              prefixText: '₹ ',
            ),
            validator: (v) =>
                parsePrice(v ?? '') == null ? 'Enter a valid amount.' : null,
          ),
          const SizedBox(height: 18),
          TextFormField(
            controller: _category,
            maxLength: 80,
            decoration: const InputDecoration(
              labelText: 'Category *',
              hintText: 'e.g. Travel, food, household',
            ),
            validator: (v) => validateLength(v, 'Category', 1, 80),
          ),
          const SizedBox(height: 12),
          TextFormField(
            controller: _note,
            maxLength: 300,
            maxLines: 2,
            decoration: const InputDecoration(labelText: 'Note'),
          ),
          ListTile(
            contentPadding: EdgeInsets.zero,
            title: Text('Date: ${mandiDateKey(_date)}'),
            trailing: TextButton(
              onPressed: () async {
                final now = indiaNow();
                final selected = await showDatePicker(
                  context: context,
                  initialDate: _date,
                  firstDate: DateTime(2020),
                  lastDate: DateTime(now.year, now.month, now.day),
                );
                if (selected != null && mounted) {
                  setState(() => _date = selected);
                }
              },
              child: const Text('Change'),
            ),
          ),
        ],
      ),
    ),
  );
}
