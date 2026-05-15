import 'package:flutter/material.dart';

import '../../core/api/property_booking_service.dart';
import '../../core/theme/app_theme.dart';
import '../../core/utils/contact_launcher.dart';

class TenantPropertyBookingsPage extends StatefulWidget {
  const TenantPropertyBookingsPage({super.key});

  @override
  State<TenantPropertyBookingsPage> createState() =>
      _TenantPropertyBookingsPageState();
}

class _TenantPropertyBookingsPageState
    extends State<TenantPropertyBookingsPage> {
  List<PropertyBookingData> _bookings = <PropertyBookingData>[];
  bool _loading = true;
  String? _error;
  String _statusGroup = '';
  String _rejectingBookingId = '';

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final result = await PropertyBookingService.filterManagerBookings(
        statusGroup: _statusGroup,
      );
      if (!mounted) return;
      setState(() {
        _bookings = result.bookings;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _error = error.toString().replaceFirst('Exception: ', '');
      });
    } finally {
      if (mounted) {
        setState(() => _loading = false);
      }
    }
  }

  Future<void> _accept(PropertyBookingData booking) async {
    try {
      await PropertyBookingService.managerAccept(booking.bookingId);
      await _load();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Booking accepted. Admin review pending.')),
      );
    } catch (error) {
      _showError(error);
    }
  }

  Future<void> _reject(PropertyBookingData booking) async {
    final TextEditingController controller = TextEditingController();
    final String? reason = await showDialog<String>(
      context: context,
      useRootNavigator: true,
      builder: (BuildContext dialogContext) => AlertDialog(
        title: const Text('Reject booking'),
        content: SingleChildScrollView(
          child: TextField(
            controller: controller,
            minLines: 3,
            maxLines: 5,
            textInputAction: TextInputAction.done,
            decoration: const InputDecoration(
              labelText: 'Reason',
              border: OutlineInputBorder(),
            ),
          ),
        ),
        actions: <Widget>[
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () =>
                Navigator.of(dialogContext).pop(controller.text.trim()),
            child: const Text('Reject'),
          ),
        ],
      ),
    );
    controller.dispose();
    if (!mounted || reason == null || reason.isEmpty) return;
    try {
      setState(() => _rejectingBookingId = booking.bookingId);
      await PropertyBookingService.managerReject(
        bookingId: booking.bookingId,
        reason: reason,
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Booking rejected. Admin will decide refund.'),
        ),
      );
      await _load();
    } catch (error) {
      _showError(error);
    } finally {
      if (mounted) {
        setState(() => _rejectingBookingId = '');
      }
    }
  }

  void _showError(Object error) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(error.toString().replaceFirst('Exception: ', ''))),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Tenant Bookings'),
        actions: <Widget>[
          IconButton(
            onPressed: _loading ? null : _load,
            icon: const Icon(Icons.refresh_rounded),
            tooltip: 'Refresh',
          ),
        ],
      ),
      body: RefreshIndicator(onRefresh: _load, child: _buildBody()),
    );
  }

  Widget _buildBody() {
    if (_loading) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_error != null) {
      return ListView(
        padding: const EdgeInsets.all(16),
        children: <Widget>[
          _StatePanel(
            icon: Icons.error_outline_rounded,
            title: 'Unable to load bookings',
            message: _error!,
            action: FilledButton.icon(
              onPressed: _load,
              icon: const Icon(Icons.refresh_rounded),
              label: const Text('Retry'),
            ),
          ),
        ],
      );
    }
    if (_bookings.isEmpty) {
      return ListView(
        padding: const EdgeInsets.all(16),
        children: <Widget>[
          _BookingFilterBar(selected: _statusGroup, onChanged: _setStatusGroup),
          const SizedBox(height: 16),
          const _StatePanel(
            icon: Icons.event_available_outlined,
            title: 'No booking requests yet',
            message: 'Tenant property bookings will appear here after payment.',
          ),
        ],
      );
    }
    return ListView.separated(
      padding: const EdgeInsets.all(16),
      itemCount: _bookings.length + 1,
      separatorBuilder: (_, __) => const SizedBox(height: 12),
      itemBuilder: (BuildContext context, int index) {
        if (index == 0) {
          return _BookingFilterBar(
            selected: _statusGroup,
            onChanged: _setStatusGroup,
          );
        }
        final PropertyBookingData booking = _bookings[index - 1];
        final bool canAct = booking.bookingStatus == 'MANAGER_REVIEW_PENDING';
        return _BookingCard(
          booking: booking,
          onAccept: canAct ? () => _accept(booking) : null,
          onReject: canAct
              ? (_rejectingBookingId == booking.bookingId
                  ? null
                  : () => _reject(booking))
              : null,
        );
      },
    );
  }

  void _setStatusGroup(String value) {
    if (_statusGroup == value) return;
    setState(() {
      _statusGroup = value;
    });
    _load();
  }
}

