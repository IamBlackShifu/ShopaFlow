import 'package:flutter/material.dart';
import 'package:quick_print/quick_print.dart';

class PrinterSettingsPage extends StatefulWidget {
  const PrinterSettingsPage({Key? key}) : super(key: key);

  @override
  State<PrinterSettingsPage> createState() => _PrinterSettingsPageState();
}

class _PrinterSettingsPageState extends State<PrinterSettingsPage> {
  List<PrinterDevice> _devices = [];
  PrinterDevice? _selectedDevice;
  bool _scanning = false;
  String? _status;

  Future<void> _scan() async {
    setState(() {
      _scanning = true;
      _status = null;
    });
    try {
      final devices = await QuickPrint.instance.scanPrinters();
      setState(() {
        _devices = devices;
        _scanning = false;
      });
    } catch (e) {
      setState(() {
        _status = 'Scan failed: $e';
        _scanning = false;
      });
    }
  }

  Future<void> _connect(PrinterDevice device) async {
    setState(() {
      _status = 'Connecting...';
    });
    try {
      await QuickPrint.instance.connect(device);
      setState(() {
        _selectedDevice = device;
        _status = 'Connected to ${device.name}';
      });
    } catch (e) {
      setState(() {
        _status = 'Connection failed: $e';
      });
    }
  }

  Future<void> _testPrint() async {
    if (_selectedDevice == null) return;
    try {
      await QuickPrint.instance.printText('Test print from ShopaFlow!');
      setState(() {
        _status = 'Test print sent.';
      });
    } catch (e) {
      setState(() {
        _status = 'Print failed: $e';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Printer Settings')),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            ElevatedButton(
              onPressed: _scanning ? null : _scan,
              child: Text(_scanning ? 'Scanning...' : 'Scan for Printers'),
            ),
            const SizedBox(height: 16),
            if (_devices.isNotEmpty)
              ...[
                const Text('Available Printers:'),
                ..._devices.map((d) => ListTile(
                      title: Text(d.name ?? 'Unknown'),
                      subtitle: Text(d.address ?? ''),
                      trailing: _selectedDevice == d
                          ? const Icon(Icons.check, color: Colors.green)
                          : null,
                      onTap: () => _connect(d),
                    )),
              ],
            if (_selectedDevice != null)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 16),
                child: ElevatedButton(
                  onPressed: _testPrint,
                  child: const Text('Test Print'),
                ),
              ),
            if (_status != null)
              Padding(
                padding: const EdgeInsets.only(top: 16),
                child: Text(_status!, style: const TextStyle(color: Colors.blue)),
              ),
          ],
        ),
      ),
    );
  }
}
