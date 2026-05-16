import 'dart:typed_data';

import 'package:flutter/services.dart' show ByteData, rootBundle;
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';

import '../models/app_models.dart';

class RentalContractPdfService {
  RentalContractPdfService._();

  static const String _logoAsset = 'assets/urban_easyflats_receipt_logo.jpg';
  static const PdfColor _blue = PdfColor(0.23, 0.51, 0.93);
  static const PdfColor _dark = PdfColor(0.12, 0.16, 0.23);
  static const PdfColor _muted = PdfColor(0.43, 0.46, 0.52);
  static const PdfColor _rowGrey = PdfColor(0.94, 0.95, 0.95);
  static const PdfColor _lineGrey = PdfColor(0.82, 0.85, 0.89);
  static const PdfColor _lightBlue = PdfColor(0.86, 0.92, 1.0);
  static const PdfColor _lightGreen = PdfColor(0.86, 0.98, 0.90);
  static const PdfColor _lightRed = PdfColor(1.0, 0.94, 0.94);
  static const PdfColor _red = PdfColor(0.74, 0.11, 0.11);
  static const PdfColor _green = PdfColor(0.05, 0.45, 0.23);

  static Future<void> shareContractPdf(RentalContractRecord contract) async {
    await Printing.sharePdf(
      bytes: await buildContractPdf(contract),
      filename: contractPdfFilename(contract),
    );
  }

  static String contractPdfFilename(RentalContractRecord contract) {
    return 'rental-agreement-${contract.id}.pdf';
  }

