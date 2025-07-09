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
                  'Permite el acceso a la ubicación, micrófono, cámara y notificaciones para que la app funcione correctamente.',
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

            // Nueva sección: Funcionalidades de la Alerta
            _buildFeaturesSection(context),

            const SizedBox(height: 24),

            // Información importante sobre iOS
            _buildInfoSection(
              context,
              title: 'Restricciones Importantes - iOS',
              content: [
                '📱 En dispositivos iOS, las fotos solo se pueden capturar cuando la app está ABIERTA',
                '🔊 Las grabaciones de audio funcionan correctamente en segundo plano',
                '📍 La ubicación se actualiza automáticamente en segundo plano',
                '⚠️ Para obtener fotos durante una alerta, mantén la app abierta',
              ],
              backgroundColor: Colors.orange.shade50,
              borderColor: Colors.orange.shade200,
              titleColor: Colors.orange.shade800,
            ),

            const SizedBox(height: 24),

            // Información general
            _buildInfoSection(
              context,
              title: 'Información General',
              content: [
                '• La aplicación funciona en segundo plano',
                '• Se requiere conexión a internet para enviar alertas',
                '• Los contactos recibirán actualizaciones en tiempo real',
                '• Puedes cancelar una alerta en cualquier momento',
                '• Todas las alertas incluyen marca de tiempo',
              ],
            ),

            const SizedBox(height: 24),

            // Nueva sección: Cómo crear un bot de Telegram
            _buildTelegramBotSection(context),

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

  Widget _buildFeaturesSection(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Funcionalidades Durante una Alerta',
          style: GoogleFonts.nunito(
            fontSize: 22,
            fontWeight: FontWeight.bold,
            color: Colors.blue.shade800,
          ),
        ),
        const SizedBox(height: 16),

        _buildFeatureCard(
          context,
          icon: Icons.mic,
          title: 'Grabaciones de Audio',
          description:
              'Se graban y envían automáticamente cada 30 segundos en segundo plano',
          color: Colors.green,
        ),

        _buildFeatureCard(
          context,
          icon: Icons.gps_fixed,
          title: 'Ubicación en Tiempo Real',
          description:
              'Tu ubicación se actualiza y envía continuamente a tus contactos',
          color: Colors.purple,
        ),

        _buildFeatureCard(
          context,
          icon: Icons.camera_alt,
          title: 'Fotos de Emergencia',
          description:
              'Captura fotos de ambas cámaras (frontal y trasera) cada 20 segundos',
          color: Colors.indigo,
        ),
      ],
    );
  }

  Widget _buildFeatureCard(
    BuildContext context, {
    required IconData icon,
    required String title,
    required String description,
    required Color color,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withOpacity(0.3)),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withOpacity(0.1),
            spreadRadius: 1,
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: color.withOpacity(0.1),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Icon(icon, color: color, size: 22),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: GoogleFonts.nunito(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: Color.lerp(color, Colors.black, 0.3)!,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    description,
                    style: GoogleFonts.nunito(
                      fontSize: 13,
                      color: Colors.grey.shade600,
                      height: 1.4,
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

  Widget _buildTelegramBotSection(BuildContext context) {
    return _buildInfoSection(
      context,
      title: 'Cómo Crear un Bot de Telegram',
      content: [
        '1️⃣ Abre Telegram y busca @BotFather',
        '2️⃣ Envía el comando /newbot',
        '3️⃣ Elige un nombre para tu bot (ej: "Mi Bot de Emergencia")',
        '4️⃣ Elige un nombre de usuario que termine en "bot" (ej: "miemergencia_bot")',
        '5️⃣ BotFather te dará un TOKEN - ¡guárdalo bien!',
        '6️⃣ Copia el token en la configuración de esta app',
        '7️⃣ Para obtener tu Chat ID, envía un mensaje a tu bot y usa @userinfobot',
        '',
        '📝 Ejemplo de token: 123456789:ABCdefGHIjklMNOpqrsTUVwxyz',
      ],
      backgroundColor: Colors.teal.shade50,
      borderColor: Colors.teal.shade200,
      titleColor: Colors.teal.shade800,
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
    Color? backgroundColor,
    Color? borderColor,
    Color? titleColor,
  }) {
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: backgroundColor ?? Colors.blue.shade50,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: borderColor ?? Colors.blue.shade200),
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
              color: titleColor ?? Colors.blue.shade800,
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
