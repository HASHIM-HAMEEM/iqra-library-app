import 'dart:io';
// import 'dart:typed_data';

import 'package:excel/excel.dart';
import 'package:intl/intl.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

import 'package:library_registration_app/domain/entities/activity_log.dart';
import 'package:library_registration_app/domain/entities/student.dart';
import 'package:library_registration_app/domain/entities/subscription.dart';

class ExportService {
  static const String _dateFormat = 'yyyy-MM-dd HH:mm:ss';
  static const String _dateOnlyFormat = 'yyyy-MM-dd';
  
  /// Export all data to Excel format
  Future<String> exportAllData({
    required List<Student> students,
    required List<Subscription> subscriptions,
    required List<ActivityLog> activityLogs,
  }) async {
    final excel = Excel.createExcel();
    
    // Remove default sheet
    excel.delete('Sheet1');
    
    // Create sheets for each data type
    _createStudentsSheet(excel, students);
    _createSubscriptionsSheet(excel, subscriptions);
    _createActivityLogsSheet(excel, activityLogs);
    _createSummarySheet(excel, students, subscriptions, activityLogs);
    
    // Save file
    final fileName = 'iqra_library_export_${_getTimestamp()}.xlsx';
    final filePath = await _saveExcelFile(excel, fileName);
    
    return filePath;
  }

  /// Export all data to CSV in a ZIP archive alongside Excel
  Future<String> exportAllDataAsCsvZip({
    required List<Student> students,
    required List<Subscription> subscriptions,
    required List<ActivityLog> activityLogs,
  }) async {
    final String ts = _getTimestamp();
    final String studentsCsv = _studentsToCsv(students);
    final String subscriptionsCsv = _subscriptionsToCsv(subscriptions);
    final String logsCsv = _activityLogsToCsv(activityLogs);

    final directory = await getApplicationDocumentsDirectory();
    final base = directory.path;

    final studentsFile = File('$base/students_$ts.csv');
    final subsFile = File('$base/subscriptions_$ts.csv');
    final logsFile = File('$base/activity_logs_$ts.csv');
    await studentsFile.writeAsString(studentsCsv);
    await subsFile.writeAsString(subscriptionsCsv);
    await logsFile.writeAsString(logsCsv);

    // Simple zip via archive_io would be ideal; to avoid adding a heavy dep here,
    // we return directory path. If you want a single ZIP file, I can add `archive` pkg.
    return directory.path;
  }
  
  /// Export only student data
  Future<String> exportStudentsData(List<Student> students) async {
    final excel = Excel.createExcel();
    excel.delete('Sheet1');
    
    _createStudentsSheet(excel, students);
    
    final fileName = 'students_export_${_getTimestamp()}.xlsx';
    final filePath = await _saveExcelFile(excel, fileName);
    
    return filePath;
  }

  Future<String> exportStudentsCsv(List<Student> students) async {
    final directory = await getApplicationDocumentsDirectory();
    final file = File('${directory.path}/students_${_getTimestamp()}.csv');
    await file.writeAsString(_studentsToCsv(students));
    return file.path;
  }
  
  /// Export only subscription data
  Future<String> exportSubscriptionsData(List<Subscription> subscriptions) async {
    final excel = Excel.createExcel();
    excel.delete('Sheet1');
    
    _createSubscriptionsSheet(excel, subscriptions);
    
    final fileName = 'subscriptions_export_${_getTimestamp()}.xlsx';
    final filePath = await _saveExcelFile(excel, fileName);
    
    return filePath;
  }

  Future<String> exportSubscriptionsCsv(List<Subscription> subscriptions) async {
    final directory = await getApplicationDocumentsDirectory();
    final file = File('${directory.path}/subscriptions_${_getTimestamp()}.csv');
    await file.writeAsString(_subscriptionsToCsv(subscriptions));
    return file.path;
  }
  
