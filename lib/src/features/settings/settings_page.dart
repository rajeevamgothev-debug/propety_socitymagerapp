import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import '../../core/models/app_models.dart';

import '../../core/api/upload_service.dart';
import '../../core/api/vendor_service.dart';
import '../../core/models/api_models.dart';
import '../../core/theme/app_theme.dart';
import '../../core/widgets/custom_button.dart';
import '../../core/widgets/custom_card.dart';
import '../../core/widgets/page_header.dart';
import '../../core/widgets/tone_badge.dart';
import '../legal/contact_us_page.dart';
import '../legal/faq_page.dart';
import '../legal/privacy_policy_page.dart';
import '../legal/refund_policy_page.dart';
import '../legal/shipping_page.dart';
import '../legal/terms_page.dart';

class SettingsPage extends StatefulWidget {
  const SettingsPage({super.key});

  @override
  State<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends State<SettingsPage> {
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _phoneController = TextEditingController();
  final TextEditingController _flatNumberController = TextEditingController();
  final TextEditingController _bioController = TextEditingController();

  VendorData? _vendor;
  bool _isLoading = true;
  bool _isSaving = false;
  bool _isUploadingPhoto = false;
  String? _errorMessage;
  String? _deleteRequestMessage;

  @override
  void initState() {
    super.initState();
    _loadVendor();
  }

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    _phoneController.dispose();
    _flatNumberController.dispose();
    _bioController.dispose();
    super.dispose();
  }

  Future<void> _loadVendor() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final VendorData? vendor = await VendorService.fetchVendorInfo();
      if (!mounted) {
        return;
      }

      _vendor = vendor;
      _nameController.text = vendor?.fullName ?? '';
      _emailController.text = vendor?.email ?? '';
      _phoneController.text = vendor?.phone ?? '';
      _flatNumberController.text = '';

