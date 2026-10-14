import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:image_picker/image_picker.dart';
import '../logic/partners_profit_cubit.dart';
import '../logic/partners_profit_state.dart';
import '../../../core/widgets/custom_date_range_filter.dart';
import '../../../core/models/erp_models.dart';

class PartnersManagementScreen extends StatefulWidget {
  const PartnersManagementScreen({super.key});

  @override
  State<PartnersManagementScreen> createState() => _PartnersManagementScreenState();
}

class _PartnersManagementScreenState extends State<PartnersManagementScreen> {
  final PartnersProfitCubit _profitCubit = PartnersProfitCubit();

  static const String _shareholdersCollection = 'shareholders';
  static const String _ledgerEntriesCollection = 'ledger_entries';

  double _currentManagementPool = 30.0;

  double _totalSalesAmount = 0.0;
  double _totalExpensesAmount = 0.0;
  double _fetchedNetOperatingProfit = 0.0;
  double _totalStoreCapital = 0.0;

  bool _isLoadingData = true;
  bool _needsMigration = false;

  List<PartnerModel> _firebasePartners = [];
  List<LedgerEntryModel> _firebaseLedgers = [];

  final Map<String, double> _partnerDirectCapital = {};
  Map<String, dynamic> _calculatedResultsMap = {};
  final Map<String, String?> _firebaseImageUrls = {};

  DateTime? _filterStartDate;
  DateTime? _filterEndDate;

  @override
  void initState() {
    super.initState();
    final now = DateTime.now();
    _filterStartDate = DateTime(now.year, now.month, 1);
    _filterEndDate = DateTime(now.year, now.month + 1, 0);

    _fetchAllDataFromFirebase();
  }

  @override
  void dispose() {
    _profitCubit.close();
    super.dispose();
  }

  DateTime _parseSafeDate(dynamic value) {
    if (value == null) return DateTime.now();
    if (value is Timestamp) return value.toDate();
    if (value is DateTime) return value;
    if (value is String) return DateTime.tryParse(value) ?? DateTime.now();
    return DateTime.now();
  }

  double _parseSafeDouble(dynamic value) {
    if (value == null) return 0.0;
    if (value is num) return value.toDouble();
    return double.tryParse(value.toString()) ?? 0.0;
  }

  Future<void> _migrateAndCleanFirebaseStructure() async {
    setState(() => _isLoadingData = true);
    try {
      final firestore = FirebaseFirestore.instance;
      var allLedgersSnap = await firestore.collection(_ledgerEntriesCollection).get();
      Map<String, double> accountCapitalMap = {};
      for (var doc in allLedgersSnap.docs) {
        var d = doc.data();
        String accId = (d['accountId'] ?? d['partnerId'] ?? '').toString();
        double credit = _parseSafeDouble(d['credit'] ?? d['amount']);
        double debit = _parseSafeDouble(d['debit']);
        if (accId.isNotEmpty) {
          accountCapitalMap[accId] = (accountCapitalMap[accId] ?? 0.0) + (credit - debit);
        }
      }

      var oldPartnersSnap = await firestore.collection('partners').get();
      Map<String, QueryDocumentSnapshot<Map<String, dynamic>>> uniqueShareholdersByName = {};
      List<QueryDocumentSnapshot<Map<String, dynamic>>> duplicatePartnerDocs = [];

      for (var doc in oldPartnersSnap.docs) {
        var data = doc.data();
        String type = (data['type'] ?? '').toString().trim().toLowerCase();
        String name = (data['name'] ?? '').toString().trim();

        if (type == 'customer') {
          await firestore.collection('customers').doc(doc.id).set(data, SetOptions(merge: true));
          await doc.reference.delete();
        } else if (type == 'supplier') {
          await firestore.collection('suppliers').doc(doc.id).set(data, SetOptions(merge: true));
          await doc.reference.delete();
        } else if (type == 'partner' || data.containsKey('managementRatio')) {
          if (name == 'رامب' || name.isEmpty) {
            await doc.reference.delete();
            continue;
          }

          if (!uniqueShareholdersByName.containsKey(name)) {
            uniqueShareholdersByName[name] = doc;
          } else {
            var existingDoc = uniqueShareholdersByName[name]!;
            double existingCap = (accountCapitalMap[existingDoc.id] ?? 0.0) + _parseSafeDouble(existingDoc.data()['capital']);
            double currentCap = (accountCapitalMap[doc.id] ?? 0.0) + _parseSafeDouble(doc.data()['capital']);

            if (currentCap > existingCap) {
              duplicatePartnerDocs.add(existingDoc);
              uniqueShareholdersByName[name] = doc;
            } else {
              duplicatePartnerDocs.add(doc);
            }
          }
        } else {
          await doc.reference.delete();
        }
      }

      for (var entry in uniqueShareholdersByName.entries) {
        var doc = entry.value;
        var data = Map<String, dynamic>.from(doc.data());
        double cap = (accountCapitalMap[doc.id] ?? 0.0) > 0 ? accountCapitalMap[doc.id]! : _parseSafeDouble(data['capital']);

        data['type'] = 'partner';
        data['capital'] = cap;
        data['joinDate'] = data['joinDate'] ?? data['createdAt'] ?? FieldValue.serverTimestamp();

        await firestore.collection(_shareholdersCollection).doc(doc.id).set(data);
        await doc.reference.delete();
      }

      for (var dupDoc in duplicatePartnerDocs) {
        await dupDoc.reference.delete();
      }

      _showSuccessMessage('تم الترحيل بنجاح!');
      await _fetchAllDataFromFirebase();
    } catch (e) {
      setState(() => _isLoadingData = false);
      if (mounted) _showSuccessMessage('خطأ أثناء الترحيل: $e', isError: true);
    }
  }

