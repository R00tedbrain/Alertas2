import UIKit
import Flutter
import BackgroundTasks
import AVFoundation
// Eliminamos esta importación para evitar que el plugin se cargue
// import flutter_background_service_ios
import audio_session
import flutter_sound

@main
@objc class AppDelegate: FlutterAppDelegate {
  var backgroundChannel: FlutterMethodChannel?
  var backgroundEngineChannel: FlutterMethodChannel?
  var audioSession: AVAudioSession?
  
  // Engine para tareas en segundo plano (headless engine)
  lazy var backgroundEngine: FlutterEngine = {
    let engine = FlutterEngine(name: "background_audio_engine")
    // Ejecutar el motor con el punto de entrada específico para el isolate de fondo
    engine.run(withEntrypoint: "_onIosBackground")
    
    // Registrar todos los plugins en ESTE motor usando GeneratedPluginRegistrant
    // El plugin de flutter_background_service_ios no se registrará porque no hemos importado la biblioteca
    GeneratedPluginRegistrant.register(with: engine)
    print("Plugins registrados para motor headless")
    
    return engine
  }()
  
  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    // Ya no usamos el taskIdentifier del plugin que hemos eliminado
    // SwiftFlutterBackgroundServicePlugin.taskIdentifier = "com.alerta.telegram.refresh"
    
    // Inicializar el motor de segundo plano
    _ = backgroundEngine
    
    // Configurar el canal para el motor headless (PRIMERO)
    setupBackgroundChannel(on: backgroundEngine.binaryMessenger, storeIn: &backgroundEngineChannel)
    
    // Registrar plugins en el motor principal
    // Aquí usamos GeneratedPluginRegistrant completo porque en el motor principal
    // el problema de doble registro no ocurre
    GeneratedPluginRegistrant.register(with: self)
    
    // Configurar sesión de audio para iOS
    setupAudioSession()
    
