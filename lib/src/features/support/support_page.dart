import 'dart:async';
import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';

import '../../core/api/rental_contract_service.dart';
import '../../core/api/society_service.dart';
import '../../core/api/support_service.dart';
import '../../core/api/upload_service.dart';
import '../../core/api/vendor_service.dart';
import '../../core/models/api_models.dart';
import '../../core/models/app_models.dart';
import '../../core/theme/app_theme.dart';
import '../../core/utils/contact_launcher.dart';
import '../../core/widgets/custom_button.dart';
import '../../core/widgets/custom_card.dart';
import '../../core/widgets/custom_tab_bar.dart';
import '../../core/widgets/page_header.dart';
import '../../core/widgets/tone_badge.dart';

class SupportPage extends StatefulWidget {
  const SupportPage({
    super.key,
    required this.role,
    required this.tickets,
    this.isLoading = false,
    this.onRefresh,
    this.societyId = '',
  });

  final AppRole role;
  final List<TicketRecord> tickets;
  final bool isLoading;
  final VoidCallback? onRefresh;
  final String societyId;

  @override
  State<SupportPage> createState() => _SupportPageState();
}

class _SupportPageState extends State<SupportPage> {
  static const int _pageSize = 10;

  final TextEditingController _searchController = TextEditingController();
  Timer? _searchDebounce;

  TicketStatus? _selectedFilter;
  int? _categoryFilter;
  int? _priorityFilter;
  VendorData? _vendor;
  String _societyId = '';
  List<TicketRecord> _tickets = <TicketRecord>[];
  bool _isLoadingTickets = true;
  String? _errorMessage;
  int _skip = 0;
  int _totalCount = 0;

  bool get _isManagementRole =>
      widget.role.isSocietyScope || widget.role == AppRole.propertyManager;

  bool get _usesTenantWebsiteFlow => widget.role == AppRole.tenant;

  int get _activeFilterCount {
    int count = 0;
    if (_categoryFilter != null) count += 1;
    if (_priorityFilter != null) count += 1;
    if (_selectedFilter != null) count += 1;
    return count;
  }

  @override
  void initState() {
    super.initState();
    _tickets = widget.tickets;
    _societyId = widget.societyId;
    _bootstrap();
  }