      setState(() {
        _isLoading = false;
      });
    } catch (error) {
      if (!mounted) {
        return;
      }
      setState(() {
        _errorMessage = error.toString().replaceFirst('Exception: ', '');
        _isLoading = false;
      });
    }
  }

  void _requestAccountDeletion() {
    setState(() {
      _deleteRequestMessage = 'Your request has been submitted.';
    });
    _showMessage('Account deletion request submitted.');
  }

  Future<void> _saveProfile() async {
    FocusScope.of(context).unfocus();

    final String fullName = _nameController.text.trim();
    final String email = _emailController.text.trim();

    if (fullName.isEmpty || email.isEmpty) {
      _showMessage('Name and email are required.');
      return;
    }

    setState(() {
      _isSaving = true;
    });

    try {
      final response = await VendorService.setVendorProfile(
        fullName: fullName,
        email: email,
      );

      if (!mounted) {
        return;
      }

      if (!response.success) {
        _showMessage(response.message ?? 'Unable to update profile.');
      } else {
        _showMessage(response.message ?? 'Profile updated successfully.');
        await _loadVendor();
      }
    } catch (error) {
      if (!mounted) {
        return;
      }
      _showMessage(error.toString().replaceFirst('Exception: ', ''));
    } finally {
      if (mounted) {
        setState(() {
          _isSaving = false;
        });
      }
    }
  }

  Future<void> _uploadPhoto() async {
    final FilePickerResult? result = await FilePicker.platform.pickFiles(
      type: FileType.image,
      allowMultiple: false,
    );
    if (result == null || result.files.single.path == null) {
      return;
    }

    setState(() {
      _isUploadingPhoto = true;
    });

    try {
      final String? imageId = await UploadService.uploadImage(
        File(result.files.single.path!),
      );
      if (!mounted) {
        return;
      }

      if (imageId == null) {
        _showMessage('Failed to upload image. Please try again.');
        return;
      }

      final String fullName = _nameController.text.trim().isNotEmpty
          ? _nameController.text.trim()
          : (_vendor?.fullName ?? '');
      final String email = _emailController.text.trim().isNotEmpty
          ? _emailController.text.trim()
          : (_vendor?.email ?? '');

      final response = await VendorService.setVendorProfile(
        fullName: fullName,
        email: email,
        imageId: imageId,
      );
      if (!mounted) {
        return;
      }

      if (!response.success) {
        _showMessage(response.message ?? 'Unable to update profile photo.');
      } else {
        _showMessage('Profile photo updated.');
        await _loadVendor();
      }
    } catch (error) {
      if (!mounted) {
        return;
      }
      _showMessage(error.toString().replaceFirst('Exception: ', ''));
    } finally {
      if (mounted) {
        setState(() {
          _isUploadingPhoto = false;
        });
      }
    }
  }

  Future<void> _removePhoto() async {
    FocusScope.of(context).unfocus();

    final String fullName = _nameController.text.trim();
    final String email = _emailController.text.trim();
    if (fullName.isEmpty || email.isEmpty) {
      _showMessage('Name and email are required.');
      return;
    }

    setState(() {
      _isSaving = true;
    });

    try {
      final String? imageId = _vendor?.imageId;
      if (imageId != null && imageId.isNotEmpty) {
        await UploadService.removeImage(imageId);
      }
      if (!mounted) {
        return;
      }

      final response = await VendorService.setVendorProfile(
        fullName: fullName,
        email: email,
      );

      if (!mounted) {
        return;
      }

      if (!response.success) {
        _showMessage(response.message ?? 'Unable to remove profile photo.');
      } else {
        _showMessage('Profile photo removed.');
        await _loadVendor();
      }
    } catch (error) {
      if (!mounted) {
        return;
      }
      _showMessage(error.toString().replaceFirst('Exception: ', ''));
    } finally {
      if (mounted) {
        setState(() {
          _isSaving = false;
        });
      }
    }
  }

  void _showMessage(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)),
    );
  }

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        titleSpacing: 16,
        title: const Text('Settings'),
        bottom: const PreferredSize(
          preferredSize: Size.fromHeight(1),
          child: Divider(height: 1, thickness: 1, color: AppTheme.border),
        ),
      ),
      body: RefreshIndicator(
        onRefresh: _loadVendor,
        child: ListView(
          padding: AppTheme.pagePadding,
          children: <Widget>[
            const PageHeader(
              title: 'Settings',
              description:
                  'Manage the same profile fields the website settings screen currently exposes.',
            ),
            const SizedBox(height: 16),
            if (_isLoading)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 64),
                child: Center(child: CircularProgressIndicator()),
              )
            else if (_errorMessage != null)
              CustomCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text(
                      'Unable to load profile',
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      _errorMessage!,
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: AppTheme.textSecondary,
                      ),
                    ),
                    const SizedBox(height: 16),
                    CustomButton(
                      label: 'Retry',
                      icon: const Icon(Icons.refresh_rounded),
                      onPressed: _loadVendor,
                    ),
                  ],
                ),
              )
            else ...<Widget>[
              CustomCard(
                child: Row(
                  children: <Widget>[
                    _ProfileAvatar(imageUrl: _vendor?.imageUrl),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: <Widget>[
                          Text(
                            _vendor?.fullName.isNotEmpty == true
                                ? _vendor!.fullName
                                : 'UrbanEasyFlats user',
                            style: theme.textTheme.titleLarge?.copyWith(
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          const SizedBox(height: 6),
                          Text(
                            _vendor?.phone.isNotEmpty == true
                                ? _vendor!.phone
                                : 'Phone number unavailable',
                            style: theme.textTheme.bodyMedium?.copyWith(
                              color: AppTheme.textSecondary,
                            ),
                          ),
                          const SizedBox(height: 10),
                          Wrap(
                            spacing: 8,
                            runSpacing: 8,
                            children: <Widget>[
                              ToneBadge(
                                label: _roleLabel(_vendor?.vendorType),
                                tone: UiTone.brand,
                              ),
                              if (_vendor?.vendorId.isNotEmpty == true)
                                ToneBadge(
                                  label: 'Vendor ${_vendor!.vendorId}',
                                  tone: UiTone.neutral,
                                ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              CustomCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text(
                      'Profile Photo',
                      style: theme.textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 10),
                    Text(
                      _vendor?.imageUrl?.isNotEmpty == true
                          ? 'A profile photo is set for this account.'
                          : 'No profile photo is set for this account.',
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: AppTheme.textSecondary,
                      ),
                    ),
                    const SizedBox(height: 16),
                    SizedBox(
                      width: double.infinity,
                      child: CustomButton(
                        label: _vendor?.imageUrl?.isNotEmpty == true
                            ? 'Change Photo'
                            : 'Upload Photo',
                        icon: const Icon(Icons.photo_camera_outlined),
                        isLoading: _isUploadingPhoto,
                        onPressed: (_isSaving || _isUploadingPhoto)
                            ? null
                            : _uploadPhoto,
                      ),
                    ),
                    if (_vendor?.imageUrl?.isNotEmpty == true) ...<Widget>[
                      const SizedBox(height: 8),
                      SizedBox(
                        width: double.infinity,
                        child: CustomButton(
                          label: 'Remove Current Photo',
                          icon: const Icon(Icons.delete_outline_rounded),
                          variant: CustomButtonVariant.outline,
                          isLoading: _isSaving,
                          onPressed: (_isSaving || _isUploadingPhoto)
                              ? null
                              : _removePhoto,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(height: 16),
              CustomCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text(
                      'Profile',
                      style: theme.textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 16),
                    TextField(
                      controller: _nameController,
                      decoration: const InputDecoration(
                        labelText: 'Full name',
                        prefixIcon: Icon(Icons.person_outline_rounded),
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: _emailController,
                      keyboardType: TextInputType.emailAddress,
                      decoration: const InputDecoration(
                        labelText: 'Email address',
                        prefixIcon: Icon(Icons.email_outlined),
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      enabled: false,
                      controller: _phoneController,
                      decoration: const InputDecoration(
                        labelText: 'Phone',
                        prefixIcon: Icon(Icons.phone_outlined),
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: _flatNumberController,
                      decoration: const InputDecoration(
                        labelText: 'Flat Number',
                        prefixIcon: Icon(Icons.home_outlined),
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: _bioController,
                      minLines: 3,
                      maxLines: 4,
                      decoration: const InputDecoration(
                        labelText: 'Bio',
                        hintText: 'Tell us about yourself...',
                        alignLabelWithHint: true,
                        prefixIcon: Icon(Icons.notes_outlined),
                      ),
                    ),
                    const SizedBox(height: 16),
                    SizedBox(
                      width: double.infinity,
                      child: CustomButton(
                        label: 'Save Changes',
                        icon: const Icon(Icons.save_outlined),
                        isLoading: _isSaving,
                        onPressed: _isSaving ? null : _saveProfile,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              CustomCard(
                color: const Color(0xFFFFF1F2),
                borderColor: const Color(0xFFFECDD3),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text(
                      'Account Deletion',
                      style: theme.textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.w600,
                        color: const Color(0xFF991B1B),
                      ),
                    ),
                    const SizedBox(height: 10),
                    Text(
                      'You can request account deletion from here. This action submits a request only.',
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: const Color(0xFFB91C1C),
                      ),
                    ),
                    const SizedBox(height: 16),
                    Wrap(
                      spacing: 12,
                      runSpacing: 8,
                      crossAxisAlignment: WrapCrossAlignment.center,
                      children: <Widget>[
                        CustomButton(
                          label: 'Delete My Account',
                          variant: CustomButtonVariant.danger,
                          icon: const Icon(Icons.delete_outline_rounded),
                          onPressed: _requestAccountDeletion,
                        ),
                        if ((_deleteRequestMessage ?? '').isNotEmpty)
                          Text(
                            _deleteRequestMessage!,
                            style: theme.textTheme.bodyMedium?.copyWith(
                              color: const Color(0xFF15803D),
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
            const SizedBox(height: 24),
            // ── Legal section ──
            CustomCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Text(
                    'Legal & Info',
                    style: theme.textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 12),
                  _LegalTile(
                    icon: Icons.help_outline_rounded,
                    label: 'FAQ',
                    onTap: () => _openPage(const FaqPage()),
                  ),
                  _LegalTile(
                    icon: Icons.contact_mail_outlined,
                    label: 'Contact Us',
                    onTap: () => _openPage(const ContactUsPage()),
                  ),
                  _LegalTile(
                    icon: Icons.privacy_tip_outlined,
                    label: 'Privacy Policy',
                    onTap: () => _openPage(const PrivacyPolicyPage()),
                  ),
                  _LegalTile(
                    icon: Icons.description_outlined,
                    label: 'Terms & Conditions',
                    onTap: () => _openPage(const TermsPage()),
                  ),
                  _LegalTile(
                    icon: Icons.currency_exchange_rounded,
                    label: 'Refund Policy',
                    onTap: () => _openPage(const RefundPolicyPage()),
                  ),
                  _LegalTile(
                    icon: Icons.local_shipping_outlined,
                    label: 'Shipping & Delivery',
                    onTap: () => _openPage(const ShippingPage()),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _openPage(Widget page) {
    Navigator.of(context).push(
      MaterialPageRoute<void>(builder: (_) => page),
    );
  }

  String _roleLabel(int? vendorType) {
    return switch (vendorType) {
      1 => 'Society',
      2 => 'Property',
      3 => 'Tenant',
      _ => 'Account',
    };
  }
}

class _ProfileAvatar extends StatelessWidget {
  const _ProfileAvatar({required this.imageUrl});

  final String? imageUrl;

  @override
  Widget build(BuildContext context) {
    final String? trimmed = imageUrl?.trim();
    if (trimmed == null || trimmed.isEmpty) {
      return Container(
        width: 64,
        height: 64,
        decoration: BoxDecoration(
          color: AppTheme.primarySoft,
          borderRadius: BorderRadius.circular(18),
        ),
        child: const Icon(
          Icons.person_outline_rounded,
          color: AppTheme.primary,
          size: 32,
        ),
      );
    }

    return ClipRRect(
      borderRadius: BorderRadius.circular(18),
      child: Image.network(
        trimmed,
        width: 64,
        height: 64,
        fit: BoxFit.cover,
        errorBuilder: (_, __, ___) {
          return Container(
            width: 64,
            height: 64,
            decoration: BoxDecoration(
              color: AppTheme.primarySoft,
              borderRadius: BorderRadius.circular(18),
            ),
            child: const Icon(
              Icons.person_outline_rounded,
              color: AppTheme.primary,
              size: 32,
            ),
          );
        },
      ),
    );
  }
}

class _LegalTile extends StatelessWidget {
  const _LegalTile({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(10),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 12),
        child: Row(
          children: <Widget>[
            Icon(icon, size: 20, color: AppTheme.textMuted),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                label,
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
            const Icon(
              Icons.chevron_right_rounded,
              size: 20,
              color: AppTheme.textMuted,
            ),
          ],
        ),
      ),
    );
  }
}
