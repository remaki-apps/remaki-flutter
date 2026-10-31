import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

enum Environment { prod, qa }

class EnvConfig {
  static Environment _environment = Environment.prod;
  static bool _manuallyConfigured = false;

  static const String prodApiUrl = 'https://remaki-backend.onrender.com/graphql';
  static const String qaApiUrl = 'https://remaki-backend-qa.onrender.com/graphql';

  /// Call in main.dart or main_qa.dart to initialize environment
  static void initialize(Environment env) {
    _environment = env;
    _manuallyConfigured = true;
  }

  static Environment get environment {
    // 1. Web URL runtime inspection takes highest priority when running in a browser.
    // This ensures production domains (remaki.in, remaki.vercel.app) ALWAYS connect to prod
    // and never show the QA badge, while QA domains (remaki-qa.vercel.app, qa.remaki.in) connect to QA.
    if (kIsWeb) {
      final host = Uri.base.host.toLowerCase();
      final href = Uri.base.toString().toLowerCase();

      // Explicit URL query param overrides (useful for testing or debugging)
      if (href.contains('env=prod')) return Environment.prod;
      if (href.contains('env=qa')) return Environment.qa;

      // Explicit QA domain patterns
      if (host == 'remaki-qa.vercel.app' ||
          host == 'qa.remaki.in' ||
          host.startsWith('qa.') ||
          host.contains('remaki-qa') ||
          host.contains('-qa.') ||
          host.contains('-qa-')) {
        return Environment.qa;
      }

      // Explicit Production domain patterns
      if (host == 'remaki.in' ||
          host == 'www.remaki.in' ||
          host == 'remaki.vercel.app' ||
          (host.endsWith('.remaki.in') && !host.startsWith('qa.'))) {
        return Environment.prod;
      }

      // Local development on localhost / 127.0.0.1 defaults to QA for safety
      if (host == 'localhost' || host == '127.0.0.1') {
        return Environment.qa;
      }
    }

    // 2. If manually initialized (e.g. main_qa.dart or main.dart)
    if (_manuallyConfigured) return _environment;

    // 3. Detect from compile-time --dart-define=ENV=qa or prod
    const envDefine = String.fromEnvironment('ENV', defaultValue: '');
    if (envDefine.toLowerCase() == 'qa') return Environment.qa;
    if (envDefine.toLowerCase() == 'prod') return Environment.prod;

    // 4. Detect from Flutter app flavor (Android / iOS flavor)
    if (appFlavor == 'qa') return Environment.qa;
    if (appFlavor == 'prod') return Environment.prod;

    return Environment.prod;
  }

  static bool get isQa => environment == Environment.qa;
  static bool get isProd => environment == Environment.prod;

  static String get appName => isQa ? 'Remaki QA' : 'Remaki';

  static String get apiUrl {
    // 1. Explicit override via --dart-define=API_URL=...
    const customUrl = String.fromEnvironment('API_URL');
    if (customUrl.isNotEmpty) return customUrl;

    // 2. Return URL based on current environment
    return isQa ? qaApiUrl : prodApiUrl;
  }

  static String get warmupUrl {
    return apiUrl.replaceAll('/graphql', '/');
  }
}
