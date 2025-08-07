import 'dart:convert';

class Viewpoint {
  final String id;
  final String creatorId;
  final String title;
  final String description;
  final String imageUrl;
  final int likes;
  final int rating;
  final MapPoint coordinates;
  final String address;
  final bool isFavourite;
  final Map<String, dynamic>? user; // Dane autora (opcjonalne)

  Viewpoint({
    required this.id,
    required this.creatorId,
    required this.title,
    required this.description,
    required this.imageUrl,
    required this.likes,
    required this.rating,
    required this.coordinates,
    required this.address,
    required this.isFavourite,
    this.user,
  });

  /// Getter alias dla `creatorId`, by umożliwić użycie `.userId` w kodzie UI
  String get userId => creatorId;

  factory Viewpoint.fromMap(Map<String, dynamic> map) {
    final locationData = map['location'];
    final Map<String, dynamic> locationJson = locationData is String
        ? jsonDecode(locationData)
        : Map<String, dynamic>.from(locationData);
    
    return Viewpoint(
      id: map['id'].toString(),
      creatorId: map['author_id'].toString(),
      title: map['title'] ?? '',
      description: map['description'] ?? '',
      imageUrl: map['image_url'] ?? '',
      likes: map['likes'] ?? 0,
      rating: map['rating'] ?? 0,
      coordinates: MapPoint.fromJson(locationJson),
      address: map['address'] ?? '',
      isFavourite: false,
      user: map['user'] != null ? Map<String, dynamic>.from(map['user']) : null,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'author_id': creatorId,
      'title': title,
      'description': description,
      'image_url': imageUrl,
      'likes': likes,
      'rating': rating,
      'location': coordinates.toJson(),
      'address': address,
      // Nie przesyłamy 'user' przy zapisie
    };
  }
}

// Klasa MapPoint do współrzędnych GPS
class MapPoint {
  final double x; // longitude
  final double y; // latitude

  const MapPoint({required this.x, required this.y});

  factory MapPoint.fromJson(Map<String, dynamic> json) {
    return MapPoint(
      x: (json['lng'] ?? 0).toDouble(),
      y: (json['lat'] ?? 0).toDouble(),
    );
  }

  Map<String, dynamic> toJson() => {
        'lat': y,
        'lng': x,
      };
}
