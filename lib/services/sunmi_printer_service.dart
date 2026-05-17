import 'package:flutter/material.dart';
import 'package:sunmi_printer_plus/sunmi_printer_plus.dart';
import 'printer_service_interface.dart';

class SunmiPrinterService extends ChangeNotifier implements PrinterServiceInterface {
  @override
  PrinterType get printerType => PrinterType.sunmi;

  bool _isConnected = false;
  String _connectionStatus = 'Not checked';
  int _paperSize = 58; // 58mm or 80mm (Sunmi devices are typically 58mm)

  @override
  bool get isConnected => _isConnected;

  @override
  String get connectionStatus => _connectionStatus;

  @override
  int get paperSize => _paperSize;

  /// Check if Sunmi printer is available on this device
  @override
  Future<bool> checkAvailability() async {
    try {
      final bool? result = await SunmiPrinter.bindingPrinter();
      _isConnected = result ?? false;
      _connectionStatus = _isConnected 
          ? 'Sunmi printer available' 
          : 'Not a Sunmi device or printer unavailable';
      notifyListeners();
      return _isConnected;
    } catch (e) {
      _connectionStatus = 'Error checking Sunmi printer: $e';
      _isConnected = false;
      notifyListeners();
      return false;
    }
  }

  /// Sunmi printers don't need scanning - they're built-in
  @override
  Future<void> scanForPrinters() async {
    await checkAvailability();
  }

  /// Connect to the built-in Sunmi printer
  @override
  Future<bool> connect() async {
    return await checkAvailability();
  }

  /// Disconnect from printer (not really applicable for Sunmi)
  @override
  Future<void> disconnect() async {
    // Sunmi printers are built-in, no need to disconnect
    _connectionStatus = 'Sunmi printer still available';
    notifyListeners();
  }

  /// Set paper size (58mm or 80mm)
  @override
  void setPaperSize(int size) {
    if (size == 58 || size == 80) {
      _paperSize = size;
      notifyListeners();
    }
  }

  /// Print test receipt
  @override
  Future<bool> printTestReceipt({String? storeName}) async {
    if (!_isConnected) {
      _connectionStatus = 'Sunmi printer not available';
      notifyListeners();
      return false;
    }

    try {
      await SunmiPrinter.initPrinter();
      await SunmiPrinter.startTransactionPrint(true);

      // Header
      await SunmiPrinter.setAlignment(SunmiPrintAlign.CENTER);
      await SunmiPrinter.bold();
      await SunmiPrinter.printText(storeName ?? 'ShopaFlow POS');
      await SunmiPrinter.resetBold();
      await SunmiPrinter.line();
      await SunmiPrinter.printText('Test Receipt');
      await SunmiPrinter.line();
      await SunmiPrinter.lineWrap(1);

      // Body
      await SunmiPrinter.setAlignment(SunmiPrintAlign.LEFT);
      await SunmiPrinter.printText('Date: ${DateTime.now().toString().substring(0, 16)}');
      await SunmiPrinter.printText('Printer: Sunmi Built-in');
      await SunmiPrinter.printText('Paper Size: ${_paperSize}mm');
      await SunmiPrinter.lineWrap(1);
      await SunmiPrinter.line();

      // Test items
      await SunmiPrinter.bold();
      await SunmiPrinter.printText('Item                 Price');
      await SunmiPrinter.resetBold();
      await SunmiPrinter.printText('--------------------------------');
      await SunmiPrinter.printText('Test Item 1          £10.00');
      await SunmiPrinter.printText('Test Item 2          £25.50');
      await SunmiPrinter.line();
      await SunmiPrinter.bold();
      await SunmiPrinter.printText('TOTAL                £35.50');
      await SunmiPrinter.resetBold();
      await SunmiPrinter.lineWrap(1);

      // Footer
      await SunmiPrinter.setAlignment(SunmiPrintAlign.CENTER);
      await SunmiPrinter.printText('Thank you for your purchase!');
      await SunmiPrinter.bold();
      await SunmiPrinter.printText('www.shopaflow.com');
      await SunmiPrinter.resetBold();
      await SunmiPrinter.lineWrap(3);

      await SunmiPrinter.exitTransactionPrint(true);

      _connectionStatus = 'Test receipt printed successfully';
      notifyListeners();
      return true;
    } catch (e) {
      _connectionStatus = 'Print error: $e';
      notifyListeners();
      return false;
    }
  }

