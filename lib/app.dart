import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'core/router/app_router.dart';
import 'core/theme/app_theme.dart';

class CafeDeskApp extends StatelessWidget {
  const CafeDeskApp({super.key});

  @override
  Widget build(BuildContext context) {
    return ScreenUtilInit(
      // Design frame — use a standard phone reference
      designSize: const Size(390, 844),
      minTextAdapt: true,
      splitScreenMode: true,
      builder: (context, child) => MaterialApp.router(
        title: 'CafeDesk',
        debugShowCheckedModeBanner: false,
        theme: AppTheme.light,
        routerConfig: appRouter,
      ),
    );
  }
}
