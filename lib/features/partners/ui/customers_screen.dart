import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'customer_ledger_screen.dart';

class CustomersScreen extends StatefulWidget {
  const CustomersScreen({super.key});

  @override
  State<CustomersScreen> createState() => _CustomersScreenState();
}

class _CustomersScreenState extends State<CustomersScreen> with SingleTickerProviderStateMixin {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final Color primaryNavy = const Color(0xFF0D1B2A);
  final Color brandOrange = Colors.orange.shade600;

  late TabController _tabController;
  late TextEditingController _searchController;
  late FocusNode _searchFocusNode;

  String _searchQuery = '';

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);

    _searchController = TextEditingController();
    _searchFocusNode = FocusNode();
    _searchController.addListener(() {
      setState(() {
        _searchQuery = _searchController.text.toLowerCase();
      });
    });
  }

  @override
  void dispose() {
    _tabController.dispose();
    _searchController.dispose();
    _searchFocusNode.dispose();
    super.dispose();
  }

  void _showAddCustomerModal(BuildContext context) {
    final TextEditingController nameController = TextEditingController();
    final TextEditingController phoneController = TextEditingController();

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (BuildContext modalContext) {
        return Directionality(
          textDirection: TextDirection.rtl,
          child: Padding(
            padding: EdgeInsets.only(bottom: MediaQuery.of(modalContext).viewInsets.bottom, left: 20, right: 20, top: 20),
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text('إضافة عميل جديد', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, fontFamily: 'Cairo', color: primaryNavy), textAlign: TextAlign.center),
                  const SizedBox(height: 20),
                  TextField(controller: nameController, decoration: InputDecoration(labelText: 'اسم العميل', border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)), prefixIcon: const Icon(Icons.person))),
                  const SizedBox(height: 15),
                  TextField(controller: phoneController, keyboardType: TextInputType.phone, decoration: InputDecoration(labelText: 'رقم الهاتف', border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)), prefixIcon: const Icon(Icons.phone))),
                  const SizedBox(height: 30),
                  ElevatedButton(
                    style: ElevatedButton.styleFrom(padding: const EdgeInsets.symmetric(vertical: 15), backgroundColor: brandOrange, foregroundColor: Colors.white, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)), elevation: 0),
                    onPressed: () async {
                      if (nameController.text.trim().isEmpty) return;
                      await _firestore.collection('customers').add({
                        'name': nameController.text.trim(),
                        'phone': phoneController.text.trim(),
                        'balance': 0.0,
                        'createdAt': FieldValue.serverTimestamp(),
                      });
                      if (context.mounted) {
                        Navigator.pop(context);
                        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('تم حفظ العميل بنجاح', style: TextStyle(fontFamily: 'Cairo'))));
                      }
                    },
                    child: const Text('حفظ البيانات', style: TextStyle(fontSize: 16, fontFamily: 'Cairo', fontWeight: FontWeight.bold)),
                  ),
                  const SizedBox(height: 20),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        backgroundColor: const Color(0xFFF5F7FA),
        appBar: AppBar(
          title: const Text('حسابات العملاء', style: TextStyle(fontFamily: 'Cairo', fontWeight: FontWeight.bold, fontSize: 18, color: Colors.white)),
          centerTitle: true,
          backgroundColor: primaryNavy,
          iconTheme: const IconThemeData(color: Colors.white),
          elevation: 0,
        ),
        body: Column(
          children: [
            Container(
              color: primaryNavy,
              padding: const EdgeInsets.only(bottom: 12, left: 16, right: 16, top: 4),
              child: TextField(
                controller: _searchController,
                focusNode: _searchFocusNode,
                style: const TextStyle(fontFamily: 'Cairo'),
                decoration: InputDecoration(
                  hintText: 'ابحث بالاسم أو رقم الهاتف...',
                  hintStyle: const TextStyle(fontFamily: 'Cairo', fontSize: 13),
                  prefixIcon: const Icon(Icons.search, color: Colors.grey),
                  suffixIcon: _searchQuery.isNotEmpty
                      ? IconButton(icon: const Icon(Icons.clear, size: 18), onPressed: () => _searchController.clear())
                      : null,
                  filled: true,
                  fillColor: Colors.white,
                  contentPadding: const EdgeInsets.symmetric(vertical: 0),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                ),
              ),
            ),

            Expanded(
              child: StreamBuilder<QuerySnapshot>(
                stream: _firestore.collection('customers').orderBy('createdAt', descending: true).snapshots(),
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) return Center(child: CircularProgressIndicator(color: brandOrange));
                  if (snapshot.hasError) return Center(child: Text('حدث خطأ: ${snapshot.error}'));

                  var allCustomers = snapshot.data?.docs ?? [];

                  double totalDebt = 0;
                  for (var doc in allCustomers) {
                    var data = doc.data() as Map<String, dynamic>;
                    double bal = double.tryParse((data['balance'] ?? 0).toString()) ?? 0;
                    if (bal > 0) totalDebt += bal;
                  }

                  var searchFiltered = allCustomers.where((doc) {
                    var data = doc.data() as Map<String, dynamic>;
                    String name = (data['name'] ?? '').toString().toLowerCase();
                    String phone = (data['phone'] ?? '').toString().toLowerCase();
                    return name.contains(_searchQuery) || phone.contains(_searchQuery);
                  }).toList();

                  var debtorsList = searchFiltered.where((doc) {
                    double bal = double.tryParse(((doc.data() as Map)['balance'] ?? 0).toString()) ?? 0;
                    return bal > 0;
                  }).toList();
                  debtorsList.sort((a, b) => (double.tryParse(((b.data() as Map)['balance'] ?? 0).toString()) ?? 0).compareTo(double.tryParse(((a.data() as Map)['balance'] ?? 0).toString()) ?? 0));

                  var clearedList = searchFiltered.where((doc) {
                    double bal = double.tryParse(((doc.data() as Map)['balance'] ?? 0).toString()) ?? 0;
                    return bal <= 0;
                  }).toList();

                  return Column(
                    children: [
                      Container(
                        color: primaryNavy,
                        padding: const EdgeInsets.only(bottom: 20, left: 16, right: 16),
                        child: Container(
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: Colors.white.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(color: Colors.white.withOpacity(0.2)),
                          ),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              const Text('إجمالي الديون بالخارج', style: TextStyle(fontFamily: 'Cairo', color: Colors.white70, fontSize: 13, fontWeight: FontWeight.bold)),
                              Text('${totalDebt.toStringAsFixed(2)} ج.م', style: TextStyle(fontFamily: 'Cairo', fontWeight: FontWeight.bold, fontSize: 18, color: brandOrange)),
                            ],
                          ),
                        ),
                      ),

                      // 🚀 التبويبات بالمسميات الجديدة والـ FittedBox لمنع قص الحروف
                      Container(
                        color: Colors.white,
                        child: TabBar(
                          controller: _tabController,
                          labelColor: brandOrange,
                          unselectedLabelColor: Colors.grey.shade600,
                          indicatorColor: brandOrange,
                          labelPadding: const EdgeInsets.symmetric(horizontal: 2), // تقليل المسافة الجانبية
                          tabs: [
                            Tab(
                              child: FittedBox(
                                fit: BoxFit.scaleDown,
                                child: Text('الكل (${searchFiltered.length})', style: const TextStyle(fontFamily: 'Cairo', fontWeight: FontWeight.bold, fontSize: 13)),
                              ),
                            ),
                            Tab(
                              child: FittedBox(
                                fit: BoxFit.scaleDown,
                                child: Text('رصيد صفري (${clearedList.length})', style: const TextStyle(fontFamily: 'Cairo', fontWeight: FontWeight.bold, fontSize: 13)),
                              ),
                            ),
                            Tab(
                              child: FittedBox(
                                fit: BoxFit.scaleDown,
                                child: Text('أرصدة مستحقة (${debtorsList.length})', style: const TextStyle(fontFamily: 'Cairo', fontWeight: FontWeight.bold, fontSize: 13)),
                              ),
                            ),
                          ],
                        ),
                      ),

                      Expanded(
                        child: TabBarView(
                          controller: _tabController,
                          children: [
                            _buildCustomersList(searchFiltered, 'لا توجد نتائج'),
                            _buildCustomersList(clearedList, 'لا يوجد عملاء بأرصدة صفرية'),
                            _buildCustomersList(debtorsList, 'لا يوجد عملاء عليهم مستحقات'),
                          ],
                        ),
                      ),
                    ],
                  );
                },
              ),
            ),
          ],
        ),
        floatingActionButton: FloatingActionButton.extended(
          onPressed: () => _showAddCustomerModal(context),
          backgroundColor: brandOrange,
          icon: const Icon(Icons.person_add, color: Colors.white),
          label: const Text('إضافة عميل', style: TextStyle(fontFamily: 'Cairo', fontWeight: FontWeight.bold, color: Colors.white)),
        ),
      ),
    );
  }

  Widget _buildCustomersList(List<QueryDocumentSnapshot> list, String emptyMessage) {
    if (list.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.folder_off_outlined, size: 60, color: Colors.grey.shade300),
            const SizedBox(height: 12),
            Text(emptyMessage, style: TextStyle(fontFamily: 'Cairo', fontSize: 16, color: Colors.grey.shade600, fontWeight: FontWeight.bold)),
          ],
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: list.length,
      itemBuilder: (context, index) {
        final doc = list[index];
        final data = doc.data() as Map<String, dynamic>;
        final customerId = doc.id;
        final customerName = data['name'] ?? 'بدون اسم';
        final customerPhone = data['phone'] ?? '';
        final double balance = double.tryParse((data['balance'] ?? 0).toString()) ?? 0.0;

        bool hasDebt = balance > 0;
        Color cardBorderColor = hasDebt ? Colors.red.shade500 : Colors.green.shade500;
        Color badgeBgColor = hasDebt ? Colors.red.shade50 : Colors.green.shade50;
        Color badgeTextColor = hasDebt ? Colors.red.shade700 : Colors.green.shade700;
        String badgeText = hasDebt ? 'مستحقات' : 'صافي الحساب';
        IconData badgeIcon = hasDebt ? Icons.warning_amber_rounded : Icons.check_circle_outline;

        return Card(
          elevation: 1.5,
          margin: const EdgeInsets.only(bottom: 12),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          clipBehavior: Clip.antiAlias,
          child: InkWell(
            onTap: () {
              _searchFocusNode.unfocus();
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => CustomerLedgerScreen(
                    customerId: customerId,
                    customerName: customerName,
                    currentBalance: balance,
                  ),
                ),
              );
            },
            child: Container(
              decoration: BoxDecoration(
                border: Border(right: BorderSide(color: cardBorderColor, width: 4)),
              ),
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Row(
                  children: [
                    CircleAvatar(
                      radius: 22,
                      backgroundColor: badgeBgColor,
                      child: Icon(Icons.person, color: badgeTextColor, size: 22),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            customerName,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(fontWeight: FontWeight.bold, fontFamily: 'Cairo', fontSize: 15, color: primaryNavy),
                          ),
                          const SizedBox(height: 6),
                          Row(
                            children: [
                              Text(
                                customerPhone.isEmpty ? 'بدون هاتف' : customerPhone,
                                style: const TextStyle(fontFamily: 'Cairo', fontSize: 12, color: Colors.grey),
                              ),
                              const SizedBox(width: 8),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                decoration: BoxDecoration(color: badgeBgColor, borderRadius: BorderRadius.circular(4)),
                                child: Row(
                                  children: [
                                    Icon(badgeIcon, size: 10, color: badgeTextColor),
                                    const SizedBox(width: 4),
                                    Text(badgeText, style: TextStyle(fontFamily: 'Cairo', fontSize: 10, fontWeight: FontWeight.bold, color: badgeTextColor)),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Text(
                          'الرصيد',
                          style: TextStyle(fontFamily: 'Cairo', fontSize: 11, color: Colors.grey.shade600, fontWeight: FontWeight.bold),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          '${balance.toStringAsFixed(2)} ج',
                          style: TextStyle(fontFamily: 'Cairo', fontWeight: FontWeight.bold, color: cardBorderColor, fontSize: 15),
                        ),
                      ],
                    )
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}