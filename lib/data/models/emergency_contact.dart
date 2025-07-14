class EmergencyContact {
  final String name;
  final String chatId;
  final String? whatsappNumber; // Nuevo: número de WhatsApp
  final bool telegramEnabled; // Nuevo: servicio Telegram habilitado
  final bool whatsappEnabled; // Nuevo: servicio WhatsApp habilitado

  EmergencyContact({
    required this.name,
    required this.chatId,
    this.whatsappNumber,
    this.telegramEnabled = true, // Por defecto habilitado para compatibilidad
    this.whatsappEnabled = false, // Por defecto deshabilitado
  });

  // Desde JSON
  factory EmergencyContact.fromJson(Map<String, dynamic> json) {
    return EmergencyContact(
      name: json['name'] as String,
      chatId: json['chat_id'] as String,
      whatsappNumber: json['whatsapp_number'] as String?,
      telegramEnabled: json['telegram_enabled'] as bool? ?? true,
      whatsappEnabled: json['whatsapp_enabled'] as bool? ?? false,
    );
  }

  // A JSON
  Map<String, dynamic> toJson() {
    return {
      'name': name,
      'chat_id': chatId,
      if (whatsappNumber != null) 'whatsapp_number': whatsappNumber,
      'telegram_enabled': telegramEnabled,
      'whatsapp_enabled': whatsappEnabled,
    };
  }

  // Métodos helper para validación
  bool get hasValidTelegram => telegramEnabled && chatId.isNotEmpty;
  bool get hasValidWhatsApp =>
      whatsappEnabled && whatsappNumber != null && whatsappNumber!.isNotEmpty;

  // Copia con cambios
  EmergencyContact copyWith({
    String? name,
    String? chatId,
    String? whatsappNumber,
    bool? telegramEnabled,
    bool? whatsappEnabled,
  }) {
    return EmergencyContact(
      name: name ?? this.name,
      chatId: chatId ?? this.chatId,
      whatsappNumber: whatsappNumber ?? this.whatsappNumber,
      telegramEnabled: telegramEnabled ?? this.telegramEnabled,
      whatsappEnabled: whatsappEnabled ?? this.whatsappEnabled,
    );
  }

  @override
  String toString() {
    return 'EmergencyContact(name: $name, chatId: $chatId, whatsappNumber: $whatsappNumber, telegramEnabled: $telegramEnabled, whatsappEnabled: $whatsappEnabled)';
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is EmergencyContact &&
        other.name == name &&
        other.chatId == chatId &&
        other.whatsappNumber == whatsappNumber &&
        other.telegramEnabled == telegramEnabled &&
        other.whatsappEnabled == whatsappEnabled;
  }

  @override
  int get hashCode {
    return name.hashCode ^
        chatId.hashCode ^
        whatsappNumber.hashCode ^
        telegramEnabled.hashCode ^
        whatsappEnabled.hashCode;
  }
}