  Future<void> _fetchAllDataFromFirebase() async {
    if (!mounted) return;
    setState(() => _isLoadingData = true);

    double totalSales = 0.0;
    double totalPurchases = 0.0;
    double totalExpenses = 0.0;
    List<PartnerModel> fetchedPartners = [];
    List<LedgerEntryModel> fetchedLedgers = [];
    _partnerDirectCapital.clear();
    double tempStoreCapital = 0.0;

    final firestore = FirebaseFirestore.instance;

    try {
      var ordersSnap = await firestore.collection('orders').get();
      for (var doc in ordersSnap.docs) {
        var data = doc.data();
        totalSales += _parseSafeDouble(data['totalPrice'] ?? data['totalAmount']);
      }
    } catch (_) {}

    try {
      var invoicesSnap = await firestore.collection('invoices').get();
      for (var doc in invoicesSnap.docs) {
        var data = doc.data();
        totalSales += _parseSafeDouble(data['totalAmount'] ?? data['totalPrice']);
      }
    } catch (_) {}

    try {
      var purchasesSnap = await firestore.collection('purchases').get();
      for (var doc in purchasesSnap.docs) {
        var data = doc.data();
        totalPurchases += _parseSafeDouble(data['totalAmount'] ?? data['totalCost']);
      }
    } catch (_) {}

    try {
      var expensesSnap = await firestore.collection('expenses').get();
      for (var doc in expensesSnap.docs) {
        var data = doc.data();
        totalExpenses += _parseSafeDouble(data['amount']);
      }
    } catch (_) {}

    bool hasUnmigratedEntities = false;
    try {
      var oldCheckSnap = await firestore.collection('partners').limit(1).get();
      hasUnmigratedEntities = oldCheckSnap.docs.isNotEmpty;
    } catch (_) {}

    try {
      var shareholdersSnap = await firestore.collection(_shareholdersCollection).get();
      if (shareholdersSnap.docs.isNotEmpty) {
        for (var doc in shareholdersSnap.docs) {
          var data = doc.data();
          PartnerModel partner = PartnerModel(
            id: doc.id,
            name: (data['name'] ?? 'شريك').toString(),
            type: 'partner',
            phone: (data['phone'] ?? '').toString(),
            managementRatio: _parseSafeDouble(data['managementRatio']),
            joinDate: _parseSafeDate(data['joinDate'] ?? data['createdAt']),
          );
          fetchedPartners.add(partner);
          _firebaseImageUrls[doc.id] = data['imageUrl']?.toString();

          double directCap = _parseSafeDouble(data['capital'] ?? data['initialCapital']);
          if (directCap > 0) {
            _partnerDirectCapital[doc.id] = directCap;
          }
        }
      } else if (hasUnmigratedEntities) {
        var oldSnap = await firestore.collection('partners').get();
        for (var doc in oldSnap.docs) {
          var data = doc.data();
          String docType = (data['type'] ?? '').toString().trim().toLowerCase();
          if (docType == 'partner' || data.containsKey('managementRatio')) {
            fetchedPartners.add(
              PartnerModel(
                id: doc.id,
                name: (data['name'] ?? 'شريك').toString(),
                type: 'partner',
                phone: (data['phone'] ?? '').toString(),
                managementRatio: _parseSafeDouble(data['managementRatio']),
                joinDate: _parseSafeDate(data['joinDate'] ?? data['createdAt']),
              ),
            );
            _firebaseImageUrls[doc.id] = data['imageUrl']?.toString();
            double directCap = _parseSafeDouble(data['capital']);
            if (directCap > 0) _partnerDirectCapital[doc.id] = directCap;
          }
        }
      }
    } catch (e) {
      debugPrint("Shareholders fetch error: $e");
    }

    try {
      var ledgersSnap = await firestore.collection(_ledgerEntriesCollection).get();
      for (var doc in ledgersSnap.docs) {
        var data = doc.data();
        String txType = (data['transactionType'] ?? data['type'] ?? '').toString();
        String accId = (data['accountId'] ?? data['partnerId'] ?? '').toString();

        if (txType == 'capital_deposit' || txType == 'profit_capitalization' || txType == 'capital_withdrawal' || txType == 'withdrawal' || accId.isNotEmpty) {
          fetchedLedgers.add(
            LedgerEntryModel(
              id: doc.id,
              accountId: accId,
              debit: _parseSafeDouble(data['debit']),
              credit: _parseSafeDouble(data['credit'] ?? data['amount']),
              referenceId: (data['referenceId'] ?? '').toString(),
              description: (data['description'] ?? '').toString(),
              timestamp: _parseSafeDate(data['timestamp'] ?? data['date'] ?? data['createdAt']),
              transactionType: txType.isEmpty ? 'capital_deposit' : txType,
            ),
          );
        }
      }
    } catch (e) {
      debugPrint("Ledger entries fetch error: $e");
    }

    for (var partner in fetchedPartners) {
      bool hasLedger = fetchedLedgers.any((l) => l.accountId == partner.id);
      if (!hasLedger) {
        double fallbackCap = _partnerDirectCapital[partner.id] ?? 0.0;
        fetchedLedgers.add(
          LedgerEntryModel(
            id: 'fallback_${partner.id}',
            accountId: partner.id,
            debit: 0.0,
            credit: fallbackCap,
            referenceId: 'initial_deposit',
            description: 'رأس مال أساسي',
            timestamp: partner.joinDate ?? DateTime(2020),
            transactionType: 'capital_deposit',
          ),
        );
      }

      double partnerCurrentCap = fetchedLedgers
          .where((l) => l.accountId == partner.id && (l.transactionType == 'capital_deposit' || l.transactionType == 'profit_capitalization' || l.transactionType == 'capital_withdrawal'))
          .fold(0.0, (sum, l) => sum + (l.credit - l.debit));

      if (partnerCurrentCap <= 0) partnerCurrentCap = _partnerDirectCapital[partner.id] ?? 0.0;
      tempStoreCapital += partnerCurrentCap;
    }

    if (mounted) {
      setState(() {
        _totalSalesAmount = totalSales;
        _totalExpensesAmount = totalPurchases + totalExpenses;
        _fetchedNetOperatingProfit = _totalSalesAmount - _totalExpensesAmount;
        _firebasePartners = fetchedPartners;
        _firebaseLedgers = fetchedLedgers;
        _totalStoreCapital = tempStoreCapital;
        _needsMigration = hasUnmigratedEntities;
        _isLoadingData = false;
      });

      _triggerCubitCalculation();
    }
  }

