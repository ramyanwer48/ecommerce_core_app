import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../../data/models/review_model.dart';
import 'reviews_state.dart';

class ReviewsCubit extends Cubit<ReviewsState> {
  ReviewsCubit() : super(ReviewsInitial());

  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  // جلب التقييمات وحساب المتوسط
  Future<void> fetchReviews(String productId) async {
    emit(ReviewsLoading());
    try {
      final snapshot = await _firestore
          .collection('products')
          .doc(productId)
          .collection('reviews')
          .orderBy('date', descending: true)
          .get();

      final reviews = snapshot.docs
          .map((doc) => ReviewModel.fromJson(doc.data()))
          .toList();

      double average = 0.0;
      if (reviews.isNotEmpty) {
        double total = 0;
        for (var r in reviews) {
          total += r.rating;
        }
        average = total / reviews.length;
      }

      emit(ReviewsLoaded(reviews, average));
    } catch (e) {
      emit(ReviewsError('حدث خطأ في جلب التقييمات: ${e.toString()}'));
    }
  }

  // إضافة تقييم جديد وتحديث الدوكيومنت الأساسي
  Future<void> addReview({
    required String productId,
    required String userName,
    required double rating,
    required String comment,
  }) async {
    emit(AddReviewLoading());
    try {
      final currentUserId = _auth.currentUser?.uid;
      if (currentUserId == null) {
        emit(ReviewsError('يجب تسجيل الدخول أولاً لإضافة تقييم'));
        return;
      }

      final now = DateTime.now();
      final dateString = "${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}";

      final review = ReviewModel(
        userName: userName,
        rating: rating,
        comment: comment,
        date: dateString,
      );

      Map<String, dynamic> reviewData = review.toJson();
      reviewData['userId'] = currentUserId;

      // 1. إضافة التقييم في فايربيز داخل subcollection
      await _firestore
          .collection('products')
          .doc(productId)
          .collection('reviews')
          .add(reviewData);

      // 2. 🚀 السحر هنا: قراءة كل التقييمات وحساب المتوسط الجديد فوراً
      final snapshot = await _firestore.collection('products').doc(productId).collection('reviews').get();
      final allReviews = snapshot.docs.map((doc) => ReviewModel.fromJson(doc.data())).toList();

      double newAverage = 0.0;
      if (allReviews.isNotEmpty) {
        double total = 0;
        for (var r in allReviews) {
          total += r.rating;
        }
        newAverage = total / allReviews.length;
      }

      // 3. 🚀 تحديث الدوكيومنت الأساسي للمنتج عشان المتجر يقراه بره
      await _firestore.collection('products').doc(productId).update({
        'rating': newAverage,
        'reviewsCount': allReviews.length,
      });

      emit(AddReviewSuccess());

      // إعادة جلب التقييمات لتحديث شاشة التفاصيل
      await fetchReviews(productId);
    } catch (e) {
      emit(ReviewsError('فشل إضافة التقييم: ${e.toString()}'));
    }
  }
}