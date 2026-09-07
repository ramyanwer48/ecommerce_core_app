class ReviewModel {
  final String userName; // اسم العميل اللي كتب التقييم
  final double rating; // التقييم من 1 إلى 5 نجوم
  final String comment; // التعليق النصي
  final String date; // تاريخ كتابة المراجعة

  ReviewModel({
    required this.userName,
    required this.rating,
    required this.comment,
    required this.date,
  });

  factory ReviewModel.fromJson(Map<String, dynamic> json) {
    return ReviewModel(
      userName: json['userName'] ?? 'مستخدم مجهول',
      rating: (json['rating'] ?? 5.0).toDouble(),
      comment: json['comment'] ?? '',
      date: json['date'] ?? '',
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'userName': userName,
      'rating': rating,
      'comment': comment,
      'date': date,
    };
  }
}