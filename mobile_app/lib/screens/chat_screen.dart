import 'package:flutter/material.dart';
import '../services/api_service.dart';
import 'package:glassmorphism/glassmorphism.dart';

class ChatScreen extends StatefulWidget {
  const ChatScreen({super.key});

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  final TextEditingController _controller = TextEditingController();
  final List<Map<String, String>> _messages = []; // {role: 'user' | 'ai', text: '...'}
  bool _isLoading = false;
  final ApiService _apiService = ApiService();

  void _sendMessage() async {
    if (_controller.text.isEmpty) return;

    final query = _controller.text;
    setState(() {
      _messages.add({'role': 'user', 'text': query});
      _isLoading = true;
      _controller.clear();
    });

    try {
      // Assuming we are chatting about the first device for now, or the selected one
      // Ideally, we should pass the deviceId. Let's get it from provider if available.
      // For now, hardcode or pick first.
      final devices = await _apiService.getAllDevices();
      final deviceId = devices.isNotEmpty ? devices.first.id : 'IND-MACHINE-01';

      final response = await _apiService.chatWithAI(deviceId, query);

      setState(() {
        _messages.add({'role': 'ai', 'text': response});
      });
    } catch (e) {
      setState(() {
        _messages.add({'role': 'ai', 'text': 'Error: Could not connect to AI.'});
      });
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF1E1E2C),
      appBar: AppBar(
        title: const Text('AI Assistant'),
        backgroundColor: Colors.transparent,
        elevation: 0,
      ),
      body: Column(
        children: [
          Expanded(
            child: ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: _messages.length,
              itemBuilder: (context, index) {
                final msg = _messages[index];
                final isUser = msg['role'] == 'user';
                return Align(
                  alignment: isUser ? Alignment.centerRight : Alignment.centerLeft,
                  child: Container(
                    margin: const EdgeInsets.symmetric(vertical: 4),
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: isUser ? Colors.blueAccent : Colors.white10,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      msg['text']!,
                      style: const TextStyle(color: Colors.white),
                    ),
                  ),
                );
              },
            ),
          ),
          if (_isLoading)
            const Padding(
              padding: EdgeInsets.all(8.0),
              child: CircularProgressIndicator(),
            ),
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Row(
              children: [
                Expanded(
                  child: GlassmorphicContainer(
                    width: double.infinity,
                    height: 50,
                    borderRadius: 25,
                    blur: 20,
                    alignment: Alignment.center,
                    border: 2,
                    linearGradient: LinearGradient(
                      colors: [Colors.white.withValues(alpha: 0.1), Colors.white.withValues(alpha: 0.05)],
                    ),
                    borderGradient: LinearGradient(
                      colors: [Colors.white.withValues(alpha: 0.5), Colors.white.withValues(alpha: 0.1)],
                    ),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      child: TextField(
                        controller: _controller,
                        style: const TextStyle(color: Colors.white),
                        decoration: const InputDecoration(
                          hintText: 'Ask about device status...',
                          hintStyle: TextStyle(color: Colors.white54),
                          border: InputBorder.none,
                        ),
                        onSubmitted: (_) => _sendMessage(),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                IconButton(
                  icon: const Icon(Icons.send, color: Colors.blueAccent),
                  onPressed: _sendMessage,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
