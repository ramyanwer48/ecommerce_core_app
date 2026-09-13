import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../models/address_model.dart';

class AddressRepo {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  String? get _currentUserId => _auth.currentUser?.uid;

  CollectionReference<Map<String, dynamic>> _userAddressesCollection() {
    if (_currentUserId == null) throw Exception('المستخدم غير مسجل الدخول');
    return _firestore.collection('users').doc(_currentUserId).collection('addresses');
  }

  // 1. جلب العناوين
  Future<List<AddressModel>> getAddresses() async {
    final snapshot = await _userAddressesCollection().orderBy('isDefault', descending: true).get();
    return snapshot.docs.map((doc) => AddressModel.fromJson(doc.data(), doc.id)).toList();
  }

  // 2. إضافة عنوان جديد (ولو هو default، بنخلي الباقي false)
  Future<void> addAddress(AddressModel address) async {
    final batch = _firestore.batch();
    final colRef = _userAddressesCollection();

    if (address.isDefault) {
      final existing = await colRef.where('isDefault', isEqualTo: true).get();
      for (var doc in existing.docs) {
        batch.update(doc.reference, {'isDefault': false});
      }
    }

    final newDocRef = colRef.doc();
    batch.set(newDocRef, address.toJson());
    await batch.commit();
  }

  // 3. تعيين عنوان كافتراضي (Default)
  Future<void> setDefaultAddress(String addressId) async {
    final batch = _firestore.batch();
    final colRef = _userAddressesCollection();
    final allDocs = await colRef.get();

    for (var doc in allDocs.docs) {
      batch.update(doc.reference, {'isDefault': doc.id == addressId});
    }

    await batch.commit();
  }

  // 4. حذف عنوان
  Future<void> deleteAddress(String addressId) async {
    await _userAddressesCollection().doc(addressId).delete();
  }
}