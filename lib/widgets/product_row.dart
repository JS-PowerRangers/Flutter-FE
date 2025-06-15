import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../models/product.dart';

class ProductRow extends StatelessWidget {
  const ProductRow({
    Key? key,
    required this.index,
    required this.product,
    required this.animation,
    required this.onDelete,
    required this.onQtyChanged,
  }) : super(key: key);

  final int index;
  final Product product;
  final Animation<double> animation;
  final VoidCallback onDelete;
  final ValueChanged<int> onQtyChanged;

  @override
  Widget build(BuildContext context) {
    final currency = NumberFormat.currency(locale: 'vi_VN', symbol: '₫');

    return SizeTransition(
      sizeFactor: animation,
      child: Card(
        margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
        elevation: 3,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        child: ListTile(
          leading: CircleAvatar(
            backgroundColor: Theme.of(context).colorScheme.secondaryContainer,
            child: Text('${index + 1}', style: const TextStyle(fontWeight: FontWeight.bold)),
          ),
          title: Text(product.name, style: const TextStyle(fontWeight: FontWeight.w600)),
          subtitle: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Đơn giá: ${currency.format(product.price)}'),
              Text('Thành tiền: ${currency.format(product.price * product.quantity)}',
                  style: const TextStyle(fontWeight: FontWeight.w500)),
            ],
          ),
          trailing: SizedBox(
            width: 120,
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                IconButton(
                  icon: const Icon(Icons.remove_circle_outline),
                  onPressed: () => onQtyChanged(product.quantity - 1),
                  splashRadius: 20,
                ),
                Text('${product.quantity}', style: const TextStyle(fontWeight: FontWeight.bold)),
                IconButton(
                  icon: const Icon(Icons.add_circle_outline),
                  onPressed: () => onQtyChanged(product.quantity + 1),
                  splashRadius: 20,
                ),
                IconButton(
                  icon: const Icon(Icons.delete_outline, color: Colors.red),
                  onPressed: onDelete,
                  splashRadius: 20,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
