// Utility functions for showing MotionToast notifications (v2.x) with friendly emojis.
import 'package:flutter/material.dart';
import 'package:motion_toast/motion_toast.dart';

class ToastUtils {
  static void success(BuildContext context, String message) {
    MotionToast.success(
      title: const Text('Thành công 😊', style: TextStyle(fontWeight: FontWeight.bold)),
      description: Text(message),
      animationCurve: Curves.easeOutExpo,
    ).show(context);
  }

  static void error(BuildContext context, String message) {
    MotionToast.error(
      title: const Text('Lỗi 😥', style: TextStyle(fontWeight: FontWeight.bold)),
      description: Text(message),
      animationCurve: Curves.easeOutExpo,
    ).show(context);
  }

  static void info(BuildContext context, String message) {
    MotionToast.info(
      title: const Text('Thông báo 😉', style: TextStyle(fontWeight: FontWeight.bold)),
      description: Text(message),
      animationCurve: Curves.easeOutExpo,
    ).show(context);
  }
}
