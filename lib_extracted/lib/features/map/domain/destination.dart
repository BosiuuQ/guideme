/// Model punktu do nawigacji / wyszukiwania
class Destination {
  final String name;
  final String address;
  final double lat;
  final double lng;
  const Destination({
    required this.name,
    required this.address,
    required this.lat,
    required this.lng,
  });
}
