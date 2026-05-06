import 'package:flutter/services.dart' show ByteData, rootBundle;
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';

import '../models/app_models.dart';

class RentalBillPdfService {
  RentalBillPdfService._();

  static const String _receiptLogoAsset =
      'assets/urban_easyflats_receipt_logo.jpg';

  static Future<void> shareBillPdf(BillRecord bill) async {
    final pw.Document document = pw.Document();
    final pw.MemoryImage? receiptLogo = await _loadReceiptLogo();
    final bool isSocietyBill =
        _hasValue(bill.societyName) ||
        _hasValue(bill.blockName) ||
        _hasValue(bill.buildingName);
    final String documentTitle = isSocietyBill
        ? 'Society Resident Bill'
        : 'Rental Bill';
    final String generatedAt = _reportDateTime(DateTime.now());
    final double finalAmount = bill.finalAmount ?? bill.amount;
    final List<_PdfRow> residentRows = _nonEmptyRows(<_PdfRow>[
      _PdfRow('Name', bill.residentName),
      _PdfRow('Phone', bill.residentPhone),
      _PdfRow('Email', bill.residentEmail),
      _PdfRow('Resident Type', bill.residentTypeLabel),
      _PdfRow('Flat / Unit', bill.unitLabel),
      _PdfRow('Society', bill.societyName),
      _PdfRow('Block', bill.blockName),
      _PdfRow('Building', bill.buildingName),
    ]);
    final List<_PdfRow> propertyRows = _nonEmptyRows(<_PdfRow>[
      _PdfRow('Property', bill.propertyTitle),
      _PdfRow('Owner', bill.ownerName),
      _PdfRow('Owner Phone', bill.ownerPhone),
      _PdfRow('Owner Email', bill.ownerEmail),
      _PdfRow('Contract Start', _dateText(bill.contractStartDate)),
      _PdfRow('Contract End', _dateText(bill.contractEndDate)),
      _PdfRow('Vacate Date', _dateText(bill.vacateDate)),
    ]);
    final List<_PdfRow> paymentRows = _nonEmptyRows(<_PdfRow>[
      _PdfRow('Payment Type', _paymentTypeLabel(bill.paymentType)),
      _PdfRow(
        'Manual Online Mode',
        _manualOnlinePaymentModeLabel(bill.manualOnlinePaymentMode),
      ),
      _PdfRow('Payment Note', bill.paymentNote),
      _PdfRow(
        'Wallet Credit',
        bill.walletCredited == null
            ? null
            : (bill.walletCredited! ? 'Credited' : 'Pending'),
      ),
      _PdfRow('Credit Initiated', _dateTimeText(bill.walletCreditTime)),
      _PdfRow('Credited At', _dateTimeText(bill.walletCreditedTime)),
      _PdfRow('Payment Proof', bill.paymentImageUrl),
    ]);

    document.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(28),
        build: (pw.Context context) {
          return <pw.Widget>[
            pw.Container(
              padding: const pw.EdgeInsets.all(16),
              decoration: pw.BoxDecoration(
                color: PdfColors.blue50,
                borderRadius: pw.BorderRadius.circular(8),
                border: pw.Border.all(color: PdfColors.blue200),
              ),
              child: pw.Row(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: <pw.Widget>[
                  pw.Expanded(
                    child: pw.Column(
                      crossAxisAlignment: pw.CrossAxisAlignment.start,
                      children: <pw.Widget>[
                        _brandLogo(receiptLogo, width: 178, height: 58),
                        pw.SizedBox(height: 10),
                        pw.Text(
                          documentTitle,
                          style: pw.TextStyle(
                            fontSize: 22,
                            fontWeight: pw.FontWeight.bold,
                          ),
                        ),
                        pw.SizedBox(height: 4),
                        pw.Text('Generated on $generatedAt'),
                      ],
                    ),
                  ),
                  pw.Container(
                    padding: const pw.EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 8,
                    ),
                    decoration: pw.BoxDecoration(
                      color: _statusBackground(bill.status),
                      borderRadius: pw.BorderRadius.circular(999),
                    ),
                    child: pw.Text(
                      bill.status.label,
                      style: pw.TextStyle(
                        color: _statusColor(bill.status),
                        fontWeight: pw.FontWeight.bold,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            pw.SizedBox(height: 18),
            pw.Row(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: <pw.Widget>[
                pw.Expanded(
                  child: _infoCard('Bill Information', <_PdfRow>[
                    _PdfRow('Bill ID', bill.id),
                    _PdfRow('Bill Title', bill.title),
                    _PdfRow('Bill Type', bill.category),
                    _PdfRow('Bill Date', _dateText(bill.billDate)),
                    _PdfRow('Due Date', _dateText(bill.dueDate)),
                    _PdfRow('Paid Date', _dateText(bill.paidDate)),
                  ]),
                ),
                pw.SizedBox(width: 12),
                pw.Expanded(child: _totalCard(finalAmount)),
              ],
            ),
            if (residentRows.isNotEmpty) ...<pw.Widget>[
              pw.SizedBox(height: 16),
              _infoCard('Resident / Society Details', residentRows),
            ],
            if (propertyRows.isNotEmpty) ...<pw.Widget>[
              pw.SizedBox(height: 16),
              _infoCard('Property / Owner Details', propertyRows),
            ],
            pw.SizedBox(height: 16),
            _chargesTable(bill),
            if (paymentRows.isNotEmpty) ...<pw.Widget>[
              pw.SizedBox(height: 16),
              _infoCard('Payment Details', paymentRows),
            ],
            if ((bill.note ?? '').trim().isNotEmpty) ...<pw.Widget>[
              pw.SizedBox(height: 16),
              _noteCard('Bill Notes', bill.note!.trim()),
            ],
            pw.SizedBox(height: 24),
            pw.Divider(color: PdfColors.grey300),
            pw.Text(
              'This PDF is generated dynamically from the latest bill data available in the mobile app.',
              style: const pw.TextStyle(fontSize: 9, color: PdfColors.grey700),
            ),
          ];
        },
      ),
    );

    await Printing.sharePdf(
      bytes: await document.save(),
      filename:
          '${_fileSafe(documentTitle)}-${_fileSafe(bill.unitLabel)}-${_fileDate(DateTime.now())}.pdf',
    );
  }

  /// Generate and share a tabular PDF report for a list of bills.
  static Future<void> shareBillsReportPdf(List<BillRecord> bills) async {
    final pw.Document document = pw.Document();
    final pw.MemoryImage? receiptLogo = await _loadReceiptLogo();
    final String generatedAt = _reportDateTime(DateTime.now());
    final String filenameDate = _fileDate(DateTime.now());
    final bool isSocietyReport = _isSocietyBillSet(bills);
    final String reportTitle = isSocietyReport
        ? 'Society Bills Report'
        : 'Rental Bills Report';
    final double collectedAmount = _sumByStatus(bills, BillStatus.paid);
    final double pendingAmount = _sumByStatus(bills, BillStatus.pending);
    final double overdueAmount = _sumByStatus(bills, BillStatus.overdue);

    if (isSocietyReport) {
      document.addPage(
        _societyBillsReportPage(bills, generatedAt, receiptLogo),
      );
      await Printing.sharePdf(
        bytes: await document.save(),
        filename: '${_fileSafe(reportTitle)}_$filenameDate.pdf',
      );
      return;
    }

    document.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4.landscape,
        margin: const pw.EdgeInsets.all(20),
        header: (pw.Context ctx) => pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: <pw.Widget>[
            _reportHeader(
              logo: receiptLogo,
              title: reportTitle,
              generatedAt: generatedAt,
              summaryLines: <String>[
                'Total Bills: ${bills.length}',
                'Total Collected: ${_reportCurrency(collectedAmount)}',
                'Pending: ${_reportCurrency(pendingAmount)}',
                'Overdue: ${_reportCurrency(overdueAmount)}',
              ],
            ),
            pw.SizedBox(height: 10),
          ],
        ),
        footer: (pw.Context ctx) => pw.Align(
          alignment: pw.Alignment.center,
          child: pw.Text(
            'Page ${ctx.pageNumber} of ${ctx.pagesCount}',
            style: const pw.TextStyle(fontSize: 9),
          ),
        ),
        build: (pw.Context ctx) {
          return <pw.Widget>[
            pw.Table(
              border: pw.TableBorder.all(color: PdfColors.grey400, width: 0.5),
              columnWidths: const <int, pw.TableColumnWidth>{
                0: pw.FixedColumnWidth(22),
                1: pw.FixedColumnWidth(62),
                2: pw.FixedColumnWidth(62),
                3: pw.FlexColumnWidth(2.4),
                4: pw.FixedColumnWidth(50),
                5: pw.FixedColumnWidth(60),
                6: pw.FixedColumnWidth(68),
                7: pw.FixedColumnWidth(60),
                8: pw.FixedColumnWidth(38),
                9: pw.FixedColumnWidth(38),
                10: pw.FixedColumnWidth(38),
                11: pw.FixedColumnWidth(50),
                12: pw.FixedColumnWidth(62),
              },
              children: <pw.TableRow>[
                pw.TableRow(
                  decoration: const pw.BoxDecoration(color: PdfColors.grey200),
                  children: <pw.Widget>[
                    _reportCell('#', bold: true),
                    _reportCell('Bill Date', bold: true),
                    _reportCell('Due Date', bold: true),
                    _reportCell('Property', bold: true),
                    _reportCell('Unit', bold: true),
                    _reportCell('Tenant', bold: true),
                    _reportCell('Phone', bold: true),
                    _reportCell('Owner', bold: true),
                    _reportCell('Rent', bold: true),
                    _reportCell('Maint.', bold: true),
                    _reportCell('Total', bold: true),
                    _reportCell('Status', bold: true),
                    _reportCell('Paid Date', bold: true),
                  ],
                ),
                ...bills.asMap().entries.map((MapEntry<int, BillRecord> entry) {
                  final BillRecord bill = entry.value;
                  return pw.TableRow(
                    children: <pw.Widget>[
                      _reportCell('${entry.key + 1}'),
                      _reportCell(_reportDate(bill.billDate)),
                      _reportCell(_reportDate(bill.dueDate)),
                      _reportCell(
                        _val(bill.propertyTitle, _val(bill.societyName, '-')),
                      ),
                      _reportCell(bill.unitLabel),
                      _reportCell(_val(bill.residentName, '-')),
                      _reportCell(_val(bill.residentPhone, '-')),
                      _reportCell(_val(bill.ownerName, '-')),
                      _reportCell(
                        _reportAmount(bill.billAmount ?? bill.amount),
                      ),
                      _reportCell(_reportAmount(bill.maintenanceAmount ?? 0)),
                      _reportCell(
                        _reportAmount(bill.finalAmount ?? bill.amount),
                      ),
                      _reportCell(bill.status.label),
                      _reportCell(_reportDate(bill.paidDate)),
                    ],
                  );
                }),
              ],
            ),
          ];
        },
      ),
    );

    await Printing.sharePdf(
      bytes: await document.save(),
      filename: '${_fileSafe(reportTitle)}_$filenameDate.pdf',
    );
  }

