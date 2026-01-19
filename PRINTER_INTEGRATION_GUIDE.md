# Printer Integration Guide

## Overview
ShopaFlow now supports **two types of printers**:
1. **Bluetooth Thermal Printers** - External Bluetooth printers (existing functionality)
2. **Sunmi Built-in Printers** - For Sunmi Android devices with integrated printers (new feature)

## Architecture

### Core Components

1. **PrinterServiceInterface** (`lib/services/printer_service_interface.dart`)
   - Base interface that all printer services implement
   - Ensures consistent API across different printer types

2. **BluetoothPrinterService** (`lib/services/bluetooth_printer_service.dart`)
   - Handles external Bluetooth thermal printers
   - Supports scanning, pairing, and connecting to Bluetooth devices
   - Compatible with ESC/POS printers (58mm and 80mm)

3. **SunmiPrinterService** (`lib/services/sunmi_printer_service.dart`)
   - Handles Sunmi built-in printers
   - Automatically detects Sunmi devices
   - No pairing or scanning required

4. **PrinterManager** (`lib/services/printer_manager.dart`)
   - Unified manager that coordinates both printer types
   - Allows switching between printer types
   - Provides single API for printing operations

## How to Use

### For Users

#### Setting Up Bluetooth Printer
1. Open **Settings** → **Printer Settings**
2. Select **"Bluetooth Printer"** as the printer type
3. Ensure your Bluetooth printer is paired in Android settings
4. Tap **"Scan for Bluetooth Printers"**
5. Select your printer from the list
6. Choose paper size (58mm or 80mm)
7. Tap **"Print Test Receipt"** to verify

#### Setting Up Sunmi Printer
1. Open **Settings** → **Printer Settings**
2. Select **"Sunmi Built-in Printer"** as the printer type
3. Tap **"Check Sunmi Printer"** to verify availability
4. Choose paper size (58mm or 80mm)
5. Tap **"Print Test Receipt"** to verify

### For Developers

#### Using the Printer in Your Code

```dart
// Get the printer manager
final printerManager = context.read<PrinterManager>();

// Check if printer is connected
if (printerManager.isConnected) {
  // Print a receipt
  await printerManager.printReceipt(
    receiptNumber: 'REC-001',
    saleDate: DateTime.now(),
    items: [
      {'name': 'Item 1', 'quantity': 2, 'total_price': 20.0},
      {'name': 'Item 2', 'quantity': 1, 'total_price': 15.0},
    ],
    total: 35.0,
    paymentMethod: 'Cash',
    storeName: 'My Store',
    storeAddress: '123 Main St',
  );
}
```

#### Switching Printer Types Programmatically

```dart
final printerManager = context.read<PrinterManager>();

// Switch to Bluetooth
await printerManager.switchPrinterType(PrinterType.bluetooth);

// Switch to Sunmi
await printerManager.switchPrinterType(PrinterType.sunmi);
```

#### Accessing Specific Printer Services

```dart
final printerManager = context.read<PrinterManager>();

// Access Bluetooth-specific features
final bluetoothPrinters = printerManager.bluetoothService.availablePrinters;

// Access Sunmi-specific features
final sunmiAvailable = await printerManager.sunmiService.checkAvailability();
```

## Key Features

### Maintained Functionality
- ✅ All existing Bluetooth printing capabilities preserved
- ✅ ESC/POS thermal printer support
- ✅ 58mm and 80mm paper sizes
- ✅ Test receipt printing
- ✅ Sales receipt printing
- ✅ PDF fallback when no printer connected

### New Functionality
- ✅ Sunmi device detection
- ✅ Built-in printer support for Sunmi devices
- ✅ Easy printer type switching
- ✅ Unified API for both printer types
- ✅ Same receipt formatting across both printer types

## Supported Devices

### Bluetooth Printers
- ESC/POS compatible thermal printers
- 58mm and 80mm paper sizes
- Mobile portable receipt printers

### Sunmi Devices
- Sunmi V2, V2 Pro
- Sunmi T2, T2 Mini
- Sunmi P2
- Other Sunmi devices with built-in printers

## Dependencies

```yaml
print_bluetooth_thermal: ^1.1.1  # Bluetooth printing
sunmi_printer_plus: ^4.1.1       # Sunmi built-in printer
esc_pos_utils_plus: ^2.0.1       # Receipt formatting
```

## Testing

### Testing Bluetooth Printer
1. Ensure a Bluetooth thermal printer is paired
2. Launch the app
3. Navigate to Printer Settings
4. Select Bluetooth printer type
5. Scan and connect to your printer
6. Print a test receipt

### Testing Sunmi Printer
1. Run the app on a Sunmi device
2. Navigate to Printer Settings
3. Select Sunmi printer type
4. Check printer availability
5. Print a test receipt

### Testing Without Hardware
The app will automatically fall back to PDF printing if no printer is connected, so you can test the full flow without physical printer hardware.

## Troubleshooting

### Bluetooth Printer Issues
- **Can't find printer**: Ensure it's paired in Android Bluetooth settings first
- **Connection fails**: Move printer closer to device, restart printer
- **Nothing prints**: Check printer has paper and is powered on

### Sunmi Printer Issues
- **Printer not available**: Confirm you're on a Sunmi device with built-in printer
- **Print quality issues**: Check paper is loaded correctly
- **Printer not responding**: Restart the app or device

## Future Enhancements
- Support for more printer types (USB, Network)
- Custom receipt templates
- Logo/image printing on Sunmi devices
- Barcode/QR code printing
- Multi-language receipt support
