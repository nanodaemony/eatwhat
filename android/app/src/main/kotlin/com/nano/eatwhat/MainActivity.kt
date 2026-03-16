package com.nano.eatwhat

import android.os.Bundle
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
    private val CHANNEL = "com.nano.eatwhat/crash"

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)

        // 初始化崩溃处理器
        CrashHandler.getInstance().init(this)
    }

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        // 设置MethodChannel来让Flutter读取崩溃日志
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL).setMethodCallHandler { call, result ->
            when (call.method) {
                "getCrashLogs" -> {
                    val logs = CrashHandler.getInstance().getNativeCrashLog()
                    result.success(logs)
                }
                "getAllCrashLogFiles" -> {
                    val files = CrashHandler.getInstance().getAllCrashLogs()
                    val fileNames = files.map { it.name }
                    result.success(fileNames)
                }
                "getCrashLogContent" -> {
                    val fileName = call.argument<String>("fileName")
                    if (fileName != null) {
                        val file = java.io.File(filesDir, fileName)
                        if (file.exists()) {
                            result.success(file.readText())
                        } else {
                            result.error("FILE_NOT_FOUND", "文件不存在", null)
                        }
                    } else {
                        result.error("INVALID_ARGUMENT", "文件名不能为空", null)
                    }
                }
                else -> result.notImplemented()
            }
        }
    }
}
