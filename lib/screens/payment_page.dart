import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

class PaymentPage extends StatelessWidget {
  final double totalPrice;

  const PaymentPage({Key? key, required this.totalPrice}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final currency = NumberFormat.currency(locale: 'vi_VN', symbol: '₫');
    return Scaffold(
      appBar: AppBar(
        title: Text('Thanh toán'),
      ),
      body: Row(
        children: [
          // Bên trái: Thông tin + hướng dẫn
          Expanded(
            flex: 3,
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Tổng số tiền cần thanh toán:',
                      style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                  SizedBox(height: 8),
                  Text(currency.format(totalPrice),
                      style: TextStyle(fontSize: 22, color: Colors.green, fontWeight: FontWeight.bold)),
                  SizedBox(height: 24),
                  Text('Các bước thanh toán:', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                  SizedBox(height: 12),
                  Text('1. Mở ứng dụng ngân hàng có hỗ trợ QR.'),
                  Text('2. Quét mã QR ở bên phải màn hình.'),
                  Text('3. Xác nhận thanh toán số tiền trên.'),
                  Text('4. Sau khi thanh toán, giữ lại hóa đơn để đối chiếu nếu cần.'),
                ],
              ),
            ),
          ),

          // Bên phải: Mã QR
          Expanded(
            flex: 2,
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Image.asset(
                'assets/images/QRcode.jpg', // Thay bằng QR thực tế
                fit: BoxFit.contain,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
