import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';

import 'presentation/screens/home_screen.dart';
import 'domain/providers/providers.dart';
import 'core/constants/app_constants.dart';

void main() async {
  try {
    // Asegurar que las dependencias de Flutter estén inicializadas
    WidgetsFlutterBinding.ensureInitialized();

    // Ejecutar la aplicación
    runApp(const ProviderScope(child: MyApp()));
  } catch (e) {
    print('Error crítico al iniciar la app: $e');
    // En una app de producción, aquí se podría registrar el error
  }
}

class MyApp extends ConsumerWidget {
  const MyApp({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Observar el estado de inicialización
    final appInitialization = ref.watch(appInitializationProvider);

    return MaterialApp(
      title: AppConstants.appName,
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3: true,
        colorScheme: ColorScheme.fromSeed(
          seedColor: Colors.blue,
          brightness: Brightness.light,
        ),
        textTheme: GoogleFonts.nunitoTextTheme(Theme.of(context).textTheme),
        appBarTheme: AppBarTheme(
          backgroundColor: Colors.blue,
          foregroundColor: Colors.white,
          elevation: 0,
          centerTitle: true,
          titleTextStyle: GoogleFonts.nunito(
            fontSize: 20,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
      home: appInitialization.when(
        data: (initialized) {
          if (initialized) {
            return const HomeScreen();
          } else {
            return InitErrorScreen(
              onRetry: () => ref.refresh(appInitializationProvider),
            );
          }
        },
        loading: () => const SplashScreen(),
        error:
            (error, stack) => InitErrorScreen(
              error: error.toString(),
              onRetry: () => ref.refresh(appInitializationProvider),
            ),
      ),
    );
  }
}

// Pantalla de carga
class SplashScreen extends StatelessWidget {
  const SplashScreen({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // Usar simplemente un icono en vez de intentar cargar una imagen que puede fallar
            const Icon(
              Icons.notifications_active,
              size: 100,
              color: Colors.blue,
            ),
            const SizedBox(height: 24),
            const Text(
              AppConstants.appName,
              style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            const CircularProgressIndicator(),
            const SizedBox(height: 24),
            const Text('Inicializando servicios...'),
          ],
        ),
      ),
    );
  }
}

// Pantalla de error de inicialización
class InitErrorScreen extends StatelessWidget {
  final String? error;
  final VoidCallback onRetry;

  const InitErrorScreen({Key? key, this.error, required this.onRetry})
    : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.error_outline, size: 80, color: Colors.red),
              const SizedBox(height: 24),
              const Text(
                'Error de inicialización',
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 16),
              Text(
                error ??
                    'No se pudo inicializar la aplicación. Por favor, reiníciala.',
                textAlign: TextAlign.center,
                style: const TextStyle(color: Colors.red),
              ),
              const SizedBox(height: 24),
              ElevatedButton(
                onPressed: onRetry,
                child: const Text('Reintentar'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
