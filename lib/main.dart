import 'dart:io';
import 'dart:isolate';
import 'package:flutter/material.dart';
import 'map_page.dart';
import 'services/logger_service.dart';

void main() {
  // 捕获 Flutter 框架错误
  FlutterError.onError = (FlutterErrorDetails details) {
    final logger = Logger();
    logger.error('FlutterError', '捕获到Flutter错误: ${details.exception}', details.stack);
    // 同时输出到控制台
    FlutterError.dumpErrorToConsole(details);
  };

  // 捕获 isolate 中的错误
  Isolate.current.addErrorListener(RawReceivePort((pair) {
    final List<dynamic> errorAndStacktrace = pair;
    final logger = Logger();
    logger.error('Isolate', 'Isolate错误: ${errorAndStacktrace.first}', errorAndStacktrace.first, errorAndStacktrace.last);
  }).sendPort);

  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'EatWhat - 今天吃什么',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.blue),
        useMaterial3: true,
      ),
      home: const HomePage(),
    );
  }
}

class HomePage extends StatelessWidget {
  const HomePage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('EatWhat - 今天吃什么'),
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
      ),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            ElevatedButton(
              onPressed: () {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Hello World'),
                    duration: Duration(seconds: 2),
                  ),
                );
              },
              child: const Text('点击我'),
            ),
            const SizedBox(height: 20),
            ElevatedButton(
              onPressed: () {
                Navigator.push(
                  context,
                  PageRouteBuilder(
                    pageBuilder: (context, animation, secondaryAnimation) => const MapPage(),
                    transitionsBuilder: (context, animation, secondaryAnimation, child) {
                      // 无动画过渡
                      return child;
                    },
                    transitionDuration: Duration.zero,
                    reverseTransitionDuration: Duration.zero,
                  ),
                );
              },
              child: const Text('进入地图'),
            ),
          ],
        ),
      ),
    );
  }
}
