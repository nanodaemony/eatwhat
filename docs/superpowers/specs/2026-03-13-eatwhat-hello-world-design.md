# EatWhat - Hello World 原型设计文档

## 项目概述

**项目名称**: eatwhat（今天吃什么）
**当前阶段**: 可行性验证原型
**目标**: 搭建最基础的 Flutter 跨平台应用，验证技术可行性

## 核心需求

1. 创建一个跨平台 Flutter 应用（支持 Android、iOS、Web）
2. 单页面应用，展示基础 UI 能力
3. 页面中央放置一个按钮
4. 点击按钮后弹出 "Hello World" 提示（使用 SnackBar）
5. 能够编译运行，验证 Flutter 开发可行性

## 技术选型

- **UI 框架**: Material Design（Flutter 默认）
- **提示组件**: SnackBar（底部轻量提示）
- **Flutter 版本**: 3.x（默认支持空安全）

## 项目结构

```
eatwhat/
├── lib/
│   └── main.dart          # 主入口，包含 MaterialApp 和首页
├── pubspec.yaml           # 依赖配置
├── android/               # Android 平台配置（模板）
├── ios/                   # iOS 平台配置（模板）
├── web/                   # Web 平台配置（模板）
└── test/                  # 测试目录（模板）
```

## 页面设计

### 首页布局
- **AppBar**: 顶部标题栏，显示 "EatWhat - 今天吃什么"
- **Body**: 使用 Center 居中布局
- **按钮**: ElevatedButton（Material 填充按钮）
  - 文字: "点击我"
  - 样式: 默认主题色（蓝色）
- **交互**: 点击按钮显示 SnackBar
  - 内容: "Hello World"
  - 持续时间: 2 秒后自动消失

## 后续规划（非本阶段实现）

- 美食推荐算法
- 地理位置服务
- 用户偏好设置
- 餐厅数据集成
- 分享功能

## 成功标准

- [x] `flutter create` 成功创建项目
- [x] `flutter run` 能在 Chrome 浏览器中运行
- [x] 页面显示居中的按钮
- [x] 点击按钮弹出 SnackBar 显示 "Hello World"
- [x] 代码结构清晰，为后续开发预留扩展空间
