import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../models/product.dart';
import './chatot_page.dart';
import './payment_page.dart';
class ProductListPage extends StatefulWidget {
  @override
  _ProductListPageState createState() => _ProductListPageState();
}

class _ProductListPageState extends State<ProductListPage> {
  List<Product> products = [
    Product('Áo Trẻ Em', 10, 120000),
    Product('Cá Mắm Tôm', 5, 85000),
    Product('Cục cứt', 2, 32000),
  ];

  bool _showBudgetInput = false;
  TextEditingController _budgetController = TextEditingController();
  double? _budget;

  double get totalPrice {
    return products.fold(0, (sum, item) => sum + (item.price * item.quantity));
  }

  void _deleteProduct(int index) {
    setState(() {
      products.removeAt(index);
    });
  }

  void _updateQuantity(int index, String value) {
    int? parsed = int.tryParse(value);
    if (parsed != null && parsed >= 0) {
      setState(() {
        products[index].quantity = parsed;
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
              setState(() {
                _showBudgetInput = false;
              });
            },
          ),
          TextButton(
            child: Text('Có'),
            onPressed: () {
              Navigator.of(context).pop();
              setState(() {
                _showBudgetInput = true;
              });
            },
          ),
        ],
      ),
    );
  }

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
                Expanded(
                  child: ListView.builder(
                    itemCount: products.length,
                    itemBuilder: (context, index) {
                      TextEditingController controller = TextEditingController(
                        text: products[index].quantity.toString(),
                      );

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
                                  onChanged: (value) => _updateQuantity(index, value),
                                  decoration: InputDecoration(
                                    isDense: true,
                                    contentPadding: EdgeInsets.symmetric(horizontal: 6, vertical: 4),
                                    border: OutlineInputBorder(),
                                  ),
                                ),
                              ),
                              SizedBox(width: 20),
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
          Container(
            width: 220,
            padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Align(
              alignment: Alignment.centerLeft,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  ElevatedButton(
                    onPressed: _askToSetBudget,
                    child: Text('Đặt giới hạn chi tiêu'),
                  ),
                  if (_showBudgetInput)
                    TextField(
                      controller: _budgetController,
                      keyboardType: TextInputType.number,
                      textInputAction: TextInputAction.done,
                      onSubmitted: (value) {
                        FocusScope.of(context).unfocus();
                        setState(() {
                          _budget = double.tryParse(
                            value.replaceAll('.', '').replaceAll(',', ''),
                          );
                          _showBudgetInput = false;
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
                  Text(
                    'Tổng tiền: ${NumberFormat.currency(locale: 'vi_VN', symbol: '₫').format(totalPrice)}',
                    style: TextStyle(
                      fontSize: 16,
                      color: _budget != null && totalPrice > _budget! ? Colors.red : Colors.green,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  if (_budget != null && totalPrice > _budget!)
                    Padding(
                      padding: const EdgeInsets.only(top: 4),
                      child: Text(
                        '⚠️ Bạn đã vượt quá giới hạn chi tiêu!',
                        style: TextStyle(fontSize: 14, color: Colors.redAccent, fontWeight: FontWeight.w600),
                      ),
                    ),
                  if (_budget != null)
                    Padding(
                      padding: const EdgeInsets.only(top: 4),
                      child: Text(
                        'Giới hạn chi tiêu: ${NumberFormat.currency(locale: 'vi_VN', symbol: '₫').format(_budget)}',
                        style: TextStyle(fontSize: 16, color: Colors.blue, fontWeight: FontWeight.bold),
                      ),
                    ),
                  SizedBox(height: 12),
                  ElevatedButton.icon(
                    onPressed: () {
                      if (_budget != null && totalPrice > _budget!) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text('Không thể thanh toán: vượt quá giới hạn chi tiêu!'),
                            backgroundColor: Colors.red,
                          ),
                        );
                      } else if (products.isEmpty) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text('Không có sản phẩm để thanh toán!'),
                            backgroundColor: Colors.orange,
                          ),
                        );
                      } else {
                        // Thực hiện logic thanh toán ở đây
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
                                  Navigator.pop(context); // Đóng dialog
                                  Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                      builder: (context) => PaymentPage(totalPrice: totalPrice),
                                    ),
                                  );
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
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
