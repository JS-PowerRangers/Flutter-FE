// lib/pages/product_list_page.dart
// Main page separated from widgets & utils. Now wired with SQLite.

import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:shelf/shelf.dart' as shelf;
import 'package:shelf/shelf_io.dart' as shelf_io;
import 'package:shelf_router/shelf_router.dart' as shelf_router;

import '../models/product.dart';
import '../utils/toast_utils.dart';
import '../widgets/product_row.dart';
import '../widgets/sidebar.dart';
import '../database/product_db.dart';
import 'chatot_page.dart';
import 'payment_page.dart';

class ProductListPage extends StatefulWidget {
  const ProductListPage({Key? key}) : super(key: key);

  @override
  State<ProductListPage> createState() => _ProductListPageState();
}

class _ProductListPageState extends State<ProductListPage>
    with TickerProviderStateMixin {
  // ------------------------------- DATA ------------------------------------
  final List<Product> _products = [];
  final GlobalKey<AnimatedListState> _listKey = GlobalKey<AnimatedListState>();

  double? _budget;
  bool _showBudgetInput = false;
  final TextEditingController _budgetController = TextEditingController();

  HttpServer? _server;

  // ----------------------------- HTTP SERVER ------------------------------
  Future<void> _startServer() async {
    final router = shelf_router.Router();
    router.post('/add_to_cart', (shelf.Request req) async {
      final payload = await req.readAsString();
      final data = jsonDecode(payload);
      if (data is Map<String, dynamic> &&
          data.containsKey('name') &&
          data.containsKey('price')) {
        final p = Product(
          data['name'] as String,
          (data['quantity'] as int?) ?? 1,
          (data['price'] as num).toDouble(),
        );
        _addProduct(p);
        return shelf.Response.ok('Added');
      }
      return shelf.Response.badRequest(body: 'Invalid payload');
    });
    _server = await shelf_io.serve(router, InternetAddress.anyIPv4, 8088);
  }

  // ------------------------------ HELPERS ---------------------------------
  void _addProduct(Product p) async {
    await ProductDB.instance.insertProduct(p);
    final idx = _products.indexWhere((e) => e.name == p.name);
    setState(() {
      if (idx == -1) {
        _products.add(p);
        _listKey.currentState?.insertItem(_products.length - 1,
            duration: const Duration(milliseconds: 300));
      } else {
        _products[idx].quantity += p.quantity;
      }
    });
    ToastUtils.success(context, '${p.name} đã thêm vào giỏ');
  }

  double get _total =>
      _products.fold(0, (sum, p) => sum + p.price * p.quantity);

  void _delete(int index) async {
    final removed = _products.removeAt(index);
    await ProductDB.instance.deleteProduct(removed.name);
    _listKey.currentState?.removeItem(
      index,
          (ctx, anim) => ProductRow(
        index: index,
        product: removed,
        animation: anim,
        onDelete: () {},
        onQtyChanged: (_) {},
      ),
      duration: const Duration(milliseconds: 300),
    );
    setState(() {});
  }

  void _updateQty(Product p, int qty) async {
    if (qty < 1) return;
    await ProductDB.instance.updateQuantity(p.name, qty);
    setState(() => p.quantity = qty);
  }

  // ----------------------------- UI ACTIONS ------------------------------
  void _askBudget() {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Giới hạn chi tiêu'),
        content: const Text('Bạn muốn đặt giới hạn chi tiêu?'),
        actions: [
          TextButton(
            child: const Text('Không'),
            onPressed: () {
              Navigator.pop(context);
              setState(() {
                _budget = null;
                _showBudgetInput = false;
              });
            },
          ),
          TextButton(
            child: const Text('Có'),
            onPressed: () {
              Navigator.pop(context);
              setState(() => _showBudgetInput = true);
            },
          ),
        ],
      ),
    );
  }

  void _saveBudget(String value) {
    final parsed = double.tryParse(value.replaceAll('.', '').replaceAll(',', ''));
    if (parsed != null) {
      setState(() {
        _budget = parsed;
        _showBudgetInput = false;
      });
      ToastUtils.success(context,
          'Đã đặt giới hạn ${NumberFormat.decimalPattern('vi_VN').format(_budget)}');
    }
  }

  void _pay() {
    if (_budget != null && _total > _budget!) {
      ToastUtils.error(context, 'Không thể thanh toán: vượt quá giới hạn!');
      return;
    }
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Xác nhận thanh toán'),
        content: Text(
            'Thanh toán ${NumberFormat.currency(locale: 'vi_VN', symbol: '₫').format(_total)}?'),
        actions: [
          TextButton(
              child: const Text('Huỷ'),
              onPressed: () => Navigator.pop(context)),
          TextButton(
            child: const Text('Xác nhận'),
            onPressed: () {
              Navigator.pop(context);
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => PaymentPage(totalPrice: _total)),
              );
            },
          ),
        ],
      ),
    );
  }

  // ---------------------------- LIFECYCLE ---------------------------------
  @override
  void initState() {
    super.initState();
    _startServer();

    // Load existing cart from SQLite
    ProductDB.instance.fetchAll().then((items) {
      setState(() => _products.addAll(items));
    });
  }

  @override
  void dispose() {
    _server?.close(force: true);
    _budgetController.dispose();
    super.dispose();
  }

  // ------------------------------ BUILD -----------------------------------
  @override
  Widget build(BuildContext context) {
    final currency = NumberFormat.currency(locale: 'vi_VN', symbol: '₫');
    return Scaffold(
      appBar: AppBar(
        title: const Text('Danh sách sản phẩm'),
        actions: [TextButton.icon(
          style: TextButton.styleFrom(
            backgroundColor: Colors.lightBlue.shade100,
            foregroundColor: Colors.blue.shade800,
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
          ),
          icon: const Icon(Icons.android),
          label: const Text('Trò chuyện với ChatBot'),
          onPressed: () {
            Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => ChatBotPage()),
            );
          },
        ),
        ],
      ),
      body: Row(
        children: [
          Expanded(
            flex: 7,
            child: _products.isEmpty
                ? const Center(
              child: Text('Chưa có sản phẩm nào',
                  style: TextStyle(color: Colors.grey)),
            )
                : AnimatedList(
              key: _listKey,
              padding: const EdgeInsets.only(bottom: 80, top: 8),
              initialItemCount: _products.length,
              itemBuilder: (ctx, idx, anim) => ProductRow(
                index: idx,
                product: _products[idx],
                animation: anim,
                onDelete: () => _delete(idx),
                onQtyChanged: (q) => _updateQty(_products[idx], q),
              ),
            ),
          ),
          SideBar(
            currency: currency,
            total: _total,
            budget: _budget,
            showBudgetInput: _showBudgetInput,
            budgetController: _budgetController,
            onBudgetToggle: _askBudget,
            onBudgetSave: _saveBudget,
            canPay: _products.isNotEmpty,
            onPay: _pay,
          ),
        ],
      ),
    );
  }
}