  /// Print actual sales receipt
  @override
  Future<bool> printReceipt({
    required String receiptNumber,
    required DateTime saleDate,
    required List<Map<String, dynamic>> items,
    required double total,
    required String paymentMethod,
    String? storeName,
    String? storeAddress,
  }) async {
    if (!_isConnected) {
      _connectionStatus = 'Sunmi printer not available';
      notifyListeners();
      return false;
    }

    try {
      await SunmiPrinter.initPrinter();
      await SunmiPrinter.startTransactionPrint(true);

      // Header
      await SunmiPrinter.setAlignment(SunmiPrintAlign.CENTER);
      await SunmiPrinter.bold();
      await SunmiPrinter.printText(storeName ?? 'ShopaFlow POS');
      await SunmiPrinter.resetBold();
      
      if (storeAddress != null && storeAddress.isNotEmpty) {
        await SunmiPrinter.printText(storeAddress);
      }
      
      await SunmiPrinter.bold();
      await SunmiPrinter.printText('Sales Receipt');
      await SunmiPrinter.resetBold();
      await SunmiPrinter.line();
      
      // Receipt details
      await SunmiPrinter.setAlignment(SunmiPrintAlign.LEFT);
      await SunmiPrinter.printText('Receipt #: $receiptNumber');
      await SunmiPrinter.printText('Date: ${saleDate.toString().substring(0, 16)}');
      await SunmiPrinter.printText('Payment: $paymentMethod');
      await SunmiPrinter.line();
      await SunmiPrinter.lineWrap(1);

      // Items header
      await SunmiPrinter.bold();
      await SunmiPrinter.printText('Item           Qty    Price');
      await SunmiPrinter.resetBold();
      await SunmiPrinter.printText('--------------------------------');

      // Items
      for (var item in items) {
        final name = (item['name'] ?? '').toString();
        final qtyValue = (item['quantity'] as num?)?.toDouble() ?? 1.0;
        final qty = qtyValue == qtyValue.roundToDouble() ? qtyValue.toStringAsFixed(0) : qtyValue.toStringAsFixed(3).replaceFirst(RegExp(r'0+$'), '').replaceFirst(RegExp(r'\.$'), '');
        final price = '£${(item['total_price'] ?? 0.0).toStringAsFixed(2)}';
        
        // Format as: Name (15 chars) Qty (4 chars) Price (13 chars right-aligned)
        final namePart = name.length > 15 ? name.substring(0, 15) : name.padRight(15);
        final qtyPart = qty.padLeft(4);
        final pricePart = price.padLeft(13);
        
        await SunmiPrinter.printText('$namePart$qtyPart$pricePart');
      }

      await SunmiPrinter.line();
      
      // Total
      await SunmiPrinter.bold();
      final totalText = 'TOTAL'.padRight(19) + '£${total.toStringAsFixed(2)}'.padLeft(13);
      await SunmiPrinter.printText(totalText);
      await SunmiPrinter.resetBold();
      await SunmiPrinter.lineWrap(1);

      // Footer
      await SunmiPrinter.setAlignment(SunmiPrintAlign.CENTER);
      await SunmiPrinter.printText('Thank you for your purchase!');
      await SunmiPrinter.bold();
      await SunmiPrinter.printText('Please come again');
      await SunmiPrinter.resetBold();
      await SunmiPrinter.lineWrap(3);

      await SunmiPrinter.exitTransactionPrint(true);

      _connectionStatus = 'Receipt printed successfully';
      notifyListeners();
      return true;
    } catch (e) {
      _connectionStatus = 'Print error: $e';
      notifyListeners();
      return false;
    }
  }

  /// Check current connection status
  @override
  Future<void> checkConnectionStatus() async {
    await checkAvailability();
  }
}
