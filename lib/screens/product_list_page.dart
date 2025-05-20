import 'dart:convert'; // For jsonDecode
import 'dart:io'; // For HttpServer, InternetAddress

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:shelf/shelf.dart' as shelf;
import 'package:shelf/shelf_io.dart' as shelf_io;
import 'package:shelf_router/shelf_router.dart' as shelf_router;

import '../models/product.dart'; // Assuming your Product model is here
import './chatot_page.dart';
import './payment_page.dart';

class ProductListPage extends StatefulWidget {
  @override
  _ProductListPageState createState() => _ProductListPageState();
}

class _ProductListPageState extends State<ProductListPage> {
  // Start with an empty list of products
  List<Product> products = []; // <--- REMOVED FAKE DATA

  bool _showBudgetInput = false;
  TextEditingController _budgetController = TextEditingController();
  double? _budget;

  HttpServer? _server;

  Future<void> _startServer() async {
    print('>>> FLUTTER: _startServer called <<<');
    final router = shelf_router.Router();
    print('>>> FLUTTER: Router created <<<');

    // ****** ĐÂY LÀ PHẦN QUAN TRỌNG PHẢI CÓ ******
    router.post('/add_to_cart', (shelf.Request request) async {
      print('>>> FLUTTER SHELF: Received POST request to /add_to_cart <<<');
      try {
        final payload = await request.readAsString();
        print('>>> FLUTTER SHELF: Payload: $payload <<<');
        final jsonData = jsonDecode(payload);

        if (jsonData is Map<String, dynamic> &&
            jsonData.containsKey('name') &&
            jsonData.containsKey('price')) {
          final String name = jsonData['name'];
          final double price = (jsonData['price'] as num).toDouble();
          final int quantity = (jsonData['quantity'] as int?) ?? 1;

          print('>>> FLUTTER SHELF: Product data parsed, adding to server. Name: $name, Price: $price, Qty: $quantity <<<');
          _addProductFromServer(Product(name, quantity, price));
          return shelf.Response.ok(
              jsonEncode({'status': 'success', 'message': 'Product received by Flutter: $name'}),
              headers: {'Content-Type': 'application/json'});
        } else {
          print('>>> FLUTTER SHELF: Invalid payload structure: $jsonData <<<');
          return shelf.Response.badRequest(
              body: jsonEncode({
                'status': 'error',
                'message': 'Invalid payload. Expected {"name": "...", "price": ..., "quantity": ... (optional)}'
              }),
              headers: {'Content-Type': 'application/json'});
        }
      } catch (e, s) {
        print('!!! FLUTTER SHELF HANDLER ERROR: $e !!!');
        print(s);
        return shelf.Response.internalServerError(body: 'Shelf handler error: $e');
      }
    });
    // ****** KẾT THÚC PHẦN QUAN TRỌNG ******
    print('>>> FLUTTER: Router POST handler configured <<<');

    try {
      print('>>> FLUTTER: Attempting shelf_io.serve on port 8088 <<<');
      _server = await shelf_io.serve(router, InternetAddress.anyIPv4, 8088);
      print('>>> FLUTTER: shelf_io.serve successful! Server listening on http://${InternetAddress.loopbackIPv4.address}:${_server?.port}/add_to_cart <<<');

      WidgetsBinding.instance.addPostFrameCallback((_) {
        // ... (SnackBar logic) ...
      });
    } catch (e, s) {
      print('!!! FLUTTER: Error starting shelf server: $e !!!');
      print(s);
      // ... (SnackBar logic for error) ...
    }
    print('>>> FLUTTER: _startServer finished <<<');
  }

