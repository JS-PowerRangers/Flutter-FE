// lib/server.dart
import 'dart:convert';
import 'dart:io';
import 'package:shelf/shelf.dart';
import 'package:shelf/shelf_io.dart' as io;

void main() async {
  final handler = Pipeline().addMiddleware(logRequests()).addHandler((request) {
    final products = ['Áo sơ mi', 'Quần jeans', 'Giày sneaker'];
    return Response.ok(jsonEncode(products), headers: {
      'Content-Type': 'application/json',
    });
  });

  final server = await io.serve(handler, InternetAddress.anyIPv4, 8080);
  print('Server đang chạy tại: http://${server.address.address}:${server.port}');
}
