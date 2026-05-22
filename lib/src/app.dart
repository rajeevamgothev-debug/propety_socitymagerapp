import 'dart:async';

import 'package:flutter/material.dart';

import 'core/api/api_client.dart';
import 'core/api/auth_service.dart';
import 'core/api/auth_storage.dart';
import 'core/api/vendor_service.dart';
import 'core/models/app_models.dart';
import 'core/services/in_app_update_service.dart';
import 'core/services/notification_tap_router.dart';
import 'core/services/push_notification_service.dart';
import 'core/services/version_update_service.dart';
import 'core/theme/app_theme.dart';
import 'features/auth/login_page.dart';
import 'features/auth/blocked_account_page.dart';
import 'features/auth/otp_page.dart';
import 'features/auth/profile_setup_page.dart';
import 'features/landing/landing_page.dart';
import 'features/shell/app_shell.dart';
import 'features/update/app_update_gate_page.dart';

class UrbanEasyFlatsApp extends StatefulWidget {
  const UrbanEasyFlatsApp({super.key});

  /// Global navigator key — used by PushNotificationService to open
  /// NotificationsPage when the user taps a push notification.
  static final GlobalKey<NavigatorState> navigatorKey =
      GlobalKey<NavigatorState>();
  static final GlobalKey<ScaffoldMessengerState> scaffoldMessengerKey =
      GlobalKey<ScaffoldMessengerState>();

  @override
  State<UrbanEasyFlatsApp> createState() => _UrbanEasyFlatsAppState();
}

