import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:provider/provider.dart';
import 'services/code_manager.dart';
import 'services/notification_service.dart';
import 'services/reminder_service.dart';
import 'services/sms_listener_service.dart';
import 'screens/home_screen.dart';
import 'theme/app_theme.dart';
import 'theme/theme_manager.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  // 初始化主题管理器
  final themeManager = ThemeManager();
  await themeManager.init();
  
  // 初始化通知服务
  final notificationService = NotificationService();
  await notificationService.init();
  
  // 初始化定时提醒服务
  final reminderService = ReminderService(notificationService: notificationService);
  await reminderService.init();
  
  // 初始化取件码管理器（带超时保护，防止卡启动页）
  final codeManager = CodeManager(notificationService: notificationService);
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
  
  // 初始化短信监听服务
  final smsListener = SmsListenerService();
  await smsListener.init(codeManager);
  
  runApp(MyApp(
    codeManager: codeManager,
    themeManager: themeManager,
    smsListener: smsListener,
    notificationService: notificationService,
    reminderService: reminderService,
  ));
}

class MyApp extends StatelessWidget {
  final CodeManager codeManager;
  final ThemeManager themeManager;
  final SmsListenerService smsListener;
  final NotificationService notificationService;
  final ReminderService reminderService;

  const MyApp({
    super.key,
    required this.codeManager,
    required this.themeManager,
    required this.smsListener,
    required this.notificationService,
    required this.reminderService,
  });

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider<CodeManager>.value(value: codeManager),
        ChangeNotifierProvider<ThemeManager>.value(value: themeManager),
        Provider<SmsListenerService>.value(value: smsListener),
        Provider<NotificationService>.value(value: notificationService),
        ChangeNotifierProvider<ReminderService>.value(value: reminderService),
      ],
      child: Consumer<ThemeManager>(
        builder: (context, themeManager, child) {
          return MaterialApp(
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
            theme: AppTheme.lightTheme,
            darkTheme: AppTheme.darkTheme,
            themeMode: themeManager.themeMode,
            home: const HomeScreen(),
          );
        },
      ),
    );
  }
}
