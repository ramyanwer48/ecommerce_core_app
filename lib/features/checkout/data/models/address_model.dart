class AddressModel {
  final String id;
  final String title; // مثال: المنزل، العمل
  final String fullName;
  final String phone;
  final String city;
  final String streetAddress;
  final bool isDefault;

  AddressModel({
    required this.id,
    required this.title,
    required this.fullName,
    required this.phone,
    required this.city,
    required this.streetAddress,
    required this.isDefault,
  });

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'title': title,
      'fullName': fullName,
      'phone': phone,
      'city': city,
      'streetAddress': streetAddress,
      'isDefault': isDefault,
    };
  }

  factory AddressModel.fromJson(Map<String, dynamic> json, String docId) {
    return AddressModel(
      id: docId,
      title: json['title'] ?? 'عنوان',
      fullName: json['fullName'] ?? '',
      phone: json['phone'] ?? '',
      city: json['city'] ?? '',
      streetAddress: json['streetAddress'] ?? '',
      isDefault: json['isDefault'] ?? false,
    );
  }

  // نص كامل للعنوان لعرضه بسلاسة في الفاتورة أو الشيك أوت
  String get fullAddressText => '$city - $streetAddress ($fullName - $phone)';
}