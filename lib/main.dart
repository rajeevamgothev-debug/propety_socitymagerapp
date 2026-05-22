import 'dart:async';
import 'dart:ui';

import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import 'firebase_options.dart';
import 'src/app.dart';
import 'src/core/services/push_notification_service.dart';

void main() {
  runZonedGuarded<Future<void>>(
    () async {
      WidgetsFlutterBinding.ensureInitialized();

      FlutterError.onError = (FlutterErrorDetails details) {
        FlutterError.presentError(details);
        PlatformDispatcher.instance.onError?.call(
          details.exception,
          details.stack ?? StackTrace.current,
        );
      };

      PlatformDispatcher.instance.onError = (Object error, StackTrace stack) {
        debugPrint('Uncaught Flutter error: $error');
        debugPrintStack(stackTrace: stack);
        return true;
      };

      ErrorWidget.builder = (FlutterErrorDetails details) {
        if (kReleaseMode) {
          return const _SafeCrashFallback();
        }
        return ErrorWidget(details.exception);
      };

      try {
        await Firebase.initializeApp(
          options: DefaultFirebaseOptions.currentPlatform,
        );
        PushNotificationService.configureBackgroundHandler();
      } catch (error, stack) {
        debugPrint('Firebase initialization failed: $error');
        debugPrintStack(stackTrace: stack);
      }

      runApp(const UrbanEasyFlatsApp());
    },
    (Object error, StackTrace stack) {
      debugPrint('Uncaught zone error: $error');
      debugPrintStack(stackTrace: stack);
    },
  );
}

class _SafeCrashFallback extends StatelessWidget {
  const _SafeCrashFallback();

  @override
  Widget build(BuildContext context) {
    return const Material(
      color: Colors.white,
      child: SafeArea(
        child: Center(
          child: Padding(
            padding: EdgeInsets.all(24),
            child: Text(
              'Something went wrong. Please go back and try again.',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: Color(0xFF111827),
                fontSize: 16,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ),
      ),
    );
  }
}
