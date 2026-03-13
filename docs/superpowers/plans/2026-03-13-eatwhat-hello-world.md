# EatWhat Hello World 原型实现计划

> **For agentic workers:** REQUIRED: Use superpowers:subagent-driven-development (if subagents available) or superpowers:executing-plans to implement this plan. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** 创建最基础的 Flutter Hello World 原型，验证跨平台开发可行性

**Architecture:** 使用 Flutter 默认的 Material Design 组件，单页面应用，通过 Scaffold + SnackBar 实现交互反馈

**Tech Stack:** Flutter 3.x, Dart, Material Design

**参考设计文档:** `docs/superpowers/specs/2026-03-13-eatwhat-hello-world-design.md`

---

## Chunk 1: 项目初始化

### Task 1: 创建 Flutter 项目

**Files:**
- Create: 整个项目目录结构

- [ ] **Step 1: 执行 flutter create 命令**

Run:
```bash
flutter create eatwhat --project-name eatwhat
```

Expected: 成功创建项目，输出 "All done!" 并提示可用命令

- [ ] **Step 2: 进入项目目录并查看结构**

Run:
```bash
cd eatwhat && ls -la
```

Expected: 看到 lib/, android/, ios/, web/, pubspec.yaml 等目录和文件

- [ ] **Step 3: 验证 Flutter 环境**

Run:
```bash
flutter doctor
```

Expected: 显示 Flutter 版本信息，可能提示 Android/iOS 工具未安装（可忽略，使用 Web 验证）

---

## Chunk 2: 实现 Hello World 页面

### Task 2: 修改 main.dart 实现基础页面

**Files:**
- Modify: `lib/main.dart`

- [ ] **Step 1: 备份原始文件**

Run:
```bash
cp lib/main.dart lib/main.dart.bak
```

- [ ] **Step 2: 编写新的 main.dart**

Write to `lib/main.dart`:

```dart
import 'package:flutter/material.dart';

void main() {
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
        child: ElevatedButton(
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
      ),
    );
  }
}
```

- [ ] **Step 3: 验证代码语法**

Run:
```bash
flutter analyze
```

Expected: 显示 "No issues found!"

---

## Chunk 3: 运行验证

### Task 3: 在 Chrome 浏览器中运行

**Files:**
- 无需修改文件，仅验证运行

- [ ] **Step 1: 检查 Chrome 是否可用**

Run:
```bash
flutter devices
```

Expected: 列表中包含 Chrome (web-javascript)

- [ ] **Step 2: 启动 Web 应用**

Run:
```bash
flutter run -d chrome
```

Expected: Chrome 浏览器自动打开，显示应用页面，包含：
- 顶部 AppBar 显示 "EatWhat - 今天吃什么"
- 页面中央有一个蓝色按钮 "点击我"
- 点击按钮后底部弹出黑色 SnackBar，显示 "Hello World"
- SnackBar 2 秒后自动消失

- [ ] **Step 3: 停止应用**

在运行 flutter run 的终端中按 `q` 键停止

Expected: 应用停止，终端返回命令提示符

---

## Chunk 4: 代码提交

### Task 4: 提交初始代码

**Files:**
- All modified files

- [ ] **Step 1: 初始化 git 仓库（如需要）**

Run:
```bash
git init
git add .
git commit -m "feat: 初始化 EatWhat Flutter 项目，实现 Hello World 原型"
```

Expected: 成功提交，显示文件数和提交信息

---

## 验证清单

- [ ] `flutter create` 成功执行
- [ ] `lib/main.dart` 包含 MaterialApp、Scaffold、ElevatedButton、SnackBar
- [ ] `flutter analyze` 无错误
- [ ] Chrome 中页面正常显示
- [ ] 点击按钮弹出 "Hello World" SnackBar
- [ ] 代码已提交到 git

## 后续开发方向（非本计划范围）

1. 添加美食推荐列表页面
2. 集成随机选择算法
3. 添加用户偏好设置
4. 集成地图/位置服务
5. 添加分享功能