class _BookingFilterBar extends StatelessWidget {
  const _BookingFilterBar({required this.selected, required this.onChanged});

  final String selected;
  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) {
    const Map<String, String> filters = <String, String>{
      '': 'All',
      'PENDING': 'Pending requests',
      'ACCEPTED': 'Accepted',
      'REJECTED': 'Rejected',
    };
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: filters.entries.map((MapEntry<String, String> item) {
          return Padding(
            padding: const EdgeInsets.only(right: 8),
            child: ChoiceChip(
              selected: selected == item.key,
              label: Text(item.value),
              onSelected: (_) => onChanged(item.key),
            ),
          );
        }).toList(),
      ),
    );
  }
}

class _BookingCard extends StatelessWidget {
  const _BookingCard({
    required this.booking,
    required this.onAccept,
    required this.onReject,
  });

  final PropertyBookingData booking;
  final VoidCallback? onAccept;
  final VoidCallback? onReject;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final String propertyImageUrl = _safeNetworkImageUrl(
      booking.propertyImageUrl,
    );
    final String imageUrl = propertyImageUrl.isEmpty
        ? _propertyFallbackPhotoUrl(booking.propertyType)
        : propertyImageUrl;
    final _PropertyVisual visual = _propertyVisual(booking);
    final _StatusTone bookingTone = _statusTone(booking.bookingStatus);
    final _StatusTone paymentTone = _statusTone(booking.paymentStatus);
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border.all(color: AppTheme.border),
        borderRadius: BorderRadius.circular(14),
        boxShadow: const <BoxShadow>[
          BoxShadow(
            color: Color(0x0F111827),
            blurRadius: 18,
            offset: Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          ClipRRect(
            borderRadius: const BorderRadius.vertical(top: Radius.circular(14)),
            child: Stack(
              children: <Widget>[
                AspectRatio(
                  aspectRatio: 16 / 9,
                  child: Image.network(
                    imageUrl,
                    fit: BoxFit.cover,
                    errorBuilder: (_, __, ___) => _PropertyImageFallback(
                      booking: booking,
                      expand: true,
                    ),
                  ),
                ),
                Positioned.fill(
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: <Color>[
                          Colors.black.withOpacity(0.04),
                          Colors.transparent,
                          Colors.black.withOpacity(0.34),
                        ],
                      ),
                    ),
                  ),
                ),
                Positioned(
                  left: 12,
                  top: 12,
                  child: _StatusChip(
                    label: _statusLabel(booking.bookingStatus),
                    tone: bookingTone,
                  ),
                ),
                Positioned(
                  right: 12,
                  top: 12,
                  child: _ImagePill(icon: visual.icon, label: visual.label),
                ),
                Positioned(
                  left: 12,
                  right: 12,
                  bottom: 12,
                  child: Text(
                    booking.propertyTitle.isEmpty
                        ? 'Property booking'
                        : booking.propertyTitle,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.titleLarge?.copyWith(
                      color: Colors.white,
                      fontWeight: FontWeight.w900,
                      shadows: const <Shadow>[
                        Shadow(color: Color(0x66000000), blurRadius: 10),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                if (booking.location.trim().isNotEmpty) ...<Widget>[
                  Row(
                    children: <Widget>[
                      const Icon(
                        Icons.place_outlined,
                        size: 16,
                        color: AppTheme.textSecondary,
                      ),
                      const SizedBox(width: 5),
                      Expanded(
                        child: Text(
                          booking.location,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: AppTheme.textSecondary,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                ],
                _TenantStrip(booking: booking),
                const SizedBox(height: 12),
                Row(
                  children: <Widget>[
                    Expanded(
                      child: _MetricTile(
                        label: 'Booking payment',
                        value: 'Rs ${booking.bookingAmount.toStringAsFixed(0)}',
                        icon: Icons.payments_outlined,
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: _MetricTile(
                        label: 'Payment',
                        value: _statusLabel(booking.paymentStatus),
                        icon: Icons.verified_outlined,
                        tone: paymentTone,
                      ),
                    ),
                  ],
                ),
                if (booking.razorpayPaymentId.trim().isNotEmpty) ...<Widget>[
                  const SizedBox(height: 10),
                  Text(
                    'Payment ID: ${booking.razorpayPaymentId}',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: AppTheme.textSecondary,
                    ),
                  ),
                ],
                if (onAccept != null || onReject != null) ...<Widget>[
                  const SizedBox(height: 14),
                  Row(
                    children: <Widget>[
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: onReject,
                          icon: const Icon(Icons.close_rounded),
                          label: const Text('Reject'),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: FilledButton.icon(
                          onPressed: onAccept,
                          icon: const Icon(Icons.check_rounded),
                          label: const Text('Accept'),
                        ),
                      ),
                    ],
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _TenantStrip extends StatelessWidget {
  const _TenantStrip({required this.booking});

  final PropertyBookingData booking;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: const Color(0xFFF8FAFC),
        border: Border.all(color: const Color(0xFFE2E8F0)),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        children: <Widget>[
          const CircleAvatar(
            radius: 18,
            backgroundColor: AppTheme.primarySoft,
            child: Icon(Icons.person_outline_rounded, color: AppTheme.primary),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(
                  booking.tenantName.isEmpty ? 'Tenant' : booking.tenantName,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.labelLarge?.copyWith(
                    fontWeight: FontWeight.w900,
                  ),
                ),
                if (booking.tenantPhone.trim().isNotEmpty)
                  ContactTextButton.phone(
                    value: booking.tenantPhone,
                    label: booking.tenantPhone,
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _PropertyImageFallback extends StatelessWidget {
  const _PropertyImageFallback({required this.booking, this.expand = false});

  final PropertyBookingData booking;
  final bool expand;

  @override
  Widget build(BuildContext context) {
    final _PropertyVisual visual = _propertyVisual(booking);
    return Container(
      width: expand ? double.infinity : 74,
      height: expand ? double.infinity : 74,
      padding: EdgeInsets.all(expand ? 18 : 6),
      decoration: BoxDecoration(
        color: visual.background,
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: <Color>[visual.background, visual.accent.withOpacity(0.18)],
        ),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: <Widget>[
          Icon(visual.icon, size: expand ? 42 : 26, color: visual.accent),
          SizedBox(height: expand ? 8 : 5),
          Text(
            visual.label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: Theme.of(context).textTheme.labelSmall?.copyWith(
                  color: visual.accent,
                  fontWeight: FontWeight.w800,
                  fontSize: expand ? 13 : 10,
                ),
          ),
        ],
      ),
    );
  }
}

class _PropertyVisual {
  const _PropertyVisual({
    required this.label,
    required this.icon,
    required this.background,
    required this.accent,
  });

  final String label;
  final IconData icon;
  final Color background;
  final Color accent;
}

class _ImagePill extends StatelessWidget {
  const _ImagePill({required this.icon, required this.label});

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.92),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          Icon(icon, size: 15, color: AppTheme.textPrimary),
          const SizedBox(width: 5),
          Text(
            label,
            style: Theme.of(context).textTheme.labelSmall?.copyWith(
                  fontWeight: FontWeight.w900,
                  color: AppTheme.textPrimary,
                ),
          ),
        ],
      ),
    );
  }
}

class _MetricTile extends StatelessWidget {
  const _MetricTile({
    required this.label,
    required this.value,
    required this.icon,
    this.tone = _StatusTone.neutral,
  });

  final String label;
  final String value;
  final IconData icon;
  final _StatusTone tone;

  @override
  Widget build(BuildContext context) {
    final _StatusPalette palette = _statusPalette(tone);
    final ThemeData theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: palette.background,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: palette.border),
      ),
      child: Row(
        children: <Widget>[
          Icon(icon, size: 18, color: palette.foreground),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.labelSmall?.copyWith(
                    color: AppTheme.textSecondary,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  value,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.labelMedium?.copyWith(
                    color: palette.foreground,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _StatusChip extends StatelessWidget {
  const _StatusChip({required this.label, required this.tone});

  final String label;
  final _StatusTone tone;

  @override
  Widget build(BuildContext context) {
    final _StatusPalette palette = _statusPalette(tone);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: palette.background,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: palette.border),
      ),
      child: Text(
        label,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: Theme.of(context).textTheme.labelSmall?.copyWith(
              fontWeight: FontWeight.w900,
              color: palette.foreground,
            ),
      ),
    );
  }
}

class _StatePanel extends StatelessWidget {
  const _StatePanel({
    required this.icon,
    required this.title,
    required this.message,
    this.action,
  });

  final IconData icon;
  final String title;
  final String message;
  final Widget? action;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border.all(color: AppTheme.border),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        children: <Widget>[
          Icon(icon, size: 42, color: AppTheme.textSecondary),
          const SizedBox(height: 10),
          Text(
            title,
            style: theme.textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 6),
          Text(message, textAlign: TextAlign.center),
          if (action != null) ...<Widget>[const SizedBox(height: 14), action!],
        ],
      ),
    );
  }
}

enum _StatusTone { success, warning, danger, brand, neutral }

class _StatusPalette {
  const _StatusPalette({
    required this.background,
    required this.foreground,
    required this.border,
  });

  final Color background;
  final Color foreground;
  final Color border;
}

_StatusPalette _statusPalette(_StatusTone tone) {
  return switch (tone) {
    _StatusTone.success => const _StatusPalette(
        background: Color(0xFFDCFCE7),
        foreground: Color(0xFF166534),
        border: Color(0xFFBBF7D0),
      ),
    _StatusTone.warning => const _StatusPalette(
        background: Color(0xFFFFF7ED),
        foreground: Color(0xFFC2410C),
        border: Color(0xFFFED7AA),
      ),
    _StatusTone.danger => const _StatusPalette(
        background: Color(0xFFFEF2F2),
        foreground: Color(0xFFB91C1C),
        border: Color(0xFFFECACA),
      ),
    _StatusTone.brand => const _StatusPalette(
        background: Color(0xFFEFF6FF),
        foreground: Color(0xFF1D4ED8),
        border: Color(0xFFBFDBFE),
      ),
    _StatusTone.neutral => const _StatusPalette(
        background: Color(0xFFF8FAFC),
        foreground: Color(0xFF334155),
        border: Color(0xFFE2E8F0),
      ),
  };
}

String _safeNetworkImageUrl(String value) {
  final String url = value.trim();
  if (url.isEmpty) return '';
  final Uri? uri = Uri.tryParse(url);
  if (uri == null || !uri.hasScheme || uri.host.isEmpty) return '';
  if (uri.scheme != 'http' && uri.scheme != 'https') return '';
  return url;
}

_PropertyVisual _propertyVisual(PropertyBookingData booking) {
  final int type = booking.propertyType;
  final String label = booking.propertyTypeLabel.trim().isEmpty
      ? _typeLabel(type)
      : booking.propertyTypeLabel;
  return switch (type) {
    2 => _PropertyVisual(
        label: label,
        icon: Icons.villa_outlined,
        background: const Color(0xFFEFF6FF),
        accent: const Color(0xFF2563EB),
      ),
    3 => _PropertyVisual(
        label: label,
        icon: Icons.groups_2_outlined,
        background: const Color(0xFFF0FDF4),
        accent: const Color(0xFF15803D),
      ),
    4 => _PropertyVisual(
        label: label,
        icon: Icons.store_mall_directory_outlined,
        background: const Color(0xFFFFF7ED),
        accent: const Color(0xFFC2410C),
      ),
    _ => _PropertyVisual(
        label: label,
        icon: Icons.apartment_rounded,
        background: const Color(0xFFF5F3FF),
        accent: const Color(0xFF6D28D9),
      ),
  };
}

String _propertyFallbackPhotoUrl(int type) {
  return switch (type) {
    2 =>
      'https://images.unsplash.com/photo-1613490493576-7fde63acd811?auto=format&fit=crop&w=220&q=80',
    3 =>
      'https://images.unsplash.com/photo-1555854877-bab0e564b8d5?auto=format&fit=crop&w=220&q=80',
    4 =>
      'https://images.unsplash.com/photo-1497366754035-f200968a6e72?auto=format&fit=crop&w=220&q=80',
    _ =>
      'https://images.unsplash.com/photo-1560448204-e02f11c3d0e2?auto=format&fit=crop&w=220&q=80',
  };
}

_StatusTone _statusTone(String value) {
  final String normalized = value.replaceAll('_', ' ').toLowerCase();
  if (normalized.contains('reject') ||
      normalized.contains('failed') ||
      normalized.contains('cancel')) {
    return _StatusTone.danger;
  }
  if (normalized.contains('success') ||
      normalized.contains('confirm') ||
      normalized.contains('approved') ||
      normalized.contains('accepted') ||
      normalized.contains('captured')) {
    return _StatusTone.success;
  }
  if (normalized.contains('pending') ||
      normalized.contains('review') ||
      normalized.contains('waiting')) {
    return _StatusTone.warning;
  }
  return _StatusTone.brand;
}

String _typeLabel(int type) {
  return switch (type) {
    2 => 'Villa',
    3 => 'PG',
    4 => 'Commercial',
    _ => 'Apartment',
  };
}

String _statusLabel(String value) {
  final String normalized = value.replaceAll('_', ' ').trim().toLowerCase();
  if (normalized.isEmpty) return 'Pending';
  return normalized
      .split(' ')
      .where((String part) => part.isNotEmpty)
      .map((String part) => '${part[0].toUpperCase()}${part.substring(1)}')
      .join(' ');
}
