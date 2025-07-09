import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class PrivacyPolicyScreen extends StatelessWidget {
  const PrivacyPolicyScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Política de Privacidad'),
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
              'Política de Privacidad',
              style: GoogleFonts.nunito(
                fontSize: 28,
                fontWeight: FontWeight.bold,
                color: Colors.blue.shade800,
              ),
            ),
            const SizedBox(height: 8),

            Text(
              'Última actualización: Diciembre 2024',
              style: GoogleFonts.nunito(
                fontSize: 14,
                color: Colors.grey.shade600,
                fontStyle: FontStyle.italic,
              ),
            ),
            const SizedBox(height: 24),

            // Introducción
            _buildPrivacySection(
              context,
              title: 'Introducción',
              content:
                  'En Alerta Telegram, respetamos su privacidad y estamos comprometidos con la protección de sus datos personales. Esta política explica cómo recopilamos, usamos y protegemos su información.',
            ),

            // Secciones de privacidad
            _buildPrivacySection(
              context,
              title: '1. Información que Recopilamos',
              content:
                  '• Datos de ubicación GPS cuando se activa una alerta\n• Tokens de bot de Telegram para el funcionamiento del servicio\n• Información de contactos de emergencia (nombres y Chat IDs)\n• Datos técnicos para el funcionamiento de la aplicación',
            ),

            _buildPrivacySection(
              context,
              title: '2. Cómo Usamos su Información',
              content:
                  'Utilizamos su información exclusivamente para:\n• Enviar alertas de emergencia a sus contactos\n• Proporcionar servicios de ubicación en tiempo real\n• Mejorar la funcionalidad de la aplicación\n• Garantizar el correcto funcionamiento del servicio',
            ),

            _buildPrivacySection(
              context,
              title: '3. Compartir Información',
              content:
                  'No vendemos, alquilamos ni compartimos su información personal con terceros, excepto:\n• Con sus contactos de emergencia cuando activa una alerta\n• Cuando sea requerido por ley\n• Con proveedores de servicios necesarios para el funcionamiento',
            ),

            _buildPrivacySection(
              context,
              title: '4. Almacenamiento de Datos',
              content:
                  'Sus datos se almacenan localmente en su dispositivo y se transmiten únicamente cuando es necesario para el funcionamiento del servicio. No mantenemos servidores centrales con su información personal.',
            ),

            _buildPrivacySection(
              context,
              title: '5. Seguridad',
              content:
                  'Implementamos medidas de seguridad técnicas y organizacionales para proteger su información contra acceso no autorizado, alteración, divulgación o destrucción.',
            ),

            _buildPrivacySection(
              context,
              title: '6. Sus Derechos',
              content:
                  'Usted tiene derecho a:\n• Acceder a su información personal\n• Corregir datos inexactos\n• Eliminar sus datos\n• Limitar el procesamiento\n• Portabilidad de datos',
            ),

            _buildPrivacySection(
              context,
              title: '7. Menores de Edad',
              content:
                  'Esta aplicación no está dirigida a menores de 13 años. No recopilamos conscientemente información personal de menores de 13 años.',
            ),

            _buildPrivacySection(
              context,
              title: '8. Cambios a esta Política',
              content:
                  'Podemos actualizar esta política de privacidad ocasionalmente. Le notificaremos sobre cambios importantes publicando la nueva política en la aplicación.',
            ),

            const SizedBox(height: 24),

            // Información de contacto
            _buildContactInfo(context),
          ],
        ),
      ),
    );
  }

  Widget _buildPrivacySection(
    BuildContext context, {
    required String title,
    required String content,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 20),
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
            Text(
              content,
              style: GoogleFonts.nunito(
                fontSize: 14,
                color: Colors.grey.shade700,
                height: 1.6,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildContactInfo(BuildContext context) {
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: Colors.green.shade50,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.green.shade200),
      ),
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.security, color: Colors.green.shade600),
              const SizedBox(width: 8),
              Text(
                'Privacidad Garantizada',
                style: GoogleFonts.nunito(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: Colors.green.shade800,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            'Tu privacidad es nuestra prioridad. Si tienes preguntas sobre cómo manejamos tu información, no dudes en contactarnos.',
            style: GoogleFonts.nunito(
              fontSize: 14,
              color: Colors.grey.shade700,
            ),
          ),
        ],
      ),
    );
  }
}