  void _triggerCubitCalculation() {
    if (_filterStartDate == null || _filterEndDate == null) return;

    List<PartnerModel> processedPartners = _firebasePartners.map((p) {
      return PartnerModel(
        id: p.id,
        name: p.name,
        type: p.type,
        phone: p.phone,
        managementRatio: p.managementRatio,
        joinDate: p.joinDate ?? DateTime(2020),
      );
    }).toList();

    _profitCubit.calculateProfitsForPeriod(
      startDate: _filterStartDate!,
      endDate: _filterEndDate!,
      totalSales: _totalSalesAmount,
      totalExpenses: _totalExpensesAmount,
      partners: processedPartners,
      capitalLedgers: _firebaseLedgers,
    );
  }

  Future<void> _addPartnerToFirebase(String name, double capital, double mngRatio) async {
    setState(() => _isLoadingData = true);
    try {
      final firestore = FirebaseFirestore.instance;
      WriteBatch batch = firestore.batch();

      DocumentReference partnerRef = firestore.collection(_shareholdersCollection).doc();
      PartnerModel newPartner = PartnerModel(
        id: partnerRef.id,
        name: name,
        type: 'partner',
        phone: '',
        managementRatio: mngRatio,
        joinDate: DateTime.now(),
      );

      Map<String, dynamic> partnerData = newPartner.toMap();
      partnerData['capital'] = capital;
      partnerData['type'] = 'partner';
      batch.set(partnerRef, partnerData);

      if (capital > 0) {
        DocumentReference ledgerRef = firestore.collection(_ledgerEntriesCollection).doc();
        LedgerEntryModel newLedger = LedgerEntryModel(
          id: ledgerRef.id,
          accountId: partnerRef.id,
          debit: 0.0,
          credit: capital,
          referenceId: 'initial_deposit',
          description: 'إيداع رأس مال مبدئي للشريك $name',
          timestamp: DateTime.now(),
          transactionType: 'capital_deposit',
        );
        batch.set(ledgerRef, newLedger.toMap());
      }

      await batch.commit();
      _showSuccessMessage('تم إضافة الشريك بنجاح');
      await _fetchAllDataFromFirebase();
    } catch (e) {
      setState(() => _isLoadingData = false);
      if (mounted) _showSuccessMessage('حدث خطأ أثناء الحفظ', isError: true);
    }
  }

  Future<void> _depositOrUpdateCapital(PartnerModel partner, double amount) async {
    setState(() => _isLoadingData = true);
    try {
      final firestore = FirebaseFirestore.instance;
      WriteBatch batch = firestore.batch();

      DocumentReference partnerRef = firestore.collection(_shareholdersCollection).doc(partner.id);
      batch.set(partnerRef, {'capital': FieldValue.increment(amount)}, SetOptions(merge: true));

      DocumentReference ledgerRef = firestore.collection(_ledgerEntriesCollection).doc();
      LedgerEntryModel newLedger = LedgerEntryModel(
        id: ledgerRef.id,
        accountId: partner.id,
        debit: 0.0,
        credit: amount,
        referenceId: 'capital_topup',
        description: 'إيداع رأس مال للشريك ${partner.name}',
        timestamp: DateTime.now(),
        transactionType: 'capital_deposit',
      );
      batch.set(ledgerRef, newLedger.toMap());

      await batch.commit();
      _showSuccessMessage('تم الإيداع بنجاح');
      await _fetchAllDataFromFirebase();
    } catch (e) {
      setState(() => _isLoadingData = false);
    }
  }

  Future<void> _withdrawCash(PartnerModel partner, double amount, String description) async {
    setState(() => _isLoadingData = true);
    try {
      final firestore = FirebaseFirestore.instance;
      WriteBatch batch = firestore.batch();

      DocumentReference ledgerRef = firestore.collection(_ledgerEntriesCollection).doc();
      LedgerEntryModel newLedger = LedgerEntryModel(
        id: ledgerRef.id,
        accountId: partner.id,
        debit: amount,
        credit: 0.0,
        referenceId: 'withdrawal',
        description: description.isEmpty ? 'مسحوبات نقدية - ${partner.name}' : description,
        timestamp: DateTime.now(),
        transactionType: 'capital_withdrawal',
      );
      batch.set(ledgerRef, newLedger.toMap());

      DocumentReference expenseRef = firestore.collection('expenses').doc(ledgerRef.id);
      batch.set(expenseRef, {
        'id': ledgerRef.id,
        'type': 'expense',
        'transactionType': 'partner_withdrawal',
        'amount': amount,
        'date': FieldValue.serverTimestamp(),
        'note': description.isEmpty ? 'مسحوبات أرباح - ${partner.name}' : description,
        'partnerName': partner.name,
      });

      await batch.commit();
      _showSuccessMessage('تم سحب المبلغ من الخزينة بنجاح');
      await _fetchAllDataFromFirebase();
    } catch (e) {
      setState(() => _isLoadingData = false);
    }
  }

