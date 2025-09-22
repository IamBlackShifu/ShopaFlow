import 'package:flutter/material.dart';

import 'package:flutter/material.dart';

class PrinterSettingsPage extends StatefulWidget {
  const PrinterSettingsPage({Key? key}) : super(key: key);

  @override
  State<PrinterSettingsPage> createState() => _PrinterSettingsPageState();
}

class _PrinterSettingsPageState extends State<PrinterSettingsPage> {
  String? _status;

  Future<void> _testPrint() async {
    setState(() {
      _status = 'Printing uses the system print dialog. Test by completing a sale.';
    });
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
            const Text(
              'Printing Configuration',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            const Text(
              'This app uses the standard Flutter printing system. When you complete a sale, a print dialog will appear allowing you to select your printer and print settings.',
              style: TextStyle(fontSize: 14),
            ),
            const SizedBox(height: 16),
            const Text(
              'Supported printers:',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 8),
            const Text('• Bluetooth thermal printers'),
            const Text('• USB printers'),
            const Text('• Network printers'),
            const Text('• System default printers'),
            const SizedBox(height: 24),
            ElevatedButton(
              onPressed: _testPrint,
              child: const Text('Test Print Info'),
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
