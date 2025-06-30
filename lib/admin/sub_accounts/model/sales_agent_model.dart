class SalesAgent {
  final String id;
  final String name;
  final String location;

  SalesAgent({
    required this.id,
    required this.name,
    required this.location,
  });

  factory SalesAgent.fromJson(Map<String, dynamic> json) {
    return SalesAgent(
      id: json['id'],
      name: json['name'],
      location: json['location'],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'location': location,
    };
  }
}
