import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:window_manager/window_manager.dart';
import 'app/app_providers.dart';
import 'core/state/global_app_state.dart';
import 'core/theme/app_theme.dart';
import 'features/auth/view/login_page.dart';
import 'main_home_page.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await windowManager.ensureInitialized();
  await windowManager.setPreventClose(true);

  runApp(
    MultiProvider(
      providers: buildAppProviders(),
      child: const MyApp(),
    ),
  );
}

class MyApp extends StatefulWidget {
  const MyApp({super.key});

  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> with WindowListener {
  bool _isClosing = false;

  @override
  void initState() {
    super.initState();
    windowManager.addListener(this);
  }

  @override
  void dispose() {
    windowManager.removeListener(this);
    super.dispose();
  }

  @override
  Future<void> onWindowClose() async {
    if (_isClosing) return;
    _isClosing = true;

    try {
      final state = context.read<GlobalAppState>();
      await state.shutdownForAppClose();
    } finally {
      await windowManager.setPreventClose(false);
      await windowManager.close();
    }
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: '脑心愈郁',
      theme: AppTheme.lightTheme,
      home: const AuthGate(),
      debugShowCheckedModeBanner: false,
    );
  }
}

class AuthGate extends StatelessWidget {
  const AuthGate({super.key});

  @override
  Widget build(BuildContext context) {
    return Consumer<GlobalAppState>(
      builder: (context, state, child) {
        if (state.isAuthLoading) {
          return const SplashPage();
        }
        if (!state.isLoggedIn) {
          return const LoginPage();
        }
        return const MainHomePage();
      },
    );
  }
}

class SplashPage extends StatefulWidget {
  const SplashPage({super.key});

  @override
  State<SplashPage> createState() => _SplashPageState();
}

class _SplashPageState extends State<SplashPage> {
  @override
  void initState() {
    super.initState();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              AppTheme.primaryMain, // 应用主题蓝色
              AppTheme.primaryDark, // 深蓝色
            ],
          ),
        ),
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              // Logo：大脑轮廓融合心跳波形
              Stack(
                alignment: Alignment.center,
                children: [
                  // 大脑轮廓图标
                  Container(
                    width: 140,
                    height: 140, // Square container for logo
                    decoration: BoxDecoration(
                      color: Colors.white.withAlpha(
                        (0.1 * 255).toInt(),
                      ), // Light background to see rounded corners
                      boxShadow: [
                        // Primary white shadow (reduced opacity for better blending)
                        BoxShadow(
                          color: Colors.white.withAlpha((0.15 * 255).toInt()),
                          blurRadius: 12,
                          spreadRadius: 1,
                          offset: Offset(0, 3),
                        ),
                        // Subtle blue shadow for depth and gradient integration
                        BoxShadow(
                          color: AppTheme.primaryDark.withAlpha(
                            (0.2 * 255).toInt(),
                          ),
                          blurRadius: 8,
                          spreadRadius: 0,
                          offset: Offset(0, 2),
                        ),
                      ],
                      borderRadius: BorderRadius.circular(
                        20,
                      ), // Rounded corners for modern look
                    ),
                    child: _buildAdaptiveLogo(),
                  ),
                  // 心跳波形效果（使用多个小圆点模拟波形）
                  Positioned(
                    top: 20, // Position above logo
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        _buildWaveDot(0),
                        _buildWaveDot(1),
                        _buildWaveDot(2),
                        _buildWaveDot(3),
                        _buildWaveDot(4),
                        _buildWaveDot(5),
                        _buildWaveDot(6),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 32),
              // 主标题
              Text(
                '脑心愈郁',
                style: Theme.of(context).textTheme.headlineLarge?.copyWith(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                  fontSize: 40,
                ),
              ),
              const SizedBox(height: 8),
              // 副标题
              Text(
                '闭环神经调控康复系统',
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  color: Colors.white.withAlpha((0.8 * 255).toInt()),
                  fontWeight: FontWeight.w500,
                ),
              ),
              const SizedBox(height: 60),
              // 加载指示器（简洁版）
              const CircularProgressIndicator(
                color: Colors.white,
                strokeWidth: 2,
              ),
              const SizedBox(height: 16),
              Text(
                '正在启动...',
                style: Theme.of(context).textTheme.labelSmall?.copyWith(
                  color: Colors.white.withAlpha((0.7 * 255).toInt()),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildWaveDot(int index) {
    final heights = [8.0, 12.0, 16.0, 20.0, 16.0, 12.0, 8.0];
    return Container(
      width: 4,
      height: heights[index],
      margin: const EdgeInsets.symmetric(horizontal: 2),
      decoration: BoxDecoration(
        color: Colors.white.withAlpha((0.7 * 255).toInt()),
        borderRadius: BorderRadius.circular(2),
      ),
    );
  }

  Widget _buildAdaptiveLogo() {
    return ClipRRect(
      borderRadius: BorderRadius.circular(20),
      child: Image.asset(
        'assets/images/logo.png',
        width: 140,
        height: 140,
        fit: BoxFit
            .cover, // Changed to cover to ensure image fills the rounded corners
        errorBuilder: (context, error, stackTrace) {
          // Fallback to placeholder if image doesn't exist
          return Container(
            width: 140,
            height: 140,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(20),
              color: Colors.white.withAlpha((0.1 * 255).toInt()),
              border: Border.all(
                color: Colors.white.withAlpha((0.3 * 255).toInt()),
                width: 2,
              ),
            ),
            child: Icon(
              Icons.psychology,
              size: 80,
              color: Colors.white.withAlpha((0.8 * 255).toInt()),
            ),
          );
        },
      ),
    );
  }
}
