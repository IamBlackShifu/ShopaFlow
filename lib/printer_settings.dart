import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:print_bluetooth_thermal/print_bluetooth_thermal.dart';
import 'services/printer_manager.dart';
import 'services/printer_service_interface.dart';
import 'services/bluetooth_printer_service.dart';
import 'main.dart'; // For StoreInfoModel


class PrinterSettingsPage extends StatefulWidget {
  const PrinterSettingsPage({super.key});

  @override
  State<PrinterSettingsPage> createState() => _PrinterSettingsPageState();
}

class _PrinterSettingsPageState extends State<PrinterSettingsPage> {
  @override
  void initState() {
    super.initState();
    // Check connection status on load
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<PrinterManager>().checkConnectionStatus();
    });
  }

  Future<void> _scanForPrinters() async {
    await context.read<PrinterManager>().scanForPrinters();
  }

  Future<void> _connectToPrinter(BluetoothInfo printer) async {
    final manager = context.read<PrinterManager>();
    final success = await manager.bluetoothService.connectToPrinter(printer);
    if (success && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Connected to ${printer.name}'), backgroundColor: Colors.green),
      );
    }
  }

  Future<void> _connectToSunmi() async {
    final manager = context.read<PrinterManager>();
    final success = await manager.sunmiService.connect();
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(success ? 'Sunmi printer ready' : 'Sunmi printer not available'),
          backgroundColor: success ? Colors.green : Colors.red,
        ),
      );
    }
  }

  Future<void> _disconnect() async {
    await context.read<PrinterManager>().disconnect();
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Disconnected from printer'), backgroundColor: Colors.orange),
      );
    }
  }

  Future<void> _testPrint() async {
    final manager = context.read<PrinterManager>();
    if (!manager.isConnected) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please connect to a printer first'), backgroundColor: Colors.red),
      );
      return;
    }

    final store = context.read<StoreInfoModel>();
    final success = await manager.printTestReceipt(storeName: store.name);
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(success ? 'Test receipt printed successfully' : 'Failed to print test receipt'),
          backgroundColor: success ? Colors.green : Colors.red,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Printer Settings')),
      body: Consumer<PrinterManager>(
        builder: (context, printerManager, child) {
          return SingleChildScrollView(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Printer Type Selection
                const Text(
                  'Printer Type',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 8),
                Card(
                  child: Column(
                    children: [
                      RadioListTile<PrinterType>(
                        title: const Text('Bluetooth Printer'),
                        subtitle: const Text('External Bluetooth thermal printers'),
                        value: PrinterType.bluetooth,
                        groupValue: printerManager.selectedType,
                        onChanged: (value) {
                          if (value != null) {
                            printerManager.switchPrinterType(value);
                          }
                        },
                      ),
                      RadioListTile<PrinterType>(
                        title: const Text('Sunmi Built-in Printer'),
                        subtitle: const Text('For Sunmi Android devices with built-in printer'),
                        value: PrinterType.sunmi,
                        groupValue: printerManager.selectedType,
                        onChanged: (value) {
                          if (value != null) {
                            printerManager.switchPrinterType(value);
                          }
                        },
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 24),

                // Connection Status Card
                Card(
                  color: printerManager.isConnected ? Colors.green.shade50 : Colors.grey.shade100,
                  child: Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Icon(
                              printerManager.isConnected ? Icons.check_circle : Icons.cancel,
                              color: printerManager.isConnected ? Colors.green : Colors.grey,
                              size: 24,
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    printerManager.isConnected ? 'Connected' : 'Not Connected',
                                    style: TextStyle(
                                      fontSize: 18,
                                      fontWeight: FontWeight.bold,
                                      color: printerManager.isConnected ? Colors.green : Colors.grey,
                                    ),
                                  ),
                                  Text(
                                    printerManager.selectedType == PrinterType.bluetooth
                                        ? 'Bluetooth Printer'
                                        : 'Sunmi Printer',
                                    style: const TextStyle(fontSize: 14, color: Colors.black54),
                                  ),
                                  if (printerManager.selectedType == PrinterType.bluetooth &&
                                      printerManager.bluetoothService.connectedPrinter != null)
                                    Text(
                                      printerManager.bluetoothService.connectedPrinter!.name,
                                      style: const TextStyle(fontSize: 14, color: Colors.black87),
                                    ),
                                ],
                              ),
                            ),
                            if (printerManager.isConnected)
                              IconButton(
                                icon: const Icon(Icons.close, color: Colors.red),
                                onPressed: _disconnect,
                                tooltip: 'Disconnect',
                              ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        Text(
                          printerManager.connectionStatus,
                          style: const TextStyle(fontSize: 12, color: Colors.black54),
                        ),
                      ],
                    ),
                  ),
                ),

                const SizedBox(height: 24),

                // Paper Size Selection
                const Text(
                  'Paper Size',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Expanded(
                      child: RadioListTile<int>(
                        title: const Text('58mm'),
                        value: 58,
                        groupValue: printerManager.paperSize,
                        onChanged: (value) {
                          if (value != null) {
                            printerManager.setPaperSize(value);
                          }
                        },
                        contentPadding: EdgeInsets.zero,
                      ),
                    ),
                    Expanded(
                      child: RadioListTile<int>(
                        title: const Text('80mm'),
                        value: 80,
                        groupValue: printerManager.paperSize,
                        onChanged: (value) {
                          if (value != null) {
                            printerManager.setPaperSize(value);
                          }
                        },
                        contentPadding: EdgeInsets.zero,
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 24),

                // Printer-specific controls
                if (printerManager.selectedType == PrinterType.bluetooth) ...[
                  // Bluetooth Scan Button
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      onPressed: _scanForPrinters,
                      icon: const Icon(Icons.bluetooth_searching),
                      label: const Text('Scan for Bluetooth Printers'),
                      style: ElevatedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 12),
                      ),
                    ),
                  ),

                  const SizedBox(height: 16),

                  // Available Bluetooth Printers List
                  if (printerManager.bluetoothService.availablePrinters.isNotEmpty) ...[
                    const Text(
                      'Available Printers',
                      style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 8),
                    ...printerManager.bluetoothService.availablePrinters.map((printer) {
                      final isConnected = 
                          printerManager.bluetoothService.connectedPrinter?.macAdress == printer.macAdress;
                      return Card(
                        color: isConnected ? Colors.green.shade50 : null,
                        child: ListTile(
                          leading: Icon(
                            Icons.print,
                            color: isConnected ? Colors.green : Colors.grey,
                          ),
                          title: Text(
                            printer.name,
                            style: TextStyle(
                              fontWeight: isConnected ? FontWeight.bold : FontWeight.normal,
                            ),
                          ),
                          subtitle: Text(printer.macAdress),
                          trailing: isConnected
                              ? const Icon(Icons.check_circle, color: Colors.green)
                              : ElevatedButton(
                                  onPressed: () => _connectToPrinter(printer),
                                  child: const Text('Connect'),
                                ),
                        ),
                      );
                    }).toList(),
                  ],
                ] else if (printerManager.selectedType == PrinterType.sunmi) ...[
                  // Sunmi Connect Button
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      onPressed: _connectToSunmi,
                      icon: const Icon(Icons.print),
                      label: const Text('Check Sunmi Printer'),
                      style: ElevatedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 12),
                      ),
                    ),
                  ),
                  
                  const SizedBox(height: 16),
                  
                  Card(
                    color: Colors.blue[50],
                    child: Padding(
                      padding: EdgeInsets.all(16.0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Icon(Icons.info_outline, color: Colors.blue),
                              SizedBox(width: 8),
                              Text(
                                'About Sunmi Printers',
                                style: TextStyle(fontWeight: FontWeight.bold),
                              ),
                            ],
                          ),
                          SizedBox(height: 8),
                          Text(
                            'Sunmi devices have a built-in thermal printer. '
                            'No pairing or scanning is required. Simply tap "Check Sunmi Printer" '
                            'to verify the printer is available.',
                            style: TextStyle(fontSize: 14),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],

                const SizedBox(height: 24),

                // Test Print Button
                if (printerManager.isConnected)
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      onPressed: _testPrint,
                      icon: const Icon(Icons.print),
                      label: const Text('Print Test Receipt'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.green,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 12),
                      ),
                    ),
                  ),

                const SizedBox(height: 24),

                // Info Section
                const Text(
                  'Supported Printers',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 8),
                const Text('• Bluetooth thermal printers (58mm, 80mm)'),
                const Text('• ESC/POS compatible printers'),
                const Text('• Portable mobile receipt printers'),
                const Text('• Sunmi V2, V2 Pro, T2, T2 Mini, and similar devices'),
                const SizedBox(height: 16),
                const Text(
                  'Instructions:',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                ),
                const SizedBox(height: 8),
                const Text('Bluetooth Printer:'),
                const Text('1. Pair your Bluetooth printer in phone settings first'),
                const Text('2. Select "Bluetooth Printer" type above'),
                const Text('3. Tap "Scan for Printers" to find paired printers'),
                const Text('4. Select your printer from the list'),
                const SizedBox(height: 8),
                const Text('Sunmi Printer:'),
                const Text('1. Make sure you\'re using a Sunmi device'),
                const Text('2. Select "Sunmi Built-in Printer" type above'),
                const Text('3. Tap "Check Sunmi Printer" to verify'),
                const SizedBox(height: 8),
                const Text('5. Choose paper size (58mm or 80mm)'),
                const Text('6. Test print to verify connection'),
                const Text('7. Receipts will print automatically after sales'),
              ],
            ),
          );
        },
      ),
    );
  }
}