  /// Export only activity logs
  Future<String> exportActivityLogsData(List<ActivityLog> activityLogs) async {
    final excel = Excel.createExcel();
    excel.delete('Sheet1');
    
    _createActivityLogsSheet(excel, activityLogs);
    
    final fileName = 'activity_logs_export_${_getTimestamp()}.xlsx';
    final filePath = await _saveExcelFile(excel, fileName);
    
    return filePath;
  }

  Future<String> exportActivityLogsCsv(List<ActivityLog> activityLogs) async {
    final directory = await getApplicationDocumentsDirectory();
    final file = File('${directory.path}/activity_logs_${_getTimestamp()}.csv');
    await file.writeAsString(_activityLogsToCsv(activityLogs));
    return file.path;
  }
  
  /// Share exported file
  Future<void> shareExportedFile(String filePath) async {
    final file = XFile(filePath);
    await Share.shareXFiles(
      [file],
      text: 'IQRA Library Data Export',
      subject: 'Library Data Export - ${DateTime.now().toString().split(' ')[0]}',
    );
  }

  // --- CSV helpers ---
  String _rowToCsv(List<Object?> values) {
    return values.map((v) => _escapeCsv(v?.toString() ?? '')).join(',');
  }
  String _studentsToCsv(List<Student> students) {
    final buf = StringBuffer();
    buf.writeln(['ID','First Name','Last Name','Date of Birth','Age','Email','Phone','Address','Seat Number','Subscription Plan','Subscription Status','Subscription Start','Subscription End','Subscription Amount','Created At','Updated At'].join(','));
    for (final s in students) {
      buf.writeln(_rowToCsv([
        s.id,
        s.firstName,
        s.lastName,
        _formatDate(s.dateOfBirth, _dateOnlyFormat),
        _calculateAge(s.dateOfBirth).toString(),
        s.email,
        s.phone,
        s.address,
        s.seatNumber,
        s.subscriptionPlan,
        s.subscriptionStatus,
        s.subscriptionStartDate != null ? _formatDate(s.subscriptionStartDate!, _dateOnlyFormat) : null,
        s.subscriptionEndDate != null ? _formatDate(s.subscriptionEndDate!, _dateOnlyFormat) : null,
        s.subscriptionAmount,
        _formatDate(s.createdAt, _dateFormat),
        _formatDate(s.updatedAt, _dateFormat),
      ]));
    }
    return buf.toString();
  }

  String _subscriptionsToCsv(List<Subscription> subs) {
    final buf = StringBuffer();
    buf.writeln(['ID','Student ID','Plan Name','Start Date','End Date','Amount','Status','Created At','Updated At'].join(','));
    for (final s in subs) {
      buf.writeln(_rowToCsv([
        s.id,
        s.studentId,
        s.planName,
        _formatDate(s.startDate, _dateOnlyFormat),
        _formatDate(s.endDate, _dateOnlyFormat),
        s.amount,
        s.status.name,
        _formatDate(s.createdAt, _dateFormat),
        _formatDate(s.updatedAt, _dateFormat),
      ]));
    }
    return buf.toString();
  }

  String _activityLogsToCsv(List<ActivityLog> logs) {
    final buf = StringBuffer();
    buf.writeln(['ID','Activity Type','Description','Entity Type','Entity ID','Timestamp','Metadata'].join(','));
    for (final l in logs) {
      buf.writeln(_rowToCsv([
        l.id,
        l.activityType.toString().split('.').last,
        l.description,
        l.entityType,
        l.entityId,
        _formatDate(l.timestamp, _dateFormat),
        l.metadata?.toString(),
      ]));
    }
    return buf.toString();
  }

  String _escapeCsv(String value) {
    final needsQuotes = value.contains(',') || value.contains('"') || value.contains('\n');
    var v = value.replaceAll('"', '""');
    return needsQuotes ? '"$v"' : v;
  }
  
