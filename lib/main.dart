import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:uni_links/uni_links.dart';
import 'dart:async';
import 'dart:io';
import 'dart:ui';
import 'package:flutter/services.dart';
import 'package:flutter/foundation.dart';

import 'presentation/screens/home_screen.dart';
import 'domain/providers/providers.dart';
import 'core/constants/app_constants.dart';
import 'core/services/background_service.dart';

// Punto de entrada para tareas en segundo plano en iOS
// Esta función es invocada por el motor headless
@pragma('vm:entry-point')
void _onIosBackground() {
  try {
    // El siguiente código es necesario para que Flutter sepa
    // que estamos en un nuevo entorno aislado (isolate)
    WidgetsFlutterBinding.ensureInitialized();
    DartPluginRegistrant.ensureInitialized();

    print('🔄 Motor headless iOS iniciado desde _onIosBackground');

    // Configurar canal para comunicación con código nativo
    const MethodChannel channel = MethodChannel(
      'com.alerta.telegram/background_tasks',
    );

    // Notificar que estamos activos
    try {
      channel.invokeMethod('headlessEngineStarted', {
        'timestamp': DateTime.now().millisecondsSinceEpoch,
      });
      print('✅ Canal nativo notificado de inicio del motor headless');
    } catch (e) {
      print('⚠️ Error al notificar canal nativo: $e');
    }

    // Inicializar servicio de alerta en segundo plano
    try {
      final service = BackgroundAlertService();
      print('✅ BackgroundAlertService inicializado en motor headless');
    } catch (e) {
      print('❌ Error al inicializar BackgroundAlertService: $e');
    }
  } catch (e) {
    print('❌ ERROR CRÍTICO en _onIosBackground: $e');
  }
}

bool _initialURIHandled = false;

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

class MyApp extends ConsumerStatefulWidget {
  const MyApp({super.key});

  @override
  ConsumerState<MyApp> createState() => _MyAppState();
}

class _MyAppState extends ConsumerState<MyApp> with WidgetsBindingObserver {
  StreamSubscription? _linkSubscription;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _initURIHandler();
    _initLinksStream();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _linkSubscription?.cancel();
    super.dispose();
  }

  // Para manejar links iniciales cuando la app se abre por primera vez
  Future<void> _initURIHandler() async {
    // No manejar URIs en web
    if (kIsWeb) return;

    if (!_initialURIHandled) {
      _initialURIHandled = true;
      try {
        final initialURI = await getInitialUri();
        if (initialURI != null) {
          _handleURI(initialURI);
        }
      } catch (e) {
        print('Error al manejar URI inicial: $e');
      }
    }
  }

  // Para manejar links cuando la app ya está abierta
  void _initLinksStream() {
    // No inicializar en web, solo en móviles
    if (kIsWeb) return;

    // Solo continuar si estamos en iOS
    if (!Platform.isIOS) return;

    _linkSubscription = uriLinkStream.listen(
      (Uri? uri) {
        if (uri != null) {
          _handleURI(uri);
        }
      },
      onError: (Object err) {
        print('Error en stream de links: $err');
      },
    );
  }

  // Manejar el URI recibido
  void _handleURI(Uri uri) {
    print('URI recibido: $uri');

    // Verificar si el esquema coincide con nuestro esquema personalizado
    if (uri.scheme == 'alertatelegram') {
      // Procesar según la ruta
      if (uri.path.isEmpty || uri.path == '/iniciar') {
        // Iniciar alerta
        _startAlert();
      }
    }
  }

  // Método para iniciar la alerta
  void _startAlert() {
    print('Iniciando alerta desde URL scheme');
    // Esperar a que la aplicación esté completamente inicializada
    // antes de intentar iniciar la alerta
    Future.delayed(Duration(seconds: 1), () {
      // Verificar que la aplicación esté inicializada
      ref
          .read(appInitializationProvider)
          .when(
            data: (initialized) {
              if (initialized) {
                // Iniciar la alerta
                ref.read(alertStatusProvider.notifier).startAlert().then((
                  success,
                ) {
                  if (success) {
                    print('Alerta iniciada correctamente desde URL scheme');
                  } else {
                    print('Error al iniciar alerta desde URL scheme');
                  }
                });
              } else {
                print('App no inicializada, no se puede iniciar alerta');
              }
            },
            loading: () => print('App cargando, esperando para iniciar alerta'),
            error:
                (error, _) =>
                    print('Error en app, no se puede iniciar alerta: $error'),
          );
    });
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      // Reintentar verificar los links al reanudar la app
      _initURIHandler();
    }
  }

  @override
  Widget build(BuildContext context) {
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
  const SplashScreen({super.key});

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

  const InitErrorScreen({super.key, this.error, required this.onRetry});

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
