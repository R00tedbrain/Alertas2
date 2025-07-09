import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter/foundation.dart';
import '../../core/constants/app_constants.dart';
import '../screens/how_it_works_screen.dart';
import '../screens/terms_of_use_screen.dart';
import '../screens/privacy_policy_screen.dart';
import '../screens/remove_ads_screen.dart';
import '../screens/my_location_screen.dart';

class AppDrawer extends StatelessWidget {
  const AppDrawer({super.key});

  @override
  Widget build(BuildContext context) {
    return Drawer(
      child: SafeArea(
        child: Column(
          children: [
            // Header del drawer
            _buildHeader(context),

            // Divider
            const Divider(height: 1),

            // Opciones del menú
            Expanded(
              child: ListView(
                padding: EdgeInsets.zero,
                children: [
                  _buildDrawerItem(
                    context,
                    icon: Icons.help_outline,
                    title: 'Cómo funciona Alerta Telegram',
                    subtitle: 'Aprende a usar la aplicación',
                    onTap: () {
                      Navigator.of(context).pop();
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => const HowItWorksScreen(),
                        ),
                      );
                    },
                  ),

                  _buildDrawerItem(
                    context,
                    icon: Icons.description_outlined,
                    title: 'Términos de Uso',
                    subtitle: 'Condiciones del servicio',
                    onTap: () {
                      Navigator.of(context).pop();
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => const TermsOfUseScreen(),
                        ),
                      );
                    },
                  ),

                  _buildDrawerItem(
                    context,
                    icon: Icons.privacy_tip_outlined,
                    title: 'Política de Privacidad',
                    subtitle: 'Tu privacidad es importante',
                    onTap: () {
                      Navigator.of(context).pop();
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => const PrivacyPolicyScreen(),
                        ),
                      );
                    },
                  ),

                  _buildDrawerItem(
                    context,
                    icon: Icons.star_outline,
                    title: 'Eliminar Anuncios',
                    subtitle: 'Disfruta sin interrupciones',
                    onTap: () {
                      Navigator.of(context).pop();
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => const RemoveAdsScreen(),
                        ),
                      );
                    },
                  ),

                  // Divider para separar las opciones principales de las utilidades
                  const Divider(height: 1),

                  _buildDrawerItem(
                    context,
                    icon: Icons.my_location,
                    title: 'Mi Ubicación',
                    subtitle: 'Ver ubicación en tiempo real',
                    onTap: () {
                      Navigator.of(context).pop();
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => const MyLocationScreen(),
                        ),
                      );
                    },
                  ),
                ],
              ),
            ),

            // Footer del drawer
            _buildFooter(context),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.blue,
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Colors.blue.shade600, Colors.blue.shade800],
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Logo/Icono de la app
          Container(
            width: 60,
            height: 60,
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.2),
              borderRadius: BorderRadius.circular(30),
            ),
            child: const Icon(
              Icons.notifications_active,
              size: 30,
              color: Colors.white,
            ),
          ),
          const SizedBox(height: 12),

          // Nombre de la app
          Text(
            AppConstants.appName,
            style: GoogleFonts.nunito(
              fontSize: 22,
              fontWeight: FontWeight.bold,
              color: Colors.white,
            ),
          ),

          // Versión o descripción
          Text(
            'Sistema de Alertas de Emergencia',
            style: GoogleFonts.nunito(
              fontSize: 14,
              color: Colors.white.withOpacity(0.9),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDrawerItem(
    BuildContext context, {
    required IconData icon,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
  }) {
    return ListTile(
      leading: Container(
        width: 40,
        height: 40,
        decoration: BoxDecoration(
          color: Colors.blue.shade50,
          borderRadius: BorderRadius.circular(20),
        ),
        child: Icon(icon, color: Colors.blue.shade600, size: 22),
      ),
      title: Text(
        title,
        style: GoogleFonts.nunito(fontSize: 16, fontWeight: FontWeight.w600),
      ),
      subtitle: Text(
        subtitle,
        style: GoogleFonts.nunito(fontSize: 12, color: Colors.grey.shade600),
      ),
      onTap: onTap,
      contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 4),
    );
  }

  Widget _buildFooter(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.grey.shade50,
        border: Border(top: BorderSide(color: Colors.grey.shade200, width: 1)),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(
            'Versión 1.0.0',
            style: GoogleFonts.nunito(
              fontSize: 12,
              color: Colors.grey.shade600,
            ),
          ),
        ],
      ),
    );
  }
}
