import UIKit
import Flutter
import BackgroundTasks
import AVFoundation

@main
@objc class AppDelegate: FlutterAppDelegate {
  var backgroundChannel: FlutterMethodChannel?
  var audioSession: AVAudioSession?
  
  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    // Registro general de plugins
    GeneratedPluginRegistrant.register(with: self)
    
    // Configurar el manejo de audio para iOS
    setupAudioSession()
    
    // Configurar el canal para manejar tareas en segundo plano
    setupBackgroundTasksChannel()
    
    // Registrar tareas en segundo plano con BGTaskScheduler para iOS 13+
    if #available(iOS 13.0, *) {
      registerBackgroundTasks()
    } else {
      print("Las tareas en segundo plano BGTask no están disponibles en esta versión de iOS")
    }
    
    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }
  
  // Configurar correctamente la sesión de audio para iOS
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
  
  // Nuevo método para configurar el canal de método para tareas en segundo plano
  func setupBackgroundTasksChannel() {
    guard let controller = window?.rootViewController as? FlutterViewController else {
      print("ERROR: No se pudo obtener el controlador Flutter")
      return
    }
    
    // Crear el canal de método para comunicación entre Flutter y nativo
    backgroundChannel = FlutterMethodChannel(
      name: "com.alerta.telegram/background_tasks",
      binaryMessenger: controller.binaryMessenger
    )
    
    // Manejar las llamadas desde Flutter
    backgroundChannel?.setMethodCallHandler { [weak self] (call, result) in
      guard let self = self else { 
        result(FlutterError(code: "UNAVAILABLE", message: "No instance available", details: nil))
        return
      }
      
      switch call.method {
      case "registerBackgroundTasks":
        // Manejar el registro de tareas en segundo plano
        if let identifiers = call.arguments as? [String: Any], let ids = identifiers["identifiers"] as? [String] {
          print("Registrando tareas en segundo plano desde Flutter: \(ids)")
          // El registro real ya está en registerBackgroundTasks()
          result(true)
        } else {
          result(FlutterError(code: "INVALID_ARGUMENTS", message: "Argumentos inválidos", details: nil))
        }
        
      case "setupBackgroundTasks":
        // Manejar la configuración adicional
        print("Configurando tareas en segundo plano desde Flutter")
        result(true)
        
      case "completeBackgroundTask":
        // Marcar una tarea en segundo plano como completada
        if let args = call.arguments as? [String: Any], let identifier = args["taskIdentifier"] as? String {
          print("Marcando tarea completada: \(identifier)")
          result(true)
        } else {
          result(FlutterError(code: "INVALID_ARGUMENTS", message: "Argumentos inválidos", details: nil))
        }
        
      case "configureAudioSession":
        // Configurar la sesión de audio desde Flutter
        print("Reconfigurando sesión de audio desde Flutter")
        self.setupAudioSession()
        result(true)
        
      case "activateAudioSession":
        // Activar la sesión de audio
        do {
          try self.audioSession?.setActive(true, options: .notifyOthersOnDeactivation)
          print("Sesión de audio activada correctamente")
          result(true)
        } catch {
          print("Error al activar sesión de audio: \(error)")
          result(FlutterError(code: "AUDIO_ERROR", message: "Error al activar sesión de audio: \(error)", details: nil))
        }
        
      case "deactivateAudioSession":
        // Desactivar la sesión de audio
        do {
          try self.audioSession?.setActive(false, options: .notifyOthersOnDeactivation)
          print("Sesión de audio desactivada correctamente")
          result(true)
        } catch {
          print("Error al desactivar sesión de audio: \(error)")
          result(FlutterError(code: "AUDIO_ERROR", message: "Error al desactivar sesión de audio: \(error)", details: nil))
        }
        
      default:
        result(FlutterMethodNotImplemented)
      }
    }
  }
  
  // Función para registrar tareas en segundo plano
  @available(iOS 13.0, *)
  func registerBackgroundTasks() {
    // Registrar los identificadores de tareas en segundo plano
    BGTaskScheduler.shared.register(forTaskWithIdentifier: "com.alerta.telegram.refresh", 
                                   using: nil) { task in
      print("Tarea de actualización iniciada")
      self.scheduleAppRefresh()
      task.setTaskCompleted(success: true)
    }
    
    BGTaskScheduler.shared.register(forTaskWithIdentifier: "com.alerta.telegram.processing", 
                                   using: nil) { task in
      print("Tarea de procesamiento iniciada")
      self.scheduleProcessingTask()
      task.setTaskCompleted(success: true)
    }
    
    BGTaskScheduler.shared.register(forTaskWithIdentifier: "com.alerta.telegram.audio", 
                                   using: nil) { task in
      print("Tarea de audio iniciada")
      self.scheduleAudioTask()
      task.setTaskCompleted(success: true)
    }
    
    // La configuración de audio session se maneja ahora desde el paquete audio_session en Flutter
    // Esto evita conflictos entre la configuración nativa y la de Flutter
    
    // Programar tareas iniciales
    scheduleAppRefresh()
    scheduleProcessingTask()
    scheduleAudioTask()
    
    print("Tareas en segundo plano registradas correctamente")
  }
  
  @available(iOS 13.0, *)
  func scheduleAppRefresh() {
    let request = BGAppRefreshTaskRequest(identifier: "com.alerta.telegram.refresh")
    // Ejecutar no antes de 15 minutos desde ahora
    request.earliestBeginDate = Date(timeIntervalSinceNow: 15 * 60)
    
    do {
      try BGTaskScheduler.shared.submit(request)
      print("Tarea app refresh programada correctamente")
    } catch {
      print("No se pudo programar app refresh: \(error)")
    }
  }
  
  @available(iOS 13.0, *)
  func scheduleProcessingTask() {
    let request = BGProcessingTaskRequest(identifier: "com.alerta.telegram.processing")
    // Ejecutar cuando el sistema lo considere oportuno
    request.earliestBeginDate = Date(timeIntervalSinceNow: 5 * 60)
    request.requiresNetworkConnectivity = true
    request.requiresExternalPower = false
    
    do {
      try BGTaskScheduler.shared.submit(request)
      print("Tarea de procesamiento programada correctamente")
    } catch {
      print("No se pudo programar tarea de procesamiento: \(error)")
    }
  }
  
  @available(iOS 13.0, *)
  func scheduleAudioTask() {
    let request = BGProcessingTaskRequest(identifier: "com.alerta.telegram.audio")
    // Ejecutar no antes de 5 minutos desde ahora
    request.earliestBeginDate = Date(timeIntervalSinceNow: 5 * 60)
    request.requiresNetworkConnectivity = true
    request.requiresExternalPower = false
    
    do {
      try BGTaskScheduler.shared.submit(request)
      print("Tarea de audio programada correctamente")
    } catch {
      print("No se pudo programar tarea de audio: \(error)")
    }
  }
}
