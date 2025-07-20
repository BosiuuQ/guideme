class Friend {
  final String id;
  final String nickname;
  final String? avatar;
  final String? lastOnline;
  final String? requestId;

  Friend({
    required this.id,
    required this.nickname,
    this.avatar,
    this.lastOnline,
    this.requestId,
  });

  factory Friend.fromMap(Map<String, dynamic> map) {
    return Friend(
      id: map['id'],
      nickname: map['nickname'] ?? 'Nieznany',
      avatar: map['avatar'],
      lastOnline: map['last_online'],
      requestId: map['requestId'], // jeśli masz to pole
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'nickname': nickname,
      'avatar': avatar,
      'last_online': lastOnline,
      'requestId': requestId,
    };
  }
}
