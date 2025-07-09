import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class RemoveAdsScreen extends StatelessWidget {
  const RemoveAdsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Eliminar Anuncios'),
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
              'Eliminar Anuncios',
              style: GoogleFonts.nunito(
                fontSize: 28,
                fontWeight: FontWeight.bold,
                color: Colors.blue.shade800,
              ),
            ),
            const SizedBox(height: 8),

            Text(
              'Disfruta de una experiencia sin interrupciones',
              style: GoogleFonts.nunito(
                fontSize: 16,
                color: Colors.grey.shade600,
              ),
            ),
            const SizedBox(height: 24),

            // Beneficios premium
            _buildBenefitsCard(context),

            const SizedBox(height: 24),

            // Planes de suscripción
            _buildPlanCard(
              context,
              title: 'Plan Mensual',
              price: '€2.99',
              period: 'por mes',
              features: [
                'Sin anuncios',
                'Soporte prioritario',
                'Actualizaciones anticipadas',
                'Funciones premium',
              ],
              color: Colors.blue,
              onTap: () => _showPurchaseDialog(context, 'Mensual'),
            ),

            const SizedBox(height: 16),

            _buildPlanCard(
              context,
              title: 'Plan Anual',
              price: '€19.99',
              period: 'por año',
              originalPrice: '€35.88',
              features: [
                'Sin anuncios',
                'Soporte prioritario',
                'Actualizaciones anticipadas',
                'Funciones premium',
                'Ahorra un 44%',
              ],
              color: Colors.green,
              isPopular: true,
              onTap: () => _showPurchaseDialog(context, 'Anual'),
            ),

            const SizedBox(height: 24),

            // Información adicional
            _buildInfoSection(context),

            const SizedBox(height: 24),

            // Botón de restaurar compras
            Center(
              child: TextButton(
                onPressed: () => _restorePurchases(context),
                child: Text(
                  'Restaurar Compras',
                  style: GoogleFonts.nunito(
                    fontSize: 16,
                    color: Colors.blue.shade600,
                    decoration: TextDecoration.underline,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBenefitsCard(BuildContext context) {
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Colors.blue.shade100, Colors.blue.shade50],
        ),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.blue.shade200),
      ),
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.star, color: Colors.amber, size: 28),
              const SizedBox(width: 8),
              Text(
                'Versión Premium',
                style: GoogleFonts.nunito(
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                  color: Colors.blue.shade800,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),

          ..._buildBenefitsList([
            'Experiencia sin anuncios',
            'Interfaz limpia y enfocada',
            'Funciones exclusivas',
            'Soporte técnico prioritario',
            'Actualizaciones tempranas',
          ]),
        ],
      ),
    );
  }

  List<Widget> _buildBenefitsList(List<String> benefits) {
    return benefits
        .map(
          (benefit) => Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Row(
              children: [
                Icon(
                  Icons.check_circle,
                  color: Colors.green.shade600,
                  size: 20,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    benefit,
                    style: GoogleFonts.nunito(
                      fontSize: 14,
                      color: Colors.grey.shade700,
                    ),
                  ),
                ),
              ],
            ),
          ),
        )
        .toList();
  }

  Widget _buildPlanCard(
    BuildContext context, {
    required String title,
    required String price,
    required String period,
    String? originalPrice,
    required List<String> features,
    required Color color,
    bool isPopular = false,
    required VoidCallback onTap,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isPopular ? color : Colors.grey.shade300,
          width: isPopular ? 2 : 1,
        ),
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
            // Header con badge popular
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  title,
                  style: GoogleFonts.nunito(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: color,
                  ),
                ),
                if (isPopular)
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.amber,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      'POPULAR',
                      style: GoogleFonts.nunito(
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 12),

            // Precio
            Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  price,
                  style: GoogleFonts.nunito(
                    fontSize: 32,
                    fontWeight: FontWeight.bold,
                    color: color,
                  ),
                ),
                const SizedBox(width: 8),
                Text(
                  period,
                  style: GoogleFonts.nunito(
                    fontSize: 16,
                    color: Colors.grey.shade600,
                  ),
                ),
                if (originalPrice != null) ...[
                  const SizedBox(width: 8),
                  Text(
                    originalPrice,
                    style: GoogleFonts.nunito(
                      fontSize: 14,
                      color: Colors.grey.shade500,
                      decoration: TextDecoration.lineThrough,
                    ),
                  ),
                ],
              ],
            ),
            const SizedBox(height: 16),

            // Características
            ...features.map(
              (feature) => Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Row(
                  children: [
                    Icon(Icons.check, color: Colors.green.shade600, size: 18),
                    const SizedBox(width: 8),
                    Text(
                      feature,
                      style: GoogleFonts.nunito(
                        fontSize: 14,
                        color: Colors.grey.shade700,
                      ),
                    ),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 16),

            // Botón de compra
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: onTap,
                style: ElevatedButton.styleFrom(
                  backgroundColor: color,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
                child: Text(
                  'Seleccionar',
                  style: GoogleFonts.nunito(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildInfoSection(BuildContext context) {
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: Colors.grey.shade50,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.shade200),
      ),
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Información',
            style: GoogleFonts.nunito(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: Colors.grey.shade800,
            ),
          ),
          const SizedBox(height: 12),
          Text(
            '• La suscripción se renovará automáticamente\n• Puedes cancelar en cualquier momento\n• El pago se cargará a tu cuenta de App Store/Play Store\n• Gestiona tu suscripción desde la configuración de tu dispositivo',
            style: GoogleFonts.nunito(
              fontSize: 14,
              color: Colors.grey.shade700,
              height: 1.5,
            ),
          ),
        ],
      ),
    );
  }

  void _showPurchaseDialog(BuildContext context, String planType) {
    showDialog(
      context: context,
      builder:
          (context) => AlertDialog(
            title: Text(
              'Confirmar compra',
              style: GoogleFonts.nunito(fontWeight: FontWeight.bold),
            ),
            content: Text(
              '¿Deseas suscribirte al plan $planType?',
              style: GoogleFonts.nunito(),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Cancelar'),
              ),
              ElevatedButton(
                onPressed: () {
                  Navigator.pop(context);
                  _processPurchase(context, planType);
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.blue,
                  foregroundColor: Colors.white,
                ),
                child: const Text('Comprar'),
              ),
            ],
          ),
    );
  }

  void _processPurchase(BuildContext context, String planType) {
    // Aquí iría la lógica de compra real
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          'Función de compra en desarrollo para el plan $planType',
          style: GoogleFonts.nunito(),
        ),
        backgroundColor: Colors.blue,
      ),
    );
  }

  void _restorePurchases(BuildContext context) {
    // Aquí iría la lógica para restaurar compras
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          'Función de restaurar compras en desarrollo',
          style: GoogleFonts.nunito(),
        ),
        backgroundColor: Colors.green,
      ),
    );
  }
}
