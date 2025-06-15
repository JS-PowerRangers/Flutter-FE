import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

class SideBar extends StatelessWidget {
  const SideBar({
    Key? key,
    required this.currency,
    required this.total,
    required this.budget,
    required this.showBudgetInput,
    required this.budgetController,
    required this.onBudgetToggle,
    required this.onBudgetSave,
    required this.canPay,
    required this.onPay,
  }) : super(key: key);

  final NumberFormat currency;
  final double total;
  final double? budget;
  final bool showBudgetInput;
  final TextEditingController budgetController;
  final VoidCallback onBudgetToggle;
  final ValueChanged<String> onBudgetSave;
  final bool canPay;
  final VoidCallback onPay;

  @override
  Widget build(BuildContext context) {
    final over = budget != null && total > budget!;
    return Container(
      width: 260,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        border: Border(left: BorderSide(color: Colors.grey.shade300)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: const [
              Icon(Icons.receipt_long),
              SizedBox(width: 8),
              Expanded(
                child: Text('Thông tin đơn hàng',
                    style: TextStyle(fontWeight: FontWeight.bold)),
              ),
            ],
          ),
          const SizedBox(height: 20),
          ElevatedButton.icon(
            icon: Icon(budget == null ? Icons.add : Icons.edit),
            label: Text(budget == null ? 'Đặt giới hạn' : 'Sửa giới hạn'),
            onPressed: onBudgetToggle,
          ),
          AnimatedSwitcher(
            duration: const Duration(milliseconds: 300),
            child: showBudgetInput
                ? Padding(
              padding: const EdgeInsets.only(top: 8),
              child: TextField(
                controller: budgetController,
                autofocus: true,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(
                  prefixIcon: Icon(Icons.monetization_on_outlined),
                  labelText: 'Giới hạn (₫)',
                  border: OutlineInputBorder(),
                ),
                onSubmitted: onBudgetSave,
              ),
            )
                : const SizedBox.shrink(),
          ),
          const SizedBox(height: 24),
          _PriceRow(label: 'Tổng tiền', value: currency.format(total), valueColor: over ? Colors.red : Colors.green),
          if (budget != null)
            _PriceRow(label: 'Giới hạn', value: currency.format(budget), valueColor: Colors.blue),
          const Spacer(),
          ElevatedButton.icon(
            icon: const Icon(Icons.payment),
            label: const Text('Thanh toán'),
            onPressed: canPay ? onPay : null,
            style: ElevatedButton.styleFrom(padding: const EdgeInsets.symmetric(vertical: 14)),
          ),
        ],
      ),
    );
  }
}

class _PriceRow extends StatelessWidget {
  const _PriceRow({Key? key, required this.label, required this.value, this.valueColor}) : super(key: key);
  final String label;
  final String value;
  final Color? valueColor;
  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        children: [
          Text(label),
          const Spacer(),
          Text(value, style: TextStyle(fontWeight: FontWeight.w600, color: valueColor)),
        ],
      ),
    );
  }
}