  Future<void> _capitalizeProfit(PartnerModel partner, double amount) async {
    setState(() => _isLoadingData = true);
    try {
      final firestore = FirebaseFirestore.instance;
      WriteBatch batch = firestore.batch();

      DocumentReference partnerRef = firestore.collection(_shareholdersCollection).doc(partner.id);
      batch.set(partnerRef, {'capital': FieldValue.increment(amount)}, SetOptions(merge: true));

      DocumentReference ledgerRef = firestore.collection(_ledgerEntriesCollection).doc();
      LedgerEntryModel newLedger = LedgerEntryModel(
        id: ledgerRef.id,
        accountId: partner.id,
        debit: 0.0,
        credit: amount,
        referenceId: 'profit_capitalization',
        description: 'رسملة أرباح (إضافة لرأس المال) - ${partner.name}',
        timestamp: DateTime.now(),
        transactionType: 'profit_capitalization',
      );
      batch.set(ledgerRef, newLedger.toMap());

      await batch.commit();
      _showSuccessMessage('تم إضافة الأرباح إلى رأس مال الشريك بنجاح');
      await _fetchAllDataFromFirebase();
    } catch (e) {
      setState(() => _isLoadingData = false);
    }
  }

  Future<void> _deletePartnerFromFirebase(String partnerId) async {
    setState(() => _isLoadingData = true);
    try {
      final firestore = FirebaseFirestore.instance;
      WriteBatch batch = firestore.batch();
      batch.delete(firestore.collection(_shareholdersCollection).doc(partnerId));

      var snap = await firestore.collection(_ledgerEntriesCollection).where('accountId', isEqualTo: partnerId).get();
      for (var doc in snap.docs) batch.delete(doc.reference);

      await batch.commit();
      _showSuccessMessage('تم إزالة الشريك');
      await _fetchAllDataFromFirebase();
    } catch (e) {
      setState(() => _isLoadingData = false);
    }
  }

  Future<void> _updatePartnerManagementRatio(String partnerId, double newRatio) async {
    setState(() => _isLoadingData = true);
    try {
      await FirebaseFirestore.instance.collection(_shareholdersCollection).doc(partnerId).update({
        'managementRatio': newRatio,
      });
      _showSuccessMessage('تم تحديث نسبة الإدارة بنجاح');
      await _fetchAllDataFromFirebase();
    } catch (e) {
      setState(() => _isLoadingData = false);
      _showSuccessMessage('حدث خطأ أثناء التحديث', isError: true);
    }
  }

  Future<void> _pickPartnerImage(String partnerId) async {
    final picker = ImagePicker();
    final pickedFile = await picker.pickImage(source: ImageSource.gallery, imageQuality: 70);

    if (pickedFile != null) {
      setState(() => _isLoadingData = true);
      try {
        String fileName = 'partners_images/${partnerId}_${DateTime.now().millisecondsSinceEpoch}.jpg';
        Reference storageRef = FirebaseStorage.instance.ref().child(fileName);

        UploadTask uploadTask = storageRef.putFile(File(pickedFile.path));
        TaskSnapshot snapshot = await uploadTask;

        String downloadUrl = await snapshot.ref.getDownloadURL();

        await FirebaseFirestore.instance.collection(_shareholdersCollection).doc(partnerId).update({
          'imageUrl': downloadUrl,
        });

        _showSuccessMessage('تم رفع وحفظ صورة الشريك بنجاح!');
        await _fetchAllDataFromFirebase();
      } catch (e) {
        setState(() => _isLoadingData = false);
        _showSuccessMessage('خطأ في رفع الصورة: تأكد من اتصال الإنترنت', isError: true);
      }
    }
  }