  void _addProductFromServer(Product newProduct) {
    if (!mounted) return;
    setState(() {
      int existingIndex = products.indexWhere((p) => p.name == newProduct.name);
      if (existingIndex != -1) {
        products[existingIndex].quantity += newProduct.quantity;
        print('Updated quantity for existing product: ${newProduct.name}');
      } else {
        products.add(newProduct);
        print('Added new product: ${newProduct.name}');
      }
    });
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('${newProduct.name} added/updated in cart!'), backgroundColor: Colors.blue),
    );
  }

  @override
  void initState() {
    super.initState();
    _startServer();
  }

  @override
  void dispose() {
    _server?.close(force: true).then((_) => print('Flutter server stopped.'));
    _budgetController.dispose();
    super.dispose();
  }

  double get totalPrice {
    return products.fold(0, (sum, item) => sum + (item.price * item.quantity));
  }

  void _deleteProduct(int index) {
    if (!mounted) return;
    setState(() {
      products.removeAt(index);
    });
  }

  void _updateQuantity(int index, String value) {
    if (!mounted) return;
    int? parsed = int.tryParse(value);
    if (parsed != null && parsed >= 0) {
      setState(() {
        products[index].quantity = parsed;
      });
    } else if (value.isEmpty) { // Allow clearing the field, maybe set quantity to 0 or 1
      setState(() {
        products[index].quantity = 0; // Or handle as invalid input
      });
    }
  }

  void _askToSetBudget() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Giới hạn chi tiêu'),
        content: Text('Bạn có muốn đặt giới hạn chi tiêu?'),
        actions: [
          TextButton(
            child: Text('Không'),
            onPressed: () {
              Navigator.of(context).pop();
              if (!mounted) return;
              setState(() {
                _showBudgetInput = false;
                _budget = null; // Clear budget if "No" is chosen
              });
            },
          ),
          TextButton(
            child: Text('Có'),
            onPressed: () {
              Navigator.of(context).pop();
              if (!mounted) return;
              setState(() {
                _showBudgetInput = true;
              });
            },
          ),
        ],
      ),
    );
  }

  // ... Rest of your _ProductListPageState build method and other UI logic remains the same ...
  // (The part with AppBar, Row, Expanded ListView, sidebar for budget/payment)
  // No changes needed there unless you want to adjust UI for an empty list state.

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Product List'),
        actions: [
          ElevatedButton.icon(
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => ChatBotPage()),
              );
            },
            icon: Icon(Icons.android),
            label: Text('Trò chuyện với chatBot'),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.deepPurple,
              foregroundColor: Colors.white,
              padding: EdgeInsets.symmetric(horizontal: 20, vertical: 12),
              textStyle: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
          ),
        ],
      ),
      body: Row(
        children: [
          Expanded(
            flex: 7,
            child: Column(
              children: [
                SizedBox(height: 10),
                Divider(thickness: 2),
                Container(
                  padding: EdgeInsets.symmetric(horizontal: 8, vertical: 8),
                  color: Colors.grey[300],
                  child: Row(
                    children: [
                      Expanded(flex: 1, child: Text('STT', style: TextStyle(fontWeight: FontWeight.bold))),
                      Expanded(flex: 3, child: Text('Tên sản phẩm', style: TextStyle(fontWeight: FontWeight.bold))),
                      Expanded(flex: 2, child: Text('Đơn giá', style: TextStyle(fontWeight: FontWeight.bold))),
                      Expanded(flex: 1, child: Text('SL', style: TextStyle(fontWeight: FontWeight.bold))),
                      Expanded(flex: 2, child: Text('Thành tiền', style: TextStyle(fontWeight: FontWeight.bold))),
                      Expanded(flex: 1, child: Text('Xóa', style: TextStyle(fontWeight: FontWeight.bold))),
                    ],
                  ),
                ),
                if (products.isEmpty) // <-- Show message if list is empty
                  Expanded(
                    child: Center(
                      child: Text(
                        'Chưa có sản phẩm nào.\nHãy quét mã vạch để thêm sản phẩm.',
                        textAlign: TextAlign.center,
                        style: TextStyle(fontSize: 16, color: Colors.grey[600]),
                      ),
                    ),
                  )
                else
                  Expanded(
                    child: ListView.builder(
                      itemCount: products.length,
                      itemBuilder: (context, index) {
                        // Create controller here but be mindful of performance for very long lists
                        // A common pattern is to manage controllers in a Map if you need to persist their state
                        // or access them outside the build method.
                        // For this case, creating it here is acceptable for simplicity.
                        TextEditingController controller = TextEditingController(
                          text: products[index].quantity.toString(),
                        );
                        // Move cursor to the end of the text
                        controller.selection = TextSelection.fromPosition(
                            TextPosition(offset: controller.text.length));

                        return Card(
                          margin: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                          child: Padding(
                            padding: EdgeInsets.symmetric(vertical: 12, horizontal: 8),
                            child: Row(
                              children: [
                                Expanded(flex: 1, child: Text('${index + 1}')),
                                Expanded(flex: 3, child: Text(products[index].name)),
                                Expanded(
                                  flex: 2,
                                  child: Text(
                                    NumberFormat.currency(locale: 'vi_VN', symbol: '₫').format(products[index].price),
                                  ),
                                ),
                                Expanded(
                                  flex: 1,
                                  child: TextField(
                                    controller: controller,
                                    keyboardType: TextInputType.number,
                                    textAlign: TextAlign.center, // Center text in TextField
                                    onChanged: (value) => _updateQuantity(index, value),
                                    decoration: InputDecoration(
                                      isDense: true,
                                      contentPadding: EdgeInsets.symmetric(horizontal: 6, vertical: 8), // Adjust padding
                                      border: OutlineInputBorder(),
                                    ),
                                  ),
                                ),
                                SizedBox(width: 8), // Reduced spacing a bit
                                Expanded(
                                  flex: 2,
                                  child: Text(
                                    NumberFormat.currency(locale: 'vi_VN', symbol: '₫')
                                        .format(products[index].price * products[index].quantity),
                                    style: TextStyle(fontWeight: FontWeight.bold),
                                  ),
                                ),
                                Expanded(
                                  flex: 1,
                                  child: Center(
                                    child: IconButton(
                                      icon: Icon(Icons.delete, color: Colors.red),
                                      onPressed: () => _deleteProduct(index),
                                      padding: EdgeInsets.zero, // Reduce default padding
                                      constraints: BoxConstraints(), // Reduce default constraints
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        );
                      },
                    ),
                  ),
              ],
            ),
          ),
          Container( // Sidebar
            width: 230, // Slightly increased width for better text fit
            padding: EdgeInsets.all(16), // Use all for consistent padding
            decoration: BoxDecoration(
                border: Border(left: BorderSide(color: Colors.grey[300]!)) // Optional: add a border
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch, // Make buttons take full width
              mainAxisAlignment: MainAxisAlignment.start, // Align to top
              children: [
                Text(
                  'Thông tin đơn hàng',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
                  textAlign: TextAlign.center,
                ),
                SizedBox(height: 16),
                ElevatedButton(
                  onPressed: _askToSetBudget,
                  child: Text(_budget == null ? 'Đặt giới hạn chi tiêu' : 'Sửa giới hạn chi tiêu'),
                ),
                if (_showBudgetInput)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 8.0),
                    child: TextField(
                      controller: _budgetController,
                      keyboardType: TextInputType.numberWithOptions(decimal: false),
                      textInputAction: TextInputAction.done,
                      onSubmitted: (value) {
                        FocusScope.of(context).unfocus();
                        if (!mounted) return;
                        setState(() {
                          _budget = double.tryParse(
                            value.replaceAll('.', '').replaceAll(',', ''),
                          );
                          _showBudgetInput = false;
                          if (_budget != null) {
                            _budgetController.text = NumberFormat.decimalPattern('vi_VN').format(_budget);
                          } else {
                            _budgetController.clear();
                          }
                        });
                      },
                      decoration: InputDecoration(
                        isDense: true,
                        contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                        labelText: 'Giới hạn (VNĐ)',
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                        prefixIcon: Icon(Icons.monetization_on),
                      ),
                    ),
                  ),
                SizedBox(height: 16),
                Text(
                  'Tổng tiền:',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.w500),
                ),
                Text(
                  NumberFormat.currency(locale: 'vi_VN', symbol: '₫').format(totalPrice),
                  style: TextStyle(
                    fontSize: 20, // Made total price larger
                    color: _budget != null && totalPrice > _budget! ? Colors.red : Colors.green,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                if (_budget != null)
                  Padding(
                    padding: const EdgeInsets.only(top: 8),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Giới hạn đã đặt:',
                          style: TextStyle(fontSize: 14, color: Colors.grey[700]),
                        ),
                        Text(
                          NumberFormat.currency(locale: 'vi_VN', symbol: '₫').format(_budget),
                          style: TextStyle(fontSize: 16, color: Colors.blue, fontWeight: FontWeight.bold),
                        ),
                        if (totalPrice > _budget!)
                          Padding(
                            padding: const EdgeInsets.only(top: 4),
                            child: Text(
                              '⚠️ Đã vượt quá giới hạn!',
                              style: TextStyle(fontSize: 14, color: Colors.redAccent, fontWeight: FontWeight.w600),
                            ),
                          ),
                      ],
                    ),
                  ),
                Spacer(), // Pushes payment button to the bottom if space allows
                ElevatedButton.icon(
                  onPressed: products.isEmpty ? null : () { // Disable if no products
                    if (_budget != null && totalPrice > _budget!) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text('Không thể thanh toán: vượt quá giới hạn chi tiêu!'),
                          backgroundColor: Colors.red,
                        ),
                      );
                    } else {
                      showDialog(
                        context: context,
                        builder: (context) => AlertDialog(
                          title: Text('Xác nhận thanh toán'),
                          content: Text(
                              'Bạn có chắc muốn thanh toán ${NumberFormat.currency(locale: 'vi_VN', symbol: '₫').format(totalPrice)} không?'),
                          actions: [
                            TextButton(
                              onPressed: () => Navigator.pop(context),
                              child: Text('Hủy'),
                            ),
                            TextButton(
                              onPressed: () {
                                Navigator.pop(context);
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (context) => PaymentPage(totalPrice: totalPrice),
                                  ),
                                ).then((_) {
                                  // Optional: Clear cart after payment or perform other actions
                                  // setState(() {
                                  //   products.clear();
                                  //   _budget = null;
                                  //   _budgetController.clear();
                                  // });
                                });
                              },
                              child: Text('Xác nhận'),
                            ),
                          ],
                        ),
                      );
                    }
                  },
                  icon: Icon(Icons.payment),
                  label: Text('Thanh toán'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.green,
                    foregroundColor: Colors.white,
                    padding: EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                    textStyle: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                    minimumSize: Size(double.infinity, 48), // Make button wider
                  ),
                ),
                SizedBox(height: 8), // Some spacing at the bottom
              ],
            ),
          ),
        ],
      ),
    );
  }
}