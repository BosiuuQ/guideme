// Finalny plik chat_view.dart

import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path/path.dart' as p;
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:uuid/uuid.dart';

class ChatView extends StatefulWidget {
  final String friendId;
  final String friendNickname;

  const ChatView({
    super.key,
    required this.friendId,
    required this.friendNickname,
  });

  @override
  State<ChatView> createState() => _ChatViewState();
}

class _ChatViewState extends State<ChatView> {
  final _messageController = TextEditingController();
  final _scrollController = ScrollController();
  final ImagePicker _picker = ImagePicker();
  final Map<String, bool> _expandedMessageIds = {};

  String? _chatId;
  late final String _currentUserId;

  String? _friendAvatarUrl;
  DateTime? _friendLastOnline;

  bool _shouldScroll = false;

  @override
  void initState() {
    super.initState();
    _currentUserId = Supabase.instance.client.auth.currentUser!.id;
    _chatId = _generateChatId(_currentUserId, widget.friendId);
    _loadFriendInfo();
  }

  String _generateChatId(String a, String b) {
    final ids = [a, b]..sort();
    return ids.join('_');
  }

  Future<void> _loadFriendInfo() async {
    final data = await Supabase.instance.client
        .from('users')
        .select('avatar, last_online')
        .eq('id', widget.friendId)
        .single();

    setState(() {
      _friendAvatarUrl = data['avatar'] as String?;
      _friendLastOnline = DateTime.tryParse(data['last_online']);
    });
  }

  Stream<List<Map<String, dynamic>>> getMessagesStream() {
    return Supabase.instance.client
        .from('private_messages')
        .stream(primaryKey: ['id'])
        .eq('chat_id', _chatId!)
        .order('created_at', ascending: true)
        .map((data) {
          setState(() => _shouldScroll = true);
          return data;
        });
  }

  Future<void> _sendMessage() async {
    final text = _messageController.text.trim();
    if (text.isEmpty || _chatId == null) return;

    await Supabase.instance.client.from('private_messages').insert({
      'chat_id': _chatId,
      'sender_id': _currentUserId,
      'receiver_id': widget.friendId,
      'text': text,
      'created_at': DateTime.now().toIso8601String(),
    });

    _messageController.clear();
    setState(() {}); // Wymuś rebuild i scroll
  }

  Future<void> _pickAndSendImage(ImageSource source) async {
    final XFile? image = await _picker.pickImage(source: source, imageQuality: 80);
    if (image == null) return;

    final fileBytes = await image.readAsBytes();
    final fileExt = p.extension(image.name);
    final fileName = const Uuid().v4() + fileExt;
    final path = 'chatyprywatnezdjecia/$fileName';

    await Supabase.instance.client.storage
        .from('chatyprywatnezdjecia')
        .uploadBinary(path, fileBytes, fileOptions: const FileOptions(contentType: 'image/jpeg'));

    final publicUrl = Supabase.instance.client.storage
        .from('chatyprywatnezdjecia')
        .getPublicUrl(path);

    await Supabase.instance.client.from('private_messages').insert({
      'chat_id': _chatId,
      'sender_id': _currentUserId,
      'receiver_id': widget.friendId,
      'image_url': publicUrl,
      'created_at': DateTime.now().toIso8601String(),
    });

    setState(() {}); // Wymuś rebuild i scroll
  }

  void _scrollToBottom() {
    if (_scrollController.hasClients) {
      _scrollController.animateTo(
        _scrollController.position.maxScrollExtent,
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeOut,
      );
    }
  }

  String _formatTimestamp(DateTime dt) {
    final now = DateTime.now();
    final diff = now.difference(dt);
    if (diff.inHours < 24) {
      return "${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}";
    } else {
      return "${dt.day.toString().padLeft(2, '0')}.${dt.month.toString().padLeft(2, '0')} ${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}";
    }
  }

