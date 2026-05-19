# 脑心愈郁 - 闭环神经调控康复系统

基于 Flutter 开发的脑心健康监测与调控应用，提供完整的神经康复解决方案。

## ✨ 功能特性

- 🧠 **脑心健康监测**：实时监测脑电与心电信号
- 📊 **数据可视化**：专业的数据分析与趋势图表
- 🎮 **交互调控**：闭环神经反馈训练系统
- 📱 **多平台支持**：Web、移动端、桌面端全覆盖
- 🔄 **实时同步**：云端数据同步与备份

## 🚀 快速预览

### 📱 部署状态说明
项目已成功部署到 Vercel，但由于项目在受保护的组织中，**需要先登录 Vercel 账户才能访问**。

### 🔗 最新部署链接
- **主域名**: [https://flutterapplication1-phi.vercel.app](https://flutterapplication1-phi.vercel.app)
- **最新部署**: [https://flutterapplication1-6ny5tzwnf-xc93704-2263s-projects.vercel.app](https://flutterapplication1-6ny5tzwnf-xc93704-2263s-projects.vercel.app)

### 🔓 访问解决方案
**方案1：在已登录 Vercel 的浏览器中访问**
1. 确保已在浏览器中登录 Vercel (https://vercel.com)
2. 直接点击上方链接访问

**方案2：将项目设置为公开（推荐）**
1. 访问 [Vercel 项目面板](https://vercel.com/xc93704-2263s-projects/flutter_application_1)
2. 在 Settings → General → Visibility 中设置为 "Public"
3. 保存后即可公开访问

**方案3：本地运行预览**
```bash
# 本地运行 Web 服务器
flutter run -d web-server --web-port 8080

# 在手机浏览器中访问
# http://[你的电脑IP]:8080
# 确保手机和电脑在同一网络
```

### ✅ 已修复的功能
- **治疗模式选择滚动修复** - 手机端可正常滚动查看全部四个模式
- **情绪晴雨表** - 实时情绪状态显示和建议
- **设备连接状态** - DBS设备和HRV手环状态监控

### 本地运行
```bash
# 克隆项目
git clone https://github.com/xxxxdxc/flutter-Naoxinyuyu-app.git
cd flutter-Naoxinyuyu-app

# 安装依赖
flutter pub get

# 运行 Web 版本
flutter run -d web-server

# 或构建发布版本
flutter build web --release
```

## 🛠 技术栈

- **框架**: Flutter 3.41.5
- **语言**: Dart 3.11.3
- **状态管理**: Provider
- **构建工具**: Flutter CLI
- **部署平台**: Vercel

## 📁 项目结构

```
lib/
├── main.dart              # 应用入口
├── main_home_page.dart    # 主页面
├── core/                  # 核心模块
│   ├── state/             # 状态管理
│   └── theme/             # 主题配置
├── features/              # 功能模块
│   ├── dashboard/         # 仪表盘
│   ├── visualizer/        # 数据可视化
│   └── controller/        # 控制器
web/                       # Web 配置
build/web/                 # Web 构建输出
```

## 🌐 部署指南

### 1. Vercel 部署 (推荐，已成功部署)
本项目已通过 Vercel 部署，提供稳定的在线预览服务。

**已部署链接：**
- **主域名**: https://flutterapplication1-phi.vercel.app
- **部署详情**: https://vercel.com/xc93704-2263s-projects/flutter_application_1

**部署命令：**
```bash
# 安装 Vercel CLI
npm install -g vercel

# 登录 Vercel
vercel login

# 部署到生产环境
vercel --prod

# 查看部署状态
vercel list

# 查看部署日志
vercel logs flutterapplication1-phi.vercel.app
```

**自动部署配置：**
1. 在 Vercel 面板中连接 GitHub 仓库
2. 配置构建命令: `flutter build web --release`
3. 输出目录: `build/web`
4. 环境变量: 无需特殊配置

### 2. Netlify 部署
1. 访问 [Netlify](https://netlify.com)
2. 拖拽 `build/web` 文件夹上传
3. 自动生成 HTTPS 链接

### 3. GitHub Pages 部署
```bash
# 构建 Web 版本
flutter build web --release --base-href "/flutter-Naoxinyuyu-app/"

# 推送到 gh-pages 分支
git subtree push --prefix build/web origin gh-pages
```

## 🔧 开发指南

### 环境要求
- Flutter SDK >= 3.10.0
- Dart SDK >= 3.0.0
- Node.js (用于部署)

### 常见命令
```bash
# 运行应用
flutter run

# 构建 Web 版本
flutter build web --release

# 代码分析
flutter analyze

# 格式化代码
dart format .

# 运行测试
flutter test
```

## 📱 支持的平台

- **Web**: Chrome, Firefox, Safari, Edge
- **Android**: API 21+
- **iOS**: 11.0+
- **Windows**: 10+
- **macOS**: 10.14+
- **Linux**: Ubuntu 18.04+

## 🤝 贡献指南

1. Fork 本项目
2. 创建功能分支 (`git checkout -b feature/AmazingFeature`)
3. 提交更改 (`git commit -m 'Add some AmazingFeature'`)
4. 推送到分支 (`git push origin feature/AmazingFeature`)
5. 开启 Pull Request

## 📄 许可证

本项目采用 MIT 许可证 - 查看 [LICENSE](LICENSE) 文件了解详情

## 📞 联系方式

如有问题或建议，请通过以下方式联系：
- **GitHub Issues**: [项目 Issues](https://github.com/xxxxdxc/flutter-Naoxinyuyu-app/issues)
- **邮箱**: @3093600673@qq.com

## 🙏 致谢

感谢以下开源项目的支持：
- [Flutter](https://flutter.dev) - Google 的 UI 工具包
- [Provider](https://pub.dev/packages/provider) - Flutter 状态管理
- [Vercel](https://vercel.com) - 云部署平台