  static Future<Uint8List> buildContractPdf(
    RentalContractRecord contract,
  ) async {
    final pw.Document document = pw.Document();
    final pw.MemoryImage? logo = await _loadLogo();
    final DateTime generatedAt = DateTime.now();

    document.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.fromLTRB(40, 34, 40, 40),
        footer: (pw.Context context) => _footer(context),
        build: (pw.Context context) {
          return <pw.Widget>[
            _header(contract, logo, generatedAt),
            pw.SizedBox(height: 20),
            _section('PROPERTY DETAILS', <_PdfRow>[
              _PdfRow('Property Name', contract.propertyTitle),
              _PdfRow('Flat/Unit No', contract.flatNo),
              _PdfRow('Property ID', contract.propertyId),
            ]),
            pw.SizedBox(height: 18),
            _section('TENANT INFORMATION', <_PdfRow>[
              _PdfRow('Name', contract.tenantName),
              _PdfRow('Phone', contract.tenantPhone),
              _PdfRow('Email', contract.tenantEmail),
            ]),
            pw.SizedBox(height: 18),
            _section('OWNER INFORMATION', <_PdfRow>[
              _PdfRow('Name', contract.ownerName),
              _PdfRow('Phone', contract.ownerPhone),
              _PdfRow('Email', contract.ownerEmail),
              _PdfRow('Address', contract.ownerAddress),
            ]),
            pw.SizedBox(height: 18),
            _section('FINANCIAL DETAILS', <_PdfRow>[
              _PdfRow('Monthly Rent', _money(contract.rent)),
              _PdfRow('Security Deposit', _money(contract.deposit)),
              _PdfRow('Token Amount', _money(contract.tokenAmount)),
              _PdfRow(
                'Maintenance Included',
                contract.whetherMaintenanceIncluded == true ? 'Yes' : 'No',
              ),
              if (contract.maintenanceAmount != null)
                _PdfRow('Maintenance Charge', _money(contract.maintenanceAmount)),
              _PdfRow('Bill Day', contract.billDay?.toString()),
            ]),
            pw.SizedBox(height: 18),
            _section('CONTRACT TERMS', <_PdfRow>[
              _PdfRow('Start Date', _date(contract.startDate)),
              _PdfRow('End Date', _date(contract.endDate)),
              _PdfRow('Days Until Expiry', _daysUntilExpiry(contract)),
              if (contract.vacateDate != null)
                _PdfRow('Vacate Date', _date(contract.vacateDate!)),
            ]),
            pw.SizedBox(height: 18),
            _section('PAYMENT STATUS', <_PdfRow>[
              _PdfRow(
                'First Month Rent',
                contract.whetherFirstMonthRentPaid == true
                    ? 'Paid'
                    : 'Pending',
              ),
              _PdfRow(
                'Security Deposit',
                contract.whetherSecurityDepositPaid == true
                    ? 'Paid'
                    : 'Pending',
              ),
            ]),
            if (_hasText(contract.specialTerms)) ...<pw.Widget>[
              pw.SizedBox(height: 18),
              _section('SPECIAL TERMS', <_PdfRow>[
                _PdfRow('Terms', contract.specialTerms),
              ]),
            ],
            pw.SizedBox(height: 18),
            _kycSection(contract),
          ];
        },
      ),
    );

    return document.save();
  }

  static Future<pw.MemoryImage?> _loadLogo() async {
    try {
      final ByteData data = await rootBundle.load(_logoAsset);
      return pw.MemoryImage(
        data.buffer.asUint8List(data.offsetInBytes, data.lengthInBytes),
      );
    } catch (_) {
      return null;
    }
  }

  static pw.Widget _header(
    RentalContractRecord contract,
    pw.MemoryImage? logo,
    DateTime generatedAt,
  ) {
    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.stretch,
      children: <pw.Widget>[
        if (logo != null)
          pw.Center(
            child: pw.Image(
              logo,
              width: 150,
              height: 58,
              fit: pw.BoxFit.contain,
            ),
          ),
        if (logo != null) pw.SizedBox(height: 10),
        pw.Text(
          'RENTAL AGREEMENT',
          textAlign: pw.TextAlign.center,
          style: pw.TextStyle(
            color: _dark,
            fontSize: 26,
            fontWeight: pw.FontWeight.bold,
            letterSpacing: 1.2,
          ),
        ),
        pw.SizedBox(height: 8),
        pw.Text(
          'UrbanEasyFlats',
          textAlign: pw.TextAlign.center,
          style: const pw.TextStyle(color: _muted, fontSize: 13),
        ),
        pw.SizedBox(height: 8),
        pw.Text(
          'Generated on: ${_dateTime(generatedAt)}',
          textAlign: pw.TextAlign.center,
          style: const pw.TextStyle(color: _muted, fontSize: 11),
        ),
        pw.SizedBox(height: 14),
        pw.Container(height: 2, color: _blue),
        pw.SizedBox(height: 10),
        pw.Table(
          border: pw.TableBorder.all(color: _blue, width: 0.4),
          children: <pw.TableRow>[
            pw.TableRow(
              decoration: const pw.BoxDecoration(color: _blue),
              children: <pw.Widget>[
                _statusCell('Status: ${_statusLabel(contract)}'),
                _statusCell('Created: ${_date(contract.startDate)}'),
              ],
            ),
          ],
        ),
      ],
    );
  }

  static pw.Widget _statusCell(String text) {
    return pw.Padding(
      padding: const pw.EdgeInsets.symmetric(vertical: 10),
      child: pw.Text(
        text,
        textAlign: pw.TextAlign.center,
        style: pw.TextStyle(
          color: PdfColors.white,
          fontSize: 11,
          fontWeight: pw.FontWeight.bold,
        ),
      ),
    );
  }

  static pw.Widget _section(String title, List<_PdfRow> rows) {
    final List<_PdfRow> visibleRows = rows
        .where((_PdfRow row) => _hasText(row.value))
        .toList(growable: false);
    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.stretch,
      children: <pw.Widget>[
        pw.Container(
          color: _blue,
          padding: const pw.EdgeInsets.symmetric(horizontal: 8, vertical: 9),
          child: pw.Text(
            title,
            style: pw.TextStyle(
              color: PdfColors.white,
              fontSize: 13,
              fontWeight: pw.FontWeight.bold,
            ),
          ),
        ),
        pw.Table(
          border: const pw.TableBorder(
            left: pw.BorderSide(color: _lineGrey, width: 0.35),
            right: pw.BorderSide(color: _lineGrey, width: 0.35),
          ),
          columnWidths: const <int, pw.TableColumnWidth>{
            0: pw.FlexColumnWidth(1.5),
            1: pw.FlexColumnWidth(2.4),
          },
          children: visibleRows.asMap().entries.map((entry) {
            final int index = entry.key;
            final _PdfRow row = entry.value;
            return pw.TableRow(
              decoration: pw.BoxDecoration(
                color: index.isEven ? _rowGrey : PdfColors.white,
              ),
              children: <pw.Widget>[
                _tableCell(row.label, bold: true),
                _tableCell(_value(row.value)),
              ],
            );
          }).toList(),
        ),
      ],
    );
  }

  static pw.Widget _kycSection(RentalContractRecord contract) {
    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.stretch,
      children: <pw.Widget>[
        pw.Container(
          color: _blue,
          padding: const pw.EdgeInsets.symmetric(horizontal: 8, vertical: 9),
          child: pw.Text(
            'KYC DOCUMENTS',
            style: pw.TextStyle(
              color: PdfColors.white,
              fontSize: 13,
              fontWeight: pw.FontWeight.bold,
            ),
          ),
        ),
        _documentGroupHeader('Tenant Documents', _lightBlue, _dark),
        _documentRow('Tenant ID Proof', contract.tenantIdProof),
        _documentRow('Tenant Address Proof', contract.tenantAddressProof),
        _documentGroupHeader('Owner Documents', _lightGreen, _green),
        _documentRow('Owner ID Proof', contract.ownerIdProof),
        _documentRow(
          'Owner Property Ownership Proof',
          contract.ownerPropertyOwnershipProof,
        ),
        _documentRow('Owner Bank Proof', contract.ownerBankProof),
      ],
    );
  }

  static pw.Widget _documentGroupHeader(
    String label,
    PdfColor color,
    PdfColor textColor,
  ) {
    return pw.Container(
      color: color,
      padding: const pw.EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      child: pw.Text(
        label,
        style: pw.TextStyle(
          color: textColor,
          fontSize: 11,
          fontWeight: pw.FontWeight.bold,
        ),
      ),
    );
  }

  static pw.Widget _documentRow(String label, ContractDocumentRecord? doc) {
    final bool uploaded = _isDocumentUploaded(doc);
    return pw.Container(
      margin: const pw.EdgeInsets.only(top: 8),
      decoration: pw.BoxDecoration(
        color: uploaded ? PdfColors.white : _lightRed,
        border: pw.Border.all(
          color: uploaded ? _lineGrey : PdfColors.red100,
          width: 0.8,
        ),
      ),
      padding: const pw.EdgeInsets.symmetric(horizontal: 12, vertical: 11),
      child: pw.Row(
        children: <pw.Widget>[
          pw.Expanded(
            child: pw.Text(
              label,
              style: pw.TextStyle(
                color: _dark,
                fontSize: 10.5,
                fontWeight: pw.FontWeight.bold,
              ),
            ),
          ),
          pw.Text(
            uploaded ? _docLabel(doc) : 'Not Uploaded',
            style: pw.TextStyle(
              color: uploaded ? _green : _red,
              fontSize: 10.5,
            ),
          ),
        ],
      ),
    );
  }

  static pw.Widget _tableCell(String text, {bool bold = false}) {
    return pw.Padding(
      padding: const pw.EdgeInsets.symmetric(horizontal: 8, vertical: 8),
      child: pw.Text(
        text,
        style: pw.TextStyle(
          color: _dark,
          fontSize: 10.5,
          fontWeight: bold ? pw.FontWeight.bold : pw.FontWeight.normal,
        ),
      ),
    );
  }

  static pw.Widget _footer(pw.Context context) {
    return pw.Container(
      padding: const pw.EdgeInsets.only(top: 10),
      decoration: const pw.BoxDecoration(
        border: pw.Border(top: pw.BorderSide(color: _lineGrey, width: 0.5)),
      ),
      child: pw.Row(
        children: <pw.Widget>[
          pw.Text(
            'UrbanEasyFlats | Rental Agreement',
            style: const pw.TextStyle(color: _muted, fontSize: 9),
          ),
          pw.Spacer(),
          pw.Text(
            'Page ${context.pageNumber} of ${context.pagesCount}',
            style: const pw.TextStyle(color: _muted, fontSize: 9),
          ),
        ],
      ),
    );
  }

  static String _statusLabel(RentalContractRecord contract) {
    if (!contract.isActive) {
      return 'Inactive';
    }
    return contract.status.label;
  }

  static String _daysUntilExpiry(RentalContractRecord contract) {
    final DateTime today = _dateOnly(DateTime.now());
    final DateTime endDate = _dateOnly(contract.endDate);
    final int days = endDate.difference(today).inDays;
    if (days < 0) {
      return 'Expired';
    }
    return '$days days';
  }

  static DateTime _dateOnly(DateTime date) {
    return DateTime(date.year, date.month, date.day);
  }

  static bool _isDocumentUploaded(ContractDocumentRecord? document) {
    if (document == null) {
      return false;
    }
    return _hasText(document.documentId) || _hasText(document.documentUrl);
  }

  static String _docLabel(ContractDocumentRecord? document) {
    if (!_isDocumentUploaded(document)) {
      return 'Not Uploaded';
    }
    if (_hasText(document!.documentName)) {
      return 'Uploaded';
    }
    return 'Uploaded';
  }

  static String _money(double? value) {
    if (value == null) {
      return 'N/A';
    }
    return 'Rs. ${value.toStringAsFixed(0)}';
  }

  static String _date(DateTime value) {
    final List<String> months = <String>[
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
    return '${value.day} ${months[value.month - 1]} ${value.year}';
  }

  static String _dateTime(DateTime value) {
    final int hour = value.hour;
    final int minute = value.minute;
    final String period = hour >= 12 ? 'PM' : 'AM';
    final int hour12 = hour % 12 == 0 ? 12 : hour % 12;
    return '${_date(value)}, $hour12:${minute.toString().padLeft(2, '0')} $period IST';
  }

  static String _value(String? value) {
    if (!_hasText(value)) {
      return 'N/A';
    }
    return value!.trim();
  }

  static bool _hasText(String? value) {
    return value != null && value.trim().isNotEmpty;
  }
}

class _PdfRow {
  const _PdfRow(this.label, this.value);

  final String label;
  final String? value;
}
