import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:print_bluetooth_thermal/print_bluetooth_thermal.dart';
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
      context.read<BluetoothPrinterService>().checkConnectionStatus();
    });
  }

  Future<void> _scanForPrinters() async {
    await context.read<BluetoothPrinterService>().scanForPrinters();
  }

  Future<void> _connectToPrinter(BluetoothInfo printer) async {
    final success = await context.read<BluetoothPrinterService>().connectToPrinter(printer);
    if (success && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Connected to ${printer.name}'), backgroundColor: Colors.green),
      );
    }
  }

  Future<void> _disconnect() async {
    await context.read<BluetoothPrinterService>().disconnect();
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Disconnected from printer'), backgroundColor: Colors.orange),
      );
    }
  }

  Future<void> _testPrint() async {
    final service = context.read<BluetoothPrinterService>();
    if (!service.isConnected) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please connect to a printer first'), backgroundColor: Colors.red),
      );
      return;
    }

    final store = context.read<StoreInfoModel>();
    final success = await service.printTestReceipt(storeName: store.name);
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
      appBar: AppBar(title: const Text('Bluetooth Printer Settings')),
      body: Consumer<BluetoothPrinterService>(
        builder: (context, printerService, child) {
          return SingleChildScrollView(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Connection Status Card
                Card(
                  color: printerService.isConnected ? Colors.green.shade50 : Colors.grey.shade100,
                  child: Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Icon(
                              printerService.isConnected ? Icons.check_circle : Icons.cancel,
                              color: printerService.isConnected ? Colors.green : Colors.grey,
                              size: 24,
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    printerService.isConnected ? 'Connected' : 'Not Connected',
                                    style: TextStyle(
                                      fontSize: 18,
                                      fontWeight: FontWeight.bold,
                                      color: printerService.isConnected ? Colors.green : Colors.grey,
                                    ),
                                  ),
                                  if (printerService.connectedPrinter != null)
                                    Text(
                                      printerService.connectedPrinter!.name,
                                      style: const TextStyle(fontSize: 14, color: Colors.black87),
                                    ),
                                ],
                              ),
                            ),
                            if (printerService.isConnected)
                              IconButton(
                                icon: const Icon(Icons.close, color: Colors.red),
                                onPressed: _disconnect,
                                tooltip: 'Disconnect',
                              ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        Text(
                          printerService.connectionStatus,
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
                        groupValue: printerService.paperSize,
                        onChanged: (value) {
                          if (value != null) {
                            printerService.setPaperSize(value);
                          }
                        },
                        contentPadding: EdgeInsets.zero,
                      ),
                    ),
                    Expanded(
                      child: RadioListTile<int>(
                        title: const Text('80mm'),
                        value: 80,
                        groupValue: printerService.paperSize,
                        onChanged: (value) {
                          if (value != null) {
                            printerService.setPaperSize(value);
                          }
                        },
                        contentPadding: EdgeInsets.zero,
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 24),

                // Scan Button
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    onPressed: _scanForPrinters,
                    icon: const Icon(Icons.bluetooth_searching),
                    label: const Text('Scan for Printers'),
                    style: ElevatedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 12),
                    ),
                  ),
                ),

                const SizedBox(height: 16),

                // Available Printers List
                if (printerService.availablePrinters.isNotEmpty) ...[
                  const Text(
                    'Available Printers',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 8),
                  ...printerService.availablePrinters.map((printer) {
                    final isConnected = printerService.connectedPrinter?.macAdress == printer.macAdress;
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

                const SizedBox(height: 24),

                // Test Print Button
                if (printerService.isConnected)
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
                const SizedBox(height: 16),
                const Text(
                  'Instructions:',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                ),
                const SizedBox(height: 8),
                const Text('1. Pair your Bluetooth printer in phone settings first'),
                const Text('2. Tap "Scan for Printers" to find paired printers'),
                const Text('3. Select your printer from the list'),
                const Text('4. Choose paper size (58mm or 80mm)'),
                const Text('5. Test print to verify connection'),
                const Text('6. Receipts will print automatically after sales'),
              ],
            ),
          );
        },
      ),
    );
  }
}
