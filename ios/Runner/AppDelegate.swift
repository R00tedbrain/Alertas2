import UIKit
import Flutter
import BackgroundTasks
import AVFoundation
// Eliminamos esta importación para evitar que el plugin se cargue
// import flutter_background_service_ios
import audio_session
import flutter_sound
import CoreLocation

@main
@objc class AppDelegate: FlutterAppDelegate {
  var backgroundChannel: FlutterMethodChannel?
  var backgroundEngineChannel: FlutterMethodChannel?
  var audioSession: AVAudioSession?
  private var audioEngine: AVAudioEngine?
  
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
    
    // Registrar manejadores de tareas en segundo plano
    BGTaskScheduler.shared.register(forTaskWithIdentifier: "com.alerta.telegram.refresh", using: nil) { task in
      self.handleAppRefresh(task: task as! BGAppRefreshTask)
    }
    
    BGTaskScheduler.shared.register(forTaskWithIdentifier: "com.alerta.telegram.processing", using: nil) { task in
      self.handleBackgroundProcessing(task: task as! BGProcessingTask)
    }
    
    BGTaskScheduler.shared.register(forTaskWithIdentifier: "com.alerta.telegram.audio", using: nil) { task in
      self.handleAudioTask(task: task as! BGProcessingTask)
    }
    
