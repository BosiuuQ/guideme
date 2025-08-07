class Event {
  final String id;
  final String title;
  final String description;
  final String location;
  final DateTime startTime;
  final DateTime endTime;
  final String type; // 'official' lub 'community'
  final String imageUrl;
  final String creatorId;

  Event({
    required this.id,
    required this.title,
    required this.description,
    required this.location,
    required this.startTime,
    required this.endTime,
    required this.type,
    required this.imageUrl,
    required this.creatorId,
  });

  factory Event.fromMap(Map<String, dynamic> map) {
    return Event(
      id: map['id'],
      title: map['title'],
      description: map['description'],
      location: map['location'],
      startTime: DateTime.parse(map['start_time']),
      endTime: DateTime.parse(map['end_time']),
      type: map['type'],
      imageUrl: map['image_url'],
      creatorId: map['creator_id'],
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'title': title,
      'description': description,
      'location': location,
      'start_time': startTime.toIso8601String(),
      'end_time': endTime.toIso8601String(),
      'type': type,
      'image_url': imageUrl,
      'creator_id': creatorId,
    };
  }
}
