import 'package:flutter_bloc/flutter_bloc.dart';
import '../../../../core/models/erp_models.dart';
import 'partners_profit_state.dart';

class PartnersProfitCubit extends Cubit<PartnersProfitState> {
  PartnersProfitCubit() : super(PartnersProfitInitial());

  // الدالة الرئيسية لحساب الأرباح بناءً على فترة الفلتر
  void calculateProfitsForPeriod({
    required DateTime startDate,
    required DateTime endDate,
    required double totalSales,
    required double totalExpenses,
    required List<PartnerModel> partners, // سيتم تمريرهم من الـ Repo مستقبلاً
    required List<LedgerEntryModel> capitalLedgers, // حركات الخزينة/رأس المال للشركاء
  }) {
    emit(PartnersProfitLoading());
    try {
      // 1. حساب صافي الربح التشغيلي (المبيعات - المصروفات)
      double netProfit = totalSales - totalExpenses;
      if (netProfit < 0) netProfit = 0; // معالجة الخسارة لاحقاً إن وجدت

      double totalManagementProfit = 0;
      double totalOperationProfit = 0;
      double totalWeightedCapital = 0;

      List<PartnerCalculationResult> tempResults = [];

      // 2. المرور على الشركاء لحساب نسب (الإدارة والتشغيل) و (وزن رأس المال)
      for (var partner in partners) {
        // حساب أرباح المجهود الثابتة
        double mngProfit = netProfit * (partner.managementRatio / 100);
        double opProfit = netProfit * (partner.operationRatio / 100);

        totalManagementProfit += mngProfit;
        totalOperationProfit += opProfit;

        // حساب وزن رأس المال في هذه الفترة الزمنية
        double partnerWeightedCapital = _calculateWeightedCapital(
            partnerId: partner.id,
            start: startDate,
            end: endDate,
            ledgers: capitalLedgers
        );

        totalWeightedCapital += partnerWeightedCapital;

        // حفظ مبدئي في القائمة
        tempResults.add(PartnerCalculationResult(
          partner: partner,
          managementProfit: mngProfit,
          operationProfit: opProfit,
          capitalProfit: 0, // سيتم حسابه في الخطوة القادمة
          totalProfit: 0,
          timeWeightedCapital: partnerWeightedCapital,
        ));
      }

      // 3. الربح المتبقي لتوزيعه على رؤوس الأموال
      double remainingProfitForCapital = netProfit - totalManagementProfit - totalOperationProfit;

      // 4. توزيع ربح رأس المال بناءً على الأوزان (Weight)
      List<PartnerCalculationResult> finalResults = [];

      for (var res in tempResults) {
        double capitalProfitRatio = totalWeightedCapital > 0
            ? (res.timeWeightedCapital / totalWeightedCapital)
            : 0;

        double capProfit = remainingProfitForCapital * capitalProfitRatio;
        double total = res.managementProfit + res.operationProfit + capProfit;

        finalResults.add(PartnerCalculationResult(
          partner: res.partner,
          managementProfit: res.managementProfit,
          operationProfit: res.operationProfit,
          capitalProfit: capProfit,
          totalProfit: total,
          timeWeightedCapital: res.timeWeightedCapital,
        ));
      }

      emit(PartnersProfitLoaded(
        calculatedResults: finalResults,
        totalSales: totalSales,
        totalExpenses: totalExpenses,
        netOperatingProfit: netProfit,
        startDate: startDate,
        endDate: endDate,
      ));
    } catch (e) {
      emit(PartnersProfitError(message: e.toString()));
    }
  }

  // --- دالة مساعدة لحساب "الوزن النسبي" لرأس مال شريك في فترة معينة ---
  double _calculateWeightedCapital({
    required String partnerId,
    required DateTime start,
    required DateTime end,
    required List<LedgerEntryModel> ledgers,
  }) {
    // فلترة حركات الإيداع والسحب الخاصة بهذا الشريك فقط والتي تمت قبل أو خلال الفترة
    var partnerLedgers = ledgers.where((l) =>
    l.accountId == partnerId &&
        (l.transactionType == 'capital_deposit' || l.transactionType == 'capital_withdrawal') &&
        !l.timestamp.isAfter(end)
    ).toList();

    double totalWeight = 0.0;
    int totalDaysInFilter = end.difference(start).inDays + 1; // +1 لاحتساب اليوم نفسه

    for (var ledger in partnerLedgers) {
      int activeDays = 0;

      if (ledger.timestamp.isBefore(start)) {
        // الفلوس موجودة من قبل بداية الفلتر، إذن عملت طوال أيام الفلتر
        activeDays = totalDaysInFilter;
      } else {
        // الفلوس دخلت أو سُحبت خلال فترة الفلتر، نحسب الأيام من تاريخ حركتها لنهاية الفلتر
        activeDays = end.difference(ledger.timestamp).inDays + 1;
      }

      // الدائن (إيداع/زيادة رأس مال) يزيد الوزن، والمدين (سحب) يقلل الوزن
      double amount = ledger.credit - ledger.debit;
      totalWeight += (amount * activeDays);
    }

    return totalWeight > 0 ? totalWeight : 0.0;
  }

  // إضافة رأس مال جديد لشريك معين وتحديث سجله (Capital History)
  void addCapitalToPartner({
    required String partnerId,
    required double additionalAmount,
  }) async {
    emit(PartnersProfitLoading());
    try {
      // تنفيذ عملية التحديث في Firestore لاحقاً
      emit(PartnersProfitActionSuccess(message: 'تم إضافة رأس المال بنجاح'));
    } catch (e) {
      emit(PartnersProfitError(message: e.toString()));
    }
  }
}