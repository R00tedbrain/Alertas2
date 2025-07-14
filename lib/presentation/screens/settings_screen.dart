import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../domain/providers/providers.dart';
import '../../data/models/emergency_contact.dart';
import '../../data/models/app_config.dart';
import '../../core/constants/app_constants.dart';
import 'remove_ads_screen.dart';

class SettingsScreen extends ConsumerStatefulWidget {
  const SettingsScreen({super.key});

  @override
  _SettingsScreenState createState() => _SettingsScreenState();
}

class _SettingsScreenState extends ConsumerState<SettingsScreen> {
  final _tokenController = TextEditingController();
  final _contactNameController = TextEditingController();
  final _contactChatIdController = TextEditingController();
  final _contactWhatsAppController = TextEditingController();

  final _formKey = GlobalKey<FormState>();

  @override
  void initState() {
    super.initState();
    final appConfig = ref.read(appConfigProvider);
    _tokenController.text = appConfig.telegramBotToken;
  }

  @override
  void dispose() {
    _tokenController.dispose();
    _contactNameController.dispose();
    _contactChatIdController.dispose();
    _contactWhatsAppController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final appConfig = ref.watch(appConfigProvider);
    final alertSettings = appConfig.alertSettings;

    return Scaffold(
      appBar: AppBar(title: const Text('Configuración')),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16.0),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Token de Telegram
                _buildSectionTitle('Token del Bot de Telegram'),
                _buildTokenInput(),
                const SizedBox(height: 24),

                // Configuración de WhatsApp (Solo Premium)
                if (ref.watch(hasPremiumProvider)) ...[
                  _buildSectionTitle('Notificaciones WhatsApp (Premium)'),
                  _buildWhatsAppPremiumInfo(),
                  const SizedBox(height: 24),
                ],

                // Configuración de intervalos
                _buildSectionTitle('Configuración de Alerta'),
                _buildIntervalSettings(alertSettings),
                const SizedBox(height: 24),

                // Contactos de emergencia
                _buildSectionTitle('Contactos de Emergencia'),
                _buildAddContactForm(),
                const SizedBox(height: 16),

                // Lista de contactos existentes
                _buildContactsList(appConfig.emergencyContacts),

                // Sección de URL Scheme
                _buildURLSchemeSection(context),

                const SizedBox(height: 24),

                // Sección Premium
                _buildPremiumSection(context),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildSectionTitle(String title) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8.0),
      child: Text(
        title,
        style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
      ),
    );
  }

  Widget _buildTokenInput() {
    return TextFormField(
      controller: _tokenController,
      decoration: InputDecoration(
        labelText: 'Token del Bot',
        hintText: 'Introduce el token proporcionado por BotFather',
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
        suffixIcon: IconButton(
          icon: const Icon(Icons.save),
          onPressed: _saveToken,
          tooltip: 'Guardar Token',
        ),
      ),
      validator: (value) {
        if (value == null || value.isEmpty) {
          return 'Por favor, introduce el token del bot';
        }
        return null;
      },
    );
  }

  Widget _buildIntervalSettings(AlertSettings settings) {
    return Card(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildSliderSetting(
              title: 'Intervalo de ubicación',
              value: settings.locationUpdateIntervalSeconds.toDouble(),
              min: 10,
              max: 300,
              division: 29,
              label: '${settings.locationUpdateIntervalSeconds} segundos',
              onChanged:
                  (value) => _updateAlertSettings(
                    settings.copyWith(
                      locationUpdateIntervalSeconds: value.toInt(),
                    ),
                  ),
            ),
            const Divider(),
            _buildSliderSetting(
              title: 'Duración de grabación',
              value: settings.audioRecordingDurationSeconds.toDouble(),
              min: 5,
              max: 60,
              division: 11,
              label: '${settings.audioRecordingDurationSeconds} segundos',
              onChanged:
                  (value) => _updateAlertSettings(
                    settings.copyWith(
                      audioRecordingDurationSeconds: value.toInt(),
                    ),
                  ),
            ),
            const Divider(),
            _buildSliderSetting(
              title: 'Intervalo de grabación',
              value: settings.audioRecordingIntervalSeconds.toDouble(),
              min: 10,
              max: 300,
              division: 29,
              label: '${settings.audioRecordingIntervalSeconds} segundos',
              onChanged:
                  (value) => _updateAlertSettings(
                    settings.copyWith(
                      audioRecordingIntervalSeconds: value.toInt(),
                    ),
                  ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSliderSetting({
    required String title,
    required double value,
    required double min,
    required double max,
    required int division,
    required String label,
    required Function(double) onChanged,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(title, style: const TextStyle(fontWeight: FontWeight.w500)),
        Row(
          children: [
            Expanded(
              child: Slider(
                value: value,
                min: min,
                max: max,
                divisions: division,
                label: label,
                onChanged: onChanged,
              ),
            ),
            SizedBox(
              width: 60,
              child: Text(
                label,
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildAddContactForm() {
    final appConfig = ref.watch(appConfigProvider);
    final whatsAppContactsCount =
        appConfig.emergencyContacts
            .where((contact) => contact.whatsappEnabled)
            .length;

    return Card(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                const Icon(Icons.person_add, color: Colors.blue),
                const SizedBox(width: 8),
                const Text(
                  'Nuevo Contacto de Emergencia',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                ),
              ],
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _contactNameController,
              decoration: const InputDecoration(
                labelText: 'Nombre del contacto',
                hintText: 'Ej: Familiar 1',
                prefixIcon: Icon(Icons.person),
              ),
              validator: (value) {
                if (value == null || value.isEmpty) {
                  return 'Por favor, introduce un nombre';
                }
                return null;
              },
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _contactChatIdController,
              decoration: const InputDecoration(
                labelText: 'Chat ID (Telegram)',
                hintText: 'ID proporcionado por el bot',
                prefixIcon: Icon(Icons.telegram),
              ),
              keyboardType: TextInputType.number,
              validator: (value) {
                if (value == null || value.isEmpty) {
                  return 'Por favor, introduce el Chat ID';
                }
                return null;
              },
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _contactWhatsAppController,
              decoration: InputDecoration(
                labelText: 'Número WhatsApp (Opcional)',
                hintText: '+34612345678',
                prefixIcon: const Icon(Icons.phone),
                suffixText: whatsAppContactsCount >= 3 ? 'Máximo 3' : null,
                suffixStyle: TextStyle(
                  color: whatsAppContactsCount >= 3 ? Colors.red : Colors.grey,
                ),
              ),
              keyboardType: TextInputType.phone,
              enabled: whatsAppContactsCount < 3,
              validator: (value) {
                if (value != null && value.isNotEmpty) {
                  if (whatsAppContactsCount >= 3) {
                    return 'Máximo 3 contactos WhatsApp permitidos';
                  }
                  if (!RegExp(r'^\+[1-9]\d{1,14}$').hasMatch(value)) {
                    return 'Formato inválido. Ej: +34612345678';
                  }
                }
                return null;
              },
            ),
            const SizedBox(height: 16),
            if (whatsAppContactsCount >= 3)
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.orange.shade100,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  children: [
                    Icon(Icons.warning, color: Colors.orange.shade700),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Máximo 3 contactos WhatsApp. Elimina uno para añadir otro.',
                        style: TextStyle(
                          color: Colors.orange.shade700,
                          fontSize: 12,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            const SizedBox(height: 16),
            ElevatedButton.icon(
              onPressed: _addContact,
              icon: const Icon(Icons.person_add),
              label: const Text('Añadir Contacto'),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.green,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 12),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildContactsList(List<EmergencyContact> contacts) {
    if (contacts.isEmpty) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(16.0),
          child: Text(
            'No hay contactos configurados',
            style: TextStyle(fontStyle: FontStyle.italic, color: Colors.grey),
          ),
        ),
      );
    }

    return ListView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: contacts.length,
      itemBuilder: (context, index) {
        final contact = contacts[index];
        return Card(
          margin: const EdgeInsets.symmetric(vertical: 4.0),
          child: ExpansionTile(
            leading: CircleAvatar(
              backgroundColor: Colors.blue.shade100,
              child: Text(
                contact.name.isNotEmpty ? contact.name[0].toUpperCase() : "?",
                style: TextStyle(
                  color: Colors.blue.shade800,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
            title: Text(contact.name),
            subtitle: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (contact.telegramEnabled)
                  Row(
                    children: [
                      const Icon(Icons.telegram, size: 16, color: Colors.blue),
                      const SizedBox(width: 4),
                      Text('Telegram: ${contact.chatId}'),
                    ],
                  ),
                if (contact.whatsappEnabled && contact.whatsappNumber != null)
                  Row(
                    children: [
                      const Icon(Icons.phone, size: 16, color: Colors.green),
                      const SizedBox(width: 4),
                      Text('WhatsApp: ${contact.whatsappNumber}'),
                    ],
                  ),
              ],
            ),
            trailing: IconButton(
              icon: const Icon(Icons.delete, color: Colors.red),
              onPressed: () => _removeContact(contact),
            ),
            children: [
              Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  children: [
                    Row(
                      children: [
                        const Icon(Icons.telegram, color: Colors.blue),
                        const SizedBox(width: 8),
                        const Text('Telegram'),
                        const Spacer(),
                        Switch(
                          value: contact.telegramEnabled,
                          onChanged:
                              (value) => _toggleContactService(
                                contact,
                                'telegram',
                                value,
                              ),
                        ),
                      ],
                    ),
                    if (contact.whatsappNumber != null)
                      Row(
                        children: [
                          const Icon(Icons.phone, color: Colors.green),
                          const SizedBox(width: 8),
                          const Text('WhatsApp'),
                          const Spacer(),
                          Switch(
                            value: contact.whatsappEnabled,
                            onChanged:
                                (value) => _toggleContactService(
                                  contact,
                                  'whatsapp',
                                  value,
                                ),
                          ),
                        ],
                      ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  void _saveToken() {
    if (_formKey.currentState!.validate()) {
      final configNotifier = ref.read(appConfigProvider.notifier);
      configNotifier.updateToken(_tokenController.text.trim());

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Token guardado correctamente'),
          backgroundColor: Colors.green,
        ),
      );
    }
  }

  void _updateAlertSettings(AlertSettings settings) {
    final configNotifier = ref.read(appConfigProvider.notifier);
    configNotifier.updateAlertSettings(settings);
  }

  void _addContact() {
    if (_formKey.currentState!.validate()) {
      final name = _contactNameController.text.trim();
      final chatId = _contactChatIdController.text.trim();
      final whatsAppNumber = _contactWhatsAppController.text.trim();

      final contact = EmergencyContact(
        name: name,
        chatId: chatId,
        whatsappNumber: whatsAppNumber.isNotEmpty ? whatsAppNumber : null,
        telegramEnabled: true,
        whatsappEnabled: whatsAppNumber.isNotEmpty,
      );

      final configNotifier = ref.read(appConfigProvider.notifier);
      configNotifier.addEmergencyContact(contact);

      // Limpiar campos
      _contactNameController.clear();
      _contactChatIdController.clear();
      _contactWhatsAppController.clear();

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Contacto $name añadido'),
          backgroundColor: Colors.green,
        ),
      );
    }
  }

  void _removeContact(EmergencyContact contact) {
    final configNotifier = ref.read(appConfigProvider.notifier);
    configNotifier.removeEmergencyContact(contact.chatId);

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Contacto ${contact.name} eliminado'),
        backgroundColor: Colors.blue,
      ),
    );
  }

  void _toggleContactService(
    EmergencyContact contact,
    String service,
    bool enabled,
  ) {
    final configNotifier = ref.read(appConfigProvider.notifier);

    EmergencyContact updatedContact;
    if (service == 'telegram') {
      updatedContact = contact.copyWith(telegramEnabled: enabled);
    } else if (service == 'whatsapp') {
      updatedContact = contact.copyWith(whatsappEnabled: enabled);
    } else {
      return;
    }

    // Remover el contacto existente y añadir el actualizado
    configNotifier.removeEmergencyContact(contact.chatId);
    configNotifier.addEmergencyContact(updatedContact);

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          '${service.toUpperCase()} ${enabled ? 'activado' : 'desactivado'} para ${contact.name}',
        ),
        backgroundColor: enabled ? Colors.green : Colors.orange,
      ),
    );
  }

  Widget _buildURLSchemeSection(BuildContext context) {
    final urlScheme = "alertatelegram://iniciar";

    return Card(
      elevation: 4,
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Row(
              children: [
                Icon(Icons.link, color: Colors.blue),
                SizedBox(width: 8),
                Text(
                  "URL Scheme para Atajos",
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
              ],
            ),
            const SizedBox(height: 16),
            const Text(
              "Puedes usar el siguiente URL scheme para activar la alerta directamente desde la app Atajos de iOS:",
              style: TextStyle(fontSize: 15),
            ),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.grey[200],
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      urlScheme,
                      style: const TextStyle(
                        fontFamily: 'monospace',
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.copy),
                    onPressed: () {
                      Clipboard.setData(ClipboardData(text: urlScheme));
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('URL copiado al portapapeles'),
                          duration: Duration(seconds: 2),
                        ),
                      );
                    },
                    tooltip: "Copiar URL",
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            const Text(
              "Instrucciones para configurar un atajo:",
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            const Text(
              "1. Abre la app Atajos en tu iPhone\n"
              "2. Crea un nuevo atajo\n"
              "3. Añade la acción \"Abrir URL\"\n"
              "4. Pega el URL scheme mostrado arriba\n"
              "5. Guarda el atajo y colócalo en tu pantalla de inicio",
            ),
            const SizedBox(height: 16),
            OutlinedButton.icon(
              icon: const Icon(Icons.play_arrow),
              label: const Text("Probar URL Scheme"),
              onPressed: () async {
                final uri = Uri.parse(urlScheme);
                if (await canLaunchUrl(uri)) {
                  await launchUrl(uri);
                } else {
                  // ignore: use_build_context_synchronously
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('No se pudo abrir el URL scheme'),
                      backgroundColor: Colors.red,
                    ),
                  );
                }
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildWhatsAppPremiumInfo() {
    return Card(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.verified, color: Colors.green.shade600),
                const SizedBox(width: 8),
                const Text(
                  'WhatsApp Premium',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                ),
                const Spacer(),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.green.shade100,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    'ACTIVO',
                    style: TextStyle(
                      color: Colors.green.shade800,
                      fontWeight: FontWeight.bold,
                      fontSize: 12,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.blue.shade50,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.blue.shade200),
              ),
              child: Row(
                children: [
                  Icon(Icons.info, color: Colors.blue.shade600),
                  const SizedBox(width: 12),
                  const Expanded(
                    child: Text(
                      'Servicio incluido en Premium. Simplemente añade números de WhatsApp a tus contactos.',
                      style: TextStyle(fontSize: 14),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Icon(
                  Icons.check_circle,
                  color: Colors.green.shade600,
                  size: 20,
                ),
                const SizedBox(width: 8),
                const Text('Alertas automáticas por WhatsApp'),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Icon(
                  Icons.check_circle,
                  color: Colors.green.shade600,
                  size: 20,
                ),
                const SizedBox(width: 8),
                const Text('Sin configuración técnica necesaria'),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Icon(
                  Icons.check_circle,
                  color: Colors.green.shade600,
                  size: 20,
                ),
                const SizedBox(width: 8),
                const Text('Envío simultáneo con Telegram'),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPremiumSection(BuildContext context) {
    final hasPremium = ref.watch(hasPremiumProvider);
    final premiumAsync = ref.watch(premiumSubscriptionProvider);

    return Card(
      elevation: 4,
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  hasPremium ? Icons.star : Icons.star_border,
                  color: hasPremium ? Colors.amber : Colors.grey,
                ),
                const SizedBox(width: 8),
                Text(
                  hasPremium ? "Premium Activo" : "Versión Gratuita",
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color:
                        hasPremium
                            ? Colors.amber.shade800
                            : Colors.grey.shade700,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),

            if (hasPremium) ...[
              premiumAsync.when(
                data:
                    (subscription) => Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          "Suscripción: ${subscription.productType?.name.toUpperCase() ?? 'DESCONOCIDA'}",
                          style: const TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        const SizedBox(height: 8),
                        if (subscription.daysRemaining > 0)
                          Text(
                            "Días restantes: ${subscription.daysRemaining}",
                            style: TextStyle(
                              fontSize: 14,
                              color: Colors.grey.shade600,
                            ),
                          ),
                        const SizedBox(height: 16),
                        const Text(
                          "Beneficios activos:",
                          style: TextStyle(fontWeight: FontWeight.bold),
                        ),
                        const SizedBox(height: 8),
                        _buildPremiumBenefit(
                          icon: Icons.audiotrack,
                          title: "Audio de Alta Calidad",
                          description: "Grabación en stereo 44.1kHz @ 192kbps",
                        ),
                        _buildPremiumBenefit(
                          icon: Icons.gps_fixed,
                          title: "GPS de Precisión Máxima",
                          description: "Ubicación con precisión centimétrica",
                        ),
                        _buildPremiumBenefit(
                          icon: Icons.update,
                          title: "Actualizaciones Frecuentes",
                          description: "Ubicación cada 10 segundos",
                        ),
                      ],
                    ),
                loading: () => const CircularProgressIndicator(),
                error:
                    (_, __) =>
                        const Text("Error al cargar información premium"),
              ),
            ] else ...[
              const Text(
                "Mejora a Premium para acceder a:",
                style: TextStyle(fontSize: 14, fontWeight: FontWeight.w500),
              ),
              const SizedBox(height: 12),
              _buildPremiumBenefit(
                icon: Icons.audiotrack,
                title: "Audio de Alta Calidad",
                description: "Grabación en stereo 44.1kHz @ 192kbps",
                enabled: false,
              ),
              _buildPremiumBenefit(
                icon: Icons.gps_fixed,
                title: "GPS de Precisión Máxima",
                description: "Ubicación con precisión centimétrica",
                enabled: false,
              ),
              _buildPremiumBenefit(
                icon: Icons.update,
                title: "Actualizaciones Frecuentes",
                description: "Ubicación cada 10 segundos",
                enabled: false,
              ),
              const SizedBox(height: 16),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  icon: const Icon(Icons.star),
                  label: const Text("Obtener Premium"),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.amber,
                    foregroundColor: Colors.black,
                    padding: const EdgeInsets.symmetric(vertical: 12),
                  ),
                  onPressed: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => const RemoveAdsScreen(),
                      ),
                    );
                  },
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildPremiumBenefit({
    required IconData icon,
    required String title,
    required String description,
    bool enabled = true,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4.0),
      child: Row(
        children: [
          Icon(icon, color: enabled ? Colors.green : Colors.grey, size: 20),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    fontWeight: FontWeight.w500,
                    color: enabled ? Colors.black : Colors.grey,
                  ),
                ),
                Text(
                  description,
                  style: TextStyle(
                    fontSize: 12,
                    color:
                        enabled ? Colors.grey.shade600 : Colors.grey.shade400,
                  ),
                ),
              ],
            ),
          ),
          if (enabled) Icon(Icons.check_circle, color: Colors.green, size: 16),
        ],
      ),
    );
  }
}
