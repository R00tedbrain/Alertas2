import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class TermsOfUseScreen extends StatelessWidget {
  const TermsOfUseScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Términos de Uso'),
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
              'Términos de Uso',
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

            // Secciones de términos
            _buildTermSection(
              context,
              title: '1. Aceptación de los Términos',
              content:
                  'Al usar Alerta Telegram, usted acepta estar sujeto a estos términos de uso. Si no está de acuerdo con alguno de estos términos, no use la aplicación.',
            ),

            _buildTermSection(
              context,
              title: '2. Uso de la Aplicación',
              content:
                  'Esta aplicación está diseñada para enviar alertas de emergencia a contactos preestablecidos. Debe usar la aplicación de manera responsable y solo para emergencias reales.',
            ),

            _buildTermSection(
              context,
              title: '3. Responsabilidades del Usuario',
              content:
                  '• Proporcionar información precisa y actualizada\n• Usar la aplicación solo para emergencias reales\n• Mantener la seguridad de sus datos de configuración\n• No compartir tokens de bot con terceros',
            ),

            _buildTermSection(
              context,
              title: '4. Privacidad y Datos',
              content:
                  'La aplicación recopila y procesa datos de ubicación únicamente para el funcionamiento del servicio de alertas. No vendemos ni compartimos sus datos con terceros.',
            ),

            _buildTermSection(
              context,
              title: '5. Limitaciones del Servicio',
              content:
                  'El servicio depende de la conectividad a internet y la disponibilidad de los servicios de Telegram. No garantizamos el funcionamiento 100% del tiempo.',
            ),

            _buildTermSection(
              context,
              title: '6. Limitación de Responsabilidad',
              content:
                  'La aplicación se proporciona "tal como está". No nos hacemos responsables por daños directos, indirectos o consecuentes derivados del uso de la aplicación.',
            ),

            _buildTermSection(
              context,
              title: '7. Modificaciones',
              content:
                  'Nos reservamos el derecho de modificar estos términos en cualquier momento. Las modificaciones entrarán en vigor inmediatamente después de su publicación.',
            ),

            _buildTermSection(
              context,
              title: '8. Terminación',
              content:
                  'Podemos terminar o suspender su acceso a la aplicación en cualquier momento, sin previo aviso, por violación de estos términos.',
            ),

            const SizedBox(height: 24),

            // Información de contacto
            _buildContactInfo(context),
          ],
        ),
      ),
    );
  }

  Widget _buildTermSection(
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
        color: Colors.blue.shade50,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.blue.shade200),
      ),
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.contact_support, color: Colors.blue.shade600),
              const SizedBox(width: 8),
              Text(
                'Contacto',
                style: GoogleFonts.nunito(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: Colors.blue.shade800,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            'Si tienes preguntas sobre estos términos, puedes contactarnos a través de los canales de soporte de la aplicación.',
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