  @override
  void dispose() {
    _searchDebounce?.cancel();
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _bootstrap() async {
    await _loadVendor();
    if (!mounted) {
      return;
    }
    await _loadTickets();
  }

  Future<void> _loadVendor() async {
    VendorData? vendor;
    try {
      vendor = await VendorService.fetchVendorInfo();
    } catch (_) {
      vendor = null;
    }
    if (!mounted) {
      return;
    }
    _vendor = vendor;

    // Resolve societyId from the society API (Vendor model has no SocietyID).
    if (widget.role.isSocietyScope && _societyId.isEmpty) {
      try {
        final SocietyData? society = await SocietyService.fetchSocietyInfo();
        if (!mounted) {
          return;
        }
        _societyId = society?.societyId ?? '';
      } catch (_) {}
    }
  }

  Future<void> _loadTickets() async {
    if (!mounted) return;
    setState(() {
      _isLoadingTickets = true;
      _errorMessage = null;
    });

    try {
      final int? ticketStatus = _selectedFilter == null
          ? null
          : _ticketStatusToApi(_selectedFilter!);
      final String? search = _searchController.text.trim().isEmpty
          ? null
          : _searchController.text.trim();

      if (widget.role.isSocietyScope && _societyId.isEmpty) {
        throw Exception('Society information is not available for this user.');
      }

      final ({List<TicketRecord> tickets, int count}) result =
          widget.role.isSocietyScope && _societyId.isNotEmpty
          ? await SupportService.filterSocietyTickets(
              societyId: _societyId,
              skip: _skip,
              limit: _pageSize,
              category: _categoryFilter,
              priority: _priorityFilter,
              ticketStatus: ticketStatus,
              search: search,
            )
          : widget.role == AppRole.propertyManager
          ? await SupportService.filterPropertyTickets(
              skip: _skip,
              limit: _pageSize,
              category: _categoryFilter,
              priority: _priorityFilter,
              ticketStatus: ticketStatus,
              search: search,
            )
          : await SupportService.filterTenantTickets(
              skip: _skip,
              limit: _pageSize,
              category: _categoryFilter,
              priority: _priorityFilter,
              ticketStatus: ticketStatus,
              search: search,
            );

      if (!mounted) {
        return;
      }

      setState(() {
        _tickets = result.tickets;
        _totalCount = result.count;
        _isLoadingTickets = false;
      });
    } catch (error) {
      if (!mounted) {
        return;
      }

      setState(() {
        _errorMessage = error.toString().replaceFirst('Exception: ', '');
        _isLoadingTickets = false;
      });
    }
  }

  Future<void> _refreshAll() async {
    await _loadVendor();
    await _loadTickets();
    widget.onRefresh?.call();
  }

  Future<void> _openFilterSheet() async {
    int? category = _categoryFilter;
    int? priority = _priorityFilter;
    TicketStatus? status = _selectedFilter;

    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (BuildContext context) {
        return StatefulBuilder(
          builder: (BuildContext context, StateSetter setModalState) {
            void apply() {
              setState(() {
                _skip = 0;
                _categoryFilter = category;
                _priorityFilter = priority;
                _selectedFilter = status;
              });
              Navigator.of(context).pop();
              _loadTickets();
            }

            void clear() {
              setModalState(() {
                category = null;
                priority = null;
                status = null;
              });
            }

            return SafeArea(
              child: Padding(
                padding: EdgeInsets.fromLTRB(
                  18,
                  8,
                  18,
                  MediaQuery.of(context).viewInsets.bottom + 18,
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Row(
                      children: <Widget>[
                        Expanded(
                          child: Text(
                            'Filter support queue',
                            style: Theme.of(context).textTheme.titleLarge,
                          ),
                        ),
                        TextButton(
                          onPressed: clear,
                          child: const Text('Clear'),
                        ),
                      ],
                    ),
                    const SizedBox(height: 14),
                    DropdownButtonFormField<int?>(
                      value: category,
                      decoration: const InputDecoration(labelText: 'Category'),
                      items: const <DropdownMenuItem<int?>>[
                        DropdownMenuItem<int?>(value: null, child: Text('All')),
                        DropdownMenuItem<int?>(
                          value: 1,
                          child: Text('Maintenance'),
                        ),
                        DropdownMenuItem<int?>(
                          value: 2,
                          child: Text('Billing'),
                        ),
                        DropdownMenuItem<int?>(
                          value: 3,
                          child: Text('Security'),
                        ),
                        DropdownMenuItem<int?>(
                          value: 4,
                          child: Text('Amenities'),
                        ),
                        DropdownMenuItem<int?>(value: 5, child: Text('Others')),
                      ],
                      onChanged: (int? value) =>
                          setModalState(() => category = value),
                    ),
                    const SizedBox(height: 12),
                    DropdownButtonFormField<int?>(
                      value: priority,
                      decoration: const InputDecoration(labelText: 'Priority'),
                      items: const <DropdownMenuItem<int?>>[
                        DropdownMenuItem<int?>(value: null, child: Text('All')),
                        DropdownMenuItem<int?>(value: 1, child: Text('Low')),
                        DropdownMenuItem<int?>(value: 2, child: Text('Medium')),
                        DropdownMenuItem<int?>(value: 3, child: Text('High')),
                        DropdownMenuItem<int?>(
                          value: 4,
                          child: Text('Critical'),
                        ),
                      ],
                      onChanged: (int? value) =>
                          setModalState(() => priority = value),
                    ),
                    const SizedBox(height: 12),
                    DropdownButtonFormField<TicketStatus?>(
                      value: status,
                      decoration: const InputDecoration(labelText: 'Status'),
                      items: <DropdownMenuItem<TicketStatus?>>[
                        const DropdownMenuItem<TicketStatus?>(
                          value: null,
                          child: Text('All'),
                        ),
                        ...TicketStatus.values.map(
                          (TicketStatus value) =>
                              DropdownMenuItem<TicketStatus?>(
                                value: value,
                                child: Text(_ticketStatusLabel(value)),
                              ),
                        ),
                      ],
                      onChanged: (TicketStatus? value) =>
                          setModalState(() => status = value),
                    ),
                    const SizedBox(height: 18),
                    Row(
                      children: <Widget>[
                        Expanded(
                          child: CustomButton(
                            label: 'Cancel',
                            variant: CustomButtonVariant.outline,
                            onPressed: () => Navigator.of(context).pop(),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: CustomButton(
                            label: 'Apply',
                            icon: const Icon(Icons.tune_rounded),
                            onPressed: apply,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final bool isBusy = widget.isLoading || _isLoadingTickets;
    final List<TicketRecord> visibleTickets = _tickets;

    Widget content = ListView(
      padding: AppTheme.pagePadding,
      children: <Widget>[
        const PageHeader(
          title: 'Support',
          description:
              'Live support queue with website-style search, filters, creation, and status actions.',
        ),
        const SizedBox(height: 16),
        Wrap(
          spacing: 12,
          runSpacing: 12,
          children: <Widget>[
            _MetricCard(
              label: 'Open',
              value:
                  '${_tickets.where((TicketRecord t) => t.status == TicketStatus.open).length}',
              tone: UiTone.warning,
            ),
            _MetricCard(
              label: 'In Progress',
              value:
                  '${_tickets.where((TicketRecord t) => t.status == TicketStatus.inProgress).length}',
              tone: UiTone.brand,
            ),
            _MetricCard(
              label: 'Resolved',
              value:
                  '${_tickets.where((TicketRecord t) => t.status == TicketStatus.resolved).length}',
              tone: UiTone.success,
            ),
            _MetricCard(
              label: 'Critical',
              value:
                  '${_tickets.where((TicketRecord t) => t.priority == TicketPriority.urgent).length}',
              tone: UiTone.danger,
            ),
          ],
        ),
        const SizedBox(height: 20),
        CustomCard(
          padding: CustomCardPadding.sm,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Row(
                children: <Widget>[
                  Expanded(
                    child: TextField(
                      controller: _searchController,
                      decoration: InputDecoration(
                        labelText: 'Search tickets',
                        prefixIcon: const Icon(Icons.search_rounded),
                        suffixIcon: IconButton(
                          onPressed: () {
                            _searchDebounce?.cancel();
                            if (!mounted) {
                              return;
                            }
                            setState(() {
                              _skip = 0;
                            });
                            _loadTickets();
                          },
                          icon: const Icon(Icons.arrow_forward_rounded),
                        ),
                      ),
                      onChanged: (String _) {
                        _searchDebounce?.cancel();
                        _searchDebounce = Timer(
                          const Duration(milliseconds: 300),
                          () {
                            if (!mounted) {
                              return;
                            }
                            setState(() {
                              _skip = 0;
                            });
                            _loadTickets();
                          },
                        );
                      },
                      onSubmitted: (_) {
                        _searchDebounce?.cancel();
                        if (!mounted) {
                          return;
                        }
                        setState(() {
                          _skip = 0;
                        });
                        _loadTickets();
                      },
                    ),
                  ),
                  const SizedBox(width: 10),
                  SizedBox(
                    height: 48,
                    child: OutlinedButton.icon(
                      onPressed: _openFilterSheet,
                      icon: const Icon(Icons.tune_rounded, size: 18),
                      label: Text(
                        _activeFilterCount == 0
                            ? 'Filter'
                            : 'Filter $_activeFilterCount',
                      ),
                    ),
                  ),
                ],
              ),
              if (_activeFilterCount > 0) ...<Widget>[
                const SizedBox(height: 12),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: <Widget>[
                    if (_categoryFilter != null)
                      ToneBadge(
                        label: _categoryFilterLabel(_categoryFilter),
                        tone: UiTone.neutral,
                        size: ToneBadgeSize.small,
                      ),
                    if (_priorityFilter != null)
                      ToneBadge(
                        label: _priorityFilterLabel(_priorityFilter),
                        tone: UiTone.warning,
                        size: ToneBadgeSize.small,
                      ),
                    if (_selectedFilter != null)
                      ToneBadge(
                        label: _ticketStatusLabel(_selectedFilter!),
                        tone: _selectedFilter!.tone,
                        size: ToneBadgeSize.small,
                      ),
                  ],
                ),
              ],
              const SizedBox(height: 14),
              CustomTabBar(
                style: CustomTabBarStyle.pill,
                currentIndex: _selectedFilter == null
                    ? 0
                    : TicketStatus.values.indexOf(_selectedFilter!) + 1,
                onChanged: (int index) {
                  setState(() {
                    _skip = 0;
                    _selectedFilter = index == 0
                        ? null
                        : TicketStatus.values[index - 1];
                  });
                  _loadTickets();
                },
                tabs: <CustomTabItem>[
                  const CustomTabItem(label: 'All'),
                  ...TicketStatus.values.map(
                    (TicketStatus status) =>
                        CustomTabItem(label: _ticketStatusLabel(status)),
                  ),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: 20),
        if (widget.role != AppRole.propertyManager &&
            visibleTickets.isNotEmpty) ...<Widget>[
          CustomCard(
            padding: CustomCardPadding.sm,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(
                  _isManagementRole
                      ? 'Create and manage support tickets for the current backend queue.'
                      : 'Raise a support issue against your linked society or property context.',
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: AppTheme.textSecondary,
                  ),
                ),
                const SizedBox(height: 12),
                SizedBox(
                  width: double.infinity,
                  child: CustomButton(
                    label: 'Create Ticket',
                    icon: const Icon(Icons.add_rounded),
                    onPressed: _openCreateTicketSheet,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
        ],
        if (isBusy)
          const _SupportLoadingSkeleton()
        else if (_errorMessage != null)
          CustomCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(
                  'Unable to load support tickets',
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
                  onPressed: _loadTickets,
                ),
              ],
            ),
          )
        else if (visibleTickets.isEmpty)
          const _SupportEmptyState()
        else
          ...visibleTickets.map((TicketRecord ticket) {
            final bool showSocietyResidentSummary =
                widget.role.isSocietyScope &&
                _hasSocietyResidentSummary(ticket);
            final DateTime displayTimestamp =
                ticket.createdAt ?? ticket.updatedAt;
            final String displayTimestampLabel = ticket.createdAt == null
                ? 'Updated'
                : 'Created';
            return _SupportTicketCard(
              ticket: ticket,
              role: widget.role,
              showSocietyResidentSummary: showSocietyResidentSummary,
              displayTimestampLabel: displayTimestampLabel,
              displayTimestamp: displayTimestamp,
              theme: theme,
              onDetails: () => _showTicketDetails(ticket),
              onAction: _isManagementRole
                  ? (int status) => _handleStatusAction(ticket, status)
                  : null,
              onContactRefresh: widget.onRefresh,
            );
          }),
        if (!isBusy && _errorMessage == null && _totalCount > _pageSize)
          CustomCard(
            padding: CustomCardPadding.sm,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(
                  'Page ${(_skip ~/ _pageSize) + 1} of ${(_totalCount / _pageSize).ceil()}',
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: AppTheme.textSecondary,
                  ),
                ),
                const SizedBox(height: 12),
                Row(
                  children: <Widget>[
                    Expanded(
                      child: CustomButton(
                        label: 'Previous',
                        variant: CustomButtonVariant.outline,
                        onPressed: _skip == 0
                            ? null
                            : () {
                                setState(() {
                                  _skip = _skip >= _pageSize
                                      ? _skip - _pageSize
                                      : 0;
                                });
                                _loadTickets();
                              },
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: CustomButton(
                        label: 'Next',
                        variant: CustomButtonVariant.outline,
                        onPressed: _skip + _pageSize >= _totalCount
                            ? null
                            : () {
                                setState(() {
                                  _skip += _pageSize;
                                });
                                _loadTickets();
                              },
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
      ],
    );

    if (widget.onRefresh != null) {
      content = RefreshIndicator(onRefresh: _refreshAll, child: content);
    }

    // FIX: Added Material ancestor for TextField.
    return Material(type: MaterialType.transparency, child: content);
  }

  static String _categoryFilterLabel(int? value) {
    return switch (value) {
      1 => 'Maintenance',
      2 => 'Billing',
      3 => 'Security',
      4 => 'Amenities',
      5 => 'Others',
      _ => 'Category',
    };
  }

  static String _priorityFilterLabel(int? value) {
    return switch (value) {
      1 => 'Low priority',
      2 => 'Medium priority',
      3 => 'High priority',
      4 => 'Critical priority',
      _ => 'Priority',
    };
  }

  String _ticketStatusLabel(TicketStatus status) {
    return status.label;
  }

  bool _hasSocietyResidentSummary(TicketRecord ticket) {
    return _firstNonEmpty(<String?>[
          ticket.residentName,
          ticket.residentPhone,
          ticket.residentEmail,
          ticket.targetName,
          ticket.societyName,
          ticket.blockName,
          ticket.buildingName,
          ticket.flatNo,
        ]) !=
        null;
  }

  String? _firstNonEmpty(List<String?> values) {
    for (final String? value in values) {
      final String trimmed = value?.trim() ?? '';
      if (trimmed.isNotEmpty) {
        return trimmed;
      }
    }
    return null;
  }

  Future<void> _handleStatusAction(TicketRecord ticket, int status) async {
    try {
      await SupportService.updateTicketStatus(
        ticketId: ticket.id,
        status: status,
      );
      _showMessage('Ticket status updated.');
      await _loadTickets();
      widget.onRefresh?.call();
    } catch (error) {
      _showMessage(error.toString().replaceFirst('Exception: ', ''));
    }
  }

  Future<void> _openCreateTicketSheet() async {
    if (_usesTenantWebsiteFlow) {
      await _openTenantCreateTicketSheet();
      return;
    }

    final TextEditingController titleController = TextEditingController();
    final TextEditingController descriptionController = TextEditingController();
    int ticketType = widget.role.isSocietyScope ? 1 : 2;
    int category = 1;
    int priority = 2;

    if (widget.role != AppRole.propertyManager &&
        (_vendor?.propertyId?.isEmpty ?? true) &&
        (_vendor?.societyId?.isNotEmpty ?? false)) {
      ticketType = 1;
    }

    File? imageFile;
    bool sheetClosed = false;

    Future<void> pickImage(StateSetter setModalState) async {
      final FilePickerResult? result = await FilePicker.platform.pickFiles(
        allowMultiple: false,
        type: FileType.image,
      );
      final String? path = result?.files.single.path;
      if (path == null || path.isEmpty) {
        return;
      }
      final String extension =
          result!.files.single.extension?.toLowerCase() ?? '';
      if (extension == 'avif') {
        _showMessage('AVIF images are not supported.');
        return;
      }
      if (!mounted || sheetClosed) {
        return;
      }
      setModalState(() {
        imageFile = File(path);
      });
    }

    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (BuildContext context) {
        bool isSubmitting = false;
        final NavigatorState sheetNavigator = Navigator.of(context);

        // FIX: Added Material ancestor for TextField.
        return Material(
          type: MaterialType.transparency,
          child: StatefulBuilder(
            builder: (BuildContext context, StateSetter setModalState) {
              Future<void> submit() async {
                if (isSubmitting || sheetClosed || !mounted) {
                  return;
                }
                final String targetId = ticketType == 1
                    ? (_vendor?.societyId ?? '')
                    : (_vendor?.propertyId ?? '');
                if (titleController.text.trim().isEmpty ||
                    descriptionController.text.trim().isEmpty ||
                    targetId.isEmpty) {
                  _showMessage(
                    'Title, description, and an active society or property context are required.',
                  );
                  return;
                }

                if (!mounted || sheetClosed) {
                  return;
                }
                setModalState(() {
                  isSubmitting = true;
                });

                try {
                  String? imageId;
                  if (imageFile != null) {
                    imageId = await UploadService.uploadImage(imageFile!);
                    if (imageId == null || imageId.isEmpty) {
                      throw Exception('Unable to upload the selected image.');
                    }
                  }

                  await SupportService.createSupportTicket(
                    ticketType: ticketType,
                    ticketTypeId: targetId,
                    title: titleController.text.trim(),
                    description: descriptionController.text.trim(),
                    category: category,
                    priority: priority,
                    imageId: imageId,
                  );
                  if (!mounted || sheetClosed) {
                    return;
                  }
                  sheetClosed = true;
                  if (sheetNavigator.mounted) {
                    sheetNavigator.pop();
                  }
                  _showMessage('Support ticket created successfully.');
                  await _loadTickets();
                  if (!mounted) {
                    return;
                  }
                  widget.onRefresh?.call();
                } catch (error) {
                  _showMessage(
                    error.toString().replaceFirst('Exception: ', ''),
                  );
                  if (!mounted || sheetClosed) {
                    return;
                  }
                  setModalState(() {
                    isSubmitting = false;
                  });
                }
              }

              return SafeArea(
                child: Padding(
                  padding: EdgeInsets.fromLTRB(
                    16,
                    12,
                    16,
                    MediaQuery.of(context).viewInsets.bottom + 24,
                  ),
                  child: ListView(
                    shrinkWrap: true,
                    children: <Widget>[
                      Text(
                        'Create Support Ticket',
                        style: Theme.of(context).textTheme.titleLarge?.copyWith(
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 16),
                      if ((_vendor?.societyId?.isNotEmpty ?? false) &&
                          (_vendor?.propertyId?.isNotEmpty ?? false))
                        Padding(
                          padding: const EdgeInsets.only(bottom: 12),
                          child: DropdownButtonFormField<int>(
                            value: ticketType,
                            decoration: const InputDecoration(
                              labelText: 'Ticket type',
                            ),
                            items: const <DropdownMenuItem<int>>[
                              DropdownMenuItem<int>(
                                value: 1,
                                child: Text('Society'),
                              ),
                              DropdownMenuItem<int>(
                                value: 2,
                                child: Text('Property'),
                              ),
                            ],
                            onChanged: (int? value) {
                              setModalState(() {
                                ticketType = value ?? 1;
                              });
                            },
                          ),
                        ),
                      TextField(
                        controller: titleController,
                        decoration: const InputDecoration(labelText: 'Title'),
                      ),
                      const SizedBox(height: 12),
                      TextField(
                        controller: descriptionController,
                        minLines: 3,
                        maxLines: 5,
                        decoration: const InputDecoration(
                          labelText: 'Description',
                        ),
                      ),
                      const SizedBox(height: 12),
                      DropdownButtonFormField<int>(
                        value: category,
                        decoration: const InputDecoration(
                          labelText: 'Category',
                        ),
                        items: const <DropdownMenuItem<int>>[
                          DropdownMenuItem<int>(
                            value: 1,
                            child: Text('Maintenance'),
                          ),
                          DropdownMenuItem<int>(
                            value: 2,
                            child: Text('Billing'),
                          ),
                          DropdownMenuItem<int>(
                            value: 3,
                            child: Text('Security'),
                          ),
                          DropdownMenuItem<int>(
                            value: 4,
                            child: Text('Amenities'),
                          ),
                          DropdownMenuItem<int>(
                            value: 5,
                            child: Text('Others'),
                          ),
                        ],
                        onChanged: (int? value) {
                          setModalState(() {
                            category = value ?? 1;
                          });
                        },
                      ),
                      const SizedBox(height: 12),
                      DropdownButtonFormField<int>(
                        value: priority,
                        decoration: const InputDecoration(
                          labelText: 'Priority',
                        ),
                        items: const <DropdownMenuItem<int>>[
                          DropdownMenuItem<int>(value: 1, child: Text('Low')),
                          DropdownMenuItem<int>(
                            value: 2,
                            child: Text('Medium'),
                          ),
                          DropdownMenuItem<int>(value: 3, child: Text('High')),
                          DropdownMenuItem<int>(
                            value: 4,
                            child: Text('Critical'),
                          ),
                        ],
                        onChanged: (int? value) {
                          setModalState(() {
                            priority = value ?? 2;
                          });
                        },
                      ),
                      const SizedBox(height: 12),
                      CustomCard(
                        padding: CustomCardPadding.sm,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: <Widget>[
                            Text(
                              'Attachment (optional)',
                              style: Theme.of(context).textTheme.titleSmall
                                  ?.copyWith(fontWeight: FontWeight.w600),
                            ),
                            const SizedBox(height: 8),
                            if (imageFile == null)
                              Text(
                                'Upload a JPG or PNG issue image. AVIF is not supported.',
                                style: Theme.of(context).textTheme.bodyMedium
                                    ?.copyWith(color: AppTheme.textSecondary),
                              )
                            else ...<Widget>[
                              ClipRRect(
                                borderRadius: BorderRadius.circular(12),
                                child: Image.file(
                                  imageFile!,
                                  width: double.infinity,
                                  height: 160,
                                  fit: BoxFit.cover,
                                ),
                              ),
                              const SizedBox(height: 8),
                              Text(
                                imageFile!.path
                                    .split(Platform.pathSeparator)
                                    .last,
                                style: Theme.of(context).textTheme.bodyMedium
                                    ?.copyWith(color: AppTheme.textSecondary),
                              ),
                            ],
                            const SizedBox(height: 12),
                            Column(
                              children: <Widget>[
                                SizedBox(
                                  width: double.infinity,
                                  child: CustomButton(
                                    label: imageFile == null
                                        ? 'Choose Image'
                                        : 'Replace Image',
                                    variant: CustomButtonVariant.outline,
                                    onPressed: () => pickImage(setModalState),
                                  ),
                                ),
                                if (imageFile != null) ...<Widget>[
                                  const SizedBox(height: 10),
                                  SizedBox(
                                    width: double.infinity,
                                    child: CustomButton(
                                      label: 'Remove',
                                      variant: CustomButtonVariant.danger,
                                      onPressed: () {
                                        setModalState(() {
                                          imageFile = null;
                                        });
                                      },
                                    ),
                                  ),
                                ],
                              ],
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 20),
                      SizedBox(
                        width: double.infinity,
                        child: CustomButton(
                          label: 'Save Ticket',
                          isLoading: isSubmitting,
                          onPressed: isSubmitting ? null : submit,
                        ),
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
        );
      },
    ).whenComplete(() {
      sheetClosed = true;
      Future<void>.delayed(const Duration(milliseconds: 700), () {
        try {
          titleController.dispose();
          descriptionController.dispose();
        } catch (_) {}
      });
    });
  }

  Future<void> _openTenantCreateTicketSheet() async {
    final TextEditingController titleController = TextEditingController();
    final TextEditingController descriptionController = TextEditingController();
    String ticketType = (_vendor?.societyId?.isNotEmpty ?? false)
        ? 'society'
        : 'property';
    String selectedTypeId = '';
    int category = 1;
    int priority = 2;
    File? imageFile;
    List<ResidentRecord> residentOptions = <ResidentRecord>[];
    List<RentalContractRecord> contractOptions = <RentalContractRecord>[];
    bool isSubmitting = false;
    bool isLoadingTargets = false;
    bool initialized = false;
    bool sheetClosed = false;

    void safeSetModalState(StateSetter setModalState, VoidCallback callback) {
      if (!mounted || sheetClosed) {
        return;
      }
      setModalState(callback);
    }

    Future<void> loadTargets(StateSetter setModalState) async {
      safeSetModalState(setModalState, () {
        isLoadingTargets = true;
        selectedTypeId = '';
      });

      try {
        if (ticketType == 'society') {
          if (_vendor?.societyId?.isNotEmpty ?? false) {
            final result = await SocietyService.filterResidents(
              societyId: _vendor!.societyId!,
              limit: 100,
              tenantVendorId: _vendor?.vendorId,
            );
            residentOptions = result.residents.where((ResidentRecord record) {
              return record.status;
            }).toList();
          } else {
            residentOptions = <ResidentRecord>[];
          }
        } else {
          final result =
              await RentalContractService.filterTenantRentalContracts(
                limit: 100,
              );
          contractOptions = result.contracts;
        }
      } catch (_) {
        residentOptions = <ResidentRecord>[];
        contractOptions = <RentalContractRecord>[];
      }

      if (!mounted || sheetClosed) {
        return;
      }

      safeSetModalState(setModalState, () {
        isLoadingTargets = false;
        selectedTypeId = ticketType == 'society'
            ? (residentOptions.isNotEmpty ? residentOptions.first.id : '')
            : (contractOptions.isNotEmpty
                  ? ((contractOptions.first.propertyId ?? '').isNotEmpty
                        ? contractOptions.first.propertyId!
                        : contractOptions.first.id)
                  : '');
      });
    }

    Future<void> pickImage(StateSetter setModalState) async {
      final FilePickerResult? result = await FilePicker.platform.pickFiles(
        allowMultiple: false,
        type: FileType.image,
      );
      final String? path = result?.files.single.path;
      if (path == null || path.isEmpty) {
        return;
      }

      final String extension =
          result!.files.single.extension?.toLowerCase() ?? '';
      if (extension == 'avif') {
        _showMessage('AVIF images are not supported.');
        return;
      }

      safeSetModalState(setModalState, () {
        imageFile = File(path);
      });
    }

    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (BuildContext context) {
        final NavigatorState sheetNavigator = Navigator.of(context);
        // FIX: Added Material ancestor for TextField.
        return Material(
          type: MaterialType.transparency,
          child: StatefulBuilder(
            builder: (BuildContext context, StateSetter setModalState) {
              if (!initialized) {
                initialized = true;
                Future<void>.microtask(() => loadTargets(setModalState));
              }

              Future<void> submit() async {
                if (isSubmitting || sheetClosed || !mounted) {
                  return;
                }
                final String ticketTypeIdForApi = ticketType == 'society'
                    ? (_vendor?.societyId ?? '')
                    : selectedTypeId;

                if (titleController.text.trim().isEmpty ||
                    descriptionController.text.trim().isEmpty ||
                    selectedTypeId.isEmpty ||
                    ticketTypeIdForApi.isEmpty) {
                  _showMessage(
                    'Title, description, and the related resident or contract are required.',
                  );
                  return;
                }

                safeSetModalState(setModalState, () {
                  isSubmitting = true;
                });

                try {
                  String? imageId;
                  if (imageFile != null) {
                    imageId = await UploadService.uploadImage(imageFile!);
                    if (imageId == null || imageId.isEmpty) {
                      throw Exception('Unable to upload the selected image.');
                    }
                  }

                  await SupportService.createSupportTicket(
                    ticketType: ticketType == 'society' ? 1 : 2,
                    ticketTypeId: ticketTypeIdForApi,
                    title: titleController.text.trim(),
                    description: descriptionController.text.trim(),
                    category: category,
                    priority: priority,
                    imageId: imageId,
                  );

                  if (!mounted || sheetClosed) {
                    return;
                  }
                  sheetClosed = true;
                  if (sheetNavigator.mounted) {
                    sheetNavigator.pop();
                  }
                  _showMessage('Support ticket created successfully.');
                  await _loadTickets();
                  if (!mounted) {
                    return;
                  }
                  widget.onRefresh?.call();
                } catch (error) {
                  _showMessage(
                    error.toString().replaceFirst('Exception: ', ''),
                  );
                  if (!mounted || sheetClosed) {
                    return;
                  }
                  safeSetModalState(setModalState, () {
                    isSubmitting = false;
                  });
                }
              }

              final bool hasSocietyContext =
                  _vendor?.societyId?.isNotEmpty ?? false;
              final bool hasPropertyContext =
                  (_vendor?.propertyId?.isNotEmpty ?? false) ||
                  contractOptions.isNotEmpty;

              return SafeArea(
                child: Padding(
                  padding: EdgeInsets.fromLTRB(
                    16,
                    12,
                    16,
                    MediaQuery.of(context).viewInsets.bottom + 24,
                  ),
                  child: ListView(
                    shrinkWrap: true,
                    children: <Widget>[
                      Text(
                        'Create Support Ticket',
                        style: Theme.of(context).textTheme.titleLarge?.copyWith(
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Match the website tenant flow by selecting whether the issue is for your society residence or a rented property contract.',
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: AppTheme.textSecondary,
                        ),
                      ),
                      const SizedBox(height: 16),
                      TextField(
                        controller: titleController,
                        decoration: const InputDecoration(labelText: 'Title'),
                      ),
                      const SizedBox(height: 12),
                      TextField(
                        controller: descriptionController,
                        minLines: 3,
                        maxLines: 5,
                        decoration: const InputDecoration(
                          labelText: 'Description',
                        ),
                      ),
                      if (hasSocietyContext && hasPropertyContext) ...<Widget>[
                        const SizedBox(height: 12),
                        DropdownButtonFormField<String>(
                          value: ticketType,
                          decoration: const InputDecoration(
                            labelText: 'Ticket for',
                          ),
                          items: const <DropdownMenuItem<String>>[
                            DropdownMenuItem<String>(
                              value: 'society',
                              child: Text('Society Resident'),
                            ),
                            DropdownMenuItem<String>(
                              value: 'property',
                              child: Text('Rented Property'),
                            ),
                          ],
                          onChanged: (String? value) {
                            setModalState(() {
                              ticketType = value ?? 'society';
                              residentOptions = <ResidentRecord>[];
                              contractOptions = <RentalContractRecord>[];
                            });
                            loadTargets(setModalState);
                          },
                        ),
                      ],
                      const SizedBox(height: 12),
                      DropdownButtonFormField<String>(
                        value: selectedTypeId.isEmpty ? null : selectedTypeId,
                        decoration: InputDecoration(
                          labelText: ticketType == 'society'
                              ? 'Select Resident Profile'
                              : 'Select Property Contract',
                        ),
                        items: <DropdownMenuItem<String>>[
                          DropdownMenuItem<String>(
                            value: '',
                            child: Text(
                              isLoadingTargets
                                  ? 'Loading...'
                                  : ticketType == 'society'
                                  ? 'Choose your resident profile'
                                  : 'Choose a contract',
                            ),
                          ),
                          ...(ticketType == 'society'
                              ? residentOptions.map(
                                  (
                                    ResidentRecord resident,
                                  ) => DropdownMenuItem<String>(
                                    value: resident.id,
                                    child: Text(
                                      '${resident.name} (${resident.flatNo})',
                                    ),
                                  ),
                                )
                              : contractOptions.map(
                                  (
                                    RentalContractRecord contract,
                                  ) => DropdownMenuItem<String>(
                                    value:
                                        (contract.propertyId ?? '').isNotEmpty
                                        ? contract.propertyId!
                                        : contract.id,
                                    child: Text(
                                      '${contract.propertyTitle} | ${contract.ownerName}',
                                    ),
                                  ),
                                )),
                        ],
                        onChanged: isLoadingTargets
                            ? null
                            : (String? value) {
                                setModalState(() {
                                  selectedTypeId = value ?? '';
                                });
                              },
                      ),
                      const SizedBox(height: 12),
                      Row(
                        children: <Widget>[
                          Expanded(
                            child: DropdownButtonFormField<int>(
                              value: category,
                              decoration: const InputDecoration(
                                labelText: 'Category',
                              ),
                              items: const <DropdownMenuItem<int>>[
                                DropdownMenuItem<int>(
                                  value: 1,
                                  child: Text('Maintenance'),
                                ),
                                DropdownMenuItem<int>(
                                  value: 2,
                                  child: Text('Billing'),
                                ),
                                DropdownMenuItem<int>(
                                  value: 3,
                                  child: Text('Security'),
                                ),
                                DropdownMenuItem<int>(
                                  value: 4,
                                  child: Text('Amenities'),
                                ),
                                DropdownMenuItem<int>(
                                  value: 5,
                                  child: Text('Others'),
                                ),
                              ],
                              onChanged: (int? value) {
                                setModalState(() {
                                  category = value ?? 1;
                                });
                              },
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: DropdownButtonFormField<int>(
                              value: priority,
                              decoration: const InputDecoration(
                                labelText: 'Priority',
                              ),
                              items: const <DropdownMenuItem<int>>[
                                DropdownMenuItem<int>(
                                  value: 1,
                                  child: Text('Low'),
                                ),
                                DropdownMenuItem<int>(
                                  value: 2,
                                  child: Text('Medium'),
                                ),
                                DropdownMenuItem<int>(
                                  value: 3,
                                  child: Text('High'),
                                ),
                                DropdownMenuItem<int>(
                                  value: 4,
                                  child: Text('Critical'),
                                ),
                              ],
                              onChanged: (int? value) {
                                setModalState(() {
                                  priority = value ?? 2;
                                });
                              },
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      CustomCard(
                        padding: CustomCardPadding.sm,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: <Widget>[
                            Text(
                              'Attachment (optional)',
                              style: Theme.of(context).textTheme.titleSmall
                                  ?.copyWith(fontWeight: FontWeight.w600),
                            ),
                            const SizedBox(height: 8),
                            if (imageFile == null)
                              Text(
                                'Upload a JPG or PNG issue image. AVIF is not supported.',
                                style: Theme.of(context).textTheme.bodyMedium
                                    ?.copyWith(color: AppTheme.textSecondary),
                              )
                            else ...<Widget>[
                              ClipRRect(
                                borderRadius: BorderRadius.circular(12),
                                child: Image.file(
                                  imageFile!,
                                  width: double.infinity,
                                  height: 160,
                                  fit: BoxFit.cover,
                                ),
                              ),
                              const SizedBox(height: 8),
                              Text(
                                imageFile!.path
                                    .split(Platform.pathSeparator)
                                    .last,
                                style: Theme.of(context).textTheme.bodyMedium
                                    ?.copyWith(color: AppTheme.textSecondary),
                              ),
                            ],
                            const SizedBox(height: 12),
                            Row(
                              children: <Widget>[
                                Expanded(
                                  child: CustomButton(
                                    label: imageFile == null
                                        ? 'Choose Image'
                                        : 'Replace Image',
                                    variant: CustomButtonVariant.outline,
                                    onPressed: () => pickImage(setModalState),
                                  ),
                                ),
                                if (imageFile != null) ...<Widget>[
                                  const SizedBox(width: 10),
                                  Expanded(
                                    child: CustomButton(
                                      label: 'Remove',
                                      variant: CustomButtonVariant.danger,
                                      onPressed: () {
                                        setModalState(() {
                                          imageFile = null;
                                        });
                                      },
                                    ),
                                  ),
                                ],
                              ],
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 20),
                      Row(
                        children: <Widget>[
                          Expanded(
                            child: CustomButton(
                              label: 'Cancel',
                              variant: CustomButtonVariant.outline,
                              onPressed: isSubmitting
                                  ? null
                                  : () => Navigator.of(context).pop(),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: CustomButton(
                              label: 'Create Ticket',
                              isLoading: isSubmitting,
                              onPressed: isSubmitting ? null : submit,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
        );
      },
    ).whenComplete(() {
      sheetClosed = true;
      Future<void>.delayed(const Duration(milliseconds: 700), () {
        try {
          titleController.dispose();
          descriptionController.dispose();
        } catch (_) {}
      });
    });
  }

  void _showTicketDetails(TicketRecord ticket) {
    showDialog<void>(
      context: context,
      builder: (BuildContext context) {
        final double dialogWidth = MediaQuery.sizeOf(context).width >= 520
            ? 440
            : MediaQuery.sizeOf(context).width - 64;
        return AlertDialog(
          title: Text(ticket.title),
          content: SizedBox(
            width: dialogWidth.clamp(280, 440),
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: <Widget>[
                      ToneBadge(
                        label: _ticketStatusLabel(ticket.status),
                        tone: ticket.status.tone,
                      ),
                      ToneBadge(
                        label: ticket.priority.label,
                        tone: ticket.priority.tone,
                      ),
                      ToneBadge(label: ticket.category, tone: UiTone.neutral),
                    ],
                  ),
                  const SizedBox(height: 16),
                  if ((ticket.targetName ?? '').isNotEmpty) ...<Widget>[
                    Text(
                      'Regarding',
                      style: Theme.of(context).textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(ticket.targetName!),
                    const SizedBox(height: 16),
                  ],
                  if (_firstNonEmpty(<String?>[
                        ticket.residentName,
                        ticket.residentPhone,
                        ticket.residentEmail,
                      ]) !=
                      null) ...<Widget>[
                    Text(
                      'Resident Details',
                      style: Theme.of(context).textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 6),
                    if ((ticket.residentName ?? '').isNotEmpty)
                      Text('Name: ${ticket.residentName!}'),
                    if ((ticket.residentPhone ?? '').isNotEmpty)
                      ContactTextButton.phone(
                        value: ticket.residentPhone!,
                        label: 'Phone: ${ticket.residentPhone!}',
                      ),
                    if ((ticket.residentEmail ?? '').isNotEmpty)
                      ContactTextButton.email(
                        value: ticket.residentEmail!,
                        label: 'Email: ${ticket.residentEmail!}',
                      ),
                    const SizedBox(height: 16),
                  ],
                  if ((ticket.societyName ?? '').isNotEmpty ||
                      (ticket.blockName ?? '').isNotEmpty ||
                      (ticket.buildingName ?? '').isNotEmpty ||
                      (ticket.flatNo ?? '').isNotEmpty) ...<Widget>[
                    Text(
                      'Location Context',
                      style: Theme.of(context).textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 6),
                    if ((ticket.societyName ?? '').isNotEmpty)
                      Text('Society: ${ticket.societyName!}'),
                    if ((ticket.blockName ?? '').isNotEmpty)
                      Text('Block: ${ticket.blockName!}'),
                    if ((ticket.buildingName ?? '').isNotEmpty)
                      Text('Building: ${ticket.buildingName!}'),
                    if ((ticket.flatNo ?? '').isNotEmpty)
                      Text('Flat: ${ticket.flatNo!}'),
                    const SizedBox(height: 16),
                  ],
                  if ((ticket.imageUrl ?? '').isNotEmpty) ...<Widget>[
                    ClipRRect(
                      borderRadius: BorderRadius.circular(14),
                      child: SizedBox(
                        width: double.infinity,
                        height: 180,
                        child: Image.network(
                          ticket.imageUrl!,
                          fit: BoxFit.cover,
                          errorBuilder: (_, __, ___) => Container(
                            color: AppTheme.surfaceMuted,
                            alignment: Alignment.center,
                            child: const Text('Unable to load attachment'),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                  ],
                  Text(
                    'Description',
                    style: Theme.of(context).textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(ticket.description),
                  const SizedBox(height: 16),
                  Text(
                    'Created ${formatCompactDate(ticket.createdAt ?? ticket.updatedAt)} at ${formatClock(ticket.createdAt ?? ticket.updatedAt)}',
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Updated ${formatCompactDate(ticket.updatedAt)} at ${formatClock(ticket.updatedAt)}',
                  ),
                  if (ticket.assignee != null) ...<Widget>[
                    const SizedBox(height: 4),
                    Text('Assignee: ${ticket.assignee}'),
                  ],
                  if ((ticket.propertyTitle ?? '').isNotEmpty ||
                      (ticket.propertyFlatNo ?? '').isNotEmpty ||
                      (ticket.tenantName ?? '').isNotEmpty ||
                      (ticket.tenantPhone ?? '').isNotEmpty) ...<Widget>[
                    const SizedBox(height: 16),
                    Text(
                      'Property Context',
                      style: Theme.of(context).textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 6),
                    if ((ticket.propertyTitle ?? '').isNotEmpty)
                      Text('Property: ${ticket.propertyTitle!}'),
                    if ((ticket.propertyFlatNo ?? '').isNotEmpty)
                      Text('Unit: ${ticket.propertyFlatNo!}'),
                    if ((ticket.tenantName ?? '').isNotEmpty)
                      Text('Tenant: ${ticket.tenantName!}'),
                    if ((ticket.tenantPhone ?? '').isNotEmpty)
                      ContactTextButton.phone(
                        value: ticket.tenantPhone!,
                        label: 'Phone: ${ticket.tenantPhone!}',
                      ),
                  ],
                ],
              ),
            ),
          ),
          actions: <Widget>[
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Close'),
            ),
          ],
        );
      },
    );
  }

  int _ticketStatusToApi(TicketStatus status) {
    return switch (status) {
      TicketStatus.open => 1,
      TicketStatus.inProgress => 2,
      TicketStatus.resolved => 3,
      TicketStatus.rejected => 4,
    };
  }

  void _showMessage(String message) {
    if (!mounted) {
      return;
    }
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) {
        return;
      }
      final ScaffoldMessengerState? messenger = ScaffoldMessenger.maybeOf(
        context,
      );
      messenger
        ?..hideCurrentSnackBar()
        ..showSnackBar(SnackBar(content: Text(message)));
    });
  }
}

class _SupportTicketAvatar extends StatefulWidget {
  const _SupportTicketAvatar({this.imageUrl});

  final String? imageUrl;

  @override
  State<_SupportTicketAvatar> createState() => _SupportTicketAvatarState();
}

class _SupportTicketAvatarState extends State<_SupportTicketAvatar> {
  String? _resolvedUrl;
  bool _isResolving = false;

  @override
  void initState() {
    super.initState();
    _resolveImageId();
  }

  @override
  void didUpdateWidget(covariant _SupportTicketAvatar oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.imageUrl != widget.imageUrl) {
      _resolvedUrl = null;
      _resolveImageId();
    }
  }

  Future<void> _resolveImageId() async {
    final String value = widget.imageUrl?.trim() ?? '';
    if (!value.startsWith('imageid:') || _isResolving) {
      return;
    }

    final String imageId = value.substring('imageid:'.length).trim();
    if (imageId.isEmpty) {
      return;
    }

    setState(() => _isResolving = true);
    try {
      final String? resolved = await UploadService.fetchImageInfo(imageId);
      if (!mounted) {
        return;
      }
      setState(() {
        _resolvedUrl = resolved;
        _isResolving = false;
      });
    } catch (_) {
      if (!mounted) {
        return;
      }
      setState(() => _isResolving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final String rawUrl = widget.imageUrl?.trim() ?? '';
    final String url = rawUrl.startsWith('imageid:')
        ? (_resolvedUrl ?? '')
        : rawUrl;

    return ClipOval(
      child: Container(
        width: 82,
        height: 82,
        color: AppTheme.surfaceMuted,
        child: _isResolving
            ? const Center(
                child: SizedBox(
                  width: 22,
                  height: 22,
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
              )
            : url.isEmpty
            ? const Icon(
                Icons.person_outline,
                size: 36,
                color: AppTheme.textMuted,
              )
            : Image.network(
                url,
                fit: BoxFit.cover,
                errorBuilder: (_, __, ___) => const Icon(
                  Icons.person_outline,
                  size: 36,
                  color: AppTheme.textMuted,
                ),
              ),
      ),
    );
  }
}

class _StatusActionMenu extends StatelessWidget {
  const _StatusActionMenu({required this.ticket, required this.onAction});

  final TicketRecord ticket;
  final void Function(int status) onAction;

  @override
  Widget build(BuildContext context) {
    final List<({String label, int status})> actions = switch (ticket.status) {
      TicketStatus.open => <({String label, int status})>[
        (label: 'In Progress', status: 2),
        (label: 'Resolve', status: 3),
        (label: 'Reject', status: 4),
      ],
      TicketStatus.inProgress => <({String label, int status})>[
        (label: 'Resolve', status: 3),
        (label: 'Reject', status: 4),
        (label: 'Reopen', status: 1),
      ],
      TicketStatus.resolved => <({String label, int status})>[
        (label: 'Reopen', status: 1),
      ],
      TicketStatus.rejected => <({String label, int status})>[
        (label: 'Reopen', status: 1),
      ],
    };

    return PopupMenuButton<int>(
      onSelected: onAction,
      itemBuilder: (_) => actions
          .map(
            (({String label, int status}) a) =>
                PopupMenuItem<int>(value: a.status, child: Text(a.label)),
          )
          .toList(),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.primary,
          borderRadius: BorderRadius.circular(AppTheme.radiusSmall),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: <Widget>[
            Text(
              'Actions',
              style: Theme.of(context).textTheme.labelLarge?.copyWith(
                color: Colors.white,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(width: 4),
            const Icon(Icons.arrow_drop_down, color: Colors.white, size: 20),
          ],
        ),
      ),
    );
  }
}

class _SupportEmptyState extends StatelessWidget {
  const _SupportEmptyState();

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    return CustomCard(
      padding: CustomCardPadding.lg,
      color: AppTheme.surface,
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 360),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              Container(
                width: 72,
                height: 72,
                decoration: BoxDecoration(
                  color: AppTheme.primarySoft,
                  borderRadius: BorderRadius.circular(24),
                ),
                child: Icon(
                  Icons.support_agent_rounded,
                  size: 34,
                  color: theme.colorScheme.primary,
                ),
              ),
              const SizedBox(height: 18),
              Text(
                'No support tickets found',
                textAlign: TextAlign.center,
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'New resident and property support requests will appear here once they are created.',
                textAlign: TextAlign.center,
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: AppTheme.textSecondary,
                  height: 1.4,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SupportLoadingSkeleton extends StatelessWidget {
  const _SupportLoadingSkeleton();

  @override
  Widget build(BuildContext context) {
    return Column(
      children: const <Widget>[
        _SupportSkeletonCard(),
        SizedBox(height: 12),
        _SupportSkeletonCard(),
        SizedBox(height: 12),
        _SupportSkeletonCard(),
      ],
    );
  }
}

class _SupportSkeletonCard extends StatelessWidget {
  const _SupportSkeletonCard();

  @override
  Widget build(BuildContext context) {
    return CustomCard(
      padding: CustomCardPadding.sm,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          _SkeletonBar(widthFactor: 0.62, height: 18),
          const SizedBox(height: 12),
          _SkeletonBar(widthFactor: 1, height: 12),
          const SizedBox(height: 8),
          _SkeletonBar(widthFactor: 0.78, height: 12),
          const SizedBox(height: 14),
          Row(
            children: const <Widget>[
              _SkeletonPill(),
              SizedBox(width: 8),
              _SkeletonPill(),
            ],
          ),
        ],
      ),
    );
  }
}

class _SkeletonBar extends StatelessWidget {
  const _SkeletonBar({required this.widthFactor, required this.height});

  final double widthFactor;
  final double height;

  @override
  Widget build(BuildContext context) {
    return FractionallySizedBox(
      widthFactor: widthFactor,
      child: Container(
        height: height,
        decoration: BoxDecoration(
          color: AppTheme.surfaceMuted,
          borderRadius: BorderRadius.circular(999),
        ),
      ),
    );
  }
}

class _SkeletonPill extends StatelessWidget {
  const _SkeletonPill();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 84,
      height: 26,
      decoration: BoxDecoration(
        color: AppTheme.surfaceMuted,
        borderRadius: BorderRadius.circular(999),
      ),
    );
  }
}

class _MetricCard extends StatelessWidget {
  const _MetricCard({
    required this.label,
    required this.value,
    required this.tone,
  });

  final String label;
  final String value;
  final UiTone tone;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 152,
      child: CustomCard(
        padding: CustomCardPadding.sm,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            ToneBadge(label: label, tone: tone, size: ToneBadgeSize.small),
            const SizedBox(height: 14),
            Text(
              value,
              style: Theme.of(
                context,
              ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w700),
            ),
          ],
        ),
      ),
    );
  }
}

class _SupportTicketCard extends StatelessWidget {
  const _SupportTicketCard({
    required this.ticket,
    required this.role,
    required this.showSocietyResidentSummary,
    required this.displayTimestampLabel,
    required this.displayTimestamp,
    required this.theme,
    required this.onDetails,
    required this.onAction,
    this.onContactRefresh,
  });

  final TicketRecord ticket;
  final AppRole role;
  final bool showSocietyResidentSummary;
  final String displayTimestampLabel;
  final DateTime displayTimestamp;
  final ThemeData theme;
  final VoidCallback onDetails;
  final ValueChanged<int>? onAction;
  final VoidCallback? onContactRefresh;

  bool get _isManagementRole =>
      role.isSocietyScope || role == AppRole.propertyManager;

  @override
  Widget build(BuildContext context) {
    final bool hasHeroImage = (ticket.imageUrl ?? '').isNotEmpty;
    final Color accent = ticket.priority.tone == UiTone.danger
        ? theme.colorScheme.error
        : ticket.priority.tone == UiTone.warning
        ? theme.colorScheme.secondary
        : theme.colorScheme.primary;

    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: CustomCard(
        padding: CustomCardPadding.none,
        child: ClipRRect(
          borderRadius: BorderRadius.circular(AppTheme.radiusMedium),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: <Widget>[
              Container(
                padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
                decoration: BoxDecoration(
                  color: accent.withValues(alpha: 0.08),
                  border: Border(left: BorderSide(color: accent, width: 4)),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: <Widget>[
                          Text(
                            ticket.title,
                            style: theme.textTheme.titleMedium?.copyWith(
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          const SizedBox(height: 6),
                          Text(
                            ticket.description,
                            style: theme.textTheme.bodyMedium?.copyWith(
                              color: AppTheme.textSecondary,
                              height: 1.35,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 10),
                    ToneBadge(
                      label: ticket.priority.label,
                      tone: ticket.priority.tone,
                      size: ToneBadgeSize.small,
                    ),
                  ],
                ),
              ),
              if (hasHeroImage)
                GestureDetector(
                  onTap: onDetails,
                  child: Image.network(
                    ticket.imageUrl!,
                    height: 176,
                    width: double.infinity,
                    fit: BoxFit.cover,
                    errorBuilder: (_, __, ___) => Container(
                      height: 176,
                      color: AppTheme.surfaceMuted,
                      alignment: Alignment.center,
                      child: const Text('Unable to load attachment'),
                    ),
                  ),
                ),
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 14, 16, 16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: <Widget>[
                        ToneBadge(
                          label: ticket.status.label,
                          tone: ticket.status.tone,
                          size: ToneBadgeSize.small,
                        ),
                        ToneBadge(
                          label: ticket.category,
                          tone: UiTone.neutral,
                          size: ToneBadgeSize.small,
                        ),
                        if (ticket.assignee != null)
                          ToneBadge(
                            label: 'Assigned: ${ticket.assignee}',
                            tone: UiTone.brand,
                            size: ToneBadgeSize.small,
                          ),
                        if ((ticket.targetName ?? '').isNotEmpty)
                          ToneBadge(
                            label: ticket.targetName!,
                            tone: UiTone.brand,
                            size: ToneBadgeSize.small,
                          ),
                        if ((ticket.propertyTitle ?? '').isNotEmpty)
                          ToneBadge(
                            label: ticket.propertyTitle!,
                            tone: UiTone.neutral,
                            size: ToneBadgeSize.small,
                          ),
                        if ((ticket.tenantName ?? '').isNotEmpty)
                          ToneBadge(
                            label: ticket.tenantName!,
                            tone: UiTone.brand,
                            size: ToneBadgeSize.small,
                          ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    if (showSocietyResidentSummary) ...<Widget>[
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: <Widget>[
                          _SupportTicketAvatar(
                            imageUrl: ticket.residentImageUrl,
                          ),
                          const SizedBox(width: 14),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: <Widget>[
                                Text(
                                  (ticket.residentName?.trim().isNotEmpty ==
                                          true
                                      ? ticket.residentName!.trim()
                                      : (ticket.targetName?.trim().isNotEmpty ==
                                                true
                                            ? ticket.targetName!.trim()
                                            : 'Resident Details')),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: theme.textTheme.titleSmall?.copyWith(
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                                const SizedBox(height: 8),
                                if ((ticket.societyName ?? '').isNotEmpty)
                                  Text(ticket.societyName!),
                                if ((ticket.blockName ?? '').isNotEmpty)
                                  Text('Block ${ticket.blockName!}'),
                                if ((ticket.buildingName ?? '').isNotEmpty)
                                  Text('Building ${ticket.buildingName!}'),
                                if ((ticket.flatNo ?? '').isNotEmpty)
                                  Text('Flat ${ticket.flatNo!}'),
                                if ((ticket.residentPhone ?? '')
                                    .isNotEmpty) ...<Widget>[
                                  const SizedBox(height: 8),
                                  ContactTextButton.phone(
                                    value: ticket.residentPhone!,
                                    label: ticket.residentPhone!,
                                  ),
                                ],
                                if ((ticket.residentEmail ?? '')
                                    .isNotEmpty) ...<Widget>[
                                  const SizedBox(height: 6),
                                  Text(ticket.residentEmail!),
                                ],
                              ],
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                    ],
                    if (!showSocietyResidentSummary &&
                        ((ticket.societyName ?? '').isNotEmpty ||
                            (ticket.blockName ?? '').isNotEmpty ||
                            (ticket.buildingName ?? '').isNotEmpty ||
                            (ticket.flatNo ?? '').isNotEmpty)) ...<Widget>[
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: AppTheme.surfaceMuted,
                          borderRadius: BorderRadius.circular(
                            AppTheme.radiusSmall,
                          ),
                        ),
                        child: Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children: <Widget>[
                            if ((ticket.societyName ?? '').isNotEmpty)
                              Text(ticket.societyName!),
                            if ((ticket.blockName ?? '').isNotEmpty)
                              Text('Block ${ticket.blockName!}'),
                            if ((ticket.buildingName ?? '').isNotEmpty)
                              Text('Building ${ticket.buildingName!}'),
                            if ((ticket.flatNo ?? '').isNotEmpty)
                              Text('Flat ${ticket.flatNo!}'),
                          ],
                        ),
                      ),
                      const SizedBox(height: 12),
                    ],
                    if (_isManagementRole &&
                        ((ticket.propertyTitle ?? '').isNotEmpty ||
                            (ticket.propertyFlatNo ?? '').isNotEmpty ||
                            (ticket.tenantName ?? '').isNotEmpty ||
                            (ticket.tenantPhone ?? '').isNotEmpty)) ...<Widget>[
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: AppTheme.primarySoft,
                          borderRadius: BorderRadius.circular(
                            AppTheme.radiusSmall,
                          ),
                        ),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: <Widget>[
                            _SupportTicketAvatar(
                              imageUrl: ticket.tenantImageUrl,
                            ),
                            const SizedBox(width: 14),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: <Widget>[
                                  if ((ticket.propertyTitle ?? '').isNotEmpty)
                                    Text(ticket.propertyTitle!),
                                  if ((ticket.propertyFlatNo ?? '').isNotEmpty)
                                    Text('Unit ${ticket.propertyFlatNo!}'),
                                  if ((ticket.tenantName ?? '').isNotEmpty)
                                    Text(ticket.tenantName!),
                                  if ((ticket.tenantPhone ?? '').isNotEmpty)
                                    ContactTextButton.phone(
                                      value: ticket.tenantPhone!,
                                      label: ticket.tenantPhone!,
                                    ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 12),
                    ],
                    Row(
                      children: <Widget>[
                        Icon(
                          Icons.schedule_rounded,
                          size: 16,
                          color: AppTheme.textMuted,
                        ),
                        const SizedBox(width: 6),
                        Text(
                          '$displayTimestampLabel ${formatCompactDate(displayTimestamp)} at ${formatClock(displayTimestamp)}',
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: AppTheme.textMuted,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 14),
                    if (_isManagementRole)
                      Row(
                        children: <Widget>[
                          Expanded(
                            child: CustomButton(
                              label: 'Details',
                              variant: CustomButtonVariant.outline,
                              onPressed: onDetails,
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: _StatusActionMenu(
                              ticket: ticket,
                              onAction: onAction ?? (_) {},
                            ),
                          ),
                        ],
                      )
                    else
                      SizedBox(
                        width: double.infinity,
                        child: CustomButton(
                          label: 'View Details',
                          variant: CustomButtonVariant.outline,
                          onPressed: onDetails,
                        ),
                      ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