  static pw.Page _societyBillsReportPage(
    List<BillRecord> bills,
    String generatedAt,
    pw.MemoryImage? receiptLogo,
  ) {
    final int maintenanceCount = bills
        .where(
          (BillRecord bill) =>
              bill.billTypeCode == 1 ||
              bill.category.toLowerCase().contains('maintenance'),
        )
        .length;
    final int rentalCount = bills
        .where(
          (BillRecord bill) =>
              bill.billTypeCode == 2 ||
              bill.category.toLowerCase().contains('rental'),
        )
        .length;
    final int pendingCount = bills
        .where((BillRecord bill) => bill.status == BillStatus.pending)
        .length;
    final int overdueCount = bills
        .where((BillRecord bill) => bill.status == BillStatus.overdue)
        .length;

    return pw.MultiPage(
      pageFormat: PdfPageFormat.a4.landscape,
      margin: const pw.EdgeInsets.fromLTRB(20, 24, 20, 30),
      header: (pw.Context ctx) => pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.stretch,
        children: <pw.Widget>[
          _reportHeader(
            logo: receiptLogo,
            title: 'Society Bills Report',
            generatedAt: generatedAt,
            summaryLines: <String>[
              'Total Bills: ${bills.length}',
              'Maintenance: $maintenanceCount',
              'Rental: $rentalCount',
              'Pending: $pendingCount',
              'Overdue: $overdueCount',
            ],
          ),
          pw.SizedBox(height: 20),
        ],
      ),
      footer: (pw.Context ctx) => pw.Align(
        alignment: pw.Alignment.center,
        child: pw.Text(
          'Page ${ctx.pageNumber} of ${ctx.pagesCount}',
          style: const pw.TextStyle(fontSize: 9, color: PdfColors.blueGrey300),
        ),
      ),
      build: (pw.Context ctx) {
        return <pw.Widget>[
          pw.Table(
            columnWidths: const <int, pw.TableColumnWidth>{
              0: pw.FixedColumnWidth(22),
              1: pw.FixedColumnWidth(54),
              2: pw.FixedColumnWidth(54),
              3: pw.FixedColumnWidth(76),
              4: pw.FixedColumnWidth(68),
              5: pw.FixedColumnWidth(62),
              6: pw.FixedColumnWidth(42),
              7: pw.FixedColumnWidth(72),
              8: pw.FixedColumnWidth(70),
              9: pw.FixedColumnWidth(54),
              10: pw.FixedColumnWidth(46),
              11: pw.FixedColumnWidth(54),
              12: pw.FixedColumnWidth(48),
              13: pw.FixedColumnWidth(58),
            },
            children: <pw.TableRow>[
              pw.TableRow(
                decoration: const pw.BoxDecoration(color: PdfColors.blue600),
                children: <pw.Widget>[
                  _societyReportCell('#', header: true, center: true),
                  _societyReportCell('Bill Date', header: true),
                  _societyReportCell('Due Date', header: true),
                  _societyReportCell('Society', header: true),
                  _societyReportCell('Block', header: true),
                  _societyReportCell('Building', header: true),
                  _societyReportCell('Flat', header: true),
                  _societyReportCell('Resident', header: true),
                  _societyReportCell('Phone', header: true),
                  _societyReportCell('Amount', header: true, numeric: true),
                  _societyReportCell('Maint.', header: true, numeric: true),
                  _societyReportCell('Total', header: true, numeric: true),
                  _societyReportCell('Status', header: true),
                  _societyReportCell('Paid Date', header: true),
                ],
              ),
              ...bills.asMap().entries.map((MapEntry<int, BillRecord> entry) {
                final BillRecord bill = entry.value;
                return pw.TableRow(
                  decoration: pw.BoxDecoration(
                    color: entry.key.isEven
                        ? PdfColors.blueGrey50
                        : PdfColors.white,
                  ),
                  children: <pw.Widget>[
                    _societyReportCell('${entry.key + 1}', center: true),
                    _societyReportCell(_reportDate(bill.billDate)),
                    _societyReportCell(_reportDate(bill.dueDate)),
                    _societyReportCell(_val(bill.societyName)),
                    _societyReportCell(_val(bill.blockName)),
                    _societyReportCell(_val(bill.buildingName)),
                    _societyReportCell(bill.unitLabel),
                    _societyReportCell(_val(bill.residentName)),
                    _societyReportCell(_val(bill.residentPhone)),
                    _societyReportCell(
                      _reportAmount(bill.billAmount ?? bill.amount),
                      numeric: true,
                    ),
                    _societyReportCell(
                      _reportAmount(bill.maintenanceAmount ?? 0),
                      numeric: true,
                    ),
                    _societyReportCell(
                      _reportAmount(bill.finalAmount ?? bill.amount),
                      numeric: true,
                    ),
                    _societyReportCell(bill.status.label),
                    _societyReportCell(_reportDateOrNA(bill.paidDate)),
                  ],
                );
              }),
            ],
          ),
        ];
      },
    );
  }

  static pw.Widget _societyReportCell(
    String text, {
    bool header = false,
    bool numeric = false,
    bool center = false,
  }) {
    final pw.Alignment alignment = center
        ? pw.Alignment.center
        : numeric
        ? pw.Alignment.centerRight
        : pw.Alignment.centerLeft;

    return pw.Container(
      alignment: alignment,
      padding: const pw.EdgeInsets.symmetric(horizontal: 6, vertical: 7),
      child: pw.Text(
        text,
        style: pw.TextStyle(
          fontSize: 7.8,
          color: header ? PdfColors.white : PdfColors.blueGrey900,
          fontWeight: header ? pw.FontWeight.bold : pw.FontWeight.normal,
        ),
      ),
    );
  }

  static Future<pw.MemoryImage?> _loadReceiptLogo() async {
    try {
      final ByteData data = await rootBundle.load(_receiptLogoAsset);
      return pw.MemoryImage(
        data.buffer.asUint8List(data.offsetInBytes, data.lengthInBytes),
      );
    } catch (_) {
      return null;
    }
  }

  static pw.Widget _brandLogo(
    pw.MemoryImage? logo, {
    double width = 150,
    double height = 48,
  }) {
    if (logo == null) {
      return pw.Text(
        'URBAN EASYFLATS',
        style: pw.TextStyle(
          color: PdfColors.blue800,
          fontSize: 18,
          fontWeight: pw.FontWeight.bold,
        ),
      );
    }

    return pw.Image(
      logo,
      width: width,
      height: height,
      fit: pw.BoxFit.contain,
      alignment: pw.Alignment.centerLeft,
    );
  }

  static pw.Widget _reportHeader({
    required pw.MemoryImage? logo,
    required String title,
    required String generatedAt,
    required List<String> summaryLines,
  }) {
    return pw.Container(
      padding: const pw.EdgeInsets.only(bottom: 10),
      decoration: const pw.BoxDecoration(
        border: pw.Border(
          bottom: pw.BorderSide(color: PdfColors.blueGrey100, width: 0.8),
        ),
      ),
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.stretch,
        children: <pw.Widget>[
          pw.Row(
            crossAxisAlignment: pw.CrossAxisAlignment.center,
            children: <pw.Widget>[
              _brandLogo(logo, width: 150, height: 48),
              pw.Spacer(),
              pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.end,
                children: <pw.Widget>[
                  pw.Text(
                    title,
                    style: pw.TextStyle(
                      fontSize: 20,
                      color: PdfColors.blueGrey900,
                      fontWeight: pw.FontWeight.bold,
                    ),
                  ),
                  pw.SizedBox(height: 4),
                  pw.Text(
                    'Generated on: $generatedAt',
                    style: const pw.TextStyle(
                      fontSize: 10,
                      color: PdfColors.blueGrey500,
                    ),
                  ),
                ],
              ),
            ],
          ),
          pw.SizedBox(height: 10),
          pw.Wrap(
            spacing: 8,
            runSpacing: 6,
            children: summaryLines.map(_summaryChip).toList(),
          ),
        ],
      ),
    );
  }

  static pw.Widget _summaryChip(String text) {
    return pw.Container(
      padding: const pw.EdgeInsets.symmetric(horizontal: 8, vertical: 5),
      decoration: pw.BoxDecoration(
        color: PdfColors.blueGrey50,
        borderRadius: pw.BorderRadius.circular(4),
        border: pw.Border.all(color: PdfColors.blueGrey100, width: 0.6),
      ),
      child: pw.Text(
        text,
        style: const pw.TextStyle(fontSize: 9.5, color: PdfColors.blueGrey800),
      ),
    );
  }

  static pw.Widget _reportCell(String text, {bool bold = false}) {
    return pw.Padding(
      padding: const pw.EdgeInsets.all(4),
      child: pw.Text(
        text,
        style: pw.TextStyle(
          fontSize: 7.5,
          fontWeight: bold ? pw.FontWeight.bold : pw.FontWeight.normal,
        ),
      ),
    );
  }

  static pw.Widget _infoCard(String title, List<_PdfRow> rows) {
    return pw.Container(
      width: double.infinity,
      padding: const pw.EdgeInsets.all(12),
      decoration: pw.BoxDecoration(
        border: pw.Border.all(color: PdfColors.grey300, width: 0.8),
        borderRadius: pw.BorderRadius.circular(8),
      ),
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: <pw.Widget>[
          pw.Text(
            title,
            style: pw.TextStyle(fontSize: 13, fontWeight: pw.FontWeight.bold),
          ),
          pw.SizedBox(height: 8),
          ...rows.map(_pdfInfoRow),
        ],
      ),
    );
  }

  static pw.Widget _totalCard(double amount) {
    return pw.Container(
      width: double.infinity,
      padding: const pw.EdgeInsets.all(14),
      decoration: pw.BoxDecoration(
        color: PdfColors.green50,
        border: pw.Border.all(color: PdfColors.green200, width: 0.8),
        borderRadius: pw.BorderRadius.circular(8),
      ),
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: <pw.Widget>[
          pw.Text(
            'Total Payable',
            style: const pw.TextStyle(fontSize: 11, color: PdfColors.grey700),
          ),
          pw.SizedBox(height: 8),
          pw.Text(
            _currency(amount),
            style: pw.TextStyle(
              fontSize: 24,
              fontWeight: pw.FontWeight.bold,
              color: PdfColors.green800,
            ),
          ),
        ],
      ),
    );
  }

  static pw.Widget _chargesTable(BillRecord bill) {
    final List<_PdfRow> rows = <_PdfRow>[
      _PdfRow('Bill Amount', _currency(bill.billAmount ?? bill.amount)),
      if (bill.maintenanceAmount != null)
        _PdfRow('Maintenance Amount', _currency(bill.maintenanceAmount!)),
      if (bill.rentAmount != null)
        _PdfRow('Rent Amount', _currency(bill.rentAmount!)),
      if (bill.depositAmount != null)
        _PdfRow('Security Deposit', _currency(bill.depositAmount!)),
      if (bill.tokenAmount != null)
        _PdfRow('Token Amount', _currency(bill.tokenAmount!)),
      _PdfRow('Final Amount', _currency(bill.finalAmount ?? bill.amount)),
    ];

    return pw.Container(
      width: double.infinity,
      decoration: pw.BoxDecoration(
        border: pw.Border.all(color: PdfColors.grey300, width: 0.8),
        borderRadius: pw.BorderRadius.circular(8),
      ),
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: <pw.Widget>[
          pw.Padding(
            padding: const pw.EdgeInsets.all(12),
            child: pw.Text(
              'Bill Amount Breakup',
              style: pw.TextStyle(fontSize: 13, fontWeight: pw.FontWeight.bold),
            ),
          ),
          pw.Table(
            border: const pw.TableBorder(
              top: pw.BorderSide(color: PdfColors.grey300, width: 0.8),
              horizontalInside: pw.BorderSide(
                color: PdfColors.grey200,
                width: 0.6,
              ),
            ),
            columnWidths: const <int, pw.TableColumnWidth>{
              0: pw.FlexColumnWidth(2),
              1: pw.FlexColumnWidth(1),
            },
            children: rows
                .map(
                  (_PdfRow row) => pw.TableRow(
                    decoration: row.label == 'Final Amount'
                        ? const pw.BoxDecoration(color: PdfColors.grey100)
                        : null,
                    children: <pw.Widget>[
                      _chargeCell(row.label, bold: row.label == 'Final Amount'),
                      _chargeCell(
                        row.value ?? '-',
                        alignRight: true,
                        bold: row.label == 'Final Amount',
                      ),
                    ],
                  ),
                )
                .toList(),
          ),
        ],
      ),
    );
  }

  static pw.Widget _noteCard(String title, String note) {
    return pw.Container(
      width: double.infinity,
      padding: const pw.EdgeInsets.all(12),
      decoration: pw.BoxDecoration(
        color: PdfColors.grey100,
        borderRadius: pw.BorderRadius.circular(8),
      ),
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: <pw.Widget>[
          pw.Text(
            title,
            style: pw.TextStyle(fontSize: 13, fontWeight: pw.FontWeight.bold),
          ),
          pw.SizedBox(height: 6),
          pw.Text(note),
        ],
      ),
    );
  }

  static pw.Widget _pdfInfoRow(_PdfRow row) {
    return pw.Padding(
      padding: const pw.EdgeInsets.only(bottom: 5),
      child: pw.Row(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: <pw.Widget>[
          pw.SizedBox(
            width: 110,
            child: pw.Text(
              row.label,
              style: pw.TextStyle(fontWeight: pw.FontWeight.bold),
            ),
          ),
          pw.SizedBox(width: 8),
          pw.Expanded(child: pw.Text(row.value ?? '-')),
        ],
      ),
    );
  }

  static pw.Widget _chargeCell(
    String text, {
    bool alignRight = false,
    bool bold = false,
  }) {
    return pw.Padding(
      padding: const pw.EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      child: pw.Align(
        alignment: alignRight
            ? pw.Alignment.centerRight
            : pw.Alignment.centerLeft,
        child: pw.Text(
          text,
          style: pw.TextStyle(
            fontWeight: bold ? pw.FontWeight.bold : pw.FontWeight.normal,
          ),
        ),
      ),
    );
  }

  static pw.Widget _section(String title, List<List<String>> rows) {
    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: <pw.Widget>[
        pw.Text(
          title,
          style: pw.TextStyle(fontSize: 14, fontWeight: pw.FontWeight.bold),
        ),
        pw.SizedBox(height: 6),
        ...rows.map(
          (List<String> row) => pw.Padding(
            padding: const pw.EdgeInsets.only(bottom: 4),
            child: pw.Row(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: <pw.Widget>[
                pw.SizedBox(
                  width: 140,
                  child: pw.Text(
                    row[0],
                    style: pw.TextStyle(fontWeight: pw.FontWeight.bold),
                  ),
                ),
                pw.Expanded(child: pw.Text(row[1])),
              ],
            ),
          ),
        ),
        pw.SizedBox(height: 16),
      ],
    );
  }

  /// Return value or fallback when null or blank.
  static String _val(String? value, [String fallback = 'N/A']) =>
      (value != null && value.trim().isNotEmpty) ? value : fallback;

  static bool _hasValue(String? value) => (value ?? '').trim().isNotEmpty;

  static bool _isSocietyBillSet(List<BillRecord> bills) {
    return bills.any(
      (BillRecord bill) =>
          _hasValue(bill.societyName) ||
          _hasValue(bill.blockName) ||
          _hasValue(bill.buildingName),
    );
  }

  static List<_PdfRow> _nonEmptyRows(List<_PdfRow> rows) {
    return rows.where((_PdfRow row) => _hasValue(row.value)).toList();
  }

  static String _currency(double value) {
    return 'Rs ${value.toStringAsFixed(0)}';
  }

  static String? _dateText(DateTime? value) {
    if (value == null) {
      return null;
    }
    return _reportDate(value);
  }

  static String? _dateTimeText(DateTime? value) {
    if (value == null) {
      return null;
    }
    return _reportDateTime(value);
  }

  static String? _paymentTypeLabel(int? value) {
    return switch (value) {
      1 => 'Cash',
      2 => 'Online',
      3 => 'Manual Online',
      null => null,
      _ => 'Other',
    };
  }

  static String? _manualOnlinePaymentModeLabel(int? value) {
    return switch (value) {
      1 => 'UPI',
      2 => 'NetBanking',
      3 => 'Card',
      4 => 'Wallet',
      5 => 'NEFT',
      6 => 'IMPS',
      7 => 'RTGS',
      8 => 'Cash Deposit',
      9 => 'Bank Transfer',
      10 => 'Other',
      null => null,
      _ => 'Other',
    };
  }

  static PdfColor _statusColor(BillStatus status) {
    return switch (status) {
      BillStatus.paid => PdfColors.green800,
      BillStatus.pending => PdfColors.orange800,
      BillStatus.overdue => PdfColors.red800,
      BillStatus.partial => PdfColors.blue800,
    };
  }

  static PdfColor _statusBackground(BillStatus status) {
    return switch (status) {
      BillStatus.paid => PdfColors.green100,
      BillStatus.pending => PdfColors.orange100,
      BillStatus.overdue => PdfColors.red100,
      BillStatus.partial => PdfColors.blue100,
    };
  }

  static String _fileSafe(String value) {
    final String cleaned = value
        .trim()
        .replaceAll(RegExp(r'[^A-Za-z0-9_-]+'), '_')
        .replaceAll(RegExp(r'_+'), '_');
    return cleaned.isEmpty ? 'bill' : cleaned;
  }

  static String _date(DateTime value) {
    final String month = value.month.toString().padLeft(2, '0');
    final String day = value.day.toString().padLeft(2, '0');
    return '${value.year}-$month-$day';
  }

  static double _sumByStatus(List<BillRecord> bills, BillStatus status) {
    return bills
        .where((BillRecord bill) => bill.status == status)
        .fold<double>(
          0,
          (double total, BillRecord bill) =>
              total + (bill.finalAmount ?? bill.amount),
        );
  }

  static String _reportAmount(double value) {
    final bool isNegative = value < 0;
    final String digits = value.abs().round().toString();
    if (digits.length <= 3) {
      return isNegative ? '-$digits' : digits;
    }

    final String lastThree = digits.substring(digits.length - 3);
    String remaining = digits.substring(0, digits.length - 3);
    final List<String> groups = <String>[];
    while (remaining.length > 2) {
      groups.insert(0, remaining.substring(remaining.length - 2));
      remaining = remaining.substring(0, remaining.length - 2);
    }
    if (remaining.isNotEmpty) {
      groups.insert(0, remaining);
    }

    final String formatted = '${groups.join(',')},$lastThree';
    return isNegative ? '-$formatted' : formatted;
  }

  static String _reportCurrency(double value) {
    return 'Rs. ${_reportAmount(value)}';
  }

  static String _reportDate(DateTime? value) {
    if (value == null) {
      return '-';
    }
    final DateTime date = _asIst(value);
    return '${date.day} ${_monthNames[date.month - 1]} ${date.year}';
  }

  static String _reportDateOrNA(DateTime? value) {
    if (value == null) {
      return 'N/A';
    }
    return _reportDate(value);
  }

  static String _reportDateTime(DateTime value) {
    final DateTime date = _utcToIst(value);
    final int hour12 = date.hour % 12 == 0 ? 12 : date.hour % 12;
    final String minute = date.minute.toString().padLeft(2, '0');
    final String period = date.hour >= 12 ? 'PM' : 'AM';
    return '${_reportDate(date)}, $hour12:$minute $period IST';
  }

  static String _fileDate(DateTime value) {
    final DateTime date = _utcToIst(value);
    final String month = date.month.toString().padLeft(2, '0');
    final String day = date.day.toString().padLeft(2, '0');
    return '${date.year}-$month-$day';
  }

  static DateTime _asIst(DateTime value) {
    if (value.isUtc) {
      return _utcToIst(value);
    }
    return value;
  }

  static DateTime _utcToIst(DateTime value) {
    final DateTime shifted = value.toUtc().add(_istOffset);
    return DateTime(
      shifted.year,
      shifted.month,
      shifted.day,
      shifted.hour,
      shifted.minute,
      shifted.second,
      shifted.millisecond,
      shifted.microsecond,
    );
  }

  static const Duration _istOffset = Duration(hours: 5, minutes: 30);

  static const List<String> _monthNames = <String>[
    'Jan',
    'Feb',
    'Mar',
    'Apr',
    'May',
    'Jun',
    'Jul',
    'Aug',
    'Sep',
    'Oct',
    'Nov',
    'Dec',
  ];
}

class _PdfRow {
  const _PdfRow(this.label, this.value);

  final String label;
  final String? value;
}
