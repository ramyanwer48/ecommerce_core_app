abstract class PartnersProfitState {}

class PartnersProfitInitial extends PartnersProfitState {}

class PartnersProfitLoading extends PartnersProfitState {}

class PartnersProfitLoaded extends PartnersProfitState {
  final List<dynamic> partners; // قائمة الشركاء
  final double managementPoolPercentage; // نسبة الإدارة الكلية (مثل 30%)
  final double totalSales;
  final double totalExpenses;
  final double netOperatingProfit;

  PartnersProfitLoaded({
    required this.partners,
    required this.managementPoolPercentage,
    required this.totalSales,
    required this.totalExpenses,
    required this.netOperatingProfit,
  });
}

class PartnersProfitError extends PartnersProfitState {
  final String message;
  PartnersProfitError({required this.message});
}

class PartnersProfitActionSuccess extends PartnersProfitState {
  final String message;
  PartnersProfitActionSuccess({required this.message});
}