  void _showSuccessMessage(String message, {bool isError = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            Icon(isError ? Icons.error_outline : Icons.check_circle_rounded, color: Colors.white),
            const SizedBox(width: 10),
            Expanded(child: Text(message, style: const TextStyle(fontFamily: 'Cairo', fontWeight: FontWeight.bold, color: Colors.white))),
          ],
        ),
        backgroundColor: isError ? Colors.red.shade700 : Colors.green.shade700,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        margin: const EdgeInsets.all(16),
        duration: const Duration(seconds: 3),
      ),
    );
  }

  void _showWithdrawalSheet(BuildContext context, PartnerModel partner) {
    final TextEditingController amountController = TextEditingController();
    final TextEditingController noteController = TextEditingController();
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => Directionality(
        textDirection: TextDirection.rtl,
        child: Container(
          padding: EdgeInsets.only(bottom: MediaQuery.of(ctx).viewInsets.bottom, left: 20, right: 20, top: 20),
          decoration: const BoxDecoration(color: Colors.white, borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text('سحب أرباح / نقدي: ${partner.name}', style: const TextStyle(fontFamily: 'Cairo', fontWeight: FontWeight.bold, fontSize: 16, color: Colors.red)),
              const Divider(),
              const SizedBox(height: 12),
              TextField(
                controller: amountController,
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                decoration: InputDecoration(labelText: 'مبلغ السحب (ج.م)', border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)), prefixIcon: const Icon(Icons.money_off, color: Colors.red)),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: noteController,
                decoration: InputDecoration(labelText: 'البيان (اختياري)', hintText: 'مثال: سحب جزء من أرباح شهر أكتوبر', border: OutlineInputBorder(borderRadius: BorderRadius.circular(10))),
              ),
              const SizedBox(height: 20),
              ElevatedButton(
                style: ElevatedButton.styleFrom(backgroundColor: Colors.red.shade700, padding: const EdgeInsets.symmetric(vertical: 14), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10))),
                onPressed: () {
                  double amount = double.tryParse(amountController.text) ?? 0.0;
                  if (amount > 0) {
                    Navigator.pop(ctx);
                    _withdrawCash(partner, amount, noteController.text.trim());
                  }
                },
                child: const Text('تأكيد السحب من الخزينة', style: TextStyle(fontFamily: 'Cairo', fontWeight: FontWeight.bold, color: Colors.white)),
              ),
              const SizedBox(height: 20),
            ],
          ),
        ),
      ),
    );
  }

  void _showCapitalizeProfitSheet(BuildContext context, PartnerModel partner, double availableProfit) {
    final TextEditingController amountController = TextEditingController(text: availableProfit > 0 ? availableProfit.toStringAsFixed(0) : '');
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => Directionality(
        textDirection: TextDirection.rtl,
        child: Container(
          padding: EdgeInsets.only(bottom: MediaQuery.of(ctx).viewInsets.bottom, left: 20, right: 20, top: 20),
          decoration: const BoxDecoration(color: Colors.white, borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text('رسملة الأرباح: ${partner.name}', style: const TextStyle(fontFamily: 'Cairo', fontWeight: FontWeight.bold, fontSize: 16, color: Colors.green)),
              const Text('ستقوم هذه العملية بنقل الأرباح إلى رأس المال دون التأثير على سيولة الخزينة.', style: TextStyle(fontFamily: 'Cairo', fontSize: 12, color: Colors.grey)),
              const Divider(),
              const SizedBox(height: 12),
              TextField(
                controller: amountController,
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                decoration: InputDecoration(labelText: 'المبلغ المراد إضافته لرأس المال (ج.م)', border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)), prefixIcon: const Icon(Icons.add_chart, color: Colors.green)),
              ),
              const SizedBox(height: 20),
              ElevatedButton(
                style: ElevatedButton.styleFrom(backgroundColor: Colors.green.shade700, padding: const EdgeInsets.symmetric(vertical: 14), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10))),
                onPressed: () {
                  double amount = double.tryParse(amountController.text) ?? 0.0;
                  if (amount > 0) {
                    Navigator.pop(ctx);
                    _capitalizeProfit(partner, amount);
                  }
                },
                child: const Text('رسملة وإضافة', style: TextStyle(fontFamily: 'Cairo', fontWeight: FontWeight.bold, color: Colors.white)),
              ),
              const SizedBox(height: 20),
            ],
          ),
        ),
      ),
    );
  }

  void _showDepositCapitalDialog(BuildContext context, PartnerModel partner) {
    final TextEditingController amountController = TextEditingController();
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => Directionality(
        textDirection: TextDirection.rtl,
        child: Container(
          padding: EdgeInsets.only(bottom: MediaQuery.of(ctx).viewInsets.bottom, left: 20, right: 20, top: 20),
          decoration: const BoxDecoration(color: Colors.white, borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text('إيداع رأس مال جديد: ${partner.name}', style: const TextStyle(fontFamily: 'Cairo', fontWeight: FontWeight.bold, fontSize: 16, color: Color(0xFF0D1B2A))),
              const Divider(),
              const SizedBox(height: 12),
              TextField(
                controller: amountController,
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                decoration: InputDecoration(labelText: 'مبلغ الإيداع (ج.م)', border: OutlineInputBorder(borderRadius: BorderRadius.circular(10))),
              ),
              const SizedBox(height: 20),
              ElevatedButton(
                style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF0D1B2A), padding: const EdgeInsets.symmetric(vertical: 14), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10))),
                onPressed: () {
                  double amount = double.tryParse(amountController.text) ?? 0.0;
                  if (amount > 0) {
                    Navigator.pop(ctx);
                    _depositOrUpdateCapital(partner, amount);
                  }
                },
                child: const Text('تأكيد الإيداع كاش', style: TextStyle(fontFamily: 'Cairo', fontWeight: FontWeight.bold, color: Colors.white)),
              ),
              const SizedBox(height: 20),
            ],
          ),
        ),
      ),
    );
  }

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
          decoration: const BoxDecoration(color: Colors.white, borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text('تعديل نسب الإدارة والتشغيل', style: TextStyle(fontFamily: 'Cairo', fontWeight: FontWeight.bold, fontSize: 16, color: Color(0xFF0D1B2A))),
                  IconButton(icon: const Icon(Icons.close, color: Colors.black), onPressed: () => Navigator.pop(ctx)),
                ],
              ),
              const Divider(),
              const SizedBox(height: 8),
              const Text('حدد نسبة الإدارة والتشغيل الإجمالية المستقطعة من الربح التشغيلي:', style: TextStyle(fontFamily: 'Cairo', fontSize: 12, color: Colors.grey)),
              const SizedBox(height: 12),
              TextField(
                controller: poolController,
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                decoration: InputDecoration(labelText: 'النسبة المئوية (%)', border: OutlineInputBorder(borderRadius: BorderRadius.circular(10))),
              ),
              const SizedBox(height: 20),
              ElevatedButton(
                style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF0D1B2A), padding: const EdgeInsets.symmetric(vertical: 14), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10))),
                onPressed: () {
                  setState(() => _currentManagementPool = double.tryParse(poolController.text) ?? _currentManagementPool);
                  Navigator.pop(ctx);
                  _triggerCubitCalculation();
                  _showSuccessMessage('تم التحديث');
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

  // 🌟 دالة التحقق وتعديل نسبة الشريك الحالي
  void _showEditManagementShareSheet(BuildContext context, PartnerModel partner) {
    final TextEditingController ratioController = TextEditingController(text: partner.managementRatio.toStringAsFixed(0));
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => Directionality(
        textDirection: TextDirection.rtl,
        child: Container(
          padding: EdgeInsets.only(bottom: MediaQuery.of(ctx).viewInsets.bottom, left: 20, right: 20, top: 20),
          decoration: const BoxDecoration(color: Colors.white, borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text('تعديل نسبة الإدارة: ${partner.name}', style: const TextStyle(fontFamily: 'Cairo', fontWeight: FontWeight.bold, fontSize: 16, color: Color(0xFF0D1B2A))),
                  IconButton(icon: const Icon(Icons.close, color: Colors.black), onPressed: () => Navigator.pop(ctx)),
                ],
              ),
              const Divider(),
              const SizedBox(height: 12),
              TextField(
                controller: ratioController,
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                decoration: InputDecoration(labelText: 'النسبة المئوية (%)', hintText: 'أدخل 0 إذا لم يكن يشارك في الإدارة', border: OutlineInputBorder(borderRadius: BorderRadius.circular(10))),
              ),
              const SizedBox(height: 20),
              ElevatedButton(
                style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF0D1B2A), padding: const EdgeInsets.symmetric(vertical: 14), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10))),
                onPressed: () {
                  double newRatio = double.tryParse(ratioController.text) ?? 0.0;

                  // 🌟 التحقق: مجموع نسب باقي الشركاء + النسبة الجديدة يجب ألا تتعدى نسبة الإدارة الإجمالية
                  double otherPartnersRatios = _firebasePartners
                      .where((p) => p.id != partner.id)
                      .fold(0.0, (sum, p) => sum + p.managementRatio);

                  if (otherPartnersRatios + newRatio > _currentManagementPool) {
                    _showSuccessMessage('خطأ: مجموع نسب الشركاء سيتجاوز نسبة الإدارة المستقطعة (${_currentManagementPool}%)', isError: true);
                    return;
                  }

                  Navigator.pop(ctx);
                  _updatePartnerManagementRatio(partner.id, newRatio);
                },
                child: const Text('حفظ النسبة الجديدة', style: TextStyle(fontFamily: 'Cairo', fontWeight: FontWeight.bold, color: Colors.white)),
              ),
              const SizedBox(height: 20),
            ],
          ),
        ),
      ),
    );
  }

  // 🌟 دالة التحقق عند إضافة شريك جديد
  void _showAddPartnerDialog(BuildContext context) {
    final TextEditingController nameController = TextEditingController();
    final TextEditingController capitalController = TextEditingController();
    final TextEditingController managementShareController = TextEditingController(text: '0');
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
                      IconButton(icon: const Icon(Icons.close, color: Colors.black), onPressed: () => Navigator.pop(ctx)),
                    ],
                  ),
                  const Divider(),
                  const SizedBox(height: 8),
                  TextField(controller: nameController, decoration: InputDecoration(labelText: 'اسم الشريك', border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)))),
                  const SizedBox(height: 16),
                  TextField(controller: capitalController, keyboardType: const TextInputType.numberWithOptions(decimal: true), decoration: InputDecoration(labelText: 'مبلغ رأس المال (ج.م)', border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)))),
                  const SizedBox(height: 16),
                  SwitchListTile(
                    title: const Text('يشارك في الإدارة والتشغيل؟', style: TextStyle(fontFamily: 'Cairo', fontSize: 13, fontWeight: FontWeight.bold)),
                    value: isManagementActive,
                    activeColor: Colors.orange.shade700,
                    onChanged: (val) => setSheetState(() => isManagementActive = val),
                  ),
                  if (isManagementActive) ...[
                    const SizedBox(height: 8),
                    TextField(controller: managementShareController, keyboardType: const TextInputType.numberWithOptions(decimal: true), decoration: InputDecoration(labelText: 'نسبة الإدارة الخاصة (%)', hintText: 'مثلاً أدخل 15 إذا كانت حصته 15%', border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)))),
                  ],
                  const SizedBox(height: 24),
                  ElevatedButton(
                    style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF0D1B2A), padding: const EdgeInsets.symmetric(vertical: 14), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
                    onPressed: () {
                      if (nameController.text.isNotEmpty && capitalController.text.isNotEmpty) {
                        double cap = double.tryParse(capitalController.text) ?? 0.0;
                        double mngRatio = isManagementActive ? (double.tryParse(managementShareController.text) ?? 0.0) : 0.0;

                        // 🌟 التحقق: مجموع نسب الشركاء الحاليين + النسبة الجديدة يجب ألا يتجاوز الإجمالي
                        double currentTotalRatios = _firebasePartners.fold(0.0, (sum, p) => sum + p.managementRatio);
                        if (currentTotalRatios + mngRatio > _currentManagementPool) {
                          _showSuccessMessage('خطأ: مجموع نسب الشركاء سيتجاوز النسبة المستقطعة للإدارة (${_currentManagementPool}%)', isError: true);
                          return;
                        }

                        Navigator.pop(ctx);
                        _addPartnerToFirebase(nameController.text.trim(), cap, mngRatio);
                      } else {
                        _showSuccessMessage('يرجى إدخال الاسم ورأس المال', isError: true);
                      }
                    },
                    child: const Text('حفظ في قاعدة البيانات', style: TextStyle(fontFamily: 'Cairo', fontWeight: FontWeight.bold, color: Colors.white, fontSize: 15)),
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

    return BlocProvider.value(
      value: _profitCubit,
      child: Directionality(
        textDirection: TextDirection.rtl,
        child: Scaffold(
          backgroundColor: bgColor,
          appBar: AppBar(
            backgroundColor: primaryNavy,
            centerTitle: true,
            title: const Text('حسابات الشركاء ورأس المال', style: TextStyle(fontFamily: 'Cairo', fontSize: 16, fontWeight: FontWeight.bold, color: Colors.white)),
            automaticallyImplyLeading: false,
            actions: [
              IconButton(icon: const Icon(Icons.arrow_forward_ios, color: Colors.white, size: 18), onPressed: () => Navigator.pop(context)),
            ],
            leading: const SizedBox.shrink(),
            elevation: 0,
          ),
          body: _isLoadingData
              ? const Center(child: CircularProgressIndicator(color: Colors.orange))
              : RefreshIndicator(
            color: Colors.orange,
            onRefresh: _fetchAllDataFromFirebase,
            child: SingleChildScrollView(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  if (_needsMigration) ...[
                    Container(
                      margin: const EdgeInsets.only(bottom: 16),
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(color: Colors.blue.shade50, borderRadius: BorderRadius.circular(12), border: Border.all(color: Colors.blue.shade400, width: 1.5)),
                      child: Column(
                        children: [
                          const Text('تنظيم قاعدة البيانات: اضغط بالأسفل لنقل الشركاء إلى (shareholders).', style: TextStyle(fontFamily: 'Cairo', fontSize: 12, fontWeight: FontWeight.bold, color: primaryNavy), textAlign: TextAlign.center),
                          const SizedBox(height: 10),
                          ElevatedButton.icon(
                            style: ElevatedButton.styleFrom(backgroundColor: Colors.blue.shade800, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10))),
                            onPressed: _migrateAndCleanFirebaseStructure,
                            icon: const Icon(Icons.cleaning_services_rounded, color: Colors.white, size: 18),
                            label: const Text('ترحيل وتنظيف الفايربيز تلقائياً الآن', style: TextStyle(fontFamily: 'Cairo', fontWeight: FontWeight.bold, color: Colors.white)),
                          ),
                        ],
                      ),
                    ),
                  ],

                  // كارت الملخص المالي
                  Container(
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: primaryNavy,
                      borderRadius: BorderRadius.circular(16),
                      boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.08), blurRadius: 10, offset: const Offset(0, 4))],
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            const SizedBox(width: 32),
                            const Text('صافي الربح التشغيلي الفعلي', style: TextStyle(fontFamily: 'Cairo', fontSize: 13, color: Colors.white70)),
                            CustomDateRangeFilter(
                              onFilterChanged: (start, end) {
                                setState(() {
                                  _filterStartDate = start;
                                  _filterEndDate = end;
                                });
                                _triggerCubitCalculation();
                              },
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        Text(
                          '${_fetchedNetOperatingProfit.toStringAsFixed(2)} ج.م',
                          style: TextStyle(fontFamily: 'Cairo', fontSize: 32, fontWeight: FontWeight.bold, color: isNegativeProfit ? Colors.redAccent : Colors.orangeAccent),
                          textAlign: TextAlign.center,
                        ),
                        const Divider(color: Colors.white24, height: 24),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text('إجمالي رأس مال المتجر: ${_totalStoreCapital.toStringAsFixed(0)} ج.م', style: const TextStyle(fontFamily: 'Cairo', fontSize: 12, color: Colors.white70, fontWeight: FontWeight.bold)),
                          ],
                        ),
                        const SizedBox(height: 4),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text('إجمالي المستقطع للإدارة: $_currentManagementPool%', style: const TextStyle(fontFamily: 'Cairo', fontSize: 12, color: Colors.white70)),
                            IconButton(icon: const Icon(Icons.settings_outlined, color: Colors.orangeAccent, size: 22), onPressed: () => _showEditManagementPoolSheet(context), padding: EdgeInsets.zero, constraints: const BoxConstraints()),
                          ],
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 24),

                  ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(backgroundColor: Colors.orange.shade700, padding: const EdgeInsets.symmetric(vertical: 14), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)), elevation: 2),
                    onPressed: () => _showAddPartnerDialog(context),
                    icon: const Icon(Icons.add_circle_outline, size: 20, color: Colors.white),
                    label: const Text('إضافة شريك جديد / إيداع', style: TextStyle(fontFamily: 'Cairo', fontWeight: FontWeight.bold, color: Colors.white, fontSize: 15)),
                  ),
                  const SizedBox(height: 24),

                  const Center(child: Text('هيكل الشركاء وحقوق الملكية', style: TextStyle(fontFamily: 'Cairo', fontSize: 17, fontWeight: FontWeight.bold, color: primaryNavy))),
                  const SizedBox(height: 14),

                  BlocConsumer<PartnersProfitCubit, PartnersProfitState>(
                    listener: (context, state) {
                      if (state is PartnersProfitLoaded) {
                        setState(() {
                          _calculatedResultsMap = {for (var r in state.calculatedResults) r.partner.id: r};
                        });
                      }
                    },
                    builder: (context, state) {
                      if (state is PartnersProfitLoaded) {
                        _calculatedResultsMap = {for (var r in state.calculatedResults) r.partner.id: r};
                      }

                      if (_firebasePartners.isEmpty) {
                        return Container(
                          padding: const EdgeInsets.all(24),
                          decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16), border: Border.all(color: Colors.grey.shade300)),
                          child: const Column(
                            children: [
                              Icon(Icons.handshake_outlined, size: 48, color: Colors.grey),
                              SizedBox(height: 12),
                              Text('لا توجد بيانات شركاء في قاعدة البيانات', style: TextStyle(fontFamily: 'Cairo', fontSize: 14, fontWeight: FontWeight.bold, color: Colors.grey), textAlign: TextAlign.center),
                            ],
                          ),
                        );
                      }

                      return ListView.builder(
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        itemCount: _firebasePartners.length,
                        itemBuilder: (context, index) {
                          final partner = _firebasePartners[index];

                          double ledgerCapital = _firebaseLedgers
                              .where((l) => l.accountId == partner.id && (l.transactionType == 'capital_deposit' || l.transactionType == 'profit_capitalization' || l.transactionType == 'capital_withdrawal'))
                              .fold(0.0, (sum, l) => sum + (l.credit - l.debit));

                          double capital = ledgerCapital > 0 ? ledgerCapital : (_partnerDirectCapital[partner.id] ?? 0.0);
                          double ownershipPercentage = _totalStoreCapital > 0 ? (capital / _totalStoreCapital) * 100 : 0.0;

                          final result = _calculatedResultsMap[partner.id];
                          double managementProfit = result?.managementProfit ?? 0.0;
                          double capitalProfit = result?.capitalProfit ?? 0.0;
                          double totalProfit = result?.totalProfit ?? 0.0;

                          bool hasManagement = partner.managementRatio > 0;
                          double displayMgmtShare = partner.managementRatio;
                          String? imagePath = _firebaseImageUrls[partner.id];

                          return Container(
                            margin: const EdgeInsets.only(bottom: 16),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(16),
                              border: Border.all(color: Colors.orange.shade600, width: 1.8),
                              boxShadow: [BoxShadow(color: Colors.orange.withOpacity(0.06), blurRadius: 8, offset: const Offset(0, 3))],
                            ),
                            child: Padding(
                              padding: const EdgeInsets.all(16.0),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    children: [
                                      GestureDetector(
                                        onTap: () => _pickPartnerImage(partner.id),
                                        child: Stack(
                                          alignment: Alignment.bottomRight,
                                          children: [
                                            CircleAvatar(
                                              radius: 24,
                                              backgroundColor: primaryNavy,
                                              backgroundImage: imagePath != null ? NetworkImage(imagePath) : null,
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
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          children: [
                                            Text(partner.name, style: const TextStyle(fontFamily: 'Cairo', fontWeight: FontWeight.bold, fontSize: 17, color: primaryNavy)),
                                            Text('حصة الملكية: ${ownershipPercentage.toStringAsFixed(1)}%', style: TextStyle(fontFamily: 'Cairo', fontWeight: FontWeight.bold, fontSize: 12, color: Colors.blue.shade700)),
                                          ],
                                        ),
                                      ),
                                      IconButton(tooltip: 'إيداع رأس مال', icon: Icon(Icons.add_card, color: Colors.blue.shade800, size: 20), onPressed: () => _showDepositCapitalDialog(context, partner)),
                                      IconButton(tooltip: 'حذف الشريك', icon: const Icon(Icons.delete_outline, color: Colors.red, size: 20), onPressed: () => _deletePartnerFromFirebase(partner.id)),
                                    ],
                                  ),
                                  const Divider(height: 20),

                                  Row(
                                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                    children: [
                                      const Text('• إجمالي رأس المال المودع (تاريخياً):', style: TextStyle(fontFamily: 'Cairo', fontSize: 13, color: Colors.black87, fontWeight: FontWeight.w600)),
                                      Text('${capital.toStringAsFixed(0)} ج.م', style: const TextStyle(fontFamily: 'Cairo', fontWeight: FontWeight.bold, fontSize: 14, color: primaryNavy)),
                                    ],
                                  ),
                                  const SizedBox(height: 8),
                                  Row(
                                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                    children: [
                                      Row(
                                        children: [
                                          Text('• نسبة الإدارة (${hasManagement ? "${displayMgmtShare.toStringAsFixed(0)}%" : "لا يوجد"}):', style: const TextStyle(fontFamily: 'Cairo', fontSize: 13, color: Colors.black87, fontWeight: FontWeight.w600)),
                                          IconButton(
                                            icon: Icon(Icons.edit, size: 14, color: Colors.grey.shade600),
                                            onPressed: () => _showEditManagementShareSheet(context, partner),
                                            constraints: const BoxConstraints(),
                                            padding: const EdgeInsets.only(right: 4),
                                          ),
                                        ],
                                      ),
                                      Text('${managementProfit.toStringAsFixed(2)} ج.م', style: TextStyle(fontFamily: 'Cairo', fontWeight: FontWeight.bold, fontSize: 14, color: Colors.orange.shade800)),
                                    ],
                                  ),
                                  const SizedBox(height: 8),
                                  Row(
                                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                    children: [
                                      const Text('• أرباح رأس المال (للفترة المحددة):', style: TextStyle(fontFamily: 'Cairo', fontSize: 13, color: Colors.black87, fontWeight: FontWeight.w600)),
                                      Text('${capitalProfit.toStringAsFixed(2)} ج.م', style: const TextStyle(fontFamily: 'Cairo', fontWeight: FontWeight.bold, fontSize: 14, color: Colors.blueAccent)),
                                    ],
                                  ),
                                  const Divider(height: 20),

                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                                    decoration: BoxDecoration(color: Colors.green.shade50, borderRadius: BorderRadius.circular(10), border: Border.all(color: Colors.green.shade300, width: 1.2)),
                                    child: Row(
                                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                      children: [
                                        const Text('أرباح الشريك لهذه الفترة:', style: TextStyle(fontFamily: 'Cairo', fontWeight: FontWeight.bold, fontSize: 14, color: Colors.green)),
                                        Text('${totalProfit.toStringAsFixed(2)} ج.م', style: TextStyle(fontFamily: 'Cairo', fontWeight: FontWeight.bold, fontSize: 17, color: Colors.green.shade800)),
                                      ],
                                    ),
                                  ),

                                  const SizedBox(height: 12),
                                  Row(
                                    children: [
                                      Expanded(
                                        child: ElevatedButton.icon(
                                          style: ElevatedButton.styleFrom(
                                            backgroundColor: Colors.white,
                                            foregroundColor: Colors.red.shade700,
                                            elevation: 0,
                                            side: BorderSide(color: Colors.red.shade200),
                                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                                          ),
                                          icon: const Icon(Icons.money_off, size: 16),
                                          label: const Text('سحب كاش', style: TextStyle(fontFamily: 'Cairo', fontWeight: FontWeight.bold, fontSize: 12)),
                                          onPressed: () => _showWithdrawalSheet(context, partner),
                                        ),
                                      ),
                                      const SizedBox(width: 8),
                                      Expanded(
                                        child: ElevatedButton.icon(
                                          style: ElevatedButton.styleFrom(
                                            backgroundColor: Colors.white,
                                            foregroundColor: Colors.green.shade700,
                                            elevation: 0,
                                            side: BorderSide(color: Colors.green.shade200),
                                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                                          ),
                                          icon: const Icon(Icons.add_chart, size: 16),
                                          label: const Text('رسملة للرصيد', style: TextStyle(fontFamily: 'Cairo', fontWeight: FontWeight.bold, fontSize: 12)),
                                          onPressed: () => _showCapitalizeProfitSheet(context, partner, totalProfit),
                                        ),
                                      ),
                                    ],
                                  )
                                ],
                              ),
                            ),
                          );
                        },
                      );
                    },
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}