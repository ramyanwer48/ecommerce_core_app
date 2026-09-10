import 'package:flutter/material.dart';

class CustomBottomSheet {
  /// دالة عامة تستقبل الـ [context] ومحتوى الشاشة [child] وعنوان اختياري [title]
  static void show({
    required BuildContext context,
    required Widget child,
    String? title,
  }) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true, // الحماية من الـ Overflow
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (context) {
        return Padding(
          // القاعدة الذهبية التي ترفع النافذة مع الكيبورد في أي شاشة
          padding: EdgeInsets.only(
            bottom: MediaQuery.of(context).viewInsets.bottom,
            left: 24,
            right: 24,
            top: 24,
          ),
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // 1. مؤشر السحب الرمادي الأنيق
                Container(
                  width: 40,
                  height: 5,
                  margin: const EdgeInsets.only(bottom: 20),
                  decoration: BoxDecoration(
                    color: Colors.grey.shade300,
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
                // 2. العنوان (إذا تم تمريره)
                if (title != null) ...[
                  Text(
                    title,
                    style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 20),
                ],
                // 3. المحتوى المتغير (الذي سيختلف من شاشة لأخرى)
                child,
                const SizedBox(height: 20), // مساحة سفلية للأمان
              ],
            ),
          ),
        );
      },
    );
  }
}