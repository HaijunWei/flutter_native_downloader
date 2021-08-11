package com.haijunwei.native_downloader

import android.util.Log
import androidx.annotation.NonNull
import com.arialyy.aria.core.Aria
import com.arialyy.aria.core.download.DownloadEntity
import com.arialyy.aria.core.download.DownloadTaskListener
import com.arialyy.aria.core.task.DownloadTask
import io.flutter.embedding.engine.plugins.FlutterPlugin
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import io.flutter.plugin.common.MethodChannel.MethodCallHandler
import io.flutter.plugin.common.MethodChannel.Result
import java.util.*

/** NativeDownloaderPlugin */
class NativeDownloaderPlugin: FlutterPlugin, MethodCallHandler {
  /// The MethodChannel that will the communication between Flutter and native Android
  ///
  /// This local reference serves to register the plugin with the Flutter Engine and unregister it
  /// when the Flutter Engine is detached from the Activity
  private lateinit var channel : MethodChannel
  private lateinit var rootPath: String
  private lateinit var listener: TaskListener

  override fun onAttachedToEngine(@NonNull flutterPluginBinding: FlutterPlugin.FlutterPluginBinding) {
    channel = MethodChannel(flutterPluginBinding.binaryMessenger, "com.haijunwei.native_downloader")
    channel.setMethodCallHandler(this)
    val context = flutterPluginBinding.applicationContext
    rootPath = Objects.requireNonNull(context.getExternalFilesDir(""))!!.path
    listener = TaskListener(channel)
    Aria.init(context)
    Aria.download(listener).register()
  }

  override fun onMethodCall(@NonNull call: MethodCall, @NonNull result: Result) {
    when (call.method) {
        "download" -> {
          download(call, result)
        }
        "multiDownload" -> {
          multiDownload(call, result)
        }
        "start" -> {
          start(call, result)
        }
        "suspend" -> {
          suspend(call, result)
        }
        "cancel" -> {
          cancel(call, result)
        }
        "remove" -> {
          remove(call, result)
        }
        "removeAll" -> {
          removeAll(call, result)
        }
        "exists" -> {
          exists(call, result)
        }
        "getTaskFilePath" -> {
          getTaskFilePath(call, result)
        }
        "syncStatus" -> {
          syncStatus(result)
        }
        else -> {
          result.notImplemented()
        }
    }
  }

  override fun onDetachedFromEngine(@NonNull binding: FlutterPlugin.FlutterPluginBinding) {
    channel.setMethodCallHandler(null)
    Aria.download(listener).unRegister()
  }

  private fun download(@NonNull call: MethodCall, @NonNull result: Result) {
    val url: String? = call.argument("url")
    var fileName: String? = call.argument("fileName")
    if (fileName == null) {
      fileName = url!!.substring(url.lastIndexOf("/"))
    }
    Aria.download(listener).load(url).setFilePath("$rootPath/$fileName").create()
    result.success(true)
  }

  private fun multiDownload(@NonNull call: MethodCall, @NonNull result: Result) {
    val urls: ArrayList<String>? = call.argument("urls")
    val fileNames: ArrayList<String>? = call.argument("fileNames")
    for (i in urls!!.indices) {
      val url = urls[i]
      val fileName: String = if (fileNames == null) {
        url.substring(url.lastIndexOf("/"))
      } else {
        fileNames[i]
      }
      Aria.download(listener).load(url).setFilePath("$rootPath/$fileName").create()
    }
    result.success(true)
  }

  private fun start(@NonNull call: MethodCall, @NonNull result: Result) {
    val url: String? = call.argument("url")
    val task = Aria.download(listener).getFirstDownloadEntity(url)
    Aria.download(listener).load(task.id).resume()
    result.success(null)
  }

  private fun suspend(@NonNull call: MethodCall, @NonNull result: Result) {
    val url: String? = call.argument("url")
    val task = Aria.download(listener).getFirstDownloadEntity(url)
    Aria.download(listener).load(task.id).stop()
    result.success(null)
  }

  private fun cancel(@NonNull call: MethodCall, @NonNull result: Result) {
    val url: String? = call.argument("url")
    val task = Aria.download(listener).getFirstDownloadEntity(url)
    Aria.download(listener).load(task.id).cancel()
    result.success(null)
  }

  private fun remove(@NonNull call: MethodCall, @NonNull result: Result) {
    val url: String? = call.argument("url")
    val task = Aria.download(listener).getFirstDownloadEntity(url)
    Aria.download(listener).load(task.id).cancel()
    result.success(null)
  }

  private fun removeAll(@NonNull call: MethodCall, @NonNull result: Result) {
    val completely: Boolean = call.argument("completely") ?: false
    Aria.download(listener).removeAllTask(completely)
    result.success(null)
  }

  private fun exists(@NonNull call: MethodCall, @NonNull result: Result) {
    val url: String? = call.argument("url")
    result.success(Aria.download(listener).taskExists(url))
  }

  private fun getTaskFilePath(@NonNull call: MethodCall, @NonNull result: Result) {
    val url: String? = call.argument("url")
    val task = Aria.download(listener).getFirstDownloadEntity(url)
    result.success(task.filePath)
  }

  private fun syncStatus(@NonNull result: Result) {
    Aria.download(listener).taskList?.forEach {
      updateTaskStatus(it)
    }
    result.success(null)
  }

  private fun updateTaskStatus(task: DownloadEntity) {
    val dict = hashMapOf<String, Any>()
    dict["url"] = task.key
    dict["totalBytes"] = task.fileSize
    dict["completedBytes"] = ((task.percent.toDouble() / 100.0) * task.fileSize.toDouble()).toInt()
    dict["speed"] = task.speed
    val status: Int = when (task.state) {
        4 -> {
          1
        }
        1 -> {
          3
        }
        2 -> {
          2
        }
        else -> {
          0
        }
    }
    dict["status"] = status
    channel.invokeMethod("taskDidUpdate", dict)
  }
}

class TaskListener(private var channel: MethodChannel) : DownloadTaskListener {
  override fun onWait(task: DownloadTask) {
    updateTaskStatus(task)
  }

  override fun onPre(task: DownloadTask) {
    updateTaskStatus(task)
  }

  override fun onTaskPre(task: DownloadTask) {
    updateTaskStatus(task)
  }

  override fun onTaskResume(task: DownloadTask) {
    updateTaskStatus(task)
  }

  override fun onTaskStart(task: DownloadTask) {
    updateTaskStatus(task)
  }

  override fun onTaskStop(task: DownloadTask) {
    updateTaskStatus(task)
  }

  override fun onTaskCancel(task: DownloadTask) {
    updateTaskStatus(task)
  }

  override fun onTaskFail(task: DownloadTask, e: Exception?) {
    updateTaskStatus(task)
  }

  override fun onTaskComplete(task: DownloadTask) {
    updateTaskStatus(task)
  }

  override fun onTaskRunning(task: DownloadTask) {
    updateTaskStatus(task)
  }

  override fun onNoSupportBreakPoint(task: DownloadTask?) {

  }

  private fun updateTaskStatus(task: DownloadTask) {
    val dict = hashMapOf<String, Any>()
    dict["url"] = task.key
    dict["totalBytes"] = task.fileSize
    dict["completedBytes"] = ((task.percent.toDouble() / 100.0) * task.fileSize.toDouble()).toInt()
    dict["speed"] = task.speed
    val status: Int = when (task.state) {
        4 -> {
          1
        }
        1 -> {
          3
        }
        2 -> {
          2
        }
        else -> {
          0
        }
    }
    dict["status"] = status
    channel.invokeMethod("taskDidUpdate", dict)
  }
}