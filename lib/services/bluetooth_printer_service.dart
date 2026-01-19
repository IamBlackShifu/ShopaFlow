import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:print_bluetooth_thermal/print_bluetooth_thermal.dart';
import 'package:esc_pos_utils_plus/esc_pos_utils_plus.dart';
import 'package:image/image.dart' as img;
import 'printer_service_interface.dart';

class BluetoothPrinterService extends ChangeNotifier implements PrinterServiceInterface {
  @override
  PrinterType get printerType => PrinterType.bluetooth;

  List<BluetoothInfo> _availablePrinters = [];
  BluetoothInfo? _connectedPrinter;
  bool _isConnected = false;
  String _connectionStatus = 'Not connected';
  int _paperSize = 58; // 58mm or 80mm

  List<BluetoothInfo> get availablePrinters => _availablePrinters;
  BluetoothInfo? get connectedPrinter => _connectedPrinter;
  
  @override
  bool get isConnected => _isConnected;
  
  @override
  String get connectionStatus => _connectionStatus;
  
  @override
  int get paperSize => _paperSize;

  // Check if Bluetooth is available and enabled
  @override
  Future<bool> checkAvailability() async {
    try {
      final bool result = await PrintBluetoothThermal.bluetoothEnabled;
      if (!result) {
        _connectionStatus = 'Bluetooth is disabled';
        notifyListeners();
      }
      return result;
    } catch (e) {
      _connectionStatus = 'Error checking Bluetooth: $e';
      notifyListeners();
      return false;
    }
  }

  // Scan for available Bluetooth printers
  @override
  Future<void> scanForPrinters() async {
    try {
      _connectionStatus = 'Scanning for printers...';
      notifyListeners();

      final bool isAvailable = await checkAvailability();
      if (!isAvailable) {
        _connectionStatus = 'Please enable Bluetooth';
        notifyListeners();
        return;
      }

      final List<BluetoothInfo> printers = await PrintBluetoothThermal.pairedBluetooths;
      _availablePrinters = printers;
      _connectionStatus = 'Found ${printers.length} printer(s)';
      notifyListeners();
    } catch (e) {
      _connectionStatus = 'Error scanning: $e';
      _availablePrinters = [];
      notifyListeners();
    }
  }

  // Connect to a specific printer
  @override
  Future<bool> connect() async {
    // For Bluetooth, we need a specific printer - use connectToPrinter instead
    if (_availablePrinters.isEmpty) {
      await scanForPrinters();
    }
    if (_availablePrinters.isEmpty) {
      _connectionStatus = 'No printers found';
      notifyListeners();
      return false;
    }
    return await connectToPrinter(_availablePrinters.first);
  }

  // Connect to a specific Bluetooth printer
  Future<bool> connectToPrinter(BluetoothInfo printer) async {
    try {
      _connectionStatus = 'Connecting to ${printer.name}...';
      notifyListeners();

      final bool result = await PrintBluetoothThermal.connect(macPrinterAddress: printer.macAdress);
      
      if (result) {
        _connectedPrinter = printer;
        _isConnected = true;
        _connectionStatus = 'Connected to ${printer.name}';
      } else {
        _connectionStatus = 'Failed to connect to ${printer.name}';
      }
      
      notifyListeners();
      return result;
    } catch (e) {
      _connectionStatus = 'Connection error: $e';
      _isConnected = false;
      notifyListeners();
      return false;
    }
  }

  // Disconnect from printer
  @override
  Future<void> disconnect() async {
    try {
      await PrintBluetoothThermal.disconnect;
      _connectedPrinter = null;
      _isConnected = false;
      _connectionStatus = 'Disconnected';
      notifyListeners();
    } catch (e) {
      _connectionStatus = 'Error disconnecting: $e';
      notifyListeners();
    }
  }

  // Set paper size (58mm or 80mm)
  @override
  void setPaperSize(int size) {
    if (size == 58 || size == 80) {
      _paperSize = size;
      notifyListeners();
    }
  }

