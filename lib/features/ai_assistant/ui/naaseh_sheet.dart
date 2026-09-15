// lib/features/ai_assistant/ui/naaseh_sheet.dart
import 'package:flutter/material.dart';
import 'package:cloud_functions/cloud_functions.dart';

class NaasehSheet extends StatefulWidget {
  const NaasehSheet({super.key});

  @override
  State<NaasehSheet> createState() => _NaasehSheetState();
}

class _NaasehSheetState extends State<NaasehSheet> {
  final TextEditingController _controller = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  final List<Map<String, String>> _messages = [];
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _messages.add({
      'sender': 'naaseh',
      'text': 'أهلاً بك في Ramy Store! أنا "ناصح"، المهندس التقني الخاص بك. كيف يمكنني مساعدتك اليوم؟'
    });
  }

  Future<void> _askNaaseh() async {
    final text = _controller.text.trim();
    if (text.isEmpty) return;

    setState(() {
      _messages.add({'sender': 'user', 'text': text});
      _isLoading = true;
      _controller.clear();
    });

    _scrollToBottom();

    try {
      final res = await FirebaseFunctions.instance
          .httpsCallable('askNaaseh')
          .call({'prompt': text});

      final reply = res.data['reply'] ?? 'عفواً، لم أتمكن من معالجة طلبك حالياً.';

      setState(() {
        _messages.add({'sender': 'naaseh', 'text': reply});
      });

    } on FirebaseFunctionsException catch (e) {
      // 💡 قراءة وعرض الخطأ الفعلي القادم من السيرفر
      setState(() {
        _messages.add({
          'sender': 'naaseh',
          'text': 'خطأ من السيرفر ⚠️: ${e.message}'
        });
      });
    } catch (e) {
      setState(() {
        _messages.add({
          'sender': 'naaseh',
          'text': 'حدث خطأ في الاتصال ⚠️: ${e.toString()}'
        });
      });
    } finally {
      setState(() {
        _isLoading = false;
      });
      _scrollToBottom();
    }
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final screenHeight = MediaQuery.of(context).size.height;

    return Container(
      height: screenHeight * 0.75,
      padding: EdgeInsets.only(
        top: 16,
        left: 16,
        right: 16,
        bottom: MediaQuery.of(context).viewInsets.bottom + 16,
      ),
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Row(
                children: [
                  Text('🤖', style: TextStyle(fontSize: 24)),
                  SizedBox(width: 12),
                  Text(
                    'المهندس ناصح',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF000826),
                    ),
                  ),
                ],
              ),
              IconButton(
                icon: const Icon(Icons.close, color: Colors.grey),
                onPressed: () => Navigator.pop(context),
              ),
            ],
          ),
          const Divider(thickness: 1),

          Expanded(
            child: ListView.builder(
              controller: _scrollController,
              itemCount: _messages.length,
              itemBuilder: (context, index) {
                final msg = _messages[index];
                final isUser = msg['sender'] == 'user';

                return Align(
                  alignment: isUser ? Alignment.centerRight : Alignment.centerLeft,
                  child: Container(
                    margin: const EdgeInsets.symmetric(vertical: 6),
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    constraints: BoxConstraints(
                      maxWidth: MediaQuery.of(context).size.width * 0.75,
                    ),
                    decoration: BoxDecoration(
                      color: isUser ? const Color(0xFF00D4FF) : const Color(0xFFF5F7FA),
                      borderRadius: BorderRadius.only(
                        topLeft: const Radius.circular(16),
                        topRight: const Radius.circular(16),
                        bottomLeft: Radius.circular(isUser ? 16 : 0),
                        bottomRight: Radius.circular(isUser ? 0 : 16),
                      ),
                    ),
                    child: Text(
                      msg['text'] ?? '',
                      style: TextStyle(
                        color: isUser ? Colors.white : const Color(0xFF000826),
                        fontSize: 15,
                        height: 1.4,
                      ),
                    ),
                  ),
                );
              },
            ),
          ),

          if (_isLoading)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 8.0),
              child: LinearProgressIndicator(
                color: Color(0xFF00D4FF),
                backgroundColor: Color(0xFFE0E0E0),
              ),
            ),

          const SizedBox(height: 8),

          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _controller,
                  textInputAction: TextInputAction.send,
                  onSubmitted: (_) => _isLoading ? null : _askNaaseh(),
                  decoration: InputDecoration(
                    hintText: 'اسأل عن منتج، ميزانية، أو مقارنة...',
                    hintStyle: const TextStyle(fontSize: 13),
                    filled: true,
                    fillColor: const Color(0xFFF5F7FA),
                    contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(24),
                      borderSide: BorderSide.none,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              CircleAvatar(
                radius: 24,
                backgroundColor: const Color(0xFF000826),
                child: IconButton(
                  icon: const Icon(Icons.send_rounded, color: Colors.white, size: 20),
                  onPressed: _isLoading ? null : _askNaaseh,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}