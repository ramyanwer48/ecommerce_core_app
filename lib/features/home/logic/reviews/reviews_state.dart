import '../../data/models/review_model.dart';

abstract class ReviewsState {}

class ReviewsInitial extends ReviewsState {}

class ReviewsLoading extends ReviewsState {}

class ReviewsLoaded extends ReviewsState {
  final List<ReviewModel> reviews;
  final double averageRating; // متوسط التقييمات

  ReviewsLoaded(this.reviews, this.averageRating);
}

class ReviewsError extends ReviewsState {
  final String error;
  ReviewsError(this.error);
}

class AddReviewLoading extends ReviewsState {}

class AddReviewSuccess extends ReviewsState {}