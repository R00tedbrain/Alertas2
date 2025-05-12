import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/models/emergency_contact.dart';
import '../../domain/providers/providers.dart';

class ContactsList extends ConsumerWidget {
  final List<EmergencyContact> contacts;
  final Function(EmergencyContact)? onDelete;

  const ContactsList({Key? key, required this.contacts, this.onDelete})
    : super(key: key);

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return ListView.builder(
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
              onPressed: () => _showDeleteConfirmation(context, ref, contact),
            ),
          ),
        );
      },
    );
  }

  void _showDeleteConfirmation(
    BuildContext context,
    WidgetRef ref,
    EmergencyContact contact,
  ) {
    showDialog(
      context: context,
      builder:
          (context) => AlertDialog(
            title: const Text('Eliminar contacto'),
            content: Text('¿Estás seguro de eliminar a ${contact.name}?'),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Cancelar'),
              ),
              TextButton(
                onPressed: () {
                  Navigator.pop(context);
                  if (onDelete != null) {
                    onDelete!(contact);
                  } else {
                    _deleteContact(ref, contact);
                  }
                },
                child: const Text(
                  'Eliminar',
                  style: TextStyle(color: Colors.red),
                ),
              ),
            ],
          ),
    );
  }

  void _deleteContact(WidgetRef ref, EmergencyContact contact) {
    final configNotifier = ref.read(appConfigProvider.notifier);
    configNotifier.removeEmergencyContact(contact.chatId);

    ScaffoldMessenger.of(ref.context).showSnackBar(
      SnackBar(
        content: Text('Contacto ${contact.name} eliminado'),
        backgroundColor: Colors.blue,
        action: SnackBarAction(
          label: 'Deshacer',
          textColor: Colors.white,
          onPressed: () {
            configNotifier.addEmergencyContact(contact);
          },
        ),
      ),
    );
  }
}
