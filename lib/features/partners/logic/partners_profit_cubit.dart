import 'package:flutter_bloc/flutter_bloc.dart';
import 'partners_profit_state.dart';
// استيراد النماذج من المسار المناسب لديك
// import '.../erp_models.dart';

class PartnersProfitCubit extends Cubit<PartnersProfitState> {
  PartnersProfitCubit() : super(PartnersProfitInitial());

  // جلب بيانات الشركاء وحساب الأرباح الشهرية
  void fetchPartnersAndProfits({
    required double totalSales,
    required double totalExpenses,
  }) {
    emit(PartnersProfitLoading());
    try {
      // هنا سيتم جلب البيانات من الـ Firestore وحساب:
      // 1. إجمالي الربح التشغيلي = totalSales - totalExpenses
      // 2. تطبيق نسبة الإدارة (مثلاً 30%) وتوزيعها
      // 3. توزيع باقي الربح على رؤوس الأموال النسبية

      double netProfit = totalSales - totalExpenses;

      emit(PartnersProfitLoaded(
        partners: [], // يتم تعبئتها من قاعدة البيانات
        managementPoolPercentage: 30.0,
        totalSales: totalSales,
        totalExpenses: totalExpenses,
        netOperatingProfit: netProfit > 0 ? netProfit : 0.0,
      ));
    } catch (e) {
      emit(PartnersProfitError(message: e.toString()));
    }
  }

  // تحديث نسبة الإدارة العامة أو نسب الشركاء في الـ Firestore
  void updateProfitSettings({required double newManagementPercentage}) async {
    emit(PartnersProfitLoading());
    try {
      // تنفيذ عملية التحديث في Firestore
      emit(PartnersProfitActionSuccess(message: 'تم تحديث النسب بنجاح'));
    } catch (e) {
      emit(PartnersProfitError(message: e.toString()));
    }
  }

  // إضافة رأس مال جديد لشريك معين وتحديث سجله (Capital History)
  void addCapitalToPartner({
    required String partnerId,
    required double additionalAmount,
  }) async {
    emit(PartnersProfitLoading());
    try {
      // إضافة المبلغ الجديد لسجل رأس مال الشريك في Firestore
      emit(PartnersProfitActionSuccess(message: 'تم إضافة رأس المال بنجاح'));
    } catch (e) {
      emit(PartnersProfitError(message: e.toString()));
    }
  }
}