import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../data/repos/address_repo.dart';
import '../logic/address_cubit.dart';
import 'add_address_bottom_sheet.dart';

class AddressesScreen extends StatelessWidget {
  final bool isPickerMode;

  const AddressesScreen({super.key, this.isPickerMode = false});

  @override
  Widget build(BuildContext context) {
    final Color primaryNavy = const Color(0xFF0D1B2A);
    final Color brandOrange = Colors.orange.shade600;

    void showCustomSnackBar(BuildContext context, String message, {bool isError = false}) {
      ScaffoldMessenger.of(context).clearSnackBars();
      ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                Icon(isError ? Icons.error_outline : Icons.check_circle_outline, color: Colors.white),
                const SizedBox(width: 12),
                Expanded(child: Text(message, style: const TextStyle(fontFamily: 'Cairo', fontWeight: FontWeight.bold, fontSize: 14))),
              ],
            ),
            backgroundColor: isError ? Colors.red.shade800 : Colors.green.shade700,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            margin: const EdgeInsets.only(bottom: 20, left: 20, right: 20),
            duration: const Duration(seconds: 3),
          )
      );
    }

    return BlocProvider(
      create: (context) => AddressCubit(AddressRepo())..fetchAddresses(),
      child: Builder(
        builder: (context) {
          return Directionality(
            textDirection: TextDirection.rtl,
            child: Scaffold(
              backgroundColor: const Color(0xFFF5F7FA),
              appBar: AppBar(
                automaticallyImplyLeading: false, // 👈 لغينا السهم اللي بيظهر يمين
                title: Text(
                  isPickerMode ? 'اختر عنوان التوصيل' : 'عناوين الاستلام',
                  style: const TextStyle(fontFamily: 'Cairo', fontWeight: FontWeight.bold, fontSize: 18, color: Colors.white),
                ),
                centerTitle: true,
                backgroundColor: primaryNavy,
                foregroundColor: Colors.white,
                elevation: 0,
                // 🚀 نقلنا السهم ناحية الشمال عن طريق وضعه في الـ actions
                actions: [
                  Directionality(
                    textDirection: TextDirection.ltr, // عشان السهم أبو شرطة يبص في الاتجاه العادي
                    child: IconButton(
                      icon: const Icon(Icons.arrow_back, color: Colors.white), // السهم أبو شرطة
                      onPressed: () {
                        HapticFeedback.lightImpact();
                        Navigator.pop(context);
                      },
                    ),
                  ),
                  const SizedBox(width: 8),
                ],
              ),
              body: Column(
                children: [
                  Expanded(
                    child: BlocConsumer<AddressCubit, AddressState>(
                      listener: (context, state) {
                        if (state is AddressActionSuccess) {
                          showCustomSnackBar(context, state.message);
                        } else if (state is AddressError) {
                          showCustomSnackBar(context, state.error, isError: true);
                        }
                      },
                      builder: (context, state) {
                        if (state is AddressLoading) {
                          return Center(child: CircularProgressIndicator(color: brandOrange));
                        } else if (state is AddressLoaded) {
                          if (state.addresses.isEmpty) {
                            return Center(
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(Icons.location_off_rounded, size: 80, color: Colors.grey.shade300),
                                  const SizedBox(height: 16),
                                  Text(
                                    'لا توجد عناوين محفوظة حالياً',
                                    style: TextStyle(fontFamily: 'Cairo', fontSize: 16, color: Colors.grey.shade600, fontWeight: FontWeight.bold),
                                  ),
                                  const SizedBox(height: 8),
                                  Text(
                                    'قم بإضافة عنوانك الأول لتسهيل عملية الطلب',
                                    style: TextStyle(fontFamily: 'Cairo', fontSize: 13, color: Colors.grey.shade500),
                                  ),
                                ],
                              ),
                            );
                          }
                          return ListView.builder(
                            itemCount: state.addresses.length,
                            padding: const EdgeInsets.all(16),
                            itemBuilder: (context, index) {
                              final address = state.addresses[index];
                              final bool isDefault = address.isDefault;

                              return Card(
                                margin: const EdgeInsets.only(bottom: 16),
                                elevation: isDefault ? 2 : 0,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(16),
                                  side: BorderSide(color: isDefault ? brandOrange.withOpacity(0.8) : Colors.grey.shade300, width: isDefault ? 2 : 1),
                                ),
                                child: InkWell(
                                  onTap: isPickerMode
                                      ? () {
                                    HapticFeedback.selectionClick();
                                    Navigator.pop(context, address);
                                  }
                                      : null,
                                  borderRadius: BorderRadius.circular(16),
                                  child: Container(
                                    padding: const EdgeInsets.all(16),
                                    decoration: BoxDecoration(
                                      color: isDefault ? brandOrange.withOpacity(0.03) : Colors.white,
                                      borderRadius: BorderRadius.circular(16),
                                    ),
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Row(
                                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                          children: [
                                            Row(
                                              children: [
                                                Container(
                                                  padding: const EdgeInsets.all(6),
                                                  decoration: BoxDecoration(color: primaryNavy.withOpacity(0.05), shape: BoxShape.circle),
                                                  child: Icon(Icons.bookmark, color: primaryNavy, size: 16),
                                                ),
                                                const SizedBox(width: 8),
                                                Text(address.title, style: const TextStyle(fontFamily: 'Cairo', fontWeight: FontWeight.bold, fontSize: 15)),
                                              ],
                                            ),
                                            if (isDefault)
                                              Container(
                                                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                                decoration: BoxDecoration(color: brandOrange.withOpacity(0.1), borderRadius: BorderRadius.circular(8)),
                                                child: Row(
                                                  children: [
                                                    Icon(Icons.check_circle, color: brandOrange, size: 14),
                                                    const SizedBox(width: 4),
                                                    Text('الافتراضي', style: TextStyle(color: brandOrange, fontSize: 11, fontWeight: FontWeight.bold, fontFamily: 'Cairo')),
                                                  ],
                                                ),
                                              )
                                            else
                                              InkWell(
                                                onTap: () {
                                                  HapticFeedback.lightImpact();
                                                  context.read<AddressCubit>().setDefaultAddress(address.id);
                                                },
                                                child: Text('تعيين كافتراضي', style: TextStyle(fontFamily: 'Cairo', color: Colors.blue.shade700, fontSize: 12, fontWeight: FontWeight.bold)),
                                              )
                                          ],
                                        ),
                                        const Padding(padding: EdgeInsets.symmetric(vertical: 10), child: Divider(height: 1)),

                                        _buildInfoRow(Icons.person_outline, address.fullName, primaryNavy),
                                        const SizedBox(height: 8),
                                        _buildInfoRow(Icons.phone_android_rounded, address.phone, primaryNavy),
                                        const SizedBox(height: 8),
                                        _buildInfoRow(Icons.location_on_outlined, '${address.city} - ${address.streetAddress}', primaryNavy),

                                        const SizedBox(height: 12),

                                        Align(
                                          alignment: Alignment.centerLeft,
                                          child: InkWell(
                                            onTap: () {
                                              HapticFeedback.heavyImpact();
                                              _showDeleteDialog(context, context.read<AddressCubit>(), address.id);
                                            },
                                            borderRadius: BorderRadius.circular(8),
                                            child: Container(
                                              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                                              decoration: BoxDecoration(color: Colors.red.shade50, borderRadius: BorderRadius.circular(8)),
                                              child: Row(
                                                mainAxisSize: MainAxisSize.min,
                                                children: [
                                                  Icon(Icons.delete_outline, color: Colors.red.shade700, size: 16),
                                                  const SizedBox(width: 4),
                                                  Text('حذف', style: TextStyle(fontFamily: 'Cairo', fontSize: 11, fontWeight: FontWeight.bold, color: Colors.red.shade700)),
                                                ],
                                              ),
                                            ),
                                          ),
                                        )
                                      ],
                                    ),
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

                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 10, offset: const Offset(0, -5))],
                    ),
                    child: SafeArea(
                      child: ElevatedButton.icon(
                        onPressed: () {
                          HapticFeedback.selectionClick();
                          final cubit = context.read<AddressCubit>();
                          showModalBottomSheet(
                            context: context,
                            isScrollControlled: true,
                            backgroundColor: Colors.transparent,
                            builder: (_) => BlocProvider.value(
                              value: cubit,
                              child: const AddAddressBottomSheet(),
                            ),
                          );
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: primaryNavy,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          elevation: 0,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                          minimumSize: const Size(double.infinity, 50),
                        ),
                        icon: const Icon(Icons.add_location_alt_outlined),
                        label: const Text('إضافة عنوان جديد', style: TextStyle(fontFamily: 'Cairo', fontSize: 16, fontWeight: FontWeight.bold)),
                      ),
                    ),
                  )
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildInfoRow(IconData icon, String text, Color iconColor) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 18, color: Colors.grey.shade500),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            text,
            style: const TextStyle(fontFamily: 'Cairo', fontSize: 13, color: Colors.black87, fontWeight: FontWeight.w600, height: 1.4),
          ),
        ),
      ],
    );
  }

  void _showDeleteDialog(BuildContext context, AddressCubit cubit, String addressId) {
    showDialog(
        context: context,
        builder: (ctx) => Directionality(
          textDirection: TextDirection.rtl,
          child: AlertDialog(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            title: const Text('تأكيد الحذف', style: TextStyle(fontFamily: 'Cairo', fontWeight: FontWeight.bold)),
            content: const Text('هل أنت متأكد من حذف هذا العنوان بشكل نهائي؟', style: TextStyle(fontFamily: 'Cairo', fontSize: 14)),
            actions: [
              TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('إلغاء', style: TextStyle(fontFamily: 'Cairo', color: Colors.grey))),
              TextButton(
                  onPressed: () {
                    cubit.deleteAddress(addressId);
                    Navigator.pop(ctx);
                  },
                  child: const Text('حذف', style: TextStyle(fontFamily: 'Cairo', color: Colors.red, fontWeight: FontWeight.bold))
              ),
            ],
          ),
        )
    );
  }
}