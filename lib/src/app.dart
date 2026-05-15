import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';

import 'core/api/api_client.dart';
import 'core/api/auth_service.dart';
import 'core/api/auth_storage.dart';
import 'core/api/vendor_service.dart';
import 'core/models/app_models.dart';
import 'core/services/push_notification_service.dart';
import 'core/theme/app_theme.dart';
import 'features/auth/login_page.dart';
import 'features/auth/otp_page.dart';
import 'features/auth/profile_setup_page.dart';
import 'features/landing/landing_page.dart';
import 'features/notifications/notifications_page.dart';
import 'features/properties/property_enquiries_page.dart';
import 'features/bookings/tenant_property_bookings_page.dart';
import 'features/shell/app_shell.dart';

class UrbanEasyFlatsApp extends StatefulWidget {
  const UrbanEasyFlatsApp({super.key});

  /// Global navigator key — used by PushNotificationService to open
  /// NotificationsPage when the user taps a push notification.
  static final GlobalKey<NavigatorState> navigatorKey =
      GlobalKey<NavigatorState>();

  @override
  State<UrbanEasyFlatsApp> createState() => _UrbanEasyFlatsAppState();
}

class _UrbanEasyFlatsAppState extends State<UrbanEasyFlatsApp> {
  bool _isInitializing = true;
  bool _isAuthenticated = false;
  bool _needsProfileSetup = false;
  String? _phoneNumber;
  AuthSource? _authSource;
  AppRole _currentRole = AppRole.tenant;

  @override
  void initState() {
    super.initState();
    _initApp();
  }

  Future<void> _initApp() async {
    ApiClient.instance.onSessionExpired = _logout;

    await AuthService.initializeApp();

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
  }

  /// Opens NotificationsPage when the user taps a push notification.
  void _handleNotificationTap(String? payload) {
    if (!_isAuthenticated) return;
    UrbanEasyFlatsApp.navigatorKey.currentState?.push(
      MaterialPageRoute<void>(
        builder: (_) => _pageForNotificationPayload(payload),
      ),
    );
  }

  Widget _pageForNotificationPayload(String? payload) {
    if (payload == null || payload.trim().isEmpty) {
      return const NotificationsPage();
    }
    try {
      final Object? decoded = jsonDecode(payload);
      if (decoded is! Map<String, dynamic>) {
        return const NotificationsPage();
      }
      final String screen = '${decoded['screen'] ?? ''}'.trim();
      final Map<String, dynamic> data = decoded['data'] is Map
          ? Map<String, dynamic>.from(decoded['data'] as Map)
          : <String, dynamic>{};
      final String propertyId =
          '${data['propertyId'] ?? data['PropertyID'] ?? ''}'.trim();

      return switch (screen) {
        'property_enquiry_detail' => PropertyEnquiriesPage(
            initialPropertyId: propertyId.isEmpty ? null : propertyId,
          ),
        'booking_detail' || 'tenant_booking_detail' =>
          const TenantPropertyBookingsPage(),
        'announcement_detail' => const NotificationsPage(),
        'support_ticket_detail' => const NotificationsPage(),
        'bill_detail' || 'payment_history' => const NotificationsPage(),
        'agreement_detail' => const NotificationsPage(),
        'wallet_detail' || 'settings' => const NotificationsPage(),
        _ => const NotificationsPage(),
      };
    } catch (_) {
      return const NotificationsPage();
    }
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
      _isInitializing = false;
      _needsProfileSetup = false;
    });
    unawaited(PushNotificationService.syncToken());
  }

  void _logout() {
    AuthService.logout();
    if (!mounted) {
      return;
    }
    setState(() {
      _isAuthenticated = false;
      _phoneNumber = null;
      _authSource = null;
      _needsProfileSetup = false;
      _currentRole = AppRole.tenant;
    });
  }

  Widget _buildHome() {
    if (_isInitializing) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    if (_isAuthenticated) {
      return AppShell(
        role: _currentRole,
        onLogout: _logout,
      );
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
      home: AnimatedSwitcher(
        duration: const Duration(milliseconds: 220),
        child: KeyedSubtree(
          key: ValueKey<String>(
            '${_isInitializing}_${_isAuthenticated}_${_needsProfileSetup}_${_authSource}_${_phoneNumber != null}',
          ),
          child: _buildHome(),
        ),
      ),
    );
  }
}
