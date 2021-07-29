import Flutter
import UIKit
import Tiercel

public class SwiftNativeDownloaderPlugin: NSObject, FlutterPlugin {
    var session: SessionManager
    var channel: FlutterMethodChannel?
    
    public static func register(with registrar: FlutterPluginRegistrar) {
        let channel = FlutterMethodChannel(name: "com.haijunwei.native_downloader", binaryMessenger: registrar.messenger())
        let instance = SwiftNativeDownloaderPlugin()
        instance.channel = channel
        registrar.addMethodCallDelegate(instance, channel: channel)
        registrar.addApplicationDelegate(instance)
    }
    
    override init() {
        var config = SessionConfiguration()
        config.maxConcurrentTasksLimit = 3
        config.allowsCellularAccess = true
        session = SessionManager("downloader", configuration: config)
        super.init()
        session.tasks.forEach {
            self.handleTaskEvent(task: $0)
        }
    }

    public func handle(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
        if call.method == "download" {
          download(call, result: result)
        } else if call.method == "multiDownload" {
            multiDownload(call, result: result)
        } else if call.method == "start" {
            start(call, result: result)
        } else if call.method == "suspend" {
            suspend(call, result: result)
        } else if call.method == "suspend" {
            suspend(call, result: result)
        } else if call.method == "cancel" {
            cancel(call, result: result)
        } else if call.method == "remove" {
            remove(call, result: result)
        } else if call.method == "removeAll" {
            removeAll(call, result: result)
        } else if call.method == "getTaskFilePath" {
            getTaskFilePath(call, result: result)
        } else if call.method == "syncStatus" {
            syncStatus(call, result: result)
        }
    }
    
    
    func download(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
        let arguments = call.arguments as! [String: Any]
        let url = URL(string:arguments["url"] as! String)!
        let fileName = arguments["fileName"] as? String
        let task = session.download(url, fileName: fileName)
        if task != nil {
            handleTaskEvent(task: task!)
            result(true)
        } else {
            result(false)
        }
    }
    
    func multiDownload(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
        let arguments = call.arguments as! [String: Any]
        let urls = (arguments["urls"] as! [String]).map { URL(string: $0)! }
        let fileNames = arguments["fileNames"] as? [String]
        let tasks = session.multiDownload(urls, fileNames: fileNames)
        if !tasks.isEmpty {
            tasks.forEach { handleTaskEvent(task: $0) }
            result(true)
        } else {
            result(false)
        }
    }
    
    func start(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
        let arguments = call.arguments as! [String: Any]
        let url = URL(string:arguments["url"] as! String)!
        session.start(url)
        result(nil)
    }
    
    func suspend(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
        let arguments = call.arguments as! [String: Any]
        let url = URL(string:arguments["url"] as! String)!
        session.suspend(url)
        result(nil)
    }
    
    func cancel(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
        let arguments = call.arguments as! [String: Any]
        let url = URL(string:arguments["url"] as! String)!
        session.cancel(url)
        result(nil)
    }
    
    func remove(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
        let arguments = call.arguments as! [String: Any]
        let url = URL(string:arguments["url"] as! String)!
        let completely = arguments["completely"] as! Bool
        session.remove(url, completely: completely)
        result(nil)
    }
    
    func removeAll(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
        let arguments = call.arguments as! [String: Any]
        let completely = arguments["completely"] as! Bool
        let tasks = session.tasks
        tasks.forEach { session.remove($0, completely: completely) }
        result(nil)
    }
    
    func exists(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
        let arguments = call.arguments as! [String: Any]
        let url = URL(string:arguments["url"] as! String)!
        let task = session.fetchTask(url)
        result(task != nil)
    }
    
    func getTaskFilePath(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
        let arguments = call.arguments as! [String: Any]
        let url = URL(string:arguments["url"] as! String)!
        let task = session.fetchTask(url)
        result(task?.filePath)
    }
    
    func syncStatus(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
        session.tasks.forEach {
            self.updateTaskStatus($0)
        }
        result(nil)
    }
    
    func handleTaskEvent(task: DownloadTask) {
        task.progress { [weak self] task in
            self?.updateTaskStatus(task)
        }
        .success { [weak self] task in
            self?.updateTaskStatus(task)
        }
        .failure { [weak self] task in
            self?.updateTaskStatus(task)
        }
    }
    
    func updateTaskStatus(_ task: DownloadTask) {
        var status = 0
        switch task.status {
        case .suspended:
            status = 2
        case .succeeded:
            status = 3
        case .running:
            status = 1
        default:
            status = 0
        }
        channel?.invokeMethod(
            "taskDidUpdate",
            arguments: [
                "url": task.url.absoluteString,
                "totalBytes": task.progress.totalUnitCount,
                "completedBytes": task.progress.completedUnitCount,
                "speed": task.speed,
                "status": status,
            ]
        )
    }
    
    // MARK: -
    
    public func application(_ application: UIApplication, handleEventsForBackgroundURLSession identifier: String, completionHandler: @escaping () -> Void) -> Bool {
        if session.identifier == identifier {
            session.completionHandler = completionHandler
        }
        return false
    }
}

