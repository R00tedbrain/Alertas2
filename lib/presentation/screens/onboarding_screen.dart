import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../domain/providers/providers.dart';

class OnboardingScreen extends ConsumerStatefulWidget {
  const OnboardingScreen({super.key});

  @override
  ConsumerState<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends ConsumerState<OnboardingScreen> {
  final PageController _pageController = PageController();
  int _currentPage = 0;

  final List<OnboardingPage> _pages = [
    OnboardingPage(
      title: '¡Bienvenido a AlertaTelegram!',
      subtitle: 'Tu sistema de emergencia personal',
      description:
          'Protégete y protege a tu familia con alertas automáticas que envían tu ubicación y audio a contactos de emergencia.',
      icon: Icons.security,
      color: Colors.blue,
    ),
    OnboardingPage(
      title: '🔒 Permisos Necesarios',
      subtitle: 'Tu seguridad es nuestra prioridad',
      description:
          '• 📍 Ubicación: Para enviar tu posición exacta a contactos de emergencia\n\n• 🎙️ Micrófono: Para grabar audio durante la emergencia\n\n• 📷 Cámara: Para capturar fotos automáticamente\n\n• 🔔 Notificaciones: Para informarte del estado de las alertas\n\nEstos permisos son esenciales para que la app funcione correctamente durante una emergencia.\n\n⚠️ IMPORTANTE: Sin estos permisos no podrás iniciar el servicio de alerta. Al presionar el botón "Iniciar Alerta" fallará y no se enviará información a tus contactos de emergencia.',
      icon: Icons.shield_outlined,
      color: Colors.indigo,
      isPermissionPage: true,
    ),
    OnboardingPage(
      title: '🎯 Prueba GRATIS por 7 días',
      subtitle: 'Sin compromisos, sin pagos',
      description:
          'Disfruta de TODAS las funciones premium completamente gratis durante una semana. Cancela cuando quieras.',
      icon: Icons.timer,
      color: Colors.green,
    ),
    OnboardingPage(
      title: '💎 Funciones Premium',
      subtitle: 'Máxima protección para emergencias',
      description:
          '• GPS de alta precisión\n• Audio de máxima calidad\n• Fotos automáticas\n• Alertas ilimitadas\n• Soporte prioritario',
      icon: Icons.diamond,
      color: Colors.purple,
    ),
    OnboardingPage(
      title: '👨‍👩‍👧‍👦 Para toda la familia',
      subtitle: 'Compartir con Family Sharing',
      description:
          'Una sola suscripción protege a toda tu familia. Compatible con Family Sharing de Apple.',
      icon: Icons.family_restroom,
      color: Colors.orange,
    ),
    OnboardingPage(
      title: '🚀 Después de los 7 días',
      subtitle: 'Elige tu plan perfecto',
      description:
          'Continúa protegido con nuestros planes flexibles:\n\n💰 Mensual: €2.99/mes\n💎 Anual: €19.99/año (44% descuento)',
      icon: Icons.launch,
      color: Colors.teal,
    ),
  ];

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: Column(
          children: [
            // Progress indicator
            _buildProgressIndicator(),

            // Content
            Expanded(
              child: PageView.builder(
                controller: _pageController,
                onPageChanged: (index) {
                  setState(() {
                    _currentPage = index;
                  });
                },
                itemCount: _pages.length,
                itemBuilder: (context, index) {
                  return _buildPage(_pages[index]);
                },
              ),
            ),

            // Bottom buttons
            _buildBottomButtons(),
          ],
        ),
      ),
    );
  }

  Widget _buildProgressIndicator() {
    return Container(
      padding: const EdgeInsets.all(20),
      child: Row(
        children: [
          // Skip button
          TextButton(
            onPressed: _skipOnboarding,
            child: Text(
              'Saltar',
              style: GoogleFonts.nunito(color: Colors.grey[600], fontSize: 16),
            ),
          ),

          // Progress dots
          Expanded(
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: List.generate(
                _pages.length,
                (index) => Container(
                  margin: const EdgeInsets.symmetric(horizontal: 4),
                  width: _currentPage == index ? 24 : 8,
                  height: 8,
                  decoration: BoxDecoration(
                    color:
                        _currentPage == index
                            ? _pages[_currentPage].color
                            : Colors.grey[300],
                    borderRadius: BorderRadius.circular(4),
                  ),
                ),
              ),
            ),
          ),

          // Page counter
          Text(
            '${_currentPage + 1}/${_pages.length}',
            style: GoogleFonts.nunito(
              color: Colors.grey[600],
              fontSize: 14,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPage(OnboardingPage page) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 20),
      child: Column(
        children: [
          // Icon with animated container
          Expanded(
            flex: 3,
            child: Container(
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    page.color.withOpacity(0.1),
                    page.color.withOpacity(0.05),
                  ],
                ),
              ),
              child: Center(
                child: Icon(page.icon, size: 120, color: page.color),
              ),
            ),
          ),

          // Content
          Expanded(
            flex: 4,
            child: Column(
              children: [
                // Title
                Text(
                  page.title,
                  textAlign: TextAlign.center,
                  style: GoogleFonts.nunito(
                    fontSize: 28,
                    fontWeight: FontWeight.bold,
                    color: Colors.grey[800],
                    height: 1.2,
                  ),
                ),

                const SizedBox(height: 16),

                // Subtitle
                Text(
                  page.subtitle,
                  textAlign: TextAlign.center,
                  style: GoogleFonts.nunito(
                    fontSize: 18,
                    fontWeight: FontWeight.w600,
                    color: page.color,
                    height: 1.3,
                  ),
                ),

                const SizedBox(height: 24),

                // Description
                Expanded(
                  child: SingleChildScrollView(
                    child: Text(
                      page.description,
                      textAlign: TextAlign.center,
                      style: GoogleFonts.nunito(
                        fontSize: 16,
                        color: Colors.grey[600],
                        height: 1.5,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBottomButtons() {
    final bool isLastPage = _currentPage == _pages.length - 1;
    final bool isPermissionPage = _pages[_currentPage].isPermissionPage;

    return Container(
      padding: const EdgeInsets.all(24),
      child: Column(
        children: [
          // Main action button
          SizedBox(
            width: double.infinity,
            height: 56,
            child: ElevatedButton(
              onPressed: isLastPage ? _finishOnboarding : _nextPage,
              style: ElevatedButton.styleFrom(
                backgroundColor: _pages[_currentPage].color,
                foregroundColor: Colors.white,
                elevation: 2,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    isLastPage ? '¡Empezar Ahora!' : 'Continuar',
                    style: GoogleFonts.nunito(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Icon(
                    isLastPage ? Icons.rocket_launch : Icons.arrow_forward,
                    size: 20,
                  ),
                ],
              ),
            ),
          ),

          // Permission settings button (only on permission page)
          if (isPermissionPage) ...[
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              height: 48,
              child: OutlinedButton(
                onPressed: _openPermissionSettings,
                style: OutlinedButton.styleFrom(
                  foregroundColor: _pages[_currentPage].color,
                  side: BorderSide(color: _pages[_currentPage].color, width: 2),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      Icons.settings,
                      size: 18,
                      color: _pages[_currentPage].color,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      'Configurar Permisos Ahora',
                      style: GoogleFonts.nunito(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],

          // Secondary info (only on last page)
          if (isLastPage) ...[
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.green.shade50,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.green.shade200),
              ),
              child: Column(
                children: [
                  Icon(
                    Icons.check_circle,
                    color: Colors.green.shade600,
                    size: 24,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Recuerda: Tienes 7 días GRATIS',
                    style: GoogleFonts.nunito(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: Colors.green.shade700,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Sin compromisos • Cancela cuando quieras',
                    style: GoogleFonts.nunito(
                      fontSize: 12,
                      color: Colors.green.shade600,
                    ),
                  ),
                ],
              ),
            ),
          ],

          // Permission info (only on permission page)
          if (isPermissionPage) ...[
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.indigo.shade50,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.indigo.shade200),
              ),
              child: Column(
                children: [
                  Icon(
                    Icons.info_outline,
                    color: Colors.indigo.shade600,
                    size: 24,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Configuración Recomendada',
                    style: GoogleFonts.nunito(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: Colors.indigo.shade700,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Puedes configurar los permisos ahora o después en la app',
                    style: GoogleFonts.nunito(
                      fontSize: 12,
                      color: Colors.indigo.shade600,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  void _nextPage() {
    if (_currentPage < _pages.length - 1) {
      _pageController.nextPage(
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
      );
    }
  }

  void _skipOnboarding() {
    _finishOnboarding();
  }

  void _openPermissionSettings() async {
    // Abrir configuración de permisos del dispositivo
    final permissionService = ref.read(permissionServiceProvider);
    await permissionService.openSettings();
  }

  void _finishOnboarding() async {
    // Marcar onboarding como completado
    await _markOnboardingCompleted();

    // Navegar a la pantalla principal
    Navigator.of(context).pushReplacementNamed('/home');
  }

  Future<void> _markOnboardingCompleted() async {
    final onboardingNotifier = ref.read(onboardingNotifierProvider);
    await onboardingNotifier.markOnboardingCompleted();
  }
}

class OnboardingPage {
  final String title;
  final String subtitle;
  final String description;
  final IconData icon;
  final Color color;
  final bool isPermissionPage;

  OnboardingPage({
    required this.title,
    required this.subtitle,
    required this.description,
    required this.icon,
    required this.color,
    this.isPermissionPage = false,
  });
}