  void _createStudentsSheet(Excel excel, List<Student> students) {
    final sheet = excel['Students'];
    
    // Headers
    final headers = [
      'ID',
      'First Name',
      'Last Name',
      'Date of Birth',
      'Age',
      'Email',
      'Phone',
      'Address',
      'Seat Number',
      'Subscription Plan',
      'Subscription Status',
      'Subscription Start',
      'Subscription End',
      'Subscription Amount',
      'Created At',
      'Updated At',
    ];
    
    // Add headers
    for (int i = 0; i < headers.length; i++) {
      final cell = sheet.cell(CellIndex.indexByColumnRow(columnIndex: i, rowIndex: 0));
      cell.value = TextCellValue(headers[i]);
      cell.cellStyle = CellStyle(
        bold: true,
        backgroundColorHex: ExcelColor.blue200,
      );
    }
    
    // Add data
    for (int i = 0; i < students.length; i++) {
      final student = students[i];
      final row = i + 1;
      
      final data = [
        student.id,
        student.firstName,
        student.lastName,
        _formatDate(student.dateOfBirth, _dateOnlyFormat),
        _calculateAge(student.dateOfBirth).toString(),
        student.email,
        student.phone ?? '',
        student.address ?? '',
        student.seatNumber ?? '',
        student.subscriptionPlan ?? '',
        student.subscriptionStatus ?? '',
        student.subscriptionStartDate != null 
            ? _formatDate(student.subscriptionStartDate!, _dateOnlyFormat) 
            : '',
        student.subscriptionEndDate != null 
            ? _formatDate(student.subscriptionEndDate!, _dateOnlyFormat) 
            : '',
        student.subscriptionAmount?.toString() ?? '',
        _formatDate(student.createdAt, _dateFormat),
        _formatDate(student.updatedAt, _dateFormat),
      ];
      
      for (int j = 0; j < data.length; j++) {
        final cell = sheet.cell(CellIndex.indexByColumnRow(columnIndex: j, rowIndex: row));
        cell.value = TextCellValue(data[j].toString());
      }
    }
    
    _autoSizeColumns(sheet, headers.length);
  }
  
  void _createSubscriptionsSheet(Excel excel, List<Subscription> subscriptions) {
    final sheet = excel['Subscriptions'];
    
    // Headers
    final headers = [
      'ID',
      'Student ID',
      'Plan Name',
      'Start Date',
      'End Date',
      'Amount',
      'Status',
      'Created At',
      'Updated At',
    ];
    
    // Add headers
    for (int i = 0; i < headers.length; i++) {
      final cell = sheet.cell(CellIndex.indexByColumnRow(columnIndex: i, rowIndex: 0));
      cell.value = TextCellValue(headers[i]);
      cell.cellStyle = CellStyle(
        bold: true,
        backgroundColorHex: ExcelColor.green200,
      );
    }
    
    // Add data
    for (int i = 0; i < subscriptions.length; i++) {
      final subscription = subscriptions[i];
      final row = i + 1;
      
      final data = [
        subscription.id,
        subscription.studentId,
        subscription.planName,
        _formatDate(subscription.startDate, _dateOnlyFormat),
        _formatDate(subscription.endDate, _dateOnlyFormat),
        subscription.amount.toString(),
        subscription.status.name,
        _formatDate(subscription.createdAt, _dateFormat),
        _formatDate(subscription.updatedAt, _dateFormat),
      ];
      
      for (int j = 0; j < data.length; j++) {
        final cell = sheet.cell(CellIndex.indexByColumnRow(columnIndex: j, rowIndex: row));
        cell.value = TextCellValue(data[j].toString());
      }
    }
    
    _autoSizeColumns(sheet, headers.length);
  }
  
