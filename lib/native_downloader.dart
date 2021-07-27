import 'dart:async';
import 'dart:convert';

import 'package:flutter/services.dart';

class DownloadTask {
  DownloadTask({
    required this.url,
    required this.totalBytes,
    required this.completedBytes,
    required this.speed,
    required this.status,
  });

  final String url;
  final int totalBytes;
  final int completedBytes;
  final int speed;

  /// 0 = 等待下载，1 = 下载中，2 = 暂停下载，3 = 已下载
  final int status;

  Map<String, dynamic> toMap() {
    return {
      'url': url,
      'totalBytes': totalBytes,
      'completedBytes': completedBytes,
      'speed': speed,
      'status': status,
    };
  }

  factory DownloadTask.fromMap(Map<String, dynamic> map) {
    return DownloadTask(
      url: map['url'],
      totalBytes: map['totalBytes'],
      completedBytes: map['completedBytes'],
      speed: map['speed'],
      status: map['status'],
    );
  }

  String toJson() => json.encode(toMap());

  factory DownloadTask.fromJson(String source) =>
      DownloadTask.fromMap(json.decode(source));
}

class NativeDownloader {
  static const MethodChannel _channel =
      MethodChannel('com.haijunwei.native_downloader');

  static final StreamController<DownloadTask> _streamController =
      StreamController.broadcast();

  static Stream<DownloadTask> get taskStream {
    _channel.setMethodCallHandler(_methodCallHandler);
    return _streamController.stream;
  }

  static Future<dynamic> _methodCallHandler(MethodCall call) async {
    if (call.method == 'taskDidUpdate') {
      final task =
          DownloadTask.fromMap(Map<String, dynamic>.from(call.arguments));
      _streamController.add(task);
    }
  }

  /// 添加单个任务到下载队列
  static Future<bool> download(
    String url, {
    String? fileName,
  }) async {
    final bool? result = await _channel.invokeMethod('download', {
      'url': url,
      'fileName': fileName,
    });
    return result ?? false;
  }

  /// 添加多个任务到下载队列
  static Future<bool> multiDownload(
    List<String> urls, {
    List<String>? fileNames,
  }) async {
    final bool? result = await _channel.invokeMethod('multiDownload', {
      'urls': urls,
      'fileNames': fileNames,
    });
    return result ?? false;
  }

  /// 开始下载任务，如果未在下载队列，则无任何效果
  static Future start(String url) async {
    await _channel.invokeMethod('start', {
      'url': url,
    });
  }

  /// 暂停下载任务
  static Future suspend(String url) async {
    await _channel.invokeMethod('suspend', {
      'url': url,
    });
  }

  /// 取消下载任务
  static Future cancel(
    String url,
  ) async {
    await _channel.invokeMethod('cancel', {
      'url': url,
    });
  }

  /// 移除下载任务，`completely` 为 true表示删除已下载的文件
  static Future remove(
    String url, {
    bool completely = true,
  }) async {
    await _channel.invokeMethod('remove', {
      'url': url,
      'completely': completely,
    });
  }

  /// 检查下载队列是否存在指定下载任务
  static Future<bool> exists(String url) async {
    final bool? result = await _channel.invokeMethod('exists', {
      'url': url,
    });
    return result ?? false;
  }

  static Future removeAll({
    bool completely = true,
  }) async {
    await _channel.invokeMethod('removeAll', {
      'completely': completely,
    });
  }

  static Future<String?> getTaskFilePath(String url) async {
    final String? result = await _channel.invokeMethod('getTaskFilePath', {
      'url': url,
    });
    return result;
  }

  static Future syncStatus() async {
    await _channel.invokeMethod('syncStatus');
  }
}
