import 'package:flutter/material.dart';
import '../../services/google_image_service.dart';

class GoogleImagePickerDialog extends StatefulWidget {
  final String productName;

  const GoogleImagePickerDialog({Key? key, required this.productName}) : super(key: key);

  @override
  State<GoogleImagePickerDialog> createState() => _GoogleImagePickerDialogState();
}

class _GoogleImagePickerDialogState extends State<GoogleImagePickerDialog> {
  List<String> imageUrls = [];
  Set<String> selectedUrls = {}; // 👈 تخزين الصور المحددة هنا
  bool isLoading = true;
  bool isUploading = false;
  String? errorMessage;

  @override
  void initState() {
    super.initState();
    _fetchImages();
  }

  Future<void> _fetchImages() async {
    try {
      final urls = await GoogleImageService.fetchImageUrls(widget.productName);
      setState(() {
        imageUrls = urls;
        isLoading = false;
      });
    } catch (e) {
      setState(() {
        errorMessage = e.toString();
        isLoading = false;
      });
    }
  }

  // 👈 دالة رفع كل الصور المحددة بضغطة واحدة
  Future<void> _uploadSelectedImages() async {
    if (selectedUrls.isEmpty) return;

    setState(() => isUploading = true);
    try {
      final firebaseStorageUrls = await GoogleImageService.downloadAndUploadMultipleImages(selectedUrls.toList());

      if (mounted) {
        Navigator.pop(context, firebaseStorageUrls); // إرجاع "قائمة" الروابط
      }
    } catch (e) {
      setState(() {
        isUploading = false;
        errorMessage = 'فشل في رفع بعض الصور، حاول مرة أخرى';
      });
    }
  }

  void _toggleSelection(String url) {
    setState(() {
      if (selectedUrls.contains(url)) {
        selectedUrls.remove(url);
      } else {
        selectedUrls.add(url);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text('اختر الصور لـ: ${widget.productName}', style: const TextStyle(fontSize: 16, fontFamily: 'Cairo', fontWeight: FontWeight.bold)),
      content: SizedBox(
        width: double.maxFinite,
        height: 350,
        child: isLoading
            ? const Center(child: CircularProgressIndicator())
            : isUploading
            ? Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const CircularProgressIndicator(),
              const SizedBox(height: 15),
              Text('جاري رفع ${selectedUrls.length} صور للسيرفر... 🚀', style: const TextStyle(fontWeight: FontWeight.bold, fontFamily: 'Cairo')),
            ],
          ),
        )
            : errorMessage != null
            ? Center(child: Text(errorMessage!, style: const TextStyle(color: Colors.red, fontFamily: 'Cairo')))
            : imageUrls.isEmpty
            ? const Center(child: Text('لم يتم العثور على صور.', style: TextStyle(fontFamily: 'Cairo')))
            : GridView.builder(
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 2,
            crossAxisSpacing: 10,
            mainAxisSpacing: 10,
          ),
          itemCount: imageUrls.length,
          itemBuilder: (context, index) {
            final url = imageUrls[index];
            final isSelected = selectedUrls.contains(url);

            return GestureDetector(
              onTap: () => _toggleSelection(url),
              child: Container(
                decoration: BoxDecoration(
                  border: Border.all(color: isSelected ? Colors.green : Colors.grey.shade300, width: isSelected ? 3 : 1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    ClipRRect(
                      borderRadius: BorderRadius.circular(6),
                      child: Image.network(
                        url,
                        fit: BoxFit.cover,
                        loadingBuilder: (context, child, loadingProgress) {
                          if (loadingProgress == null) return child;
                          return const Center(child: CircularProgressIndicator(strokeWidth: 2));
                        },
                      ),
                    ),
                    if (isSelected)
                      Container(
                        decoration: BoxDecoration(color: Colors.black.withValues(alpha: 0.4), borderRadius: BorderRadius.circular(6)),
                        child: const Icon(Icons.check_circle, color: Colors.green, size: 40),
                      ),
                  ],
                ),
              ),
            );
          },
        ),
      ),
      actions: [
        TextButton(
          onPressed: isUploading ? null : () => Navigator.pop(context),
          child: const Text('إلغاء', style: TextStyle(color: Colors.red, fontFamily: 'Cairo', fontWeight: FontWeight.bold)),
        ),
        if (selectedUrls.isNotEmpty && !isUploading)
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.green),
            onPressed: _uploadSelectedImages,
            child: Text('تأكيد (${selectedUrls.length})', style: const TextStyle(color: Colors.white, fontFamily: 'Cairo', fontWeight: FontWeight.bold)),
          ),
      ],
    );
  }
}