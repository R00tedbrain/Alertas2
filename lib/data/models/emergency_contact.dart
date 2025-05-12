class EmergencyContact {
  final String name;
  final String chatId;

  EmergencyContact({required this.name, required this.chatId});

  // Desde JSON
  factory EmergencyContact.fromJson(Map<String, dynamic> json) {
    return EmergencyContact(
      name: json['name'] as String,
      chatId: json['chat_id'] as String,
    );
  }

  // A JSON
  Map<String, dynamic> toJson() {
    return {'name': name, 'chat_id': chatId};
  }

  // Copiar con
  EmergencyContact copyWith({String? name, String? chatId}) {
    return EmergencyContact(
      name: name ?? this.name,
      chatId: chatId ?? this.chatId,
    );
  }

  @override
  String toString() => 'EmergencyContact(name: $name, chatId: $chatId)';

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is EmergencyContact && other.chatId == chatId;
  }

  @override
  int get hashCode => chatId.hashCode;
}
