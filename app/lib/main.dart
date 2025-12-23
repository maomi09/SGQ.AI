import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'providers/auth_provider.dart';
import 'providers/grammar_topic_provider.dart';
import 'providers/question_provider.dart';
import 'providers/badge_provider.dart';
import 'providers/chat_provider.dart';
import 'screens/auth/login_screen.dart';
import 'screens/auth/forgot_password_screen.dart';
import 'screens/auth/reset_password_screen.dart';
import 'screens/student/student_main_screen.dart';
import 'screens/teacher/teacher_main_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await Supabase.initialize(
    url: 'https://iqmhqdkpultzyzurolwv.supabase.co', // 請在 config/app_config.dart 中設定
    anonKey: 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6ImlxbWhxZGtwdWx0enl6dXJvbHd2Iiwicm9sZSI6ImFub24iLCJpYXQiOjE3NjU4MDc1NzMsImV4cCI6MjA4MTM4MzU3M30.OfBqLiwFQLjyuJwkgU1Vu1eedjrzkeVsSznQAnR9B9Q', // 請在 config/app_config.dart 中設定
    authOptions: const FlutterAuthClientOptions(
      authFlowType: AuthFlowType.pkce,
    ),
  );

  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => AuthProvider()),
        ChangeNotifierProvider(create: (_) => GrammarTopicProvider()),
        ChangeNotifierProvider(create: (_) => QuestionProvider()),
        ChangeNotifierProvider(create: (_) => BadgeProvider()),
        ChangeNotifierProvider(create: (_) => ChatProvider()),
      ],
      child: MaterialApp(
        title: 'SGQ 學習系統',
        theme: ThemeData(
          colorScheme: ColorScheme.fromSeed(seedColor: Colors.blue),
          useMaterial3: true,
        ),
        home: const AuthWrapper(),
        routes: {
          '/login': (context) => const LoginScreen(),
          '/forgot-password': (context) => const ForgotPasswordScreen(),
          '/reset-password': (context) => const ResetPasswordScreen(),
        },
      ),
    );
  }
}

class AuthWrapper extends StatefulWidget {
  const AuthWrapper({super.key});

  @override
  State<AuthWrapper> createState() => _AuthWrapperState();
}

class _AuthWrapperState extends State<AuthWrapper> {
  late StreamSubscription<AuthState> _authStateSubscription;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      Provider.of<AuthProvider>(context, listen: false).checkAuth();
    });
    
    // 監聽 Supabase 認證狀態變化（用於 Google 登入回調和重設密碼）
    _authStateSubscription = Supabase.instance.client.auth.onAuthStateChange.listen((data) {
      final event = data.event;
      final session = data.session;
      print('Auth state changed: $event, has session: ${session != null}');
      
      // 檢查是否在登入頁面（避免在註冊流程中觸發跳轉）
      final currentRoute = ModalRoute.of(context);
      final isOnLoginScreen = currentRoute?.settings.name == '/login' || 
                              currentRoute?.settings.name == null;
      
      if (event == AuthChangeEvent.signedIn) {
        print('User signed in, checking auth...');
        // 如果有有效的 session，應該更新認證狀態（無論在哪個頁面）
        if (session != null) {
          print('Valid session found, updating auth state...');
          // 延遲檢查，給深度連結處理時間完成
          Future.delayed(const Duration(milliseconds: 300), () {
            if (!mounted) return;
            
            final authProvider = Provider.of<AuthProvider>(context, listen: false);
            // 檢查是否在註冊流程中（通過檢查是否正在載入）
            if (!authProvider.isLoading) {
              print('Checking auth after sign in...');
              authProvider.checkAuth();
            } else {
              // 如果正在載入，稍後再檢查（可能是註冊流程）
              Future.delayed(const Duration(milliseconds: 1000), () {
                if (mounted && !authProvider.isLoading) {
                  print('Delayed auth check after sign in...');
                  authProvider.checkAuth();
                }
              });
            }
          });
        } else {
          print('No session found in signedIn event, skipping auth check');
        }
      } else if (event == AuthChangeEvent.tokenRefreshed) {
        print('Token refreshed, checking auth...');
        if (isOnLoginScreen) {
          Provider.of<AuthProvider>(context, listen: false).checkAuth();
        }
      } else if (event == AuthChangeEvent.passwordRecovery) {
        print('Password recovery detected, navigating to reset password screen...');
        // 當檢測到密碼重設事件時，導航到重設密碼頁面
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) {
            Navigator.of(context).pushNamed('/reset-password');
          }
        });
      } else if (event == AuthChangeEvent.signedOut) {
        print('User signed out');
        // 清除認證狀態
        Provider.of<AuthProvider>(context, listen: false).checkAuth();
      }
    });
    
    // 處理應用程式啟動時的深度連結
    _handleInitialLink();
  }

  Future<void> _handleInitialLink() async {
    // 等待一下讓深度連結處理完成
    await Future.delayed(const Duration(milliseconds: 500));
    
    // 檢查是否有待處理的認證會話
    final session = Supabase.instance.client.auth.currentSession;
    if (session != null) {
      print('Found existing session in initial link handler, checking auth...');
      await Provider.of<AuthProvider>(context, listen: false).checkAuth();
    } else {
      print('No session found in initial link handler');
    }
  }

  @override
  void dispose() {
    _authStateSubscription.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<AuthProvider>(
      builder: (context, authProvider, child) {
        // 檢查認證狀態
        // 注意：不要在發送驗證碼時顯示載入畫面，避免跳轉
        
        // 如果有有效的 Supabase session 但 AuthProvider 還沒有用戶資料，先檢查認證
        final supabaseSession = Supabase.instance.client.auth.currentSession;
        if (supabaseSession != null && 
            (!authProvider.isAuthenticated || authProvider.currentUser == null) &&
            !authProvider.isLoading) {
          // 在下一幀檢查認證，避免在 build 期間觸發異步操作
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (mounted) {
              print('Supabase session exists but AuthProvider has no user, checking auth...');
              authProvider.checkAuth();
            }
          });
        }
        
        if (!authProvider.isAuthenticated || authProvider.currentUser == null) {
          // 只有在非載入狀態或載入完成後才顯示登入頁面
          // 這可以避免在發送驗證碼時觸發跳轉
          return const LoginScreen();
        }

        final user = authProvider.currentUser!;
        
        // 根據用戶角色導航
        if (user.role == 'teacher') {
          return const TeacherMainScreen();
        } else {
          return const StudentMainScreen();
        }
      },
    );
  }
}
