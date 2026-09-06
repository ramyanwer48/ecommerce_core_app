import 'package:flutter/material.dart';
import '../../../core/theming/colors.dart';
import '../../../core/theming/styles.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: ColorsManager.mainDarkBlue,
      appBar: AppBar(
        backgroundColor: ColorsManager.mainDarkBlue,
        elevation: 0,
        title: const Text(
          'RAMY STORE',
          style: TextStyle(
            fontSize: 24,
            fontWeight: FontWeight.bold,
            color: ColorsManager.white,
            letterSpacing: 1.5,
          ),
        ),
        centerTitle: true,
        actions: [
          IconButton(
            icon: const Icon(Icons.shopping_cart_outlined, color: ColorsManager.lightBlue),
            onPressed: () {
              // سنبرمج سلة المشتريات لاحقاً
            },
          ),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // --- قسم العروض أو الترحيب ---
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [Color(0xFF007BFF), Color(0xFF00D4FF)], // تدرج التركواز
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(16),
              ),
              child: const Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('أحدث قطع الهاردوير', style: TextStyles.font24WhiteBold),
                  SizedBox(height: 8),
                  Text('خصومات تصل إلى 20% على كروت الشاشة', style: TextStyles.font14LightGrayRegular),
                ],
              ),
            ),
            const SizedBox(height: 24),

            // --- عنوان قسم المنتجات ---
            const Text('المنتجات المتاحة', style: TextStyles.font18WhiteMedium),
            const SizedBox(height: 16),

            // --- شبكة عرض المنتجات (مؤقتاً سنضع منتجات وهمية حتى نربطها بـ Firebase) ---
            Expanded(
              child: GridView.builder(
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 2, // عدد الأعمدة
                  mainAxisSpacing: 16,
                  crossAxisSpacing: 16,
                  childAspectRatio: 0.75, // نسبة العرض للطول للكارت
                ),
                itemCount: 4, // عدد المنتجات الوهمية للتجربة
                itemBuilder: (context, index) {
                  return _buildProductCard();
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  // --- دالة لبناء كارت المنتج ---
  Widget _buildProductCard() {
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFF0A122E), // كحلي أفتح قليلاً من الخلفية
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: ColorsManager.darkGray.withOpacity(0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // صورة المنتج (مؤقتة)
          Expanded(
            child: Container(
              decoration: const BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
              ),
              child: const Center(
                child: Icon(Icons.computer, size: 50, color: ColorsManager.mainDarkBlue),
              ),
            ),
          ),
          // تفاصيل المنتج
          Padding(
            padding: const EdgeInsets.all(12.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'ASUS ROG Laptop',
                  style: TextStyles.font18WhiteMedium,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 4),
                const Text(
                  '55,000 EGP',
                  style: TextStyles.font20NeonBlueBold,
                ),
                const SizedBox(height: 8),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: ColorsManager.neonBlue,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                    onPressed: () {},
                    child: const Text('أضف للسلة', style: TextStyle(color: Colors.white)),
                  ),
                )
              ],
            ),
          )
        ],
      ),
    );
  }
}