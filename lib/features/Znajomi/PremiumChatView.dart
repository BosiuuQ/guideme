import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:guide_me/features/znajomi/znajomi_backend.dart';

class PremiumChatView extends StatefulWidget {
  const PremiumChatView({Key? key}) : super(key: key);

  @override
  State<PremiumChatView> createState() => _PremiumChatViewState();
}

class _PremiumChatViewState extends State<PremiumChatView> {
  final TextEditingController _controller = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  String? currentUserId;

  @override
  void initState() {
    super.initState();
    _loadCurrentUserId();
  }

  Future<void> _loadCurrentUserId() async {
    final id = await ZnajomiBackend.getCurrentUserId();
    if (id == null) return;
    setState(() => currentUserId = id);
  }

  Future<void> _sendMessage() async {
    final text = _controller.text.trim();
    if (text.isNotEmpty) {
      await ZnajomiBackend.sendPremiumMessage(text);
      _controller.clear();
    }
  }

  String formatTimestamp(String? iso) {
    if (iso == null) return "";
    final ts = DateTime.parse(iso).toLocal();
    final now = DateTime.now();
    final isOlderThan24h = now.difference(ts).inHours >= 24;
    return isOlderThan24h
        ? DateFormat('dd.MM.yyyy HH:mm').format(ts)
        : DateFormat('HH:mm').format(ts);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0E0E1C),
      appBar: AppBar(
        backgroundColor: const Color(0xFF0E0E1C),
        elevation: 4,
        title: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: const [
            Icon(Icons.diamond, color: Colors.lightBlueAccent),
            SizedBox(width: 8),
            Text("Premium Chat", style: TextStyle(color: Colors.white)),
          ],
        ),
        centerTitle: true,
      ),
      body: currentUserId == null
          ? const Center(child: CircularProgressIndicator())
          : Column(
              children: [
                Expanded(
                  child: StreamBuilder<List<Map<String, dynamic>>>(
                    stream: ZnajomiBackend.premiumMessagesStream(),
                    builder: (context, snapshot) {
                      if (!snapshot.hasData) {
                        return const Center(child: CircularProgressIndicator());
                      }

                      final messages = snapshot.data!..sort((a, b) {
                        final aTime = DateTime.tryParse(a['created_at'] ?? '') ?? DateTime.now();
                        final bTime = DateTime.tryParse(b['created_at'] ?? '') ?? DateTime.now();
                        return aTime.compareTo(bTime);
                      });

                      WidgetsBinding.instance.addPostFrameCallback((_) {
                        if (_scrollController.hasClients) {
                          _scrollController.animateTo(
                            _scrollController.position.maxScrollExtent,
                            duration: const Duration(milliseconds: 300),
                            curve: Curves.easeOut,
                          );
                        }
                      });

                      return ListView.builder(
                        controller: _scrollController,
                        padding: const EdgeInsets.all(16),
                        itemCount: messages.length,
                        itemBuilder: (context, index) {
                          final msg = messages[index];
                          final isMe = msg['sender_id'] == currentUserId;
                          final text = msg['text'] ?? '';
                          final nickname = msg['sender_nickname'] ?? 'Użytkownik';
                          final time = formatTimestamp(msg['created_at']);

                          return Align(
                            alignment: isMe ? Alignment.centerRight : Alignment.centerLeft,
                            child: IntrinsicWidth(
                              child: ConstrainedBox(
                                constraints: BoxConstraints(
                                  maxWidth: MediaQuery.of(context).size.width * 0.75,
                                ),
                                child: Container(
                                  margin: const EdgeInsets.symmetric(vertical: 6),
                                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                                  decoration: BoxDecoration(
                                    color: isMe ? Colors.blueAccent.withOpacity(0.9) : Colors.white10,
                                    borderRadius: BorderRadius.only(
                                      topLeft: const Radius.circular(16),
                                      topRight: const Radius.circular(16),
                                      bottomLeft: Radius.circular(isMe ? 16 : 4),
                                      bottomRight: Radius.circular(isMe ? 4 : 16),
                                    ),
                                  ),
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        nickname,
                                        style: const TextStyle(fontSize: 12, color: Colors.white70),
                                      ),
                                      const SizedBox(height: 4),
                                      Text(
                                        text,
                                        style: const TextStyle(fontSize: 15, color: Colors.white),
                                      ),
                                      Align(
                                        alignment: Alignment.bottomRight,
                                        child: Text(
                                          time,
                                          style: const TextStyle(fontSize: 11, color: Colors.white54),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ),
                          );
                        },
                      );
                    },
                  ),
                ),
                _chatInput(),
              ],
            ),
    );
  }

  Widget _chatInput() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: const BoxDecoration(
        color: Color(0xFF1A1A2E),
        boxShadow: [
          BoxShadow(
            color: Colors.black54,
            blurRadius: 6,
            offset: Offset(0, -2),
          ),
        ],
      ),
      child: Row(
        children: [
          Expanded(
            child: TextField(
              controller: _controller,
              style: const TextStyle(color: Colors.white),
              decoration: InputDecoration(
                hintText: "Napisz wiadomość...",
                hintStyle: const TextStyle(color: Colors.white38),
                filled: true,
                fillColor: const Color(0xFF2A2A40),
                contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(16),
                  borderSide: BorderSide.none,
                ),
              ),
              onSubmitted: (_) => _sendMessage(),
            ),
          ),
          const SizedBox(width: 8),
          GestureDetector(
            onTap: _sendMessage,
            child: Container(
              padding: const EdgeInsets.all(12),
              decoration: const BoxDecoration(
                color: Colors.lightBlueAccent,
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.send, color: Colors.white),
            ),
          ),
        ],
      ),
    );
  }
}
