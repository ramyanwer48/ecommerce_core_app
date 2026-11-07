import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../logic/admin_returns_cubit.dart';
import '../logic/admin_returns_state.dart';
import '../data/repos/admin_returns_repo.dart';
import 'returns_log_screen.dart'; // (تأكد أن المسار مطابق لمكان وجود الملف عندك)
class ManageReturnsScreen extends StatelessWidget {
  const ManageReturnsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (context) {
        AdminReturnsCubit cubit = AdminReturnsCubit(AdminReturnsRepo());
        cubit.fetchPendingReturns();
        return cubit;
      },
      child: const ManageReturnsView(),
    );
  }
}

class ManageReturnsView extends StatelessWidget {
  const ManageReturnsView({super.key});

  final Color primaryNavy = const Color(0xFF0D1B2A);
  final Color brandOrange = const Color(0xFFFF9F0A);

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        backgroundColor: const Color(0xFFF5F7FA),
        appBar: AppBar(
          title: const Text('إدارة المرتجعات', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.white, fontFamily: 'Cairo', fontSize: 18)),
          centerTitle: true,
          backgroundColor: primaryNavy,
          elevation: 0,
          automaticallyImplyLeading: false,
          actions: [
            // 🚀 زرار أرشيف المرتجعات الأرشيفي مع نص واضح ليكون مفهوم للجميع
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 8),
              child: TextButton.icon(
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (context) => const ReturnsLogScreen()),
                  );
                },
                style: TextButton.styleFrom(
                  backgroundColor: Colors.orange.withOpacity(0.15),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 0),
                ),
                icon: const Icon(Icons.archive_rounded, color: Colors.orangeAccent, size: 20),
                label: const Text(
                  'الأرشيف',
                  style: TextStyle(
                    color: Colors.orangeAccent,
                    fontWeight: FontWeight.bold,
                    fontFamily: 'Cairo',
                    fontSize: 13,
                  ),
                ),
              ),
            ),
            const SizedBox(width: 4),
            Directionality(
              textDirection: TextDirection.ltr,
              child: IconButton(
                icon: const Icon(Icons.arrow_back_ios_new, color: Colors.white, size: 22),
                onPressed: () => Navigator.pop(context),
              ),
            ),
            const SizedBox(width: 8),
          ],
        ),
        body: BlocConsumer<AdminReturnsCubit, AdminReturnsState>(
          listener: (context, state) {
            if (state is AdminReturnsActionLoading) {
              showDialog(
                context: context,
                barrierDismissible: false,
                builder: (ctx) => Center(child: CircularProgressIndicator(color: brandOrange)),
              );
            } else if (state is AdminReturnsActionSuccess) {
              // 🚀 التأكد الجذري من إغلاق أي نوافذ مفتوحة (اللودينج) قبل إظهار رسالة النجاح
              Navigator.of(context, rootNavigator: true).pop();
              _showSuccessModal(context, state.message);
            } else if (state is AdminReturnsError) {
              // 🚀 التأكد الجذري من إغلاق أي نوافذ مفتوحة (اللودينج) قبل إظهار رسالة الخطأ
              Navigator.of(context, rootNavigator: true).pop();
              _showErrorModal(context, state.error);
            }
          },
          buildWhen: (previous, current) => current is AdminReturnsLoading || current is AdminReturnsLoaded,
          builder: (context, state) {
            if (state is AdminReturnsLoading) {
              return Center(child: CircularProgressIndicator(color: brandOrange));
            }

            if (state is AdminReturnsLoaded) {
              final returns = state.pendingReturns;

              if (returns.isEmpty) {
                return Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.assignment_turned_in_rounded, size: 80, color: Colors.grey.shade300),
                      const SizedBox(height: 16),
                      Text('لا توجد طلبات مرتجعات معلقة', style: TextStyle(fontSize: 18, color: Colors.grey.shade600, fontFamily: 'Cairo', fontWeight: FontWeight.bold)),
                    ],
                  ),
                );
              }

              return ListView.builder(
                physics: const BouncingScrollPhysics(),
                padding: const EdgeInsets.all(16),
                itemCount: returns.length,
                itemBuilder: (context, index) {
                  Map returnData = returns[index] as Map;
                  return _buildReturnCard(context, returnData);
                },
              );
            }

            return const SizedBox.shrink();
          },
        ),
      ),
    );
  }

  Widget _buildReturnCard(BuildContext context, Map returnData) {
    final String returnId = returnData['id']?.toString() ?? '';
    final String orderId = returnData['orderId']?.toString() ?? '';
    final String orderNumber = returnData['orderNumber']?.toString() ?? 'غير متوفر';
    final double totalRefund = (returnData['totalRefund'] ?? 0.0).toDouble();
    final String reason = returnData['reason']?.toString() ?? 'لم يتم تحديد سبب';

    String formattedDate = '';
    if (returnData['requestDate'] != null) {
      DateTime date = (returnData['requestDate'] as Timestamp).toDate();
      formattedDate = '\u200E${date.day.toString().padLeft(2, '0')}/${date.month.toString().padLeft(2, '0')}/${date.year}';
    }

    final List items = (returnData['items'] ?? []) as List;

    // 🚀 تصحيح الخطأ المطبعي في حساب عدد المنتجات الإضافية
    String productsSummary = items.isNotEmpty
        ? '${(items.first as Map)['name'] ?? 'صنف'} ${items.length > 1 ? '+ ${items.length - 1} منتج آخر' : ''}'
        : 'منتجات غير محددة';

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: brandOrange, width: 1.2),
        boxShadow: [
          BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 10, offset: const Offset(0, 4)),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(color: Colors.orange.shade50, borderRadius: BorderRadius.circular(8)),
                  child: Text('طلب مرتجع', style: TextStyle(color: Colors.orange.shade800, fontWeight: FontWeight.bold, fontSize: 12, fontFamily: 'Cairo')),
                ),
                Text(
                  formattedDate,
                  style: const TextStyle(color: Colors.black54, fontSize: 13, fontFamily: 'Cairo', fontWeight: FontWeight.bold),
                  textDirection: TextDirection.ltr,
                ),
              ],
            ),
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 12),
              child: Divider(height: 1, thickness: 1, color: Color(0xFFEEEEEE)),
            ),

            _buildInfoRow('رقم الطلب الأصلي:', orderNumber, Icons.receipt_long_rounded),
            const SizedBox(height: 12),
            _buildInfoRow('المنتجات المرتجعة:', productsSummary, Icons.shopping_bag_outlined),
            const SizedBox(height: 12),
            _buildInfoRow('سبب الإرجاع:', reason, Icons.help_outline_rounded, isMultiLine: true),

            const Padding(
              padding: EdgeInsets.symmetric(vertical: 12),
              child: Divider(height: 1, thickness: 1, color: Color(0xFFEEEEEE)),
            ),

            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text('المبلغ المسترد:', style: TextStyle(fontFamily: 'Cairo', fontWeight: FontWeight.bold, fontSize: 14, color: Colors.black87)),
                Text('${totalRefund.toStringAsFixed(2)} ج.م', style: TextStyle(fontFamily: 'Cairo', fontWeight: FontWeight.bold, fontSize: 18, color: Colors.red.shade700)),
              ],
            ),

            const SizedBox(height: 20),

            Row(
              children: [
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: () {
                      HapticFeedback.lightImpact();
                      _showActionConfirmation(
                        context: context,
                        title: 'اعتماد المرتجع',
                        message: 'هل أنت متأكد من الموافقة؟ سيتم خصم المبلغ من الخزينة وإرجاع المنتجات للمخزن.',
                        isApprove: true,
                        onConfirm: () => context.read<AdminReturnsCubit>().approveRequest(returnId, returnData),
                      );
                    },
                    icon: const Icon(Icons.check_circle_outline, color: Colors.white, size: 20),
                    label: const Text('اعتماد وخصم', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontFamily: 'Cairo')),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.green.shade600,
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      elevation: 0,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: () {
                      HapticFeedback.lightImpact();
                      _showActionConfirmation(
                        context: context,
                        title: 'رفض المرتجع',
                        message: 'هل أنت متأكد من رفض هذا الطلب؟ لن يتم استرداد أي مبالغ.',
                        isApprove: false,
                        onConfirm: () => context.read<AdminReturnsCubit>().rejectRequest(returnId, orderId),
                      );
                    },
                    icon: const Icon(Icons.cancel_outlined, color: Colors.redAccent, size: 20),
                    label: const Text('رفض الطلب', style: TextStyle(color: Colors.redAccent, fontWeight: FontWeight.bold, fontFamily: 'Cairo')),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.red.shade50,
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      elevation: 0,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10), side: BorderSide(color: Colors.red.shade200)),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildInfoRow(String title, String value, IconData icon, {bool isMultiLine = false}) {
    return Row(
      crossAxisAlignment: isMultiLine ? CrossAxisAlignment.start : CrossAxisAlignment.center,
      children: [
        Icon(icon, size: 18, color: primaryNavy),
        const SizedBox(width: 8),
        Text(title, style: const TextStyle(fontSize: 13, color: Colors.black54, fontWeight: FontWeight.bold, fontFamily: 'Cairo')),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            value,
            style: const TextStyle(fontSize: 14, color: Colors.black87, fontFamily: 'Cairo', fontWeight: FontWeight.bold),
            maxLines: isMultiLine ? 3 : 1,
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ],
    );
  }

  void _showActionConfirmation({required BuildContext context, required String title, required String message, required bool isApprove, required VoidCallback onConfirm}) {
    showDialog(
      context: context,
      builder: (dialogContext) => Directionality(
        textDirection: TextDirection.rtl,
        child: AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(color: (isApprove ? Colors.green : Colors.red).withOpacity(0.1), shape: BoxShape.circle),
                child: Icon(isApprove ? Icons.check_circle : Icons.warning_amber_rounded, color: isApprove ? Colors.green : Colors.red),
              ),
              const SizedBox(width: 12),
              Text(title, style: const TextStyle(fontWeight: FontWeight.bold, fontFamily: 'Cairo', fontSize: 18)),
            ],
          ),
          content: Text(message, style: const TextStyle(fontFamily: 'Cairo', fontSize: 14, height: 1.5)),
          actionsPadding: const EdgeInsets.only(bottom: 16, left: 16, right: 16),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: const Text('تراجع', style: TextStyle(color: Colors.grey, fontFamily: 'Cairo', fontWeight: FontWeight.bold)),
            ),
            ElevatedButton(
              onPressed: () {
                HapticFeedback.heavyImpact();
                Navigator.pop(dialogContext);
                onConfirm();
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: isApprove ? Colors.green.shade600 : Colors.redAccent,
                elevation: 0,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
              ),
              child: Text(isApprove ? 'تأكيد الاعتماد' : 'تأكيد الرفض', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontFamily: 'Cairo')),
            ),
          ],
        ),
      ),
    );
  }

  void _showSuccessModal(BuildContext context, String message) {
    showDialog(
      context: context,
      builder: (successContext) => Directionality(
        textDirection: TextDirection.rtl,
        child: Dialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          child: Padding(
            padding: const EdgeInsets.all(24.0),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(color: Colors.green.withOpacity(0.1), shape: BoxShape.circle),
                  child: const Icon(Icons.check_circle_rounded, color: Colors.green, size: 48),
                ),
                const SizedBox(height: 16),
                const Text('تمت العملية بنجاح', style: TextStyle(fontWeight: FontWeight.bold, fontFamily: 'Cairo', fontSize: 20)),
                const SizedBox(height: 8),
                Text(message, textAlign: TextAlign.center, style: const TextStyle(fontFamily: 'Cairo', fontSize: 14, color: Colors.black87, height: 1.5)),
                const SizedBox(height: 24),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: () => Navigator.pop(successContext),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: primaryNavy,
                      elevation: 0,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      padding: const EdgeInsets.symmetric(vertical: 12),
                    ),
                    child: const Text('حسناً', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontFamily: 'Cairo', fontSize: 16)),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _showErrorModal(BuildContext context, String error) {
    showDialog(
      context: context,
      builder: (errorContext) => Directionality(
        textDirection: TextDirection.rtl,
        child: AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: const Row(
            children: [
              Icon(Icons.error_outline, color: Colors.redAccent),
              SizedBox(width: 8),
              Text('تنبيه', style: TextStyle(fontFamily: 'Cairo', fontWeight: FontWeight.bold, fontSize: 18)),
            ],
          ),
          content: Text(error, style: const TextStyle(fontFamily: 'Cairo', height: 1.5)),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(errorContext),
              child: Text('حسناً', style: TextStyle(color: primaryNavy, fontWeight: FontWeight.bold, fontFamily: 'Cairo')),
            ),
          ],
        ),
      ),
    );
  }
}