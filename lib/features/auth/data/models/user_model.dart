class UserModel {
  final String uid;
  final String name;
  final String email;
  final String role; // 👈 بطل القصة النهاردة (customer, admin, accountant, warehouse)

  UserModel({
    required this.uid,
    required this.name,
    required this.email,
    this.role = 'customer', // أي حد بيسجل جديد بياخد دور عميل كافتراضي
  });

  // تحويل البيانات لـ Map عشان تترفع للـ Firestore
  Map<String, dynamic> toMap() {
    return {
      'uid': uid,
      'name': name,
      'email': email,
      'role': role,
      'createdAt': DateTime.now().toIso8601String(),
    };
  }

  // قراءة البيانات من الـ Firestore
  factory UserModel.fromMap(Map<String, dynamic> map, String documentId) {
    return UserModel(
      uid: documentId,
      name: map['name'] ?? '',
      email: map['email'] ?? '',
      role: map['role'] ?? 'customer',
    );
  }
}