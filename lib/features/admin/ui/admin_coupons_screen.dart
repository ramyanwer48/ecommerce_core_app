import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../logic/admin_coupons_cubit.dart';

class AdminCouponsScreen extends StatelessWidget {
  const AdminCouponsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    // استدعاء الكوبونات فور فتح الشاشة
    context.read<AdminCouponsCubit>().fetchCoupons();

    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        backgroundColor: const Color(0xFFF5F7FA),
        appBar: AppBar(
          title: const Text('إدارة كوبونات الخصم', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.white)),
          centerTitle: true,
          backgroundColor: const Color(0xFF000826),
          iconTheme: const IconThemeData(color: Colors.white),
        ),
        floatingActionButton: FloatingActionButton.extended(
          onPressed: () => _showAddCouponBottomSheet(context),
          backgroundColor: const Color(0xFF000826),
          icon: const Icon(Icons.add, color: Colors.white),
          label: const Text('إضافة كوبون جديد', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        ),
        body: BlocConsumer<AdminCouponsCubit, AdminCouponsState>(
          listener: (context, state) {
            if (state is AdminCouponsActionSuccess) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text(state.message), backgroundColor: Colors.green),
              );
            } else if (state is AdminCouponsError) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text(state.error), backgroundColor: Colors.red),
              );
            }
          },
          builder: (context, state) {
            if (state is AdminCouponsLoading) {
              return const Center(child: CircularProgressIndicator(color: Color(0xFF000826)));
            }

            if (state is AdminCouponsLoaded) {
              final coupons = state.coupons;
              if (coupons.isEmpty) {
                return const Center(
                  child: Text(
                    'لا توجد كوبونات مضافة حتى الآن 🎟️',
                    style: TextStyle(fontSize: 16, color: Colors.grey, fontWeight: FontWeight.bold),
                  ),
                );
              }

              return ListView.builder(
                padding: const EdgeInsets.all(16),
                itemCount: coupons.length,
                itemBuilder: (context, index) {
                  final coupon = coupons[index];
                  return Card(
                    elevation: 3,
                    margin: const EdgeInsets.only(bottom: 12),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                    child: ListTile(
                      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                      leading: CircleAvatar(
                        backgroundColor: coupon.isActive ? Colors.green.withValues(alpha: 0.1) : Colors.grey.withValues(alpha: 0.1),
                        child: Icon(
                          Icons.local_offer_rounded,
                          color: coupon.isActive ? Colors.green : Colors.grey,
                        ),
                      ),
                      title: Text(
                        coupon.code,
                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Color(0xFF000826)),
                      ),
                      subtitle: Text(
                        'نسبة الخصم: ${coupon.discountPercentage}%',
                        style: const TextStyle(color: Colors.black54, fontWeight: FontWeight.w500),
                      ),
                      trailing: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          // زر التفعيل / التعطيل
                          Switch(
                            value: coupon.isActive,
                            activeColor: Colors.green,
                            onChanged: (val) {
                              context.read<AdminCouponsCubit>().toggleStatus(coupon.id, coupon.isActive);
                            },
                          ),
                          // زر الحذف
                          IconButton(
                            icon: const Icon(Icons.delete_outline, color: Colors.red),
                            onPressed: () => _showDeleteConfirmation(context, coupon.id),
                          ),
                        ],
                      ),
                    ),
                  );
                },
              );
            }
            return const SizedBox.shrink();
          },
        ),
      ),
    );
  }

  // نافذة سفلية (Bottom Sheet) لإضافة كوبون جديد
  void _showAddCouponBottomSheet(BuildContext context) {
    final codeController = TextEditingController();
    final discountController = TextEditingController();
    final formKey = GlobalKey<FormState>();

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (sheetContext) {
        return Padding(
          padding: EdgeInsets.only(
            bottom: MediaQuery.of(sheetContext).viewInsets.bottom + 20,
            top: 20,
            left: 20,
            right: 20,
          ),
          child: Directionality(
            textDirection: TextDirection.rtl,
            child: Form(
              key: formKey,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Center(
                    child: Text('إضافة كوبون خصم جديد', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                  ),
                  const SizedBox(height: 20),
                  TextFormField(
                    controller: codeController,
                    decoration: const InputDecoration(
                      labelText: 'كود الكوبون (مثال: RAMY20)',
                      border: OutlineInputBorder(),
                    ),
                    validator: (val) => val == null || val.isEmpty ? 'يرجى إدخال كود الكوبون' : null,
                  ),
                  const SizedBox(height: 16),
                  TextFormField(
                    controller: discountController,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(
                      labelText: 'نسبة الخصم % (مثال: 15)',
                      border: OutlineInputBorder(),
                    ),
                    validator: (val) {
                      if (val == null || val.isEmpty) return 'يرجى إدخال نسبة الخصم';
                      if (double.tryParse(val) == null) return 'يرجى إدخال رقم صحيح';
                      return null;
                    },
                  ),
                  const SizedBox(height: 24),
                  SizedBox(
                    width: double.infinity,
                    height: 50,
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF000826),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                      ),
                      onPressed: () {
                        if (formKey.currentState!.validate()) {
                          final code = codeController.text.trim();
                          final discount = double.parse(discountController.text);

                          // إرسال البيانات للكوبيت
                          context.read<AdminCouponsCubit>().addCoupon(code, discount);
                          Navigator.pop(sheetContext);
                        }
                      },
                      child: const Text('حفظ وإضافة الكوبون', style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)),
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  // نافذة تأكيد الحذف
  void _showDeleteConfirmation(BuildContext context, String couponId) {
    showDialog(
      context: context,
      builder: (dialogContext) => Directionality(
        textDirection: TextDirection.rtl,
        child: AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: const Text('تأكيد الحذف', style: TextStyle(fontWeight: FontWeight.bold)),
          content: const Text('هل أنت متأكد من رغبتك في حذف هذا الكوبون نهائياً؟'),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: const Text('تراجع', style: TextStyle(color: Colors.grey)),
            ),
            ElevatedButton(
              onPressed: () {
                Navigator.pop(dialogContext);
                context.read<AdminCouponsCubit>().deleteCoupon(couponId);
              },
              style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
              child: const Text('حذف', style: TextStyle(color: Colors.white)),
            ),
          ],
        ),
      ),
    );
  }
}