  void _createActivityLogsSheet(Excel excel, List<ActivityLog> activityLogs) {
    final sheet = excel['Activity Logs'];
    
    // Headers
    final headers = [
      'ID',
      'Activity Type',
      'Description',
      'Entity Type',
      'Entity ID',
      'Timestamp',
      'Metadata',
    ];
    
    // Add headers
    for (int i = 0; i < headers.length; i++) {
      final cell = sheet.cell(CellIndex.indexByColumnRow(columnIndex: i, rowIndex: 0));
      cell.value = TextCellValue(headers[i]);
      cell.cellStyle = CellStyle(
        bold: true,
        backgroundColorHex: ExcelColor.orange200,
      );
    }
    
    // Add data
    for (int i = 0; i < activityLogs.length; i++) {
      final log = activityLogs[i];
      final row = i + 1;
      
      final data = [
        log.id,
        log.activityType.toString().split('.').last,
        log.description,
        log.entityType,
        log.entityId,
        _formatDate(log.timestamp, _dateFormat),
        log.metadata?.toString() ?? '',
      ];
      
      for (int j = 0; j < data.length; j++) {
        final cell = sheet.cell(CellIndex.indexByColumnRow(columnIndex: j, rowIndex: row));
        cell.value = TextCellValue(data[j].toString());
      }
    }
    
    _autoSizeColumns(sheet, headers.length);
  }
  
  void _createSummarySheet(Excel excel, List<Student> students, 
      List<Subscription> subscriptions, List<ActivityLog> activityLogs) {
    final sheet = excel['Summary'];
    
    // Title
    final titleCell = sheet.cell(CellIndex.indexByColumnRow(columnIndex: 0, rowIndex: 0));
    titleCell.value = TextCellValue('IQRA Library Data Export Summary');
    titleCell.cellStyle = CellStyle(
      bold: true,
      fontSize: 16,
      backgroundColorHex: ExcelColor.blue300,
    );
    
    // Export info
    final exportDate = sheet.cell(CellIndex.indexByColumnRow(columnIndex: 0, rowIndex: 2));
    exportDate.value = TextCellValue('Export Date: ${_formatDate(DateTime.now(), _dateFormat)}');
    
    // Statistics
    final stats = [
      ['Total Students:', students.length.toString()],
      ['Total Subscriptions:', subscriptions.length.toString()],
      ['Total Activity Logs:', activityLogs.length.toString()],
      ['Active Subscriptions:', subscriptions.where((s) => s.status == SubscriptionStatus.active).length.toString()],
      ['Expired Subscriptions:', subscriptions.where((s) => s.status == SubscriptionStatus.expired).length.toString()],
    ];
    
    for (int i = 0; i < stats.length; i++) {
      final labelCell = sheet.cell(CellIndex.indexByColumnRow(columnIndex: 0, rowIndex: 4 + i));
      final valueCell = sheet.cell(CellIndex.indexByColumnRow(columnIndex: 1, rowIndex: 4 + i));
      
      labelCell.value = TextCellValue(stats[i][0]);
      labelCell.cellStyle = CellStyle(bold: true);
      valueCell.value = TextCellValue(stats[i][1]);
    }
    
    _autoSizeColumns(sheet, 2);
  }
  
  void _autoSizeColumns(Sheet sheet, int columnCount) {
    for (int i = 0; i < columnCount; i++) {
      sheet.setColumnAutoFit(i);
    }
  }
  
  String _formatDate(DateTime date, String format) {
    return DateFormat(format).format(date);
  }
  
  int _calculateAge(DateTime birthDate) {
    final now = DateTime.now();
    int age = now.year - birthDate.year;
    if (now.month < birthDate.month || 
        (now.month == birthDate.month && now.day < birthDate.day)) {
      age--;
    }
    return age;
  }
  
  String _getTimestamp() {
    return DateFormat('yyyyMMdd_HHmmss').format(DateTime.now());
  }
  
  Future<String> _saveExcelFile(Excel excel, String fileName) async {
    final List<int> bytes = excel.save()!;
    
    final directory = await getApplicationDocumentsDirectory();
    final file = File('${directory.path}/$fileName');
    await file.writeAsBytes(bytes);
    
    return file.path;
  }
}