    // Registrar para notificaciones de cambio de ruta de audio
    NotificationCenter.default.addObserver(
      self,
      selector: #selector(handleRouteChange),
      name: AVAudioSession.routeChangeNotification,
      object: nil
    )
    
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
                                      mode: .voiceChat,
                                      options: [.defaultToSpeaker, .allowBluetooth, .allowAirPlay])
          print("Sesión de audio configurada correctamente")
          result(true)
        } catch {
          print("Error al configurar sesión de audio: \(error)")
          result(FlutterError(code: "AUDIO_ERROR", message: "Error al configurar sesión de audio: \(error)", details: nil))
        }
        
      case "prepareForRecording":
        print("Preparando para grabación desde Flutter")
        self.prepareForRecording()
        result(true)
        
      case "activateAudioSession":
        print("Activando sesión de audio")
        self.activateAudioSession()
        result(true)
        
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
        
      case "deactivateAudioSession":
        self.deactivateAudioSession()
        result(true)
        
      case "startAudioEngine":
        self.setupAudioEngine()
        result(true)
        
      case "stopAudioEngine":
        self.completelyStopAudioEngine()
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
                                   mode: .voiceChat,
                                   options: [.defaultToSpeaker, .allowBluetooth, .allowAirPlay])
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
      // Pausar grabación si es necesario y detener el motor de audio temporalmente
      completelyStopAudioEngine()
    case .ended:
      print("Interrupción de audio terminó")
      if let optionsInt = userInfo[AVAudioSessionInterruptionOptionKey] as? UInt {
        let options = AVAudioSession.InterruptionOptions(rawValue: optionsInt)
        if options.contains(.shouldResume) {
          print("Se puede reanudar audio")
          // Reanudar el motor de audio en modo silencioso para mantener la app activa
          setupAudioEngine()
        }
      }
    @unknown default:
      break
    }
  }
  
  // Configure la sesión de audio para modo background
  private func configureAudioSession() {
    print("Configurando sesión de audio")
    
    // Mantener una referencia fuerte a la sesión de audio
    audioSession = AVAudioSession.sharedInstance()
    
    do {
      // Configurar sesión para grabación específicamente con modo de voz
      try audioSession?.setCategory(.playAndRecord, 
                                   mode: .voiceChat, 
                                   options: [.allowBluetooth, .defaultToSpeaker, .allowAirPlay, .allowBluetoothA2DP])
      
      // Configurar calidad de grabación óptima
      try audioSession?.setPreferredSampleRate(44100)
      try audioSession?.setPreferredIOBufferDuration(0.005)
      
      // Establecer enrutamiento preferido para el micrófono integrado
      try audioSession?.setPreferredInput(audioSession?.availableInputs?.first(where: { $0.portType == .builtInMic }))
      
      // Activar la sesión con opciones para mantenerla activa
      try audioSession?.setActive(true, options: [.notifyOthersOnDeactivation])
      print("Sesión de audio configurada correctamente")
      
      // Inicializar y mantener activo el motor de audio para background
      setupAudioEngine()
    } catch {
      print("Error al configurar sesión de audio: \(error.localizedDescription)")
    }
  }
  
  // Método para activar la sesión de audio
  private func activateAudioSession() {
    print("Activando sesión de audio")
    
    // Crear la sesión si no existe
    if audioSession == nil {
      audioSession = AVAudioSession.sharedInstance()
    }
    
    do {
      // Volver a configurar y activar la sesión
      try audioSession?.setCategory(.playAndRecord, 
                                  mode: .default, 
                                  options: [.allowBluetooth, .defaultToSpeaker, .allowAirPlay])
                                   
      try audioSession?.setActive(true, options: .notifyOthersOnDeactivation)
      print("Sesión de audio activada correctamente")
      
      // Configurar el motor de audio si no está activo
      if audioEngine == nil || !(audioEngine?.isRunning ?? false) {
        setupAudioEngine()
      }
    } catch {
      print("Error al activar sesión de audio: \(error)")
    }
  }
  
  // Método para desactivar sesión de audio de forma limpia
  private func deactivateAudioSession() {
    print("Desactivando sesión de audio")
    
    // Detener el motor de audio primero
    completelyStopAudioEngine()
    
    // Desactivar la sesión de audio
    do {
      try audioSession?.setActive(false, options: .notifyOthersOnDeactivation)
      print("Sesión de audio desactivada correctamente")
    } catch {
      print("Error al desactivar sesión de audio: \(error)")
    }
  }
  
  // Configurar un motor de audio mínimo para mantener la app activa en background
  private func setupAudioEngine() {
    // Primero limpiar cualquier instancia anterior para evitar problemas
    completelyStopAudioEngine()
    
    // Crear una nueva instancia limpia
    audioEngine = AVAudioEngine()
    
    do {
      // Crear un formato de audio que coincida con el formato de grabación
      let silentFormat = AVAudioFormat(standardFormatWithSampleRate: 44100, channels: 2)!
      
      // Necesitamos instalar un tap en el nodo de entrada (micrófono)
      // pero NO vamos a enrutar este audio a la salida (para evitar acoplamiento)
      let inputNode = audioEngine!.inputNode
      let inputFormat = inputNode.inputFormat(forBus: 0)
      
      // Instalar un tap en la entrada para mantener activo el micrófono
      inputNode.installTap(onBus: 0, bufferSize: 4096, format: inputFormat) { buffer, time in
        // No hacemos nada con los datos del buffer
        // Solo mantenemos el micrófono activo
      }
      
      // Crear un nodo silencioso para mantener la sesión activa sin reproducir nada real
      let silentPlayer = AVAudioPlayerNode()
      audioEngine?.attach(silentPlayer)
      
      // Conectar el nodo al motor de audio, pero NO a la entrada para evitar acoplamiento
      audioEngine?.connect(silentPlayer, to: audioEngine!.mainMixerNode, format: silentFormat)
      
      // Activar el motor de audio
      try audioEngine?.start()
      
      // Crear un buffer silencioso y programarlo para reproducción continua en un loop
      let silentBuffer = AVAudioPCMBuffer(pcmFormat: silentFormat, frameCapacity: 1024)!
      for i in 0..<Int(silentBuffer.frameCapacity) {
        let bufferData = silentBuffer.floatChannelData![0]
        bufferData[i] = 0.0 // Silencio completo
      }
      silentBuffer.frameLength = silentBuffer.frameCapacity
      
      // Reproducir el silencio en un loop para mantener activo el motor de audio
      silentPlayer.play()
      silentPlayer.scheduleBuffer(silentBuffer, at: nil, options: .loops, completionHandler: nil)
      
      print("Motor de audio con micrófono activo configurado correctamente")
    } catch {
      print("Error al configurar el motor de audio: \(error.localizedDescription)")
    }
  }
  
  // Detener completamente el motor de audio
  private func completelyStopAudioEngine() {
    if let engine = audioEngine {
      if engine.isRunning {
        engine.stop()
        print("Motor de audio detenido")
      }
      
      // Limpiar todas las conexiones y nodos
      engine.inputNode.removeTap(onBus: 0)
      engine.reset()
    }
    audioEngine = nil
  }
  
  // Manejar tarea de actualización de la app
  private func handleAppRefresh(task: BGAppRefreshTask) {
    print("Ejecutando tarea de actualización en segundo plano")
    
    // Programar la próxima ejecución
    scheduleAppRefresh(identifier: "com.alerta.telegram.refresh", delay: 60)
    
    // Completar la tarea
    task.setTaskCompleted(success: true)
  }
  
  // Manejar tarea de procesamiento en segundo plano
  private func handleBackgroundProcessing(task: BGProcessingTask) {
    print("Ejecutando tarea de procesamiento en segundo plano")
    
    // Programar la próxima ejecución
    scheduleBackgroundProcessing(identifier: "com.alerta.telegram.processing", delay: 900)
    
    // Completar la tarea
    task.setTaskCompleted(success: true)
  }
  
  // Preparar específicamente para grabación de audio
  private func prepareForRecording() {
    print("Preparando explícitamente para grabación")
    
    // Detener el motor de audio actual si está corriendo
    completelyStopAudioEngine()
    
    // Obtener la sesión de audio
    audioSession = AVAudioSession.sharedInstance()
    
    do {
      // Configuración óptima para grabación de voz
      try audioSession?.setCategory(.playAndRecord, 
                                   mode: .voiceChat,
                                   options: [.defaultToSpeaker, .allowBluetooth])
      
      // Configurar preferencias para calidad óptima de grabación de voz
      try audioSession?.setPreferredSampleRate(44100)
      try audioSession?.setPreferredInputNumberOfChannels(1)
      try audioSession?.setPreferredIOBufferDuration(0.005)
      
      // Asegurar que usamos el micrófono interno
      if let inputs = audioSession?.availableInputs {
        for input in inputs {
          if input.portType == .builtInMic {
            try audioSession?.setPreferredInput(input)
            break
          }
        }
      }
      
      // Activar la sesión
      try audioSession?.setActive(true, options: .notifyOthersOnDeactivation)
      
      // Configurar un motor de audio que permita la grabación
      setupAudioEngine()
      
      print("Sesión preparada para grabación exitosamente")
    } catch {
      print("Error al preparar sesión para grabación: \(error)")
    }
  }
  
  // Método para manejar tarea de audio en segundo plano
  private func handleAudioTask(task: BGProcessingTask) {
    print("Ejecutando tarea de audio en segundo plano")
    
    // Configurar la sesión para grabación
    prepareForRecording()
    
    // Programar la próxima ejecución
    scheduleAudioTask(identifier: "com.alerta.telegram.audio", delay: 60)
    
    // Completar la tarea
    task.setTaskCompleted(success: true)
  }
  
  // Programar tarea de actualización de la app
  private func scheduleAppRefresh(identifier: String, delay: TimeInterval) {
    let request = BGAppRefreshTaskRequest(identifier: identifier)
    request.earliestBeginDate = Date(timeIntervalSinceNow: delay)
    
    do {
      try BGTaskScheduler.shared.submit(request)
      print("Tarea de actualización programada: \(identifier), después de \(delay) segundos")
    } catch {
      print("No se pudo programar la tarea de actualización: \(error)")
    }
  }
  
  // Programar tarea de procesamiento en segundo plano
  private func scheduleBackgroundProcessing(identifier: String, delay: TimeInterval) {
    let request = BGProcessingTaskRequest(identifier: identifier)
    request.earliestBeginDate = Date(timeIntervalSinceNow: delay)
    request.requiresNetworkConnectivity = true
    
    do {
      try BGTaskScheduler.shared.submit(request)
      print("Tarea de procesamiento programada: \(identifier), después de \(delay) segundos")
    } catch {
      print("No se pudo programar la tarea de procesamiento: \(error)")
    }
  }
  
  // Programar tarea de audio en segundo plano
  private func scheduleAudioTask(identifier: String, delay: TimeInterval) {
    let request = BGProcessingTaskRequest(identifier: identifier)
    request.earliestBeginDate = Date(timeIntervalSinceNow: delay)
    request.requiresExternalPower = false
    
    do {
      try BGTaskScheduler.shared.submit(request)
      print("Tarea de audio programada: \(identifier), después de \(delay) segundos")
    } catch {
      print("No se pudo programar la tarea de audio: \(error)")
    }
  }
  
  // Implementar método para manejo de estado en background
  override func applicationWillResignActive(_ application: UIApplication) {
    // Asegurar que la sesión de audio permanezca activa
    activateAudioSession()
  }
  
  override func applicationDidEnterBackground(_ application: UIApplication) {
    // Asegurar que la sesión de audio permanezca activa
    activateAudioSession()
  }
  
  // Detectar cambios en la ruta de audio (conectar/desconectar auriculares, etc.)
  @objc func handleRouteChange(notification: Notification) {
    guard let userInfo = notification.userInfo,
          let reasonValue = userInfo[AVAudioSessionRouteChangeReasonKey] as? UInt,
          let reason = AVAudioSession.RouteChangeReason(rawValue: reasonValue) else {
      return
    }
    
    // La razón nos dice qué cambió
    switch reason {
    case .newDeviceAvailable:
      // Se conectó un nuevo dispositivo de salida
      print("Nueva ruta de audio disponible (posible auricular conectado)")
      // Asegurar que no hay acoplamiento al cambiar dispositivos
      if audioEngine?.isRunning == true {
        completelyStopAudioEngine()
        setupAudioEngine()
      }
    case .oldDeviceUnavailable:
      // Se desconectó un dispositivo
      print("Dispositivo de audio desconectado")
      // Reconfigurar el motor de audio para evitar problemas
      if audioEngine?.isRunning == true {
        completelyStopAudioEngine()
        setupAudioEngine()
      }
    default:
      break
    }
  }
}
