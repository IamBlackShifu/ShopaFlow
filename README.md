# ShopaFlow

A modern mobile Point of Sale (POS) system designed for shops, bars, and wholesalers. ShopaFlow provides offline-first functionality with cloud synchronization, inventory management, customer loyalty programs, and integrated payment processing.

## Features

### 🚀 Core POS Functionality
- **Offline-First Design**: Works seamlessly without internet connection
- **Product Management**: Easy product catalog with search and filtering
- **Sales Processing**: Quick checkout with shopping cart functionality
- **Receipt Generation**: Professional receipts with customizable templates

### 📦 Inventory Management
- **Real-time Stock Tracking**: Monitor inventory levels automatically
- **Low Stock Alerts**: Get notified when products are running low
- **CSV Import/Export**: Bulk product management and reporting
- **Currency Conversion**: USD ⇆ ZWL exchange rate support

### 👥 Customer Management
- **Customer Database**: Track customer information and purchase history
- **Loyalty Programs**: Points-based rewards and customer retention
- **Analytics Dashboard**: Business insights and performance metrics

### 💳 Payment Integration
- **Mobile Money**: EcoCash and OneMoney payment processing
- **Multiple Payment Methods**: Cash, card, and mobile payments
- **Hardware Support**: Bluetooth printers and barcode scanners

## Tech Stack

### Frontend
- **Framework**: Flutter 3.x (Cross-platform mobile app)
- **State Management**: Provider/Riverpod
- **Local Database**: SQLite with sqflite
- **UI Design**: Material Design 3
- **Offline Support**: Background sync service

### Backend
- **Runtime**: Node.js with Express.js
- **Database**: PostgreSQL (Supabase) or Firestore (Firebase)
- **Authentication**: JWT with refresh tokens
- **API**: RESTful endpoints with real-time sync
- **Cloud Storage**: Supabase/Firebase for data synchronization

### Infrastructure
- **Cloud Provider**: Supabase or Firebase
- **Payment APIs**: EcoCash, OneMoney integrations
- **Hardware**: Bluetooth thermal printers, barcode scanners
- **Deployment**: Mobile app stores and cloud hosting

## Project Structure

```
ShopaFlow/
├── lib/                          # Flutter app source code
│   ├── main.dart                 # App entry point
│   ├── services/                 # Business logic services
│   │   ├── db_service.dart       # Local SQLite database
│   │   ├── sync_service.dart     # Cloud synchronization
│   │   └── payment_service.dart  # Payment processing
│   ├── models/                   # Data models
│   ├── screens/                  # UI screens
│   └── widgets/                  # Reusable UI components
├── backend/                      # Node.js backend API
│   ├── server.js                 # Express server
│   ├── routes/                   # API endpoints
│   ├── models/                   # Database models
│   └── middleware/               # Authentication & validation
├── docs/                         # Documentation
└── test/                         # Test files
```

## Prerequisites

### For Flutter Development
- Flutter SDK 3.10.0 or higher
- Dart SDK 3.0.0 or higher
- Android Studio / VS Code with Flutter extensions
- Android SDK for Android development
- Xcode for iOS development (macOS only)

### For Backend Development
- Node.js 18.0.0 or higher
- npm or yarn package manager
- PostgreSQL 14+ (for local development)
- Supabase or Firebase account

### For Hardware Integration
- Android device with Bluetooth support
- Bluetooth thermal printer (compatible models)
- Barcode scanner (USB or Bluetooth)

## Quick Start

### 1. Clone the Repository
```bash
git clone https://github.com/IamBlackShifu/ShopaFlow.git
cd ShopaFlow
```

### 2. Setup Flutter App
```bash
# Install Flutter dependencies
flutter pub get

# Generate required files (if any)
flutter packages pub run build_runner build

# Run the app
flutter run
```

### 3. Setup Backend Server
```bash
# Navigate to backend directory
cd backend

# Install Node.js dependencies
npm install

# Set up environment variables
cp .env.example .env
# Edit .env with your configuration

# Start the development server
npm run dev
```

### 4. Configure Cloud Services

#### Option A: Supabase Setup
1. Create a new project at [supabase.com](https://supabase.com)
2. Copy your project URL and anon key
3. Update the configuration in your app

#### Option B: Firebase Setup
1. Create a new project at [console.firebase.google.com](https://console.firebase.google.com)
2. Enable Authentication and Firestore
3. Download and add configuration files

## Development

### Running Tests
```bash
# Flutter tests
flutter test

# Backend tests
cd backend && npm test
```

### Building for Production
```bash
# Android APK
flutter build apk --release

# Android App Bundle
flutter build appbundle --release

# iOS (macOS only)
flutter build ios --release
```

### Code Quality
```bash
# Flutter code analysis
flutter analyze

# Code formatting
flutter format .

# Backend linting
cd backend && npm run lint
```

## Configuration

### Environment Variables
Create a `.env` file in the backend directory:
```env
# Server Configuration
PORT=3000
NODE_ENV=development

# Database Configuration
DATABASE_URL=your_database_url

# Authentication
JWT_SECRET=your_jwt_secret
JWT_REFRESH_SECRET=your_jwt_refresh_secret

# Cloud Services
SUPABASE_URL=your_supabase_url
SUPABASE_ANON_KEY=your_supabase_anon_key

# Payment APIs
ECOCASH_API_KEY=your_ecocash_api_key
ONEMONEY_API_KEY=your_onemoney_api_key

# Exchange Rate API
EXCHANGE_RATE_API_KEY=your_exchange_rate_api_key
```

## Hardware Setup

### Bluetooth Printer Configuration
1. Pair your Bluetooth thermal printer with the device
2. Configure printer settings in the app
3. Test printing functionality

### Barcode Scanner Setup
1. Connect USB or pair Bluetooth barcode scanner
2. Configure scanner settings in the app
3. Test barcode scanning functionality

## Contributing

1. Fork the repository
2. Create a feature branch (`git checkout -b feature/amazing-feature`)
3. Commit your changes (`git commit -m 'Add amazing feature'`)
4. Push to the branch (`git push origin feature/amazing-feature`)
5. Open a Pull Request

## Roadmap

See [ROADMAP.md](ROADMAP.md) for detailed development phases and milestones.

## License

This project is licensed under the MIT License - see the [LICENSE](LICENSE) file for details.

## Support

- 📧 Email: support@shopaflow.com
- 📱 WhatsApp: +263 XXX XXX XXX
- 🌐 Website: https://shopaflow.com
- 📖 Documentation: https://docs.shopaflow.com

## Acknowledgments

- Flutter team for the amazing cross-platform framework
- Supabase/Firebase for backend infrastructure
- The open-source community for various packages and tools