import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../domain/providers/providers.dart';
import '../../data/models/emergency_contact.dart';
import '../../data/models/app_config.dart';

class SettingsScreen extends ConsumerStatefulWidget {
  const SettingsScreen({Key? key}) : super(key: key);

  @override
  _SettingsScreenState createState() => _SettingsScreenState();
}

class _SettingsScreenState extends ConsumerState<SettingsScreen> {
  final _tokenController = TextEditingController();
  final _contactNameController = TextEditingController();
  final _contactChatIdController = TextEditingController();
  final _formKey = GlobalKey<FormState>();

  @override
  void initState() {
    super.initState();
    _tokenController.text = ref.read(appConfigProvider).telegramBotToken;
  }

  @override
  void dispose() {
    _tokenController.dispose();
    _contactNameController.dispose();
    _contactChatIdController.dispose();
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
    return Card(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            TextFormField(
              controller: _contactNameController,
              decoration: const InputDecoration(
                labelText: 'Nombre del contacto',
                hintText: 'Ej: Familiar 1',
              ),
              validator: (value) {
                if (value == null || value.isEmpty) {
                  return 'Por favor, introduce un nombre';
                }
                return null;
              },
            ),
            const SizedBox(height: 8),
            TextFormField(
              controller: _contactChatIdController,
              decoration: const InputDecoration(
                labelText: 'Chat ID',
                hintText: 'ID proporcionado por el bot',
              ),
              keyboardType: TextInputType.number,
              validator: (value) {
                if (value == null || value.isEmpty) {
                  return 'Por favor, introduce el Chat ID';
                }
                return null;
              },
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
          child: ListTile(
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
            subtitle: Text('Chat ID: ${contact.chatId}'),
            trailing: IconButton(
              icon: const Icon(Icons.delete, color: Colors.red),
              onPressed: () => _removeContact(contact),
            ),
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

      final contact = EmergencyContact(name: name, chatId: chatId);

      final configNotifier = ref.read(appConfigProvider.notifier);
      configNotifier.addEmergencyContact(contact);

      // Limpiar campos
      _contactNameController.clear();
      _contactChatIdController.clear();

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
}
