abstract class AdminReturnsState {}

class AdminReturnsInitial extends AdminReturnsState {}

class AdminReturnsLoading extends AdminReturnsState {}

class AdminReturnsLoaded extends AdminReturnsState {
  final List pendingReturns;
  AdminReturnsLoaded(this.pendingReturns);
}

class AdminReturnsActionLoading extends AdminReturnsState {}

class AdminReturnsActionSuccess extends AdminReturnsState {
  final String message;
  AdminReturnsActionSuccess(this.message);
}

class AdminReturnsError extends AdminReturnsState {
  final String error;
  AdminReturnsError(this.error);
}