package com.nano.eatwhat

import android.content.Context
import android.util.Log
import java.io.BufferedReader
import java.io.File
import java.io.FileWriter
import java.io.InputStreamReader
import java.io.PrintWriter
import java.text.SimpleDateFormat
import java.util.Date
import java.util.Locale

/**
 * 全面的崩溃处理类
 * 包括Java异常和Native崩溃
 */
class CrashHandler private constructor() : Thread.UncaughtExceptionHandler {
    private val TAG = "CrashHandler"
    private var defaultHandler: Thread.UncaughtExceptionHandler? = null
    private lateinit var context: Context

    companion object {
        @Volatile
        private var instance: CrashHandler? = null

        fun getInstance(): CrashHandler {
            return instance ?: synchronized(this) {
                instance ?: CrashHandler().also { instance = it }
            }
        }
    }

    fun init(context: Context) {
        this.context = context.applicationContext
        // 保存默认的异常处理器
        defaultHandler = Thread.getDefaultUncaughtExceptionHandler()
        // 设置我们的异常处理器
        Thread.setDefaultUncaughtExceptionHandler(this)

        // 启动logcat监控进程来捕获Native崩溃
        startLogcatMonitor()
    }

    /**
     * 启动logcat监控来捕获Native崩溃日志
     * SIGABRT等Native崩溃会被记录在这里
     */
    private fun startLogcatMonitor() {
        Thread {
            try {
                // 获取上次记录的日志位置
                val logFile = File(context.filesDir, "native_crash_monitor.log")
                val process = Runtime.getRuntime().exec("logcat -v threadtime *:E")
                val reader = BufferedReader(InputStreamReader(process.inputStream))
                val writer = FileWriter(logFile, true)
                val pw = PrintWriter(writer)

                val timestamp = SimpleDateFormat("yyyy-MM-dd HH:mm:ss", Locale.getDefault()).format(Date())
                pw.println("\n=== Logcat Monitor Started at $timestamp ===\n")

                var line: String?
                while (true) {
                    line = reader.readLine()
                    if (line == null) break

                    // 只记录包含特定关键词的行
                    if (line.contains("eatwhat") ||
                        line.contains("flutter") ||
                        line.contains("DEBUG") ||
                        line.contains("Signal") ||
                        line.contains("SIGABRT") ||
                        line.contains("libc") ||
                        line.contains("tombstone") ||
                        line.contains("GLThread") ||
                        line.contains("Amap") ||
                        line.contains("amap")) {
                        pw.println(line)
                        pw.flush()
                    }
                }
            } catch (e: Exception) {
                Log.e(TAG, "Logcat monitor error", e)
            }
        }.apply {
            isDaemon = true
            start()
        }
    }

    override fun uncaughtException(thread: Thread, throwable: Throwable) {
        Log.e(TAG, "未捕获的异常在线程: ${thread.name}", throwable)
        logCrash(throwable, thread)

        // 调用默认处理器
        defaultHandler?.uncaughtException(thread, throwable) ?: run {
            android.os.Process.killProcess(android.os.Process.myPid())
            System.exit(10)
        }
    }

    private fun logCrash(throwable: Throwable, thread: Thread) {
        try {
            val timestamp = SimpleDateFormat("yyyy-MM-dd_HH-mm-ss", Locale.getDefault()).format(Date())
            val logFile = File(context.filesDir, "crash_$timestamp.log")

            FileWriter(logFile).use { writer ->
                PrintWriter(writer).use { pw ->
                    pw.println("=== Crash Report ===")
                    pw.println("Time: $timestamp")
                    pw.println("Package: ${context.packageName}")
                    pw.println("Thread: ${thread.name} (id=${thread.id})")
                    pw.println("Exception: ${throwable.javaClass.name}")
                    pw.println("Message: ${throwable.message}")
                    pw.println("StackTrace:")
                    throwable.printStackTrace(pw)

                    // 记录所有线程状态
                    pw.println("\n=== All Threads ===")
                    val threadSet = Thread.getAllStackTraces()
                    for ((t, stack) in threadSet) {
                        pw.println("\nThread: ${t.name} (id=${t.id}, state=${t.state})")
                        for (element in stack) {
                            pw.println("\tat $element")
                        }
                    }

                    pw.println("\n=== End of Report ===")
                }
            }

            Log.i(TAG, "崩溃日志已写入: ${logFile.absolutePath}")
        } catch (e: Exception) {
            Log.e(TAG, "写入崩溃日志失败", e)
        }
    }

    /**
     * 获取所有崩溃日志文件
     */
    fun getAllCrashLogs(): List<File> {
        return context.filesDir.listFiles { _, name ->
            name.startsWith("crash_") && name.endsWith(".log")
        }?.sortedByDescending { it.lastModified() } ?: emptyList()
    }

    /**
     * 获取最近的Native崩溃日志
     */
    fun getNativeCrashLog(): String {
        val logFile = File(context.filesDir, "native_crash_monitor.log")
        return if (logFile.exists()) {
            logFile.readText()
        } else {
            "暂无Native崩溃日志"
        }
    }
}