class _UrbanEasyFlatsAppState extends State<UrbanEasyFlatsApp>
    with WidgetsBindingObserver {
  bool _isInitializing = true;
  bool _isAuthenticated = false;
  bool _isAccountBlocked = false;
  String? _accountBlockReason;
  bool _needsProfileSetup = false;
  String? _phoneNumber;
  AuthSource? _authSource;
  AppRole _currentRole = AppRole.tenant;
  bool _hasScheduledUpdateCheck = false;
  AppUpdateDecision? _appUpdateDecision;
  bool _softUpdateDismissed = false;
  String? _pendingNotificationPayload;
  bool _isOpeningPendingNotification = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _scheduleInAppUpdateCheck();
    _initApp();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed && _isAuthenticated) {
      unawaited(PushNotificationService.syncToken());
    }
  }

  Future<void> _initApp() async {
    ApiClient.instance.onSessionExpired = _logout;

    await AuthService.initializeApp();
    await _checkBackendDrivenUpdate();

    if (!mounted) {
      return;
    }

    if (AuthStorage.isLoggedIn) {
      final AppRole role = await _resolveRole();

      if (!mounted) {
        return;
      }

      setState(() {
        _currentRole = role;
        _isAuthenticated = true;
        _isAccountBlocked = AuthStorage.whetherAccountBlockedByAdmin;
        _accountBlockReason = AuthStorage.accountBlockReason;
        _isInitializing = false;
      });
    } else {
      setState(() {
        _isInitializing = false;
      });
    }

    // Initialize push notifications after auth state is resolved.
    // Errors are swallowed — FCM is non-critical (Firebase may not be configured yet).
    PushNotificationService.initialize(
      onNotificationTap: _handleNotificationTap,
    ).catchError((_) {});
    _flushPendingNotificationTap();
  }

  void _scheduleInAppUpdateCheck() {
    if (_hasScheduledUpdateCheck) return;
    _hasScheduledUpdateCheck = true;

    WidgetsBinding.instance.addPostFrameCallback((_) {
      AppUpdateService.checkForUpdate();
    });
  }

  Future<void> _checkBackendDrivenUpdate() async {
    final AppUpdateDecision decision = await VersionUpdateService.check(
      appCode: 'manager',
    );
    if (!mounted || !decision.requiresUpdate) {
      return;
    }
    setState(() {
      _appUpdateDecision = decision;
      _softUpdateDismissed = false;
    });
  }

  /// Opens NotificationsPage when the user taps a push notification.
  void _handleNotificationTap(String? payload) {
    if (payload == null || payload.trim().isEmpty) {
      return;
    }

    if (!_isAuthenticated ||
        UrbanEasyFlatsApp.navigatorKey.currentState == null) {
      _pendingNotificationPayload = payload;
      _flushPendingNotificationTap();
      return;
    }

    UrbanEasyFlatsApp.navigatorKey.currentState?.push(
      MaterialPageRoute<void>(
        builder: (_) => NotificationTapRouter.buildPage(
          role: _currentRole,
          payload: payload,
        ),
      ),
    );
  }

  void _flushPendingNotificationTap() {
    if (_isOpeningPendingNotification) {
      return;
    }
    if (!_isAuthenticated || _pendingNotificationPayload == null) {
      return;
    }
    if (UrbanEasyFlatsApp.navigatorKey.currentState == null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          _flushPendingNotificationTap();
        }
      });
      return;
    }

    _isOpeningPendingNotification = true;
    final String payload = _pendingNotificationPayload!;
    _pendingNotificationPayload = null;

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) {
        _isOpeningPendingNotification = false;
        return;
      }

      UrbanEasyFlatsApp.navigatorKey.currentState?.push(
        MaterialPageRoute<void>(
          builder: (_) => NotificationTapRouter.buildPage(
            role: _currentRole,
            payload: payload,
          ),
        ),
      );
      _isOpeningPendingNotification = false;
    });
  }

  Future<AppRole> _resolveRole([AuthSource? fallbackSource]) async {
    int? vendorType = AuthStorage.vendorType;

    if (vendorType == null && AuthStorage.isLoggedIn) {
      final vendor = await VendorService.fetchVendorInfo();
      if (vendor != null && vendor.vendorType != 0) {
        vendorType = vendor.vendorType;
        await AuthStorage.setVendorType(vendor.vendorType);
      }
    }

    return roleFromVendorType(vendorType, fallbackSource: fallbackSource);
  }

  void _startAuth(AuthSource source) {
    setState(() {
      _authSource = source;
      _phoneNumber = null;
      _needsProfileSetup = false;
    });
  }

  void _backToLanding() {
    setState(() {
      _authSource = null;
      _phoneNumber = null;
      _needsProfileSetup = false;
    });
  }

  void _cancelProfileSetup() {
    AuthService.logout();
    _backToLanding();
  }

  void _onOtpRequested(String phone) {
    setState(() {
      _phoneNumber = phone;
    });
  }

  Future<void> _onOtpVerified(bool needsProfile) async {
    if (AuthStorage.whetherAccountBlockedByAdmin) {
      await _completeAuthentication();
      return;
    }

    if (needsProfile) {
      setState(() {
        _needsProfileSetup = true;
      });
      return;
    }

    await _completeAuthentication();
  }

  Future<void> _onProfileCompleted() async {
    await _completeAuthentication();
  }

  Future<void> _completeAuthentication() async {
    setState(() {
      _isInitializing = true;
    });

    final AppRole role = await _resolveRole(_authSource);

    if (!mounted) {
      return;
    }

    setState(() {
      _currentRole = role;
      _isAuthenticated = true;
      _isAccountBlocked = AuthStorage.whetherAccountBlockedByAdmin;
      _accountBlockReason = AuthStorage.accountBlockReason;
      _isInitializing = false;
      _needsProfileSetup = false;
    });
    unawaited(PushNotificationService.syncToken());
    _flushPendingNotificationTap();
  }

  void _logout() {
    AuthService.logout();
    if (!mounted) {
      return;
    }
    setState(() {
      _isAuthenticated = false;
      _isAccountBlocked = false;
      _accountBlockReason = null;
      _phoneNumber = null;
      _authSource = null;
      _needsProfileSetup = false;
      _currentRole = AppRole.tenant;
    });
    _pendingNotificationPayload = null;
  }

  Widget _buildHome() {
    final AppUpdateDecision? updateDecision = _appUpdateDecision;
    if (updateDecision != null &&
        updateDecision.requiresUpdate &&
        (updateDecision.isForce || !_softUpdateDismissed)) {
      return AppUpdateGatePage(
        decision: updateDecision,
        appName: 'UrbanEasyFlats Manager',
        logoAsset: 'assets/manager_logo.jpg',
        onLater: () {
          setState(() {
            _softUpdateDismissed = true;
          });
        },
      );
    }

    if (_isInitializing) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    if (_isAccountBlocked) {
      return BlockedAccountPage(reason: _accountBlockReason, onLogout: _logout);
    }

    if (_isAuthenticated) {
      return AppShell(role: _currentRole, onLogout: _logout);
    }

    if (_needsProfileSetup) {
      return ProfileSetupPage(
        onCompleted: _onProfileCompleted,
        onBack: _cancelProfileSetup,
      );
    }

    if (_authSource == null) {
      return LandingPage(onOpenAuth: _startAuth);
    }

    if (_phoneNumber == null) {
      return LoginPage(
        authSource: _authSource!,
        onOtpRequested: _onOtpRequested,
        onBack: _backToLanding,
      );
    }

    return OtpPage(
      phoneNumber: _phoneNumber!,
      authSource: _authSource!,
      onBack: () {
        setState(() {
          _phoneNumber = null;
        });
      },
      onVerified: (bool needsProfile) {
        _onOtpVerified(needsProfile);
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'UrbanEasyFlats Manager',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.lightTheme,
      navigatorKey: UrbanEasyFlatsApp.navigatorKey,
      scaffoldMessengerKey: UrbanEasyFlatsApp.scaffoldMessengerKey,
      builder: (BuildContext context, Widget? child) {
        return ColoredBox(
          color: AppTheme.background,
          child: SafeArea(child: child ?? const SizedBox.shrink()),
        );
      },
      home: AnimatedSwitcher(
        duration: const Duration(milliseconds: 220),
        child: KeyedSubtree(
          key: ValueKey<String>(
            '${_isInitializing}_${_isAuthenticated}_${_isAccountBlocked}_${_needsProfileSetup}_${_authSource}_${_phoneNumber != null}',
          ),
          child: _buildHome(),
        ),
      ),
    );
  }
}
