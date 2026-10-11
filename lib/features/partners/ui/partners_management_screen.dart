import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:image_picker/image_picker.dart';
import '../logic/partners_profit_cubit.dart';
import '../logic/partners_profit_state.dart';

class PartnersManagementScreen extends StatefulWidget {
  const PartnersManagementScreen({super.key});

  @override
  State<PartnersManagementScreen> createState() => _PartnersManagementScreenState();
}

class _PartnersManagementScreenState extends State<PartnersManagementScreen> {
  // قائمة الشركاء
  final List<Map<String, dynamic>> _localPartners = [
    {
      'name': 'رامي',
      'capital': 100000.0,
      'isManagementActive': true,
      'managementShare': 15.0,
      'imagePath': null,
    },
    {
      'name': 'عبدالله',
      'capital': 100000.0,
      'isManagementActive': true,
      'managementShare': 15.0,
      'imagePath': null,
    }
  ];
  double _currentManagementPool = 30.0;
  double _fetchedNetOperatingProfit = 0.0;
  bool _isLoadingProfit = true;

  @override
  void initState() {
    super.initState();
    _calculateRealNetProfitFromFirebase();
  }

  // جلب الحسابات الفعلية للربح التشغيلي من Firebase
  Future<void> _calculateRealNetProfitFromFirebase() async {
    try {
      var ordersSnap = await FirebaseFirestore.instance.collection('orders').get();
      double totalSales = 0;
      for (var doc in ordersSnap.docs) {
        var data = doc.data();
        totalSales += double.tryParse((data['totalPrice'] ?? data['totalAmount'] ?? 0).toString()) ?? 0.0;
      }

      var salesInvoicesSnap = await FirebaseFirestore.instance.collection('sales_invoices').get();
      for (var doc in salesInvoicesSnap.docs) {
        var data = doc.data();
        totalSales += double.tryParse((data['totalAmount'] ?? data['totalPrice'] ?? 0).toString()) ?? 0.0;
      }

      var purchasesSnap = await FirebaseFirestore.instance.collection('purchases').get();
      double totalPurchases = 0;
      for (var doc in purchasesSnap.docs) {
        var data = doc.data();
        totalPurchases += double.tryParse((data['totalAmount'] ?? data['totalCost'] ?? 0).toString()) ?? 0.0;
      }

      var expensesSnap = await FirebaseFirestore.instance.collection('expenses').get();
      double totalExpenses = 0;
      for (var doc in expensesSnap.docs) {
        var data = doc.data();
        totalExpenses += double.tryParse((data['amount'] ?? 0).toString()) ?? 0.0;
      }

      setState(() {
        _fetchedNetOperatingProfit = totalSales - (totalPurchases + totalExpenses);
        _isLoadingProfit = false;
      });
    } catch (e) {
      setState(() {
        _isLoadingProfit = false;
      });
      debugPrint("Error calculating profit: $e");
    }
  }

  // اختيار وتغيير صورة الشريك
  Future<void> _pickPartnerImage(int index) async {
    final picker = ImagePicker();
    final pickedFile = await picker.pickImage(source: ImageSource.gallery, imageQuality: 70);
    if (pickedFile != null) {
      setState(() {
        _localPartners[index]['imagePath'] = pickedFile.path;
      });
      _showSuccessMessage('تم تحديث صورة الشريك بنجاح');
    }
  }

