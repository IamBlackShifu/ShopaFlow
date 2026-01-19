import 'package:flutter/material.dart';

/// Enum to identify the type of printer
enum PrinterType {
  bluetooth,
  sunmi,
}

/// Base interface for all printer services
abstract class PrinterServiceInterface extends ChangeNotifier {
  PrinterType get printerType;
  bool get isConnected;
  String get connectionStatus;
  int get paperSize;

  /// Initialize or check printer availability
  Future<bool> checkAvailability();

  /// Scan for available printers (if applicable)
  Future<void> scanForPrinters();

  /// Connect to a printer
  Future<bool> connect();

  /// Disconnect from printer
  Future<void> disconnect();

  /// Set paper size (58mm or 80mm)
  void setPaperSize(int size);

  /// Print a test receipt
  Future<bool> printTestReceipt({String? storeName});

  /// Print actual sales receipt
  Future<bool> printReceipt({
    required String receiptNumber,
    required DateTime saleDate,
    required List<Map<String, dynamic>> items,
    required double total,
    required String paymentMethod,
    String? storeName,
    String? storeAddress,
  });

  /// Check current connection status
  Future<void> checkConnectionStatus();
}
