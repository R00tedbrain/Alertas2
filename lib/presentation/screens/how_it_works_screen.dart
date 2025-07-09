import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class HowItWorksScreen extends StatelessWidget {
  const HowItWorksScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Cómo funciona'),
        backgroundColor: Colors.blue,
        foregroundColor: Colors.white,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Título principal
            Text(
              'Cómo funciona Alerta Telegram',
              style: GoogleFonts.nunito(
                fontSize: 28,
                fontWeight: FontWeight.bold,
                color: Colors.blue.shade800,
              ),
            ),
            const SizedBox(height: 24),

            // Pasos del funcionamiento
            _buildStepCard(
              context,
              stepNumber: 1,
              title: 'Configurar Bot de Telegram',
              description:
                  'Primero debes crear un bot en Telegram usando @BotFather y obtener el token de tu bot.',
              icon: Icons.smart_toy,
            ),

            _buildStepCard(
              context,
              stepNumber: 2,
              title: 'Añadir Contactos de Emergencia',
              description:
                  'Añade los contactos que recibirán las alertas. Necesitas su Chat ID de Telegram.',
              icon: Icons.contacts,
            ),

            _buildStepCard(
              context,
              stepNumber: 3,
              title: 'Configurar Permisos',
              description:
                  'Permite el acceso a la ubicación y las notificaciones para que la app funcione correctamente.',
              icon: Icons.location_on,
            ),

            _buildStepCard(
              context,
              stepNumber: 4,
              title: 'Activar Alerta',
              description:
                  'Cuando tengas una emergencia, pulsa el botón de alerta y se enviará tu ubicación a todos los contactos.',
              icon: Icons.emergency,
            ),

            const SizedBox(height: 24),

            // Información adicional
            _buildInfoSection(
              context,
              title: 'Información Importante',
              content: [
                '• La aplicación funciona en segundo plano',
                '• Se requiere conexión a internet para enviar alertas',
                '• Los contactos recibirán tu ubicación en tiempo real',
                '• Puedes cancelar una alerta en cualquier momento',
              ],
            ),

            const SizedBox(height: 24),

            // Botón de ayuda
            Center(
              child: ElevatedButton.icon(
                onPressed: () {
                  _showHelpDialog(context);
                },
                icon: const Icon(Icons.help_outline),
                label: const Text('¿Necesitas más ayuda?'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.blue,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 24,
                    vertical: 12,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStepCard(
    BuildContext context, {
    required int stepNumber,
    required String title,
    required String description,
    required IconData icon,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withOpacity(0.1),
            spreadRadius: 1,
            blurRadius: 6,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Número del paso
            Container(
              width: 50,
              height: 50,
              decoration: BoxDecoration(
                color: Colors.blue,
                borderRadius: BorderRadius.circular(25),
              ),
              child: Center(
                child: Text(
                  stepNumber.toString(),
                  style: GoogleFonts.nunito(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
              ),
            ),
            const SizedBox(width: 16),

            // Contenido del paso
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(icon, color: Colors.blue.shade600, size: 24),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          title,
                          style: GoogleFonts.nunito(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: Colors.blue.shade800,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(
                    description,
                    style: GoogleFonts.nunito(
                      fontSize: 14,
                      color: Colors.grey.shade700,
                      height: 1.5,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildInfoSection(
    BuildContext context, {
    required String title,
    required List<String> content,
  }) {
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: Colors.blue.shade50,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.blue.shade200),
      ),
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: GoogleFonts.nunito(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: Colors.blue.shade800,
            ),
          ),
          const SizedBox(height: 12),
          ...content.map(
            (item) => Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Text(
                item,
                style: GoogleFonts.nunito(
                  fontSize: 14,
                  color: Colors.grey.shade700,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _showHelpDialog(BuildContext context) {
    showDialog(
      context: context,
      builder:
          (context) => AlertDialog(
            title: Text(
              'Ayuda Adicional',
              style: GoogleFonts.nunito(fontWeight: FontWeight.bold),
            ),
            content: Text(
              'Si necesitas ayuda adicional, puedes consultar la documentación completa o contactar con el soporte técnico.',
              style: GoogleFonts.nunito(),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Entendido'),
              ),
            ],
          ),
    );
  }
}
