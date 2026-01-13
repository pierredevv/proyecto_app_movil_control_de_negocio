import 'dart:io';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'theme/app_theme.dart';
import 'screens/main_screen.dart';
import 'providers/inventory_provider.dart';
import 'providers/customer_provider.dart';
import 'providers/navigation_provider.dart';
import 'providers/cart_provider.dart';
import 'providers/dashboard_provider.dart';
import 'providers/supplier_provider.dart';
import 'providers/notification_provider.dart';

import 'services/backup_service.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  if (Platform.isWindows || Platform.isLinux) {
    // Initialize FFI
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  }

  runApp(const MyApp());
}

class MyApp extends StatefulWidget {
  const MyApp({super.key});

  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  @override
  void initState() {
    super.initState();
    // Auto-Run Backup after first frame
    WidgetsBinding.instance.addPostFrameCallback((_) {
      BackupService.autoBackupIfNeeded();
    });
  }

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(
            create: (_) => InventoryProvider()..loadProducts()),
        ChangeNotifierProvider(
            create: (_) => CustomerProvider()..loadCustomers()),
        ChangeNotifierProvider(create: (_) => NavigationProvider()),
        ChangeNotifierProvider(create: (_) => CartProvider()),
        ChangeNotifierProvider(create: (_) => DashboardProvider()),
        ChangeNotifierProvider(
            create: (_) => SupplierProvider()..loadSuppliers()),
        ChangeNotifierProvider(create: (_) => NotificationProvider()),
      ],
      child: MaterialApp(
        title: 'Gestion de Negocio App',
        debugShowCheckedModeBanner: false,
        theme: AppTheme.lightTheme,
        darkTheme: AppTheme.darkTheme,
        themeMode: ThemeMode.system,
        home: const MainScreen(),
      ),
    );
  }
}
