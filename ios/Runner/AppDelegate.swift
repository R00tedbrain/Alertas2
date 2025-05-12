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
    
    // CRÍTICO: Registrar los plugins para el motor en segundo plano
    // Usando nuestra propia implementación de FlutterBackgroundServicePlugin
    // Manejamos el registro manualmente sin usar el callback
    print("Registrando plugins para el motor en segundo plano")
    
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
  
  // CRÍTICO: Implementar el método de background fetch para iOS
  override func application(
    _ application: UIApplication,
    performFetchWithCompletionHandler completionHandler: @escaping (UIBackgroundFetchResult) -> Void
  ) {
    print("iOS llamó a performFetchWithCompletionHandler - despertar Dart")
    
    // Implementación directa sin usar la clase que causa problemas
    guard let controller = window?.rootViewController as? FlutterViewController else {
      print("ERROR: No se pudo obtener el controlador Flutter para background fetch")
      completionHandler(.failed)
      return
    }
    
    let methodChannel = FlutterMethodChannel(
      name: "com.alerta.telegram/background_tasks",
      binaryMessenger: controller.binaryMessenger
    )
    
    // Llamar a Flutter para que maneje el background fetch
    methodChannel.invokeMethod("startBackgroundFetch", arguments: ["taskId": "background_fetch"]) { result in
      if let success = result as? Bool, success {
        print("Flutter respondió exitosamente a startBackgroundFetch")
        completionHandler(.newData)
      } else {
        print("Flutter falló al responder a startBackgroundFetch: \(String(describing: result))")
        completionHandler(.failed)
      }
    }
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
        
      case "scheduleTasks":
        // Manejar la programación manual de tareas
        if #available(iOS 13.0, *) {
          guard let args = call.arguments as? [String: Any] else {
            result(FlutterError(code: "INVALID_ARGUMENTS", message: "Argumentos inválidos para programar tareas", details: nil))
            return
          }
          
          print("Recibida solicitud para programar tareas desde Flutter: \(args)")
          
          // Programar tarea de refresh
          if let refreshParams = args["refresh"] as? [String: Any],
             let refreshId = refreshParams["id"] as? String,
             let refreshDelay = refreshParams["delay"] as? Int {
            
            let request = BGAppRefreshTaskRequest(identifier: refreshId)
            request.earliestBeginDate = Date(timeIntervalSinceNow: TimeInterval(refreshDelay))
            
            do {
              try BGTaskScheduler.shared.submit(request)
              print("Tarea \(refreshId) programada para ejecutarse en \(refreshDelay) segundos")
            } catch {
              print("Error al programar tarea \(refreshId): \(error)")
            }
          }
          
          // Programar tarea de procesamiento
          if let processingParams = args["processing"] as? [String: Any],
             let processingId = processingParams["id"] as? String,
             let processingDelay = processingParams["delay"] as? Int {
            
            let request = BGProcessingTaskRequest(identifier: processingId)
            request.earliestBeginDate = Date(timeIntervalSinceNow: TimeInterval(processingDelay))
            request.requiresNetworkConnectivity = true
            request.requiresExternalPower = false
            
            do {
              try BGTaskScheduler.shared.submit(request)
              print("Tarea \(processingId) programada para ejecutarse en \(processingDelay) segundos")
            } catch {
              print("Error al programar tarea \(processingId): \(error)")
            }
          }
          
          // Programar tarea de audio
          if let audioParams = args["audio"] as? [String: Any],
             let audioId = audioParams["id"] as? String,
             let audioDelay = audioParams["delay"] as? Int {
            
            let request = BGProcessingTaskRequest(identifier: audioId)
            request.earliestBeginDate = Date(timeIntervalSinceNow: TimeInterval(audioDelay))
            request.requiresNetworkConnectivity = true
            request.requiresExternalPower = false
            
            do {
              try BGTaskScheduler.shared.submit(request)
              print("Tarea \(audioId) programada para ejecutarse en \(audioDelay) segundos")
            } catch {
              print("Error al programar tarea \(audioId): \(error)")
            }
          }
          
          result(true)
        } else {
          result(FlutterError(code: "UNSUPPORTED", message: "Programación de tareas no soportada en esta versión de iOS", details: nil))
        }
        
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
      
      // Intentar despertar a la aplicación Flutter usando el método existente
      self.executeFlutterInBackground(task: task, identifier: "com.alerta.telegram.refresh")
      
      // Programar la próxima ejecución
      self.scheduleAppRefresh()
    }
    
    BGTaskScheduler.shared.register(forTaskWithIdentifier: "com.alerta.telegram.processing", 
                                   using: nil) { task in
      print("Tarea de procesamiento iniciada")
      
      // Intentar despertar a la aplicación Flutter
      self.executeFlutterInBackground(task: task, identifier: "com.alerta.telegram.processing")
      
      // Programar la próxima ejecución
      self.scheduleProcessingTask()
    }
    
    BGTaskScheduler.shared.register(forTaskWithIdentifier: "com.alerta.telegram.audio", 
                                   using: nil) { task in
      print("Tarea de audio iniciada")
      
      // Intentar despertar a la aplicación Flutter
      self.executeFlutterInBackground(task: task, identifier: "com.alerta.telegram.audio")
      
      // Programar la próxima ejecución
      self.scheduleAudioTask()
    }
    
    // Programar tareas iniciales
    scheduleAppRefresh()
    scheduleProcessingTask()
    scheduleAudioTask()
    
    print("Tareas en segundo plano registradas correctamente")
  }
  
  @available(iOS 13.0, *)
  func executeFlutterInBackground(task: BGTask, identifier: String) {
    print("Ejecutando Flutter en segundo plano para \(identifier)")
    
    // Asegurarse de que la sesión de audio esté configurada
    setupAudioSession()
    
    // Crear un temporizador para completar la tarea eventualmente
    let taskTimer = Timer.scheduledTimer(withTimeInterval: 25, repeats: false) { _ in
      print("Tiempo límite alcanzado para \(identifier), completando tarea")
      task.setTaskCompleted(success: true)
    }
    
    // Evitar que la aplicación se duerma durante el procesamiento
    let processingTask = UIApplication.shared.beginBackgroundTask {
      print("Background execution time limit reached")
      taskTimer.invalidate()
      task.setTaskCompleted(success: false)
    }
    
    // Usar el canal existente para solicitar que Flutter ejecute el servicio de fondo
    guard let controller = window?.rootViewController as? FlutterViewController else {
      print("ERROR: No se pudo obtener el controlador Flutter para BGTask")
      taskTimer.invalidate()
      task.setTaskCompleted(success: false)
      
      if processingTask != UIBackgroundTaskIdentifier.invalid {
        UIApplication.shared.endBackgroundTask(processingTask)
      }
      
      return
    }
    
    // Usar el canal existente
    let methodChannel = FlutterMethodChannel(
      name: "com.alerta.telegram/background_tasks",
      binaryMessenger: controller.binaryMessenger
    )
    
    // Asegurarnos de registrar los plugins directamente
    print("Registrando plugins para el contexto de ejecución en segundo plano")
    GeneratedPluginRegistrant.register(with: controller)
    
    // Llamar a Flutter para que ejecute el servicio en segundo plano
    methodChannel.invokeMethod("startBackgroundFetch", arguments: ["taskId": identifier]) { result in
      if let success = result as? Bool, success {
        print("Flutter respondió exitosamente a startBackgroundFetch")
        taskTimer.invalidate()
        task.setTaskCompleted(success: true)
      } else {
        print("Flutter falló al responder a startBackgroundFetch: \(String(describing: result))")
        task.setTaskCompleted(success: false)
      }
      
      // Finalizar la tarea de procesamiento
      if processingTask != UIBackgroundTaskIdentifier.invalid {
        UIApplication.shared.endBackgroundTask(processingTask)
      }
    }
  }
  
  @available(iOS 13.0, *)
  func scheduleAppRefresh() {
    let request = BGAppRefreshTaskRequest(identifier: "com.alerta.telegram.refresh")
    // Ejecutar no antes de 15 minutos desde ahora (reducido para pruebas)
    request.earliestBeginDate = Date(timeIntervalSinceNow: 5 * 60)
    
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
    request.earliestBeginDate = Date(timeIntervalSinceNow: 2 * 60)
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
    request.earliestBeginDate = Date(timeIntervalSinceNow: 3 * 60)
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
