import 'package:flutter/material.dart';
import 'printer_service_interface.dart';
import 'bluetooth_printer_service.dart';
import 'sunmi_printer_service.dart';

/// Unified printer manager that handles both Bluetooth and Sunmi printers
class PrinterManager extends ChangeNotifier {
  PrinterServiceInterface? _activePrinter;
  final BluetoothPrinterService _bluetoothService = BluetoothPrinterService();
  final SunmiPrinterService _sunmiService = SunmiPrinterService();
  PrinterType _selectedType = PrinterType.bluetooth;

  PrinterServiceInterface? get activePrinter => _activePrinter;
  BluetoothPrinterService get bluetoothService => _bluetoothService;
  SunmiPrinterService get sunmiService => _sunmiService;
  PrinterType get selectedType => _selectedType;

  bool get isConnected => _activePrinter?.isConnected ?? false;
  String get connectionStatus => _activePrinter?.connectionStatus ?? 'No printer selected';
  int get paperSize => _activePrinter?.paperSize ?? 58;

  PrinterManager() {
    // Listen to changes in both services
    _bluetoothService.addListener(_onServiceUpdate);
    _sunmiService.addListener(_onServiceUpdate);
    
    // Default to Bluetooth
    _activePrinter = _bluetoothService;
  }

  void _onServiceUpdate() {
    notifyListeners();
  }

  /// Switch between printer types
  Future<void> switchPrinterType(PrinterType type) async {
    if (_selectedType == type) return;

    _selectedType = type;
    
    switch (type) {
      case PrinterType.bluetooth:
        _activePrinter = _bluetoothService;
        break;
      case PrinterType.sunmi:
        _activePrinter = _sunmiService;
        // Automatically check if Sunmi printer is available
        await _sunmiService.checkAvailability();
        break;
    }
    
    notifyListeners();
  }

  /// Check availability of the current printer type
  Future<bool> checkAvailability() async {
    if (_activePrinter == null) return false;
    return await _activePrinter!.checkAvailability();
  }

  /// Scan for printers (mainly for Bluetooth)
  Future<void> scanForPrinters() async {
    if (_activePrinter == null) return;
    await _activePrinter!.scanForPrinters();
  }

  /// Connect to printer
  Future<bool> connect() async {
    if (_activePrinter == null) return false;
    return await _activePrinter!.connect();
  }

  /// Disconnect from printer
  Future<void> disconnect() async {
    if (_activePrinter == null) return;
    await _activePrinter!.disconnect();
  }

  /// Set paper size
  void setPaperSize(int size) {
    if (_activePrinter == null) return;
    _activePrinter!.setPaperSize(size);
  }

  /// Print test receipt
  Future<bool> printTestReceipt({String? storeName}) async {
    if (_activePrinter == null) return false;
    return await _activePrinter!.printTestReceipt(storeName: storeName);
  }

  /// Print actual sales receipt
  Future<bool> printReceipt({
    required String receiptNumber,
    required DateTime saleDate,
    required List<Map<String, dynamic>> items,
    required double total,
    required String paymentMethod,
    String? storeName,
    String? storeAddress,
  }) async {
    if (_activePrinter == null) return false;
    return await _activePrinter!.printReceipt(
      receiptNumber: receiptNumber,
      saleDate: saleDate,
      items: items,
      total: total,
      paymentMethod: paymentMethod,
      storeName: storeName,
      storeAddress: storeAddress,
    );
  }

  /// Check connection status
  Future<void> checkConnectionStatus() async {
    if (_activePrinter == null) return;
    await _activePrinter!.checkConnectionStatus();
  }

  @override
  void dispose() {
    _bluetoothService.removeListener(_onServiceUpdate);
    _sunmiService.removeListener(_onServiceUpdate);
    _bluetoothService.dispose();
    _sunmiService.dispose();
    super.dispose();
  }
}