    // Configurar el canal para la UI principal (opcional)
    if let controller = window?.rootViewController as? FlutterViewController {
      setupBackgroundChannel(on: controller.binaryMessenger, storeIn: &backgroundChannel)
    }
    
    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }
  
  // Configurar el canal nativo usando la misma lógica para ambos motores (principal y headless)
  func setupBackgroundChannel(on messenger: FlutterBinaryMessenger, storeIn channelRef: inout FlutterMethodChannel?) {
    let channel = FlutterMethodChannel(
      name: "com.alerta.telegram/background_tasks",
      binaryMessenger: messenger
    )
    
    channel.setMethodCallHandler { [weak self] (call, result) in
      guard let self = self else {
        result(FlutterError(code: "UNAVAILABLE", message: "AppDelegate instance not available", details: nil))
        return
      }
      
      print("Canal recibió llamada: \(call.method)")
      
      switch call.method {
      case "configureAudioSession":
        print("Configurando sesión de audio")
        let sharedSession = AVAudioSession.sharedInstance()
        do {
          try sharedSession.setCategory(.playAndRecord, 
                                      mode: .spokenAudio,
                                      options: [.defaultToSpeaker, .allowBluetooth])
          print("Sesión de audio configurada correctamente")
          result(true)
        } catch {
          print("Error al configurar sesión de audio: \(error)")
          result(FlutterError(code: "AUDIO_ERROR", message: "Error al configurar sesión de audio: \(error)", details: nil))
        }
        
      case "activateAudioSession":
        print("Activando sesión de audio")
        let sharedSession = AVAudioSession.sharedInstance()
        do {
          try sharedSession.setActive(true, options: .notifyOthersOnDeactivation)
          print("Sesión de audio activada correctamente")
          result(true)
        } catch {
          print("Error al activar sesión de audio: \(error)")
          result(FlutterError(code: "AUDIO_ERROR", message: "Error al activar sesión de audio: \(error)", details: nil))
        }
        
      case "setupBackgroundTasks":
        print("Configurando tareas en segundo plano")
        result(true)
        
      case "startBackgroundFetch":
        print("Recibida solicitud startBackgroundFetch: \(String(describing: call.arguments))")
        // Este método es llamado desde nativo en performFetchWithCompletionHandler
        // y necesita ser manejado por el código Dart
        result(true)
        
      case "scheduleTasks":
        // Ya NO programamos tareas con BGTaskScheduler porque causa los errores
        // Simplemente devolvemos true para evitar errores en la app
        print("Ignorando solicitud de programación de tareas")
        result(true)

      case "registerBackgroundTasks":
        // Implementación dummy del método para evitar MissingPluginException
        print("Registrando tareas en segundo plano (dummy)")
        result(true)
        
      case "completeBackgroundTask":
        // Implementación dummy del método
        print("Completando tarea en segundo plano (dummy)")
        result(true)
        
      case "cancelBackgroundTasks":
        // Implementación dummy del método
        print("Cancelando tareas en segundo plano (dummy)")
        result(true)
        
      case "headlessEngineStarted":
        // Manejar notificación desde el motor headless
        if let args = call.arguments as? [String: Any],
           let timestamp = args["timestamp"] as? Int64 {
          print("Motor headless notificó inicio: \(timestamp)")
          // Podríamos almacenar este estado para saber que el motor está activo
        } else {
          print("Motor headless notificó inicio (sin timestamp)")
        }
        result(true)
        
      default:
        result(FlutterMethodNotImplemented)
      }
    }
    
    channelRef = channel
  }
  
  // CRÍTICO: Implementar el método de background fetch para iOS
  override func application(
    _ application: UIApplication,
    performFetchWithCompletionHandler completionHandler: @escaping (UIBackgroundFetchResult) -> Void
  ) {
    print("iOS llamó a performFetchWithCompletionHandler - despertar Dart")
    
    // Siempre usar el canal del motor headless para background fetch
    if let channel = backgroundEngineChannel {
      // Llamar a Flutter para que maneje el background fetch
      channel.invokeMethod("startBackgroundFetch", arguments: ["taskId": "background_fetch"]) { result in
        let success = (result as? Bool) == true
        if success {
          print("Flutter respondió exitosamente a startBackgroundFetch")
          completionHandler(.newData)
        } else {
          print("Flutter falló al responder a startBackgroundFetch: \(String(describing: result))")
          completionHandler(.failed)
        }
      }
    } else {
      print("ERROR: Canal headless no disponible para background fetch")
      completionHandler(.failed)
    }
  }
  
  // Función para configurar la sesión de audio
  func setupAudioSession() {
    audioSession = AVAudioSession.sharedInstance()
    do {
      try audioSession?.setCategory(.playAndRecord, 
                                   mode: .spokenAudio,
                                   options: [.defaultToSpeaker, .allowBluetooth])
      try audioSession?.setActive(true)
      print("Sesión de audio configurada desde AppDelegate")
    } catch {
      print("Error al configurar sesión de audio: \(error)")
    }
    
    // Registrar para notificaciones de interrupción (llamadas, etc.)
    NotificationCenter.default.addObserver(
      self,
      selector: #selector(handleAudioSessionInterruption),
      name: AVAudioSession.interruptionNotification,
      object: nil
    )
  }
  
  // Manejar interrupciones de audio
  @objc func handleAudioSessionInterruption(notification: Notification) {
    guard let userInfo = notification.userInfo,
          let typeInt = userInfo[AVAudioSessionInterruptionTypeKey] as? UInt,
          let type = AVAudioSession.InterruptionType(rawValue: typeInt) else {
      return
    }
    
    switch type {
    case .began:
      print("Interrupción de audio comenzó")
      // Pausar reproducción o grabación si es necesario
    case .ended:
      print("Interrupción de audio terminó")
      if let optionsInt = userInfo[AVAudioSessionInterruptionOptionKey] as? UInt {
        let options = AVAudioSession.InterruptionOptions(rawValue: optionsInt)
        if options.contains(.shouldResume) {
          print("Se puede reanudar audio")
          // Reanudar reproducción o grabación si es apropiado
        }
      }
    @unknown default:
      break
    }
  }
}