  String _formatLastSeen() {
    if (_friendLastOnline == null) return "Nieaktywny";
    final now = DateTime.now();
    final diff = now.difference(_friendLastOnline!);
    if (diff.inHours < 24) {
      return "Aktywny: ${diff.inHours} godz. temu";
    } else {
      return "Aktywny: ${_friendLastOnline!.day.toString().padLeft(2, '0')}.${_friendLastOnline!.month.toString().padLeft(2, '0')} o ${_friendLastOnline!.hour.toString().padLeft(2, '0')}:${_friendLastOnline!.minute.toString().padLeft(2, '0')}";
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        title: Row(
          children: [
            CircleAvatar(
              backgroundImage: _friendAvatarUrl != null
                  ? NetworkImage(_friendAvatarUrl!)
                  : const AssetImage('assets/images/default_avatar.png') as ImageProvider,
              radius: 20,
            ),
            const SizedBox(width: 12),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(widget.friendNickname, style: const TextStyle(fontSize: 18)),
                Text(
                  _formatLastSeen(),
                  style: const TextStyle(fontSize: 12, color: Colors.white70),
                ),
              ],
            )
          ],
        ),
      ),
      body: Column(
        children: [
          Expanded(
            child: _chatId == null
                ? const Center(child: CircularProgressIndicator())
                : StreamBuilder<List<Map<String, dynamic>>>(
                    stream: getMessagesStream(),
                    builder: (context, snapshot) {
                      if (!snapshot.hasData) {
                        return const Center(child: CircularProgressIndicator());
                      }
                      final messages = snapshot.data!;
                      if (_shouldScroll) {
                        WidgetsBinding.instance.addPostFrameCallback((_) {
                          _scrollToBottom();
                          _shouldScroll = false;
                        });
                      }
                      return ListView.builder(
                        controller: _scrollController,
                        itemCount: messages.length,
                        padding: const EdgeInsets.all(12),
                        itemBuilder: (context, index) {
                          final msg = messages[index];
                          final isMe = msg['sender_id'] == _currentUserId;
                          final createdAt = DateTime.tryParse(msg['created_at'] ?? '') ?? DateTime.now();
                          final isExpanded = _expandedMessageIds[msg['id']] == true;
                          return GestureDetector(
                            onTap: () {
                              setState(() {
                                _expandedMessageIds[msg['id']] = !isExpanded;
                              });
                            },
                            child: Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              mainAxisAlignment: isMe ? MainAxisAlignment.end : MainAxisAlignment.start,
                              children: [
                                if (!isMe)
                                  Padding(
                                    padding: const EdgeInsets.only(right: 8),
                                    child: CircleAvatar(
                                      radius: 18,
                                      backgroundImage: _friendAvatarUrl != null
                                          ? NetworkImage(_friendAvatarUrl!)
                                          : const AssetImage('assets/images/default_avatar.png') as ImageProvider,
                                    ),
                                  ),
                                Flexible(
                                  child: Column(
                                    crossAxisAlignment: isMe ? CrossAxisAlignment.end : CrossAxisAlignment.start,
                                    children: [
                                      Container(
                                        padding: const EdgeInsets.all(12),
                                        margin: const EdgeInsets.symmetric(vertical: 4),
                                        decoration: BoxDecoration(
                                          color: isMe ? Colors.blue : Colors.grey[700],
                                          borderRadius: BorderRadius.circular(16),
                                        ),
                                        child: msg['image_url'] != null
                                            ? GestureDetector(
                                                onTap: () {
                                                  showDialog(
                                                    context: context,
                                                    builder: (_) => Dialog(
                                                      backgroundColor: Colors.black,
                                                      child: Stack(
                                                        children: [
                                                          Center(
                                                            child: InteractiveViewer(
                                                              child: Image.network(msg['image_url']),
                                                            ),
                                                          ),
                                                          Positioned(
                                                            top: 10,
                                                            right: 10,
                                                            child: IconButton(
                                                              icon: const Icon(Icons.close, color: Colors.white),
                                                              onPressed: () => Navigator.of(context).pop(),
                                                            ),
                                                          ),
                                                        ],
                                                      ),
                                                    ),
                                                  );
                                                },
                                                child: ClipRRect(
                                                  borderRadius: BorderRadius.circular(12),
                                                  child: Image.network(
                                                    msg['image_url'],
                                                    width: 180,
                                                    fit: BoxFit.cover,
                                                    loadingBuilder: (context, child, progress) {
                                                      if (progress == null) return child;
                                                      return Container(
                                                        width: 180,
                                                        height: 150,
                                                        alignment: Alignment.center,
                                                        child: const CircularProgressIndicator(),
                                                      );
                                                    },
                                                  ),
                                                ),
                                              )
                                            : Text(
                                                msg['text'] ?? '',
                                                style: const TextStyle(color: Colors.white),
                                              ),
                                      ),
                                      if (isExpanded)
                                        Padding(
                                          padding: const EdgeInsets.only(bottom: 4),
                                          child: Text(
                                            _formatTimestamp(createdAt),
                                            style: const TextStyle(color: Colors.white60, fontSize: 11),
                                          ),
                                        ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          );
                        },
                      );
                    },
                  ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            color: Colors.black,
            child: Row(
              children: [
                IconButton(
                  icon: const Icon(Icons.camera_alt, color: Colors.white),
                  onPressed: () => _pickAndSendImage(ImageSource.camera),
                ),
                IconButton(
                  icon: const Icon(Icons.photo, color: Colors.white),
                  onPressed: () => _pickAndSendImage(ImageSource.gallery),
                ),
                Expanded(
                  child: TextField(
                    controller: _messageController,
                    style: const TextStyle(color: Colors.white),
                    decoration: InputDecoration(
                      hintText: 'Napisz wiadomość...',
                      hintStyle: const TextStyle(color: Colors.white54),
                      filled: true,
                      fillColor: Colors.grey[850],
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(30),
                        borderSide: BorderSide.none,
                      ),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 20),
                    ),
                    onSubmitted: (_) => _sendMessage(),
                  ),
                ),
                const SizedBox(width: 8),
                IconButton(
                  icon: const Icon(Icons.send, color: Colors.lightBlueAccent),
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