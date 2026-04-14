import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:provider/provider.dart';
import 'services/code_manager.dart';
import 'screens/home_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  // 初始化取件码管理器（带超时保护，防止卡启动页）
  final codeManager = CodeManager();
  try {
    // 设置 5 秒超时，避免初始化卡住
    await codeManager.init().timeout(
      const Duration(seconds: 5),
      onTimeout: () {
        print('CodeManager init timeout, continuing anyway...');
      },
    );
  } catch (e) {
    print('CodeManager init failed: $e');
    // 即使初始化失败，也继续运行 App
  }
  
  runApp(MyApp(codeManager: codeManager));
}

class MyApp extends StatelessWidget {
  final CodeManager codeManager;

  const MyApp({super.key, required this.codeManager});

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider<CodeManager>.value(
      value: codeManager,
      child: MaterialApp(
        title: '记忆岛',
        debugShowCheckedModeBanner: false,
        // 中文本地化配置
        localizationsDelegates: const [
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
        ],
        supportedLocales: const [
          Locale('zh', 'CN'), // 中文
          Locale('en', 'US'), // 英文
        ],
        locale: const Locale('zh', 'CN'), // 默认中文
        theme: ThemeData(
          colorScheme: ColorScheme.fromSeed(
            seedColor: Colors.blue,
            brightness: Brightness.light,
          ),
          useMaterial3: true,
          appBarTheme: const AppBarTheme(
            centerTitle: true,
            elevation: 0,
          ),
          cardTheme: CardTheme(
            elevation: 2,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
          ),
          floatingActionButtonTheme: const FloatingActionButtonThemeData(
            elevation: 4,
          ),
        ),
        darkTheme: ThemeData(
          colorScheme: ColorScheme.fromSeed(
            seedColor: Colors.blue,
            brightness: Brightness.dark,
          ),
          useMaterial3: true,
          appBarTheme: const AppBarTheme(
            centerTitle: true,
            elevation: 0,
          ),
          cardTheme: CardTheme(
            elevation: 2,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
          ),
        ),
        themeMode: ThemeMode.system,
        home: const HomeScreen(),
      ),
    );
  }
}
