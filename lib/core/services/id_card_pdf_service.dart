import 'dart:typed_data';

import 'package:flutter/services.dart';
import 'package:image/image.dart' as img;
import 'package:intl/intl.dart';
import 'package:library_registration_app/core/services/id_card_service.dart';
import 'package:library_registration_app/domain/entities/student.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

class IdCardPdfService {
  // ID-1 format (credit card size)
  static const double _id1WidthMm = 85.60;
  static const double _id1HeightMm = 53.98;

  static double get _cardWidthPt => _id1WidthMm * PdfPageFormat.mm;
  static double get _cardHeightPt => _id1HeightMm * PdfPageFormat.mm;

  /// Generates a print-friendly PDF sheet with the ID card FRONT + BACK.
  ///
  /// The cards are rendered at true ID-1 physical dimensions (85.60mm x 53.98mm).
  /// For correct sizing when printing, ensure the print dialog uses "Actual size"
  /// (no scaling).
  static Future<Uint8List> buildFrontBackSheetPdf({
    required Student student,
    required IdCardPayload payload,
    Uint8List? profileImageBytes,
    PdfPageFormat pageFormat = PdfPageFormat.a4,
  }) async {
    final doc = pw.Document(
      title: 'IQRA Student ID Card',
      author: 'IQRA Library',
      creator: 'IQRA Library App',
    );

    final logoBytes = (await rootBundle.load('IqraLogo.png')).buffer.asUint8List();
    final logoImage = pw.MemoryImage(logoBytes);

    final profileImage = _buildPdfProfileImage(profileImageBytes);

    final dob = DateFormat('dd MMM yyyy').format(student.dateOfBirth.toLocal());
    final issuedAt = DateFormat('dd MMM yyyy').format(payload.issuedAt.toLocal());
    final shortId = _shortId(student.id);

    final cardW = _cardWidthPt;
    final cardH = _cardHeightPt;

    doc.addPage(
      pw.Page(
        pageFormat: pageFormat,
        margin: const pw.EdgeInsets.all(24),
        build: (context) {
          return pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.stretch,
            children: [
              pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                crossAxisAlignment: pw.CrossAxisAlignment.end,
                children: [
                  pw.Text(
                    'Student ID Card',
                    style: pw.TextStyle(
                      fontSize: 18,
                      fontWeight: pw.FontWeight.bold,
                      color: PdfColor.fromInt(0xFF0D253F),
                    ),
                  ),
                  pw.Text(
                    'Print at 100% / Actual size',
                    style: pw.TextStyle(
                      fontSize: 9,
                      color: PdfColor.fromInt(0xFF5A6772),
                    ),
                  ),
                ],
              ),
              pw.SizedBox(height: 14),
              pw.Center(
                child: pw.Row(
                  mainAxisAlignment: pw.MainAxisAlignment.center,
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    pw.Column(
                      mainAxisSize: pw.MainAxisSize.min,
                      crossAxisAlignment: pw.CrossAxisAlignment.center,
                      children: [
                        _label('FRONT'),
                        pw.SizedBox(height: 6),
                        _buildFrontCard(
                          student: student,
                          logoImage: logoImage,
                          profileImage: profileImage,
                          cardWidth: cardW,
                          cardHeight: cardH,
                          dob: dob,
                          issuedAt: issuedAt,
                          shortId: shortId,
                        ),
                      ],
                    ),
                    pw.SizedBox(width: 22),
                    pw.Column(
                      mainAxisSize: pw.MainAxisSize.min,
                      crossAxisAlignment: pw.CrossAxisAlignment.center,
                      children: [
                        _label('BACK'),
                        pw.SizedBox(height: 6),
                        _buildBackCard(
                          payload: payload,
                          cardWidth: cardW,
                          cardHeight: cardH,
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              pw.SizedBox(height: 18),
              pw.Text(
                'Tip: For best results, use thicker paper, cut along the card border, then laminate.',
                style: pw.TextStyle(
                  fontSize: 9,
                  color: PdfColor.fromInt(0xFF5A6772),
                ),
                textAlign: pw.TextAlign.center,
              ),
            ],
          );
        },
      ),
    );

    return doc.save();
  }

  static pw.Widget _label(String text) {
    return pw.Container(
      padding: const pw.EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: pw.BoxDecoration(
        color: PdfColor.fromInt(0xFFEFF3F6),
        borderRadius: pw.BorderRadius.circular(100),
        border: pw.Border.all(color: PdfColor.fromInt(0xFFD0D8DF), width: 1),
      ),
      child: pw.Text(
        text,
        style: pw.TextStyle(
          fontSize: 9,
          fontWeight: pw.FontWeight.bold,
          letterSpacing: 1.5,
          color: PdfColor.fromInt(0xFF0D253F),
        ),
      ),
    );
  }

  static pw.Widget _buildFrontCard({
    required Student student,
    required pw.MemoryImage logoImage,
    required pw.MemoryImage? profileImage,
    required double cardWidth,
    required double cardHeight,
    required String dob,
    required String issuedAt,
    required String shortId,
  }) {
    const navy = 0xFF0D253F;
    const navy2 = 0xFF1B3A5C;
    const navy3 = 0xFF274C77;
    const gold = 0xFFD4A843;
    const gold2 = 0xFFF0C75E;

    final cGold = PdfColor.fromInt(gold);
    final cGold2 = PdfColor.fromInt(gold2);

    final photoW = 20 * PdfPageFormat.mm;
    final photoH = 26 * PdfPageFormat.mm;

    return pw.Container(
      width: cardWidth,
      height: cardHeight,
      decoration: pw.BoxDecoration(
        borderRadius: pw.BorderRadius.circular(10),
        border: pw.Border.all(color: PdfColor.fromInt(0xFF0E1E2C), width: 1),
        gradient: pw.LinearGradient(
          begin: pw.Alignment.topLeft,
          end: pw.Alignment.bottomRight,
          colors: [
            PdfColor.fromInt(navy),
            PdfColor.fromInt(navy2),
            PdfColor.fromInt(navy3),
          ],
        ),
      ),
      child: pw.Stack(
        children: [
          pw.Positioned(
            top: 0,
            left: 0,
            right: 0,
            child: pw.Container(
              height: 3,
              decoration: pw.BoxDecoration(
                gradient: pw.LinearGradient(
                  begin: pw.Alignment.centerLeft,
                  end: pw.Alignment.centerRight,
                  colors: [
                    PdfColor.fromInt(gold),
                    PdfColor.fromInt(gold2),
                    PdfColor.fromInt(gold),
                  ],
                ),
              ),
            ),
          ),
          pw.Padding(
            padding: const pw.EdgeInsets.fromLTRB(10, 8, 10, 8),
            child: pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.stretch,
              children: [
                pw.Row(
                  crossAxisAlignment: pw.CrossAxisAlignment.center,
                  children: [
                    pw.Container(
                      width: 22,
                      height: 22,
                      padding: const pw.EdgeInsets.all(3),
                      decoration: pw.BoxDecoration(
                        borderRadius: pw.BorderRadius.circular(6),
                        gradient: pw.LinearGradient(
                          colors: [cGold, cGold2],
                          begin: pw.Alignment.topLeft,
                          end: pw.Alignment.bottomRight,
                        ),
                      ),
                      child: pw.Image(logoImage, fit: pw.BoxFit.contain),
                    ),
                    pw.SizedBox(width: 8),
                    pw.Expanded(
                      child: pw.Column(
                        crossAxisAlignment: pw.CrossAxisAlignment.start,
                        children: [
                          pw.Text(
                            'IQRA LIBRARY',
                            style: pw.TextStyle(
                              color: PdfColors.white,
                              fontWeight: pw.FontWeight.bold,
                              fontSize: 11,
                              letterSpacing: 1.5,
                            ),
                            maxLines: 1,
                            overflow: pw.TextOverflow.clip,
                          ),
                          pw.SizedBox(height: 1),
                          pw.Text(
                            'STUDENT IDENTIFICATION CARD',
                            style: pw.TextStyle(
                              color: cGold2,
                              fontWeight: pw.FontWeight.bold,
                              fontSize: 6,
                              letterSpacing: 0.8,
                            ),
                            maxLines: 1,
                            overflow: pw.TextOverflow.clip,
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                pw.SizedBox(height: 8),
                pw.Container(
                  height: 1,
                  decoration: pw.BoxDecoration(
                    gradient: pw.LinearGradient(
                      colors: [
                        _withOpacity(PdfColors.white, 0),
                        _withOpacity(PdfColors.white, 0.18),
                        _withOpacity(PdfColors.white, 0),
                      ],
                    ),
                  ),
                ),
                pw.SizedBox(height: 8),
                pw.Row(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    pw.Container(
                      width: photoW,
                      height: photoH,
                      decoration: pw.BoxDecoration(
                        borderRadius: pw.BorderRadius.circular(7),
                        border: pw.Border.all(
                          color: _withOpacity(cGold, 0.7),
                          width: 2,
                        ),
                        color: PdfColor.fromInt(navy2),
                      ),
                      child: pw.ClipRRect(
                        horizontalRadius: 6,
                        verticalRadius: 6,
                        child: profileImage != null
                            ? pw.Image(profileImage, fit: pw.BoxFit.cover)
                            : pw.Center(
                                child: pw.Text(
                                  student.initials,
                                  style: pw.TextStyle(
                                    color: cGold2,
                                    fontWeight: pw.FontWeight.bold,
                                    fontSize: 18,
                                    letterSpacing: 2,
                                  ),
                                ),
                              ),
                      ),
                    ),
                    pw.SizedBox(width: 10),
                    pw.Expanded(
                      child: pw.Column(
                        crossAxisAlignment: pw.CrossAxisAlignment.start,
                        children: [
                          pw.Text(
                            student.fullName.toUpperCase(),
                            style: pw.TextStyle(
                              color: PdfColors.white,
                              fontWeight: pw.FontWeight.bold,
                              fontSize: 10,
                              letterSpacing: 0.6,
                            ),
                            maxLines: 2,
                            overflow: pw.TextOverflow.clip,
                          ),
                          pw.SizedBox(height: 6),
                          _infoField('Student ID', shortId, labelColor: cGold2),
                          pw.SizedBox(height: 4),
                          _infoField('Date of Birth', dob, labelColor: cGold2),
                          pw.SizedBox(height: 4),
                          _infoField(
                            'Seat No.',
                            (student.seatNumber ?? 'N/A').trim().isEmpty
                                ? 'N/A'
                                : (student.seatNumber ?? 'N/A'),
                            labelColor: cGold2,
                          ),
                          pw.SizedBox(height: 4),
                          _infoField('Email', student.email, labelColor: cGold2),
                        ],
                      ),
                    ),
                  ],
                ),
                pw.Spacer(),
                pw.Container(
                  height: 1,
                  decoration: pw.BoxDecoration(
                    gradient: pw.LinearGradient(
                      colors: [
                        _withOpacity(PdfColors.white, 0),
                        _withOpacity(PdfColors.white, 0.12),
                        _withOpacity(PdfColors.white, 0),
                      ],
                    ),
                  ),
                ),
                pw.SizedBox(height: 6),
                pw.Row(
                  mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                  crossAxisAlignment: pw.CrossAxisAlignment.center,
                  children: [
                    pw.Text(
                      'Issued: $issuedAt',
                      style: pw.TextStyle(
                        color: _withOpacity(PdfColors.white, 0.7),
                        fontSize: 7,
                        fontWeight: pw.FontWeight.normal,
                      ),
                    ),
                    pw.Container(
                      padding: const pw.EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: pw.BoxDecoration(
                        borderRadius: pw.BorderRadius.circular(5),
                        border: pw.Border.all(color: _withOpacity(cGold, 0.5), width: 1),
                        color: _withOpacity(cGold, 0.12),
                      ),
                      child: pw.Text(
                        'VERIFIED',
                        style: pw.TextStyle(
                          color: cGold2,
                          fontSize: 6,
                          fontWeight: pw.FontWeight.bold,
                          letterSpacing: 1.4,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  static pw.Widget _buildBackCard({
    required IdCardPayload payload,
    required double cardWidth,
    required double cardHeight,
  }) {
    final cNavy = PdfColor.fromInt(0xFF0D253F);
    final cGold = PdfColor.fromInt(0xFFD4A843);

    final qrSize = 34 * PdfPageFormat.mm;

    return pw.Container(
      width: cardWidth,
      height: cardHeight,
      decoration: pw.BoxDecoration(
        color: PdfColors.white,
        borderRadius: pw.BorderRadius.circular(10),
        border: pw.Border.all(color: PdfColor.fromInt(0xFFE0E0E0), width: 1),
      ),
      child: pw.Padding(
        padding: const pw.EdgeInsets.fromLTRB(10, 10, 10, 10),
        child: pw.Column(
          mainAxisAlignment: pw.MainAxisAlignment.center,
          children: [
            pw.Text(
              'SCAN TO VERIFY',
              style: pw.TextStyle(
                color: cNavy,
                fontWeight: pw.FontWeight.bold,
                letterSpacing: 2.0,
                fontSize: 8,
              ),
            ),
            pw.SizedBox(height: 8),
            pw.Container(
              padding: const pw.EdgeInsets.all(6),
              decoration: pw.BoxDecoration(
                borderRadius: pw.BorderRadius.circular(10),
                border: pw.Border.all(color: _withOpacity(cGold, 0.55), width: 2),
              ),
              child: pw.BarcodeWidget(
                barcode: pw.Barcode.qrCode(),
                data: payload.qrData,
                width: qrSize,
                height: qrSize,
                color: cNavy,
                backgroundColor: PdfColors.white,
                drawText: false,
              ),
            ),
            pw.SizedBox(height: 8),
            pw.Text(
              'This card is the property of IQRA Library.',
              style: pw.TextStyle(
                color: PdfColor.fromInt(0xFF6B7280),
                fontSize: 6.5,
              ),
              textAlign: pw.TextAlign.center,
            ),
            pw.SizedBox(height: 2),
            pw.Text(
              'If found, please return to the nearest branch.',
              style: pw.TextStyle(
                color: PdfColor.fromInt(0xFF8A94A0),
                fontSize: 6.5,
              ),
              textAlign: pw.TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  static pw.Widget _infoField(
    String label,
    String value, {
    required PdfColor labelColor,
  }) {
    final safeValue = value.trim().isEmpty ? 'N/A' : value.trim();
    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        pw.Text(
          label.toUpperCase(),
          style: pw.TextStyle(
            color: _withOpacity(labelColor, 0.9),
            fontSize: 5.5,
            fontWeight: pw.FontWeight.bold,
            letterSpacing: 1.0,
          ),
          maxLines: 1,
          overflow: pw.TextOverflow.clip,
        ),
        pw.SizedBox(height: 1),
        pw.Text(
          safeValue,
          style: pw.TextStyle(
            color: _withOpacity(PdfColors.white, 0.96),
            fontSize: 7.2,
            fontWeight: pw.FontWeight.bold,
          ),
          maxLines: 1,
          overflow: pw.TextOverflow.clip,
        ),
      ],
    );
  }

  static String _shortId(String id) {
    final trimmed = id.trim();
    if (trimmed.isEmpty) return 'N/A';
    return trimmed.length >= 8 ? trimmed.substring(0, 8).toUpperCase() : trimmed.toUpperCase();
  }

  static pw.MemoryImage? _buildPdfProfileImage(Uint8List? profileImageBytes) {
    if (profileImageBytes == null || profileImageBytes.isEmpty) return null;

    // Convert to JPEG for better compatibility with PDF image decoders.
    try {
      final decoded = img.decodeImage(profileImageBytes);
      if (decoded != null) {
        final jpgBytes = img.encodeJpg(decoded, quality: 94);
        return pw.MemoryImage(Uint8List.fromList(jpgBytes));
      }
    } catch (_) {
      // Fall back to raw bytes below.
    }

    try {
      return pw.MemoryImage(profileImageBytes);
    } catch (_) {
      return null;
    }
  }

  static PdfColor _withOpacity(PdfColor color, double opacity) {
    return PdfColor(color.red, color.green, color.blue, opacity);
  }
}
