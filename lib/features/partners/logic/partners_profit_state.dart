import '../../../../core/models/erp_models.dart';

abstract class PartnersProfitState {}

class PartnersProfitInitial extends PartnersProfitState {}

class PartnersProfitLoading extends PartnersProfitState {}

// هذا الكلاس الوسيط لتسهيل عرض نتائج كل شريك في الواجهة
class PartnerCalculationResult {
  final PartnerModel partner;
  final double managementProfit; // ربح الإدارة
  final double operationProfit; // ربح التشغيل
  final double capitalProfit; // ربح رأس المال (بناءً على الأيام)
  final double totalProfit; // إجمالي ما يستحقه الشريك
  final double timeWeightedCapital; // وزن رأس ماله (المبلغ × الأيام)

  PartnerCalculationResult({
    required this.partner,
    required this.managementProfit,
    required this.operationProfit,
    required this.capitalProfit,
    required this.totalProfit,
    required this.timeWeightedCapital,
  });
}

class PartnersProfitLoaded extends PartnersProfitState {
  final List<PartnerCalculationResult> calculatedResults;
  final double totalSales;
  final double totalExpenses;
  final double netOperatingProfit;
  final DateTime startDate; // بداية فترة الفلتر
  final DateTime endDate;   // نهاية فترة الفلتر

  PartnersProfitLoaded({
    required this.calculatedResults,
    required this.totalSales,
    required this.totalExpenses,
    required this.netOperatingProfit,
    required this.startDate,
    required this.endDate,
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