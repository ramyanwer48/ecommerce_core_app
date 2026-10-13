import 'package:flutter/material.dart';

class CustomDateRangeFilter extends StatefulWidget {
  final Function(DateTime? start, DateTime? end) onFilterChanged;

  const CustomDateRangeFilter({Key? key, required this.onFilterChanged}) : super(key: key);

  @override
  _CustomDateRangeFilterState createState() => _CustomDateRangeFilterState();
}

class _CustomDateRangeFilterState extends State<CustomDateRangeFilter> {
  DateTime? startDate;
  DateTime? endDate;

  void _pickDateRange() async {
    DateTimeRange? pickedRange = await showDateRangePicker(
      context: context,
      initialDateRange: startDate != null && endDate != null
          ? DateTimeRange(start: startDate!, end: endDate!)
          : null,
      firstDate: DateTime(2020),
      lastDate: DateTime.now().add(const Duration(days: 365)),
      // تخصيص النصوص والاتجاه لتكون "حفظ" على الشمال و"إلغاء" على اليمين
      saveText: 'حفظ',
      cancelText: 'إلغاء',
      builder: (context, child) {
        return Theme(
          data: ThemeData.light().copyWith(
            colorScheme: const ColorScheme.light(
              primary: Colors.orange,
              onPrimary: Colors.white,
              surface: Colors.white,
              onSurface: Colors.black87,
            ),
            dialogBackgroundColor: Colors.white,
          ),
          child: Directionality(
            textDirection: TextDirection.ltr, // لترتيب أزرار الحفظ والإلغاء بالعكس (حفظ شمال، إلغاء يمين)
            child: child!,
          ),
        );
      },
    );

    if (pickedRange != null) {
      setState(() {
        startDate = pickedRange.start;
        endDate = pickedRange.end;
      });
      widget.onFilterChanged(startDate, endDate);
    }
  }

  void _clearFilter() {
    setState(() {
      startDate = null;
      endDate = null;
    });
    widget.onFilterChanged(null, null);
  }

  @override
  Widget build(BuildContext context) {
    bool hasFilter = startDate != null && endDate != null;

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (hasFilter) ...[
          InkWell(
            onTap: _clearFilter,
            borderRadius: BorderRadius.circular(8),
            child: Container(
              padding: const EdgeInsets.all(7),
              decoration: BoxDecoration(
                color: Colors.white,
                border: Border.all(color: Colors.red, width: 1.3),
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Icon(Icons.close, color: Colors.red, size: 18),
            ),
          ),
          const SizedBox(width: 6),
        ],
        InkWell(
          onTap: _pickDateRange,
          borderRadius: BorderRadius.circular(8),
          child: Container(
            padding: const EdgeInsets.all(7),
            decoration: BoxDecoration(
              color: Colors.white,
              border: Border.all(color: Colors.orange, width: 1.3),
              borderRadius: BorderRadius.circular(8),
            ),
            child: const Icon(
              Icons.tune_rounded,
              color: Colors.orange,
              size: 18,
            ),
          ),
        ),
      ],
    );
  }
}