  // رسالة نجاح أنيقة وسريعة
  void _showSuccessMessage(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const Icon(Icons.check_circle_rounded, color: Colors.white),
            const SizedBox(width: 10),
            Text(message, style: const TextStyle(fontFamily: 'Cairo', fontWeight: FontWeight.bold, color: Colors.white)),
          ],
        ),
        backgroundColor: Colors.green.shade700,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        margin: const EdgeInsets.all(16),
        duration: const Duration(seconds: 2),
      ),
    );
  }

  // نافذة تعديل نسب الإدارة والتشغيل العامة
  void _showEditManagementPoolSheet(BuildContext context) {
    final TextEditingController poolController = TextEditingController(text: _currentManagementPool.toString());

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => Directionality(
        textDirection: TextDirection.rtl,
        child: Container(
          padding: EdgeInsets.only(bottom: MediaQuery.of(ctx).viewInsets.bottom, left: 20, right: 20, top: 20),
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text('تعديل نسب الإدارة والتشغيل', style: TextStyle(fontFamily: 'Cairo', fontWeight: FontWeight.bold, fontSize: 16, color: Color(0xFF0D1B2A))),
                  Container(
                    width: 32,
                    height: 32,
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: Colors.black, width: 1.5),
                    ),
                    child: IconButton(
                      icon: const Icon(Icons.close, color: Colors.black, size: 16),
                      onPressed: () => Navigator.pop(ctx),
                      padding: EdgeInsets.zero,
                    ),
                  ),
                ],
              ),
              const Divider(),
              const SizedBox(height: 8),
              const Text('حدد نسبة الإدارة والتشغيل الإجمالية المستقطعة من الربح التشغيلي:', style: TextStyle(fontFamily: 'Cairo', fontSize: 12, color: Colors.grey)),
              const SizedBox(height: 12),
              TextField(
                controller: poolController,
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                decoration: InputDecoration(
                  labelText: 'النسبة المئوية (%)',
                  labelStyle: const TextStyle(fontFamily: 'Cairo'),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                ),
              ),
              const SizedBox(height: 20),
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF0D1B2A),
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                ),
                onPressed: () {
                  setState(() {
                    _currentManagementPool = double.tryParse(poolController.text) ?? _currentManagementPool;
                  });
                  Navigator.pop(ctx);
                  _showSuccessMessage('تم تحديث نسبة الإدارة بنجاح');
                },
                child: const Text('حفظ التعديل', style: TextStyle(fontFamily: 'Cairo', fontWeight: FontWeight.bold, color: Colors.white)),
              ),
              const SizedBox(height: 20),
            ],
          ),
        ),
      ),
    );
  }

  // نافذة إضافة شريك جديد ورأس المال
  void _showAddPartnerDialog(BuildContext context) {
    final TextEditingController nameController = TextEditingController();
    final TextEditingController capitalController = TextEditingController();
    final TextEditingController managementShareController = TextEditingController(text: '15');
    bool isManagementActive = true;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setSheetState) => Directionality(
          textDirection: TextDirection.rtl,
          child: Container(
            padding: EdgeInsets.only(bottom: MediaQuery.of(ctx).viewInsets.bottom, left: 20, right: 20, top: 20),
            decoration: const BoxDecoration(color: Colors.white, borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text('إضافة شريك أو رأس مال جديد', style: TextStyle(fontFamily: 'Cairo', fontWeight: FontWeight.bold, fontSize: 18, color: Color(0xFF0D1B2A))),
                      Container(
                        width: 32,
                        height: 32,
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: Colors.black, width: 1.5),
                        ),
                        child: IconButton(
                          icon: const Icon(Icons.close, color: Colors.black, size: 16),
                          onPressed: () => Navigator.pop(ctx),
                          padding: EdgeInsets.zero,
                        ),
                      ),
                    ],
                  ),
                  const Divider(),
                  const SizedBox(height: 8),
                  TextField(
                    controller: nameController,
                    decoration: InputDecoration(
                      labelText: 'اسم الشريك (مثلاً: رامي، عبدالله...)',
                      labelStyle: const TextStyle(fontFamily: 'Cairo', fontSize: 13),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                    ),
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    controller: capitalController,
                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                    decoration: InputDecoration(
                      labelText: 'مبلغ رأس المال (ج.م)',
                      labelStyle: const TextStyle(fontFamily: 'Cairo', fontSize: 13),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                    ),
                  ),
                  const SizedBox(height: 16),
                  SwitchListTile(
                    title: const Text('يشارك في الإدارة والتشغيل؟', style: TextStyle(fontFamily: 'Cairo', fontSize: 13, fontWeight: FontWeight.bold)),
                    value: isManagementActive,
                    activeColor: Colors.orange.shade700,
                    onChanged: (val) => setSheetState(() => isManagementActive = val),
                  ),
                  if (isManagementActive) ...[
                    const SizedBox(height: 8),
                    TextField(
                      controller: managementShareController,
                      keyboardType: const TextInputType.numberWithOptions(decimal: true),
                      decoration: InputDecoration(
                        labelText: 'نسبة الإدارة والتشغيل الخاصة (%)',
                        labelStyle: const TextStyle(fontFamily: 'Cairo', fontSize: 13),
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                      ),
                    ),
                  ],
                  const SizedBox(height: 24),
                  ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF0D1B2A),
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                    onPressed: () {
                      if (nameController.text.isNotEmpty && capitalController.text.isNotEmpty) {
                        setState(() {
                          _localPartners.add({
                            'name': nameController.text,
                            'capital': double.tryParse(capitalController.text) ?? 0.0,
                            'isManagementActive': isManagementActive,
                            'managementShare': isManagementActive ? (double.tryParse(managementShareController.text) ?? 0.0) : 0.0,
                            'imagePath': null,
                          });
                        });
                        Navigator.pop(ctx);
                        _showSuccessMessage('تم إضافة الشريك ورأس المال بنجاح');
                      } else {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            backgroundColor: Colors.red,
                            content: const Text('يرجى إدخال الاسم ومبلغ رأس المال', style: TextStyle(fontFamily: 'Cairo', color: Colors.white)),
                          ),
                        );
                      }
                    },
                    child: const Text('حفظ وإضافة للنظام', style: TextStyle(fontFamily: 'Cairo', fontWeight: FontWeight.bold, color: Colors.white, fontSize: 15)),
                  ),
                  const SizedBox(height: 20),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    const Color primaryNavy = Color(0xFF0D1B2A);
    const Color bgColor = Color(0xFFF5F7FA);

    bool isNegativeProfit = _fetchedNetOperatingProfit < 0;

    return BlocProvider(
      create: (context) => PartnersProfitCubit()..fetchPartnersAndProfits(totalSales: 0.0, totalExpenses: 0.0),
      child: Directionality(
        textDirection: TextDirection.rtl,
        child: Scaffold(
          backgroundColor: bgColor,
          appBar: AppBar(
            backgroundColor: primaryNavy,
            centerTitle: true,
            // مسمى مختصر وواضح تماماً وبدون أي قطع وبخط مناسب ومقروء
            title: const Text(
              'إدارة الشركاء والأرباح',
              style: TextStyle(fontFamily: 'Cairo', fontSize: 16, fontWeight: FontWeight.bold, color: Colors.white),
            ),
            automaticallyImplyLeading: false,
            actions: [
              IconButton(
                icon: const Icon(Icons.arrow_forward_ios, color: Colors.white, size: 18),
                onPressed: () => Navigator.pop(context),
              ),
            ],
            leading: const SizedBox.shrink(),
            elevation: 0,
          ),
          body: _isLoadingProfit
              ? const Center(child: CircularProgressIndicator(color: primaryNavy))
              : SingleChildScrollView(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // كارت الملخص المالي
                Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: primaryNavy,
                    borderRadius: BorderRadius.circular(16),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.08),
                        blurRadius: 10,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      const Text(
                        'إجمالي الربح التشغيلي الفعلي',
                        style: TextStyle(fontFamily: 'Cairo', fontSize: 13, color: Colors.white70),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 8),
                      Text(
                        '${_fetchedNetOperatingProfit.toStringAsFixed(_fetchedNetOperatingProfit.truncateToDouble() == _fetchedNetOperatingProfit ? 0 : 2)} ج.م',
                        style: TextStyle(
                          fontFamily: 'Cairo',
                          fontSize: 32,
                          fontWeight: FontWeight.bold,
                          color: isNegativeProfit ? Colors.redAccent : Colors.orangeAccent,
                        ),
                        textAlign: TextAlign.center,
                      ),
                      const Divider(color: Colors.white24, height: 24),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            'نسبة الإدارة والتشغيل المستقطعة: $_currentManagementPool%',
                            style: const TextStyle(fontFamily: 'Cairo', fontSize: 12, color: Colors.white70),
                          ),
                          IconButton(
                            icon: const Icon(Icons.settings_outlined, color: Colors.orangeAccent, size: 22),
                            onPressed: () => _showEditManagementPoolSheet(context),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 24),

                // زر "إضافة رأس المال" بشكل فخم وبارز
                ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.orange.shade700,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    elevation: 2,
                  ),
                  onPressed: () => _showAddPartnerDialog(context),
                  icon: const Icon(Icons.add_circle_outline, size: 20, color: Colors.white),
                  label: const Text(
                    'إضافة رأس مال وشريك جديد',
                    style: TextStyle(fontFamily: 'Cairo', fontWeight: FontWeight.bold, color: Colors.white, fontSize: 15),
                  ),
                ),
                const SizedBox(height: 24),

                // عنوان قسم الشركاء في المنتصف تماماً
                const Center(
                  child: Text(
                    'قائمة الشركاء وتفاصيل الأرباح',
                    style: TextStyle(fontFamily: 'Cairo', fontSize: 17, fontWeight: FontWeight.bold, color: primaryNavy),
                  ),
                ),
                const SizedBox(height: 14),

                // عرض الشركاء بكروت متميزة
                _localPartners.isEmpty
                    ? Container(
                  padding: const EdgeInsets.all(24),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: Colors.grey.shade300),
                  ),
                  child: Column(
                    children: [
                      const Icon(Icons.handshake_outlined, size: 48, color: Colors.grey),
                      const SizedBox(height: 12),
                      const Text(
                        'لا توجد حصص رؤوس أموال مسجلة بعد',
                        style: TextStyle(fontFamily: 'Cairo', fontSize: 14, fontWeight: FontWeight.bold, color: Colors.grey),
                        textAlign: TextAlign.center,
                      ),
                    ],
                  ),
                )
                    : ListView.builder(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: _localPartners.length,
                  itemBuilder: (context, index) {
                    final partner = _localPartners[index];
                    double capital = partner['capital'];
                    bool hasManagement = partner['isManagementActive'];
                    double mgmtSharePercent = partner['managementShare'];
                    String? imagePath = partner['imagePath'];

                    double totalCapital = _localPartners.fold(0.0, (sum, p) => sum + (p['capital'] as double));
                    double netProfit = _fetchedNetOperatingProfit > 0 ? _fetchedNetOperatingProfit : 0.0;
                    double managementPoolAmount = netProfit * (_currentManagementPool / 100);
                    double remainingCapitalProfit = netProfit - managementPoolAmount;

                    double capitalShareRatio = totalCapital > 0 ? (capital / totalCapital) : 0.0;
                    double partnerCapitalProfit = remainingCapitalProfit * capitalShareRatio;
                    double partnerManagementProfit = hasManagement ? (managementPoolAmount * (mgmtSharePercent / 100)) : 0.0;
                    double partnerTotalProfit = partnerCapitalProfit + partnerManagementProfit;

                    return Container(
                      margin: const EdgeInsets.only(bottom: 16),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: Colors.orange.shade600, width: 1.8),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.orange.withOpacity(0.06),
                            blurRadius: 8,
                            offset: const Offset(0, 3),
                          ),
                        ],
                      ),
                      child: Padding(
                        padding: const EdgeInsets.all(16.0),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                GestureDetector(
                                  onTap: () => _pickPartnerImage(index),
                                  child: Stack(
                                    alignment: Alignment.bottomRight,
                                    children: [
                                      CircleAvatar(
                                        radius: 24,
                                        backgroundColor: primaryNavy,
                                        backgroundImage: imagePath != null ? FileImage(File(imagePath)) : null,
                                        child: imagePath == null ? const Icon(Icons.person, color: Colors.white, size: 22) : null,
                                      ),
                                      Container(
                                        padding: const EdgeInsets.all(2),
                                        decoration: BoxDecoration(color: Colors.orange.shade700, shape: BoxShape.circle),
                                        child: const Icon(Icons.camera_alt, size: 10, color: Colors.white),
                                      ),
                                    ],
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Text(
                                  partner['name'],
                                  style: const TextStyle(fontFamily: 'Cairo', fontWeight: FontWeight.bold, fontSize: 17, color: primaryNavy),
                                ),
                                const Spacer(),
                                IconButton(
                                  icon: const Icon(Icons.delete_outline, color: Colors.red, size: 20),
                                  onPressed: () {
                                    setState(() {
                                      _localPartners.removeAt(index);
                                    });
                                    _showSuccessMessage('تم حذف الشريك بنجاح');
                                  },
                                ),
                              ],
                            ),
                            const Divider(height: 20),
                            // رأس المال المدفوع
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                const Text('• رأس المال المدفوع:', style: TextStyle(fontFamily: 'Cairo', fontSize: 13, color: Colors.black87, fontWeight: FontWeight.w600)),
                                Text('${capital.toStringAsFixed(0)} ج.م', style: const TextStyle(fontFamily: 'Cairo', fontWeight: FontWeight.bold, fontSize: 14, color: primaryNavy)),
                              ],
                            ),
                            const SizedBox(height: 8),
                            // نسبة الإدارة والتشغيل
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text('• نسبة الإدارة والتشغيل (${hasManagement ? "$mgmtSharePercent%" : "لا يوجد"}):', style: const TextStyle(fontFamily: 'Cairo', fontSize: 13, color: Colors.black87, fontWeight: FontWeight.w600)),
                                Text('${partnerManagementProfit.toStringAsFixed(2)} ج.م', style: TextStyle(fontFamily: 'Cairo', fontWeight: FontWeight.bold, fontSize: 14, color: Colors.orange.shade800)),
                              ],
                            ),
                            const SizedBox(height: 8),
                            // نصيب أرباح رأس المال
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                const Text('• نصيب أرباح رأس المال:', style: TextStyle(fontFamily: 'Cairo', fontSize: 13, color: Colors.black87, fontWeight: FontWeight.w600)),
                                Text('${partnerCapitalProfit.toStringAsFixed(2)} ج.م', style: const TextStyle(fontFamily: 'Cairo', fontWeight: FontWeight.bold, fontSize: 14, color: Colors.blueAccent)),
                              ],
                            ),
                            const Divider(height: 20),
                            // إجمالي الربح النهائي للشريك
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                              decoration: BoxDecoration(
                                color: Colors.green.shade50,
                                borderRadius: BorderRadius.circular(10),
                                border: Border.all(color: Colors.green.shade300, width: 1.2),
                              ),
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  const Text('إجمالي ربح الشريك (نهاية الشهر):', style: TextStyle(fontFamily: 'Cairo', fontWeight: FontWeight.bold, fontSize: 14, color: Colors.green)),
                                  Text(
                                    '${partnerTotalProfit.toStringAsFixed(2)} ج.م',
                                    style: TextStyle(fontFamily: 'Cairo', fontWeight: FontWeight.bold, fontSize: 17, color: Colors.green.shade800),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}