import 'package:flutter/material.dart';
import 'colors.dart';

class TextStyles {
  // عناوين الشاشات (كبيرة وعريضة)
  static const TextStyle font24WhiteBold = TextStyle(
    fontSize: 24,
    fontWeight: FontWeight.bold,
    color: ColorsManager.white,
  );

  // أسماء المنتجات أو العناوين الفرعية
  static const TextStyle font18WhiteMedium = TextStyle(
    fontSize: 18,
    fontWeight: FontWeight.w500,
    color: ColorsManager.white,
  );

  // السعر المميز (باللون الأزرق المضيء)
  static const TextStyle font20NeonBlueBold = TextStyle(
    fontSize: 20,
    fontWeight: FontWeight.bold,
    color: ColorsManager.neonBlue,
  );

  // النصوص العادية (مثل وصف المنتج)
  static const TextStyle font14LightGrayRegular = TextStyle(
    fontSize: 14,
    fontWeight: FontWeight.w400,
    color: ColorsManager.lightGray,
  );
}