  // Print test receipt
  @override
  Future<bool> printTestReceipt({String? storeName}) async {
    if (!_isConnected) {
      _connectionStatus = 'Please connect to a printer first';
      notifyListeners();
      return false;
    }

    try {
      List<int> bytes = [];
      final profile = await CapabilityProfile.load();
      final generator = Generator(_paperSize == 58 ? PaperSize.mm58 : PaperSize.mm80, profile);

      // Header
      bytes += generator.text(
        storeName ?? 'ShopaFlow POS',
        styles: const PosStyles(align: PosAlign.center, bold: true, height: PosTextSize.size2, width: PosTextSize.size2),
      );
      bytes += generator.text(
        'Test Receipt',
        styles: const PosStyles(align: PosAlign.center, bold: true),
      );
      bytes += generator.hr();
      bytes += generator.emptyLines(1);

      // Body
      bytes += generator.text('Date: ${DateTime.now().toString().substring(0, 16)}');
      bytes += generator.text('Printer: ${_connectedPrinter?.name ?? "Unknown"}');
      bytes += generator.text('Paper Size: ${_paperSize}mm');
      bytes += generator.emptyLines(1);
      bytes += generator.hr();

      // Test items
      bytes += generator.row([
        PosColumn(text: 'Item', width: 6, styles: const PosStyles(bold: true)),
        PosColumn(text: 'Price', width: 6, styles: const PosStyles(bold: true, align: PosAlign.right)),
      ]);
      bytes += generator.hr(ch: '-');
      bytes += generator.row([
        PosColumn(text: 'Test Item 1', width: 6),
        PosColumn(text: '£10.00', width: 6, styles: const PosStyles(align: PosAlign.right)),
      ]);
      bytes += generator.row([
        PosColumn(text: 'Test Item 2', width: 6),
        PosColumn(text: '£25.50', width: 6, styles: const PosStyles(align: PosAlign.right)),
      ]);
      bytes += generator.hr();
      bytes += generator.row([
        PosColumn(text: 'TOTAL', width: 6, styles: const PosStyles(bold: true)),
        PosColumn(text: '£35.50', width: 6, styles: const PosStyles(bold: true, align: PosAlign.right)),
      ]);
      bytes += generator.emptyLines(1);

      // Footer
      bytes += generator.text(
        'Thank you for your purchase!',
        styles: const PosStyles(align: PosAlign.center),
      );
      bytes += generator.text(
        'www.shopaflow.com',
        styles: const PosStyles(align: PosAlign.center, bold: true),
      );
      bytes += generator.emptyLines(2);
      bytes += generator.cut();

      // Send to printer
      await PrintBluetoothThermal.writeBytes(bytes);
      
      _connectionStatus = 'Test receipt printed successfully';
      notifyListeners();
      return true;
    } catch (e) {
      _connectionStatus = 'Print error: $e';
      notifyListeners();
      return false;
    }
  }

  // Print actual sales receipt
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
      _connectionStatus = 'Please connect to a printer first';
      notifyListeners();
      return false;
    }

    try {
      List<int> bytes = [];
      final profile = await CapabilityProfile.load();
      final generator = Generator(_paperSize == 58 ? PaperSize.mm58 : PaperSize.mm80, profile);

      // Header
      bytes += generator.text(
        storeName ?? 'ShopaFlow POS',
        styles: const PosStyles(align: PosAlign.center, bold: true, height: PosTextSize.size2, width: PosTextSize.size2),
      );
      if (storeAddress != null && storeAddress.isNotEmpty) {
        bytes += generator.text(
          storeAddress,
          styles: const PosStyles(align: PosAlign.center),
        );
      }
      bytes += generator.text(
        'Sales Receipt',
        styles: const PosStyles(align: PosAlign.center, bold: true),
      );
      bytes += generator.hr();
      bytes += generator.text('Receipt #: $receiptNumber');
      bytes += generator.text('Date: ${saleDate.toString().substring(0, 16)}');
      bytes += generator.text('Payment: $paymentMethod');
      bytes += generator.hr();
      bytes += generator.emptyLines(1);

      // Items
      bytes += generator.row([
        PosColumn(text: 'Item', width: 6, styles: const PosStyles(bold: true)),
        PosColumn(text: 'Qty', width: 2, styles: const PosStyles(bold: true, align: PosAlign.center)),
        PosColumn(text: 'Price', width: 4, styles: const PosStyles(bold: true, align: PosAlign.right)),
      ]);
      bytes += generator.hr(ch: '-');

      for (var item in items) {
        bytes += generator.row([
          PosColumn(text: item['name'] ?? '', width: 6),
          PosColumn(text: '${item['quantity'] ?? 1}', width: 2, styles: const PosStyles(align: PosAlign.center)),
          PosColumn(text: '${(item['total_price'] ?? 0.0).toStringAsFixed(2)}', width: 4, styles: const PosStyles(align: PosAlign.right)),
        ]);
      }

      bytes += generator.hr();
      bytes += generator.row([
        PosColumn(text: 'TOTAL', width: 8, styles: const PosStyles(bold: true, height: PosTextSize.size2, width: PosTextSize.size2)),
        PosColumn(
          text: '${total.toStringAsFixed(2)}',
          width: 4,
          styles: const PosStyles(bold: true, align: PosAlign.right, height: PosTextSize.size2, width: PosTextSize.size2),
        ),
      ]);
      bytes += generator.emptyLines(1);

      // Footer
      bytes += generator.text(
        'Thank you for your purchase!',
        styles: const PosStyles(align: PosAlign.center),
      );
      bytes += generator.text(
        'Please come again',
        styles: const PosStyles(align: PosAlign.center, bold: true),
      );
      bytes += generator.emptyLines(3);
      bytes += generator.cut();

      // Send to printer
      await PrintBluetoothThermal.writeBytes(bytes);
      
      _connectionStatus = 'Receipt printed successfully';
      notifyListeners();
      return true;
    } catch (e) {
      _connectionStatus = 'Print error: $e';
      notifyListeners();
      return false;
    }
  }

  // Check current connection status
  @override
  Future<void> checkConnectionStatus() async {
    try {
      final bool status = await PrintBluetoothThermal.connectionStatus;
      _isConnected = status;
      if (!status) {
        _connectedPrinter = null;
        _connectionStatus = 'Not connected';
      }
      notifyListeners();
    } catch (e) {
      _isConnected = false;
      _connectionStatus = 'Error checking status: $e';
      notifyListeners();
    }
  }
}
