import 'package:printing/printing.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'dart:async';
import 'dart:io';
import 'dart:convert';
import 'package:share_plus/share_plus.dart';
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:crypto/crypto.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'firebase_options.dart';
import 'services/db_service.dart';
import 'services/firebase_sync_service.dart';
import 'services/printer_manager.dart';
import 'printer_settings.dart';
import 'package:csv/csv.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:pdf/pdf.dart';

// ================== MODELS & PROVIDERS ==================
class ExchangeRateModel extends ChangeNotifier {
  double _rate = 320; // default
  double get rate => _rate;
  static const _prefsKey = 'exchange_rate_usd_zwl';

  Future<void> load() async {
    final prefs = await SharedPreferences.getInstance();
    _rate = prefs.getDouble(_prefsKey) ?? 320;
    notifyListeners();
  }

  Future<void> update(double newRate) async {
    _rate = newRate;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setDouble(_prefsKey, newRate);
    notifyListeners();
  }
}

class StoreInfoModel extends ChangeNotifier {
  String _name = 'My Shop';
  String _address = '123 Main Street';
  static const _nameKey = 'store_name';
  static const _addrKey = 'store_address';

  String get name => _name;
  String get address => _address;

  Future<void> load() async {
    final prefs = await SharedPreferences.getInstance();
    _name = prefs.getString(_nameKey) ?? _name;
    _address = prefs.getString(_addrKey) ?? _address;
    notifyListeners();
  }

  Future<void> updateName(String name) async {
    _name = name.trim().isEmpty ? _name : name.trim();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_nameKey, _name);
    notifyListeners();
  }

  Future<void> updateAddress(String address) async {
    _address = address.trim().isEmpty ? _address : address.trim();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_addrKey, _address);
    notifyListeners();
  }
}

class ThemeModel extends ChangeNotifier {
  Color _primaryColor = Colors.green;
  static const _colorKey = 'app_primary_color';

  Color get primaryColor => _primaryColor;
  
  final List<Color> availableColors = [
    Colors.green,
    Colors.blue,
    Colors.purple,
    Colors.orange,
    Colors.teal,
    Colors.indigo,
    Colors.red,
    Colors.brown,
  ];

  Future<void> load() async {
    final prefs = await SharedPreferences.getInstance();
    final colorValue = prefs.getInt(_colorKey);
    if (colorValue != null) {
      _primaryColor = Color(colorValue);
      notifyListeners();
    }
  }

  Future<void> updateColor(Color color) async {
    _primaryColor = color;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_colorKey, color.toARGB32());
    notifyListeners();
  }
}

class SetupStatusModel extends ChangeNotifier {
  bool _isSetupCompleted = false;
  static const _setupKey = 'app_setup_completed';

  bool get isSetupCompleted => _isSetupCompleted;

  Future<void> load() async {
    final prefs = await SharedPreferences.getInstance();
    _isSetupCompleted = prefs.getBool(_setupKey) ?? false;
    notifyListeners();
  }

  Future<void> markSetupCompleted() async {
    _isSetupCompleted = true;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_setupKey, true);
    notifyListeners();
  }
}

class AuthSessionModel extends ChangeNotifier {
  static const _loggedInKey = 'auth_logged_in';
  static const _ownerNameKey = 'auth_owner_name';
  static const _emailKey = 'auth_email';
  static const _passwordKey = 'auth_password';
  static const _companyNameKey = 'auth_company_name';
  static const _phoneKey = 'auth_phone';
  static const _userIdKey = 'auth_user_id';
  static const _companyIdKey = 'auth_company_id';
  static const _storeIdKey = 'auth_store_id';
  static const _registerIdKey = 'auth_register_id';
  static const _roleKey = 'auth_role';

  bool _isAuthenticated = false;
  String _userId = DatabaseService.defaultUserId;
  String _companyId = DatabaseService.defaultCompanyId;
  String _storeId = DatabaseService.defaultStoreId;
  String _registerId = DatabaseService.defaultRegisterId;
  String _role = 'owner';
  String _ownerName = '';
  String _email = '';
  String _companyName = '';
  String _phone = '';

  bool get isAuthenticated => _isAuthenticated;
  String get userId => _userId;
  String get companyId => _companyId;
  String get storeId => _storeId;
  String get registerId => _registerId;
  String get role => _role;
  String get ownerName => _ownerName;
  String get email => _email;
  String get companyName => _companyName;
  String get phone => _phone;
  bool get canSell => _hasAnyRole(const {'owner', 'admin', 'manager', 'cashier'});
  bool get canManageInventory => _hasAnyRole(const {'owner', 'admin', 'manager'});
  bool get canViewReports => _hasAnyRole(const {'owner', 'admin', 'manager'});
  bool get canManageSettings => _hasAnyRole(const {'owner', 'admin'});

  bool _hasAnyRole(Set<String> roles) => roles.contains(_role);

  String _hashPassword(String password) {
    return sha256.convert(utf8.encode(password)).toString();
  }

  String _stableId(String prefix, String seed, [int start = 0]) {
    final digest = sha256.convert(utf8.encode(seed.trim().toLowerCase())).toString();
    return '${prefix}_${digest.substring(start, start + 20)}';
  }

  String _companyIdForUser(String uid, String? savedCompanyId) {
    if (savedCompanyId == null || savedCompanyId.trim().isEmpty || savedCompanyId == DatabaseService.defaultCompanyId) {
      return _stableId('cmp', uid);
    }
    return savedCompanyId;
  }

  String _storeIdForCompany(String companyId, String? savedStoreId) {
    if (savedStoreId == null || savedStoreId.trim().isEmpty || savedStoreId == DatabaseService.defaultStoreId) {
      return _stableId('store', companyId);
    }
    return savedStoreId;
  }

  String _registerIdForStore(String storeId, String? savedRegisterId) {
    if (savedRegisterId == null || savedRegisterId.trim().isEmpty || savedRegisterId == DatabaseService.defaultRegisterId) {
      return '${storeId}_register';
    }
    return savedRegisterId;
  }

  void configureDatabase(DatabaseService db) {
    db.configureTenant(
      companyId: _companyId,
      storeId: _storeId,
      registerId: _registerId,
      userId: _userId,
      role: _role,
    );
  }

  Future<void> _loadFirebaseMembership(String uid) async {
    try {
      final memberships = await FirebaseFirestore.instance
          .collection('user_memberships')
          .doc(uid)
          .collection('companies')
          .limit(1)
          .get();
      Map<String, dynamic> data;
      if (memberships.docs.isNotEmpty) {
        final doc = memberships.docs.first;
        data = doc.data();
        _companyId = doc.id;
      } else {
        final companyUsers = await FirebaseFirestore.instance
            .collectionGroup('users')
            .where('id', isEqualTo: uid)
            .limit(1)
            .get();
        if (companyUsers.docs.isEmpty) return;
        final doc = companyUsers.docs.first;
        data = doc.data();
        _companyId = doc.reference.parent.parent?.id ?? (data['company_id'] ?? _companyId).toString();
      }
      _storeId = (data['store_id'] ?? _stableId('store', _companyId)).toString();
      _registerId = (data['register_id'] ?? '${_storeId}_register').toString();
      _role = (data['role'] ?? 'cashier').toString().toLowerCase();
      _companyName = (data['company_name'] ?? _companyName).toString();
      if (_companyName.isEmpty) {
        final companyDoc = await FirebaseFirestore.instance.collection('companies').doc(_companyId).get();
        _companyName = (companyDoc.data()?['name'] ?? _companyName).toString();
      }
      final userDoc = await FirebaseFirestore.instance
          .collection('companies')
          .doc(_companyId)
          .collection('users')
          .doc(uid)
          .get();
      final userData = userDoc.data();
      if (userData != null) {
        _ownerName = (userData['name'] ?? _ownerName).toString();
        _email = (userData['email'] ?? _email).toString();
        _role = (userData['role'] ?? _role).toString().toLowerCase();
        _storeId = (userData['store_id'] ?? _storeId).toString();
        _registerId = (userData['register_id'] ?? _registerId).toString();
      }
    } catch (_) {
      // Keep the locally persisted tenant if the cloud membership mirror is not available yet.
    }
  }

  Future<void> load() async {
    final prefs = await SharedPreferences.getInstance();
    _isAuthenticated = prefs.getBool(_loggedInKey) ?? false;
    _ownerName = prefs.getString(_ownerNameKey) ?? '';
    _email = prefs.getString(_emailKey) ?? '';
    _companyName = prefs.getString(_companyNameKey) ?? '';
    _phone = prefs.getString(_phoneKey) ?? '';
    _userId = prefs.getString(_userIdKey) ??
        (Firebase.apps.isNotEmpty ? FirebaseAuth.instance.currentUser?.uid : null) ??
        DatabaseService.defaultUserId;
    _companyId = _companyIdForUser(_userId, prefs.getString(_companyIdKey));
    _storeId = _storeIdForCompany(_companyId, prefs.getString(_storeIdKey));
    _registerId = _registerIdForStore(_storeId, prefs.getString(_registerIdKey));
    _role = prefs.getString(_roleKey) ?? 'owner';
    if (Firebase.apps.isNotEmpty && FirebaseAuth.instance.currentUser != null) {
      await _loadFirebaseMembership(_userId);
      await prefs.setString(_companyIdKey, _companyId);
      await prefs.setString(_storeIdKey, _storeId);
      await prefs.setString(_registerIdKey, _registerId);
      await prefs.setString(_roleKey, _role);
      await prefs.setString(_companyNameKey, _companyName);
    }
    notifyListeners();
  }

  Future<String?> login({
    required String email,
    required String password,
  }) async {
    if (Firebase.apps.isNotEmpty) {
      try {
        final credential = await FirebaseAuth.instance.signInWithEmailAndPassword(
          email: email.trim().toLowerCase(),
          password: password,
        );
        final prefs = await SharedPreferences.getInstance();
        _isAuthenticated = true;
        _userId = credential.user?.uid ?? DatabaseService.defaultUserId;
        _email = credential.user?.email ?? email.trim().toLowerCase();
        _ownerName = credential.user?.displayName ?? prefs.getString(_ownerNameKey) ?? '';
        _companyId = _companyIdForUser(_userId, prefs.getString(_companyIdKey));
        _storeId = _storeIdForCompany(_companyId, prefs.getString(_storeIdKey));
        _registerId = _registerIdForStore(_storeId, prefs.getString(_registerIdKey));
        _role = prefs.getString(_roleKey) ?? 'owner';
        _companyName = prefs.getString(_companyNameKey) ?? '';
        _phone = prefs.getString(_phoneKey) ?? '';
        await _loadFirebaseMembership(_userId);
        await prefs.setBool(_loggedInKey, true);
        await prefs.setString(_userIdKey, _userId);
        await prefs.setString(_companyIdKey, _companyId);
        await prefs.setString(_storeIdKey, _storeId);
        await prefs.setString(_registerIdKey, _registerId);
      await prefs.setString(_roleKey, _role);
      await prefs.setString(_emailKey, _email);
      await prefs.setString(_ownerNameKey, _ownerName);
      await prefs.setString(_companyNameKey, _companyName);
      notifyListeners();
        return null;
      } on FirebaseAuthException catch (error) {
        return error.message ?? 'Unable to sign in with Firebase.';
      }
    }

    final prefs = await SharedPreferences.getInstance();
    final savedEmail = prefs.getString(_emailKey);
    final savedPassword = prefs.getString(_passwordKey);

    if (savedEmail == null || savedPassword == null) {
      return 'No company account exists on this device yet.';
    }

    if (savedEmail.toLowerCase() != email.trim().toLowerCase() || savedPassword != _hashPassword(password)) {
      return 'Invalid email or password.';
    }

    _isAuthenticated = true;
    _userId = prefs.getString(_userIdKey) ?? DatabaseService.defaultUserId;
    _companyId = _companyIdForUser(_userId, prefs.getString(_companyIdKey));
    _storeId = _storeIdForCompany(_companyId, prefs.getString(_storeIdKey));
    _registerId = _registerIdForStore(_storeId, prefs.getString(_registerIdKey));
    _role = prefs.getString(_roleKey) ?? 'owner';
    _email = savedEmail;
    _ownerName = prefs.getString(_ownerNameKey) ?? '';
    _companyName = prefs.getString(_companyNameKey) ?? '';
    _phone = prefs.getString(_phoneKey) ?? '';
    await prefs.setBool(_loggedInKey, true);
    await prefs.setString(_userIdKey, _userId);
    notifyListeners();
    return null;
  }

  Future<String?> registerCompany({
    required String companyName,
    required String ownerName,
    required String email,
    required String phone,
    required String password,
  }) async {
    if (companyName.trim().isEmpty || ownerName.trim().isEmpty || email.trim().isEmpty || password.isEmpty) {
      return 'Please complete all required fields.';
    }
    if (!email.contains('@')) {
      return 'Enter a valid email address.';
    }
    if (password.length < 6) {
      return 'Password must be at least 6 characters.';
    }

    final prefs = await SharedPreferences.getInstance();
    if (Firebase.apps.isNotEmpty) {
      try {
        final credential = await FirebaseAuth.instance.createUserWithEmailAndPassword(
          email: email.trim().toLowerCase(),
          password: password,
        );
        await credential.user?.updateDisplayName(ownerName.trim());
        _userId = credential.user?.uid ?? DatabaseService.defaultUserId;
      } on FirebaseAuthException catch (error) {
        return error.message ?? 'Unable to create the Firebase account.';
      }
    } else {
      _userId = _stableId('usr', email);
    }

    _isAuthenticated = true;
    _companyId = _stableId('cmp', _userId);
    _storeId = _stableId('store', _companyId);
    _registerId = '${_storeId}_register';
    _role = 'owner';
    _companyName = companyName.trim();
    _ownerName = ownerName.trim();
    _email = email.trim().toLowerCase();
    _phone = phone.trim();

    await prefs.setBool(_loggedInKey, true);
    await prefs.setString(_userIdKey, _userId);
    await prefs.setString(_companyIdKey, _companyId);
    await prefs.setString(_storeIdKey, _storeId);
    await prefs.setString(_registerIdKey, _registerId);
    await prefs.setString(_roleKey, _role);
    await prefs.setString(_companyNameKey, _companyName);
    await prefs.setString(_ownerNameKey, _ownerName);
    await prefs.setString(_emailKey, _email);
    await prefs.setString(_phoneKey, _phone);
    await prefs.setString(_passwordKey, _hashPassword(password));
    notifyListeners();
    return null;
  }

  Future<void> logout() async {
    final prefs = await SharedPreferences.getInstance();
    if (Firebase.apps.isNotEmpty) {
      await FirebaseAuth.instance.signOut();
    }
    _isAuthenticated = false;
    await prefs.setBool(_loggedInKey, false);
    notifyListeners();
  }
}

enum BusinessMode { shop, butchery }

String businessModeLabel(BusinessMode mode) {
  return mode == BusinessMode.butchery ? 'Butchery' : 'Shop';
}

String formatDecimal(num value, {int decimals = 2}) {
  final asDouble = value.toDouble();
  if ((asDouble - asDouble.roundToDouble()).abs() < 0.000001) {
    return asDouble.round().toString();
  }
  final fixed = asDouble.toStringAsFixed(decimals);
  return fixed.replaceFirst(RegExp(r'0+$'), '').replaceFirst(RegExp(r'\.$'), '');
}

String formatQuantityDisplay(double qty, {required bool isWeight}) {
  final formatted = formatDecimal(qty, decimals: 3);
  return isWeight ? '$formatted kg' : formatted;
}

double asDouble(dynamic value, {double fallback = 0.0}) {
  if (value is num) return value.toDouble();
  if (value is String) return double.tryParse(value) ?? fallback;
  return fallback;
}

class BusinessModeModel extends ChangeNotifier {
  BusinessMode _mode = BusinessMode.shop;
  bool _hasSelection = false;
  static const _modeKey = 'business_mode';

  BusinessMode get mode => _mode;
  bool get isButchery => _mode == BusinessMode.butchery;
  bool get hasSelection => _hasSelection;

  Future<void> load() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_modeKey);
    if (raw == null || raw.trim().isEmpty) {
      _hasSelection = false;
      return;
    }

    _mode = raw == 'butchery' ? BusinessMode.butchery : BusinessMode.shop;
    _hasSelection = true;
    notifyListeners();
  }

  Future<void> update(BusinessMode mode) async {
    _mode = mode;
    _hasSelection = true;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_modeKey, mode == BusinessMode.butchery ? 'butchery' : 'shop');
    notifyListeners();
  }
}

// ================== APP ENTRY ==================
Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  try {
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );
  } catch (_) {
    // Firebase is optional until the project is configured with FlutterFire.
  }
  runApp(const ShopaFlowApp());
}

class ShopaFlowApp extends StatelessWidget {
  const ShopaFlowApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => StoreInfoModel()),
        ChangeNotifierProvider(create: (_) => ExchangeRateModel()),
        ChangeNotifierProvider(create: (_) => ThemeModel()),
        ChangeNotifierProvider(create: (_) => SetupStatusModel()),
        ChangeNotifierProvider(create: (_) => AuthSessionModel()),
        ChangeNotifierProvider(create: (_) => BusinessModeModel()),
        ChangeNotifierProvider(create: (_) => PrinterManager()),
        Provider(create: (_) => DatabaseService()),
        // Add other providers here if needed
      ],
      child: Consumer<ThemeModel>(
        builder: (context, themeModel, _) => MaterialApp(
          debugShowCheckedModeBanner: false,
          theme: ThemeData(
            useMaterial3: true,
            colorScheme: ColorScheme.fromSeed(
              seedColor: themeModel.primaryColor,
              brightness: Brightness.light,
            ),
          ),
          home: const SplashScreen(),
        ),
      ),
    );
  }
}

// Reports Tab Widget (standalone)
Widget buildReportsTab(BuildContext context) {
  final db = context.read<DatabaseService>();
  return Padding(
    padding: const EdgeInsets.all(16.0),
    child: SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Sales Reports', style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: 8),
          FutureBuilder<List<Map<String, dynamic>>>(
            future: db.getSalesByDate(DateTime.now()),
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Center(child: CircularProgressIndicator());
              }
              if (!snapshot.hasData || snapshot.data!.isEmpty) {
                return const Text('No sales data available.');
              }
              final sales = snapshot.data!;
              return ListView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: sales.length,
                itemBuilder: (context, index) {
                  final sale = sales[index];
                  return Card(
                    margin: const EdgeInsets.symmetric(vertical: 4),
                    child: ListTile(
                      title: Text('Sale #${sale['id']}'),
                      subtitle: Text('Amount: ${sale['total_amount']}'),
                    ),
                  );
                },
              );
            },
          ),
          const SizedBox(height: 24),
          Text('Inventory Reports', style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: 8),
          FutureBuilder<List<Map<String, dynamic>>>(
            future: db.getAllProducts(),
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Center(child: CircularProgressIndicator());
              }
              if (!snapshot.hasData || snapshot.data!.isEmpty) {
                return const Text('No inventory data available.');
              }
              final items = snapshot.data!;
              return ListView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: items.length,
                itemBuilder: (context, index) {
                  final item = items[index];
                  return Card(
                    margin: const EdgeInsets.symmetric(vertical: 4),
                    child: ListTile(
                      title: Text(item['name']),
                      subtitle: Text('Stock: ${item['stock_quantity']}'),
                      trailing: item['stock_quantity'] < (item['min_stock_level'] ?? 5)
                          ? const Icon(Icons.warning, color: Colors.red)
                          : null,
                    ),
                  );
                },
              );
            },
          ),
          const SizedBox(height: 24),
          Text('Financial Reports', style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: 8),
          FutureBuilder<Map<String, dynamic>>(
            future: db.getDailySalesSummary(DateTime.now()),
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Center(child: CircularProgressIndicator());
              }
              if (!snapshot.hasData) {
                return const Text('No financial data available.');
              }
              final summary = snapshot.data!;
              return Card(
                child: Padding(
                  padding: const EdgeInsets.all(12.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Revenue: ${summary['total_sales']}'),
                      Text('Profit Margin: ${summary['average_sale']}'),
                      const Text('Cost: N/A'),
                    ],
                  ),
                ),
              );
            },
          ),
        ],
      ),
    ),
  );
}

// ================== SPLASH ==================
class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});
  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> with TickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _fade;
  Timer? _navigationTimer;
  @override
  void initState() {
    super.initState();
    _controller = AnimationController(vsync: this, duration: const Duration(seconds: 2))..forward();
    _fade = CurvedAnimation(parent: _controller, curve: Curves.easeIn);
    _initializeApp();
  }

  Future<void> _initializeApp() async {
    final storeInfo = context.read<StoreInfoModel>();
    final exchangeRate = context.read<ExchangeRateModel>();
    final themeModel = context.read<ThemeModel>();
    final setupStatus = context.read<SetupStatusModel>();
    final authSession = context.read<AuthSessionModel>();
    final businessMode = context.read<BusinessModeModel>();
    final db = context.read<DatabaseService>();

    // Load all models
    await storeInfo.load();
    await exchangeRate.load();
    await themeModel.load();
    await setupStatus.load();
    await authSession.load();
    authSession.configureDatabase(db);

    // Request Bluetooth and Nearby Device permissions at launch for printer persistence
    if (Platform.isAndroid) {
      await [
        Permission.bluetoothScan,
        Permission.bluetoothConnect,
        Permission.location,
      ].request();
    }

    if (authSession.isAuthenticated) {
      await FirebaseSyncService(databaseService: db).pullCompanyData(
        companyId: authSession.companyId,
        storeId: authSession.storeId,
        userId: authSession.userId,
      );
    }
    await businessMode.load();

    if (!mounted) {
      return;
    }
    
    // Navigate after loading
    _navigationTimer = Timer(const Duration(seconds: 2), () {
      if (!mounted) {
        return;
      }
      final isSetupCompleted = setupStatus.isSetupCompleted;
      final Widget nextScreen = isSetupCompleted ? const MainScreen() : const SetupWizardScreen();
      if (!authSession.isAuthenticated) {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (_) => const AuthGateScreen()),
        );
        return;
      }

      Navigator.pushReplacement(
        context, 
        MaterialPageRoute(
          builder: (_) => BusinessModeSelectionScreen(nextScreen: nextScreen),
        )
      );
    });
  }

  @override
  void dispose() {
    _navigationTimer?.cancel();
    _controller.dispose();
    super.dispose();
  }
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        color: const Color(0xFF004D40), // Cleaner, solid background matching the new icon style
        child: Center(
          child: FadeTransition(
            opacity: _fade,
            child: const Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.shopping_bag_outlined, color: Colors.white, size: 80),
                SizedBox(height: 16),
                Text('ShopaFlow', style: TextStyle(color: Colors.white, fontSize: 28, fontWeight: FontWeight.bold)),
                SizedBox(height: 8),
                Text('Point of Sale System', style: TextStyle(color: Colors.white70)),
                SizedBox(height: 24),
                SizedBox(width: 180, child: LinearProgressIndicator(color: Colors.white, backgroundColor: Colors.white24)),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class AuthGateScreen extends StatefulWidget {
  const AuthGateScreen({super.key});

  @override
  State<AuthGateScreen> createState() => _AuthGateScreenState();
}

class _AuthGateScreenState extends State<AuthGateScreen> {
  bool _showRegister = true;

  void _goToNextScreen() {
    final setupStatus = context.read<SetupStatusModel>();
    final nextScreen = setupStatus.isSetupCompleted ? const MainScreen() : const SetupWizardScreen();
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(builder: (_) => BusinessModeSelectionScreen(nextScreen: nextScreen)),
    );
  }

  @override
  Widget build(BuildContext context) {
    final primary = Theme.of(context).colorScheme.primary;
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 520),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Icon(Icons.point_of_sale, size: 64, color: primary),
                  const SizedBox(height: 14),
                  Text(
                    'ShopaFlow',
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.headlineMedium?.copyWith(fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    _showRegister ? 'Create your company workspace' : 'Sign in to your company workspace',
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.bodyLarge,
                  ),
                  const SizedBox(height: 24),
                  SegmentedButton<bool>(
                    segments: const [
                      ButtonSegment(value: true, icon: Icon(Icons.business), label: Text('Register')),
                      ButtonSegment(value: false, icon: Icon(Icons.login), label: Text('Login')),
                    ],
                    selected: {_showRegister},
                    onSelectionChanged: (selection) => setState(() => _showRegister = selection.first),
                  ),
                  const SizedBox(height: 20),
                  AnimatedSwitcher(
                    duration: const Duration(milliseconds: 220),
                    child: _showRegister
                        ? RegisterCompanyForm(key: const ValueKey('register'), onSuccess: _goToNextScreen)
                        : LoginForm(key: const ValueKey('login'), onSuccess: _goToNextScreen),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class LoginForm extends StatefulWidget {
  final VoidCallback onSuccess;
  const LoginForm({super.key, required this.onSuccess});

  @override
  State<LoginForm> createState() => _LoginFormState();
}

class _LoginFormState extends State<LoginForm> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _obscurePassword = true;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _emailController.text = context.read<AuthSessionModel>().email;
  }

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _saving = true);
    final error = await context.read<AuthSessionModel>().login(
      email: _emailController.text,
      password: _passwordController.text,
    );
    if (!mounted) return;
    setState(() => _saving = false);
    if (error != null) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(error)));
      return;
    }
    if (!mounted) return;
    final auth = context.read<AuthSessionModel>();
    final db = context.read<DatabaseService>();
    auth.configureDatabase(db);
    final pullResult = await FirebaseSyncService(databaseService: db).pullCompanyData(
      companyId: auth.companyId,
      storeId: auth.storeId,
      userId: auth.userId,
    );
    if (pullResult.message != null && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Cloud pull warning: ${pullResult.message}')));
    }
    if (auth.companyName.isNotEmpty) {
      await context.read<StoreInfoModel>().updateName(auth.companyName);
    }
    if (pullResult.configured && pullResult.message == null) {
      await context.read<SetupStatusModel>().markSetupCompleted();
    }
    if (!mounted) return;
    widget.onSuccess();
  }

  @override
  Widget build(BuildContext context) {
    return Form(
      key: _formKey,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          TextFormField(
            controller: _emailController,
            decoration: const InputDecoration(
              labelText: 'Email',
              prefixIcon: Icon(Icons.mail_outline),
              border: OutlineInputBorder(),
            ),
            keyboardType: TextInputType.emailAddress,
            validator: (value) => (value == null || value.trim().isEmpty) ? 'Email is required' : null,
          ),
          const SizedBox(height: 14),
          TextFormField(
            controller: _passwordController,
            obscureText: _obscurePassword,
            decoration: InputDecoration(
              labelText: 'Password',
              prefixIcon: const Icon(Icons.lock_outline),
              border: const OutlineInputBorder(),
              suffixIcon: IconButton(
                tooltip: _obscurePassword ? 'Show password' : 'Hide password',
                icon: Icon(_obscurePassword ? Icons.visibility : Icons.visibility_off),
                onPressed: () => setState(() => _obscurePassword = !_obscurePassword),
              ),
            ),
            validator: (value) => (value == null || value.isEmpty) ? 'Password is required' : null,
          ),
          const SizedBox(height: 18),
          FilledButton.icon(
            onPressed: _saving ? null : _submit,
            icon: _saving
                ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2))
                : const Icon(Icons.login),
            label: Text(_saving ? 'Signing in...' : 'Sign in'),
          ),
        ],
      ),
    );
  }
}

class RegisterCompanyForm extends StatefulWidget {
  final VoidCallback onSuccess;
  const RegisterCompanyForm({super.key, required this.onSuccess});

  @override
  State<RegisterCompanyForm> createState() => _RegisterCompanyFormState();
}

class _RegisterCompanyFormState extends State<RegisterCompanyForm> {
  final _formKey = GlobalKey<FormState>();
  final _companyController = TextEditingController();
  final _ownerController = TextEditingController();
  final _emailController = TextEditingController();
  final _phoneController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _obscurePassword = true;
  bool _saving = false;

  @override
  void dispose() {
    _companyController.dispose();
    _ownerController.dispose();
    _emailController.dispose();
    _phoneController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _saving = true);
    final error = await context.read<AuthSessionModel>().registerCompany(
      companyName: _companyController.text,
      ownerName: _ownerController.text,
      email: _emailController.text,
      phone: _phoneController.text,
      password: _passwordController.text,
    );
    if (!mounted) return;
    setState(() => _saving = false);
    if (error != null) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(error)));
      return;
    }
    context.read<AuthSessionModel>().configureDatabase(context.read<DatabaseService>());
    await context.read<StoreInfoModel>().updateName(_companyController.text);
    await context.read<DatabaseService>().upsertLocalCompanyProfile(
      companyId: context.read<AuthSessionModel>().companyId,
      storeId: context.read<AuthSessionModel>().storeId,
      companyName: _companyController.text,
      ownerName: _ownerController.text,
      email: _emailController.text,
      userId: context.read<AuthSessionModel>().userId,
      role: context.read<AuthSessionModel>().role,
      storeName: _companyController.text,
    );
    if (!mounted) return;
    widget.onSuccess();
  }

  @override
  Widget build(BuildContext context) {
    return Form(
      key: _formKey,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          TextFormField(
            controller: _companyController,
            decoration: const InputDecoration(
              labelText: 'Company name',
              prefixIcon: Icon(Icons.business_outlined),
              border: OutlineInputBorder(),
            ),
            textInputAction: TextInputAction.next,
            validator: (value) => (value == null || value.trim().isEmpty) ? 'Company name is required' : null,
          ),
          const SizedBox(height: 14),
          TextFormField(
            controller: _ownerController,
            decoration: const InputDecoration(
              labelText: 'Owner name',
              prefixIcon: Icon(Icons.person_outline),
              border: OutlineInputBorder(),
            ),
            textInputAction: TextInputAction.next,
            validator: (value) => (value == null || value.trim().isEmpty) ? 'Owner name is required' : null,
          ),
          const SizedBox(height: 14),
          TextFormField(
            controller: _emailController,
            decoration: const InputDecoration(
              labelText: 'Email',
              prefixIcon: Icon(Icons.mail_outline),
              border: OutlineInputBorder(),
            ),
            keyboardType: TextInputType.emailAddress,
            textInputAction: TextInputAction.next,
            validator: (value) {
              if (value == null || value.trim().isEmpty) return 'Email is required';
              if (!value.contains('@')) return 'Enter a valid email';
              return null;
            },
          ),
          const SizedBox(height: 14),
          TextFormField(
            controller: _phoneController,
            decoration: const InputDecoration(
              labelText: 'Phone (optional)',
              prefixIcon: Icon(Icons.phone_outlined),
              border: OutlineInputBorder(),
            ),
            keyboardType: TextInputType.phone,
            textInputAction: TextInputAction.next,
          ),
          const SizedBox(height: 14),
          TextFormField(
            controller: _passwordController,
            obscureText: _obscurePassword,
            decoration: InputDecoration(
              labelText: 'Password',
              prefixIcon: const Icon(Icons.lock_outline),
              border: const OutlineInputBorder(),
              suffixIcon: IconButton(
                tooltip: _obscurePassword ? 'Show password' : 'Hide password',
                icon: Icon(_obscurePassword ? Icons.visibility : Icons.visibility_off),
                onPressed: () => setState(() => _obscurePassword = !_obscurePassword),
              ),
            ),
            validator: (value) {
              if (value == null || value.isEmpty) return 'Password is required';
              if (value.length < 6) return 'Use at least 6 characters';
              return null;
            },
          ),
          const SizedBox(height: 18),
          FilledButton.icon(
            onPressed: _saving ? null : _submit,
            icon: _saving
                ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2))
                : const Icon(Icons.business),
            label: Text(_saving ? 'Creating workspace...' : 'Create workspace'),
          ),
        ],
      ),
    );
  }
}

class BusinessModeSelectionScreen extends StatefulWidget {
  final Widget nextScreen;
  const BusinessModeSelectionScreen({super.key, required this.nextScreen});

  @override
  State<BusinessModeSelectionScreen> createState() => _BusinessModeSelectionScreenState();
}

class _BusinessModeSelectionScreenState extends State<BusinessModeSelectionScreen> {
  late BusinessMode _selected;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _selected = context.read<BusinessModeModel>().mode;
  }

  Future<void> _continue() async {
    setState(() => _saving = true);
    await context.read<BusinessModeModel>().update(_selected);
    if (!mounted) return;
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(builder: (_) => widget.nextScreen),
    );
  }

  @override
  Widget build(BuildContext context) {
    final primary = Theme.of(context).colorScheme.primary;
    return Scaffold(
      appBar: AppBar(
        title: const Text('Choose Business Type'),
        backgroundColor: primary,
        foregroundColor: Colors.white,
        automaticallyImplyLeading: false,
      ),
      body: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Select how you want to run this POS',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            const Text('You can change this later from Settings.'),
            const SizedBox(height: 20),
            Expanded(
              child: ListView(
                children: [
                  _buildModeCard(
                    mode: BusinessMode.shop,
                    icon: Icons.storefront,
                    title: 'Shop Mode',
                    subtitle: 'Whole-number quantities (1, 2, 3...) for regular retail items.',
                  ),
                  const SizedBox(height: 12),
                  _buildModeCard(
                    mode: BusinessMode.butchery,
                    icon: Icons.set_meal,
                    title: 'Butchery Mode',
                    subtitle: 'Fractional quantities in kilograms (for example 0.25 kg, 0.5 kg, 1.75 kg).',
                  ),
                ],
              ),
            ),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: _saving ? null : _continue,
                icon: const Icon(Icons.arrow_forward),
                label: Text(_saving ? 'Saving...' : 'Continue'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildModeCard({
    required BusinessMode mode,
    required IconData icon,
    required String title,
    required String subtitle,
  }) {
    final selected = _selected == mode;
    final primary = Theme.of(context).colorScheme.primary;
    return InkWell(
      onTap: () => setState(() => _selected = mode),
      borderRadius: BorderRadius.circular(14),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: selected ? primary : Colors.grey.shade300, width: selected ? 2 : 1),
          color: selected ? primary.withValues(alpha: 0.08) : Colors.white,
        ),
        child: Row(
          children: [
            CircleAvatar(
              backgroundColor: selected ? primary : Colors.grey.shade200,
              foregroundColor: selected ? Colors.white : Colors.black87,
              child: Icon(icon),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 16)),
                  const SizedBox(height: 6),
                  Text(subtitle),
                ],
              ),
            ),
            if (selected) Icon(Icons.check_circle, color: primary),
          ],
        ),
      ),
    );
  }
}

// ================== SETUP WIZARD ==================
class SetupWizardScreen extends StatefulWidget {
  const SetupWizardScreen({super.key});
  @override
  State<SetupWizardScreen> createState() => _SetupWizardScreenState();
}

class _SetupWizardScreenState extends State<SetupWizardScreen> {
  final PageController _pageController = PageController();
  int _currentPage = 0;
  
  // Form controllers
  final _shopNameController = TextEditingController();
  final _addressController = TextEditingController();
  final _exchangeRateController = TextEditingController();
  
  Color _selectedColor = Colors.green;

  @override
  void initState() {
    super.initState();
    // Pre-populate with existing values
    _shopNameController.text = context.read<StoreInfoModel>().name;
    _addressController.text = context.read<StoreInfoModel>().address;
    _exchangeRateController.text = context.read<ExchangeRateModel>().rate.toString();
    _selectedColor = context.read<ThemeModel>().primaryColor;
  }

  @override
  void dispose() {
    _shopNameController.dispose();
    _addressController.dispose();
    _exchangeRateController.dispose();
    _pageController.dispose();
    super.dispose();
  }

  void _nextPage() {
    if (_currentPage < 2) {
      _pageController.nextPage(
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
      );
    } else {
      _completeSetup();
    }
  }

  void _previousPage() {
    if (_currentPage > 0) {
      _pageController.previousPage(
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
      );
    }
  }

  Future<void> _completeSetup() async {
    final storeInfo = context.read<StoreInfoModel>();
    final exchangeRate = context.read<ExchangeRateModel>();
    final themeModel = context.read<ThemeModel>();
    final setupStatus = context.read<SetupStatusModel>();

    // Save all settings
    await storeInfo.updateName(_shopNameController.text);
    await storeInfo.updateAddress(_addressController.text);
    await exchangeRate.update(double.tryParse(_exchangeRateController.text) ?? 320);
    await themeModel.updateColor(_selectedColor);
    final auth = context.read<AuthSessionModel>();
    final db = context.read<DatabaseService>();
    auth.configureDatabase(db);
    await db.upsertLocalCompanyProfile(
      companyId: auth.companyId,
      storeId: auth.storeId,
      companyName: auth.companyName.isEmpty ? _shopNameController.text : auth.companyName,
      ownerName: auth.ownerName,
      email: auth.email,
      userId: auth.userId,
      role: auth.role,
      storeName: _shopNameController.text,
      storeAddress: _addressController.text,
    );
    await setupStatus.markSetupCompleted();

    // Navigate to main screen
    if (mounted) {
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (_) => const MainScreen()),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Setup ShopaFlow'),
        backgroundColor: _selectedColor,
        foregroundColor: Colors.white,
        automaticallyImplyLeading: false,
      ),
      body: Column(
        children: [
          // Progress indicator
          LinearProgressIndicator(
            value: (_currentPage + 1) / 3,
            backgroundColor: Colors.grey[300],
            valueColor: AlwaysStoppedAnimation(_selectedColor),
          ),
          Expanded(
            child: PageView(
              controller: _pageController,
              onPageChanged: (index) => setState(() => _currentPage = index),
              children: [
                _buildWelcomePage(),
                _buildShopInfoPage(),
                _buildCustomizationPage(),
              ],
            ),
          ),
          // Navigation buttons
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                if (_currentPage > 0)
                  TextButton(
                    onPressed: _previousPage,
                    child: const Text('Back'),
                  )
                else
                  const SizedBox.shrink(),
                ElevatedButton(
                  onPressed: _nextPage,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: _selectedColor,
                    foregroundColor: Colors.white,
                  ),
                  child: Text(_currentPage < 2 ? 'Next' : 'Complete Setup'),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildWelcomePage() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24.0),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.store, size: 100, color: _selectedColor),
          const SizedBox(height: 24),
          Text(
            'Welcome to ShopaFlow!',
            style: Theme.of(context).textTheme.headlineMedium?.copyWith(
              fontWeight: FontWeight.bold,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 16),
          Text(
            'Let\'s set up your shop in just a few steps. You can always change these settings later.',
            style: Theme.of(context).textTheme.bodyLarge,
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 32),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: _selectedColor.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Column(
              children: [
                Text(
                  'What we\'ll set up:',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 12),
                const Row(
                  children: [
                    Icon(Icons.check_circle, color: Colors.green, size: 20),
                    SizedBox(width: 8),
                    Text('Shop name and address'),
                  ],
                ),
                const SizedBox(height: 8),
                const Row(
                  children: [
                    Icon(Icons.check_circle, color: Colors.green, size: 20),
                    SizedBox(width: 8),
                    Text('Currency exchange rate'),
                  ],
                ),
                const SizedBox(height: 8),
                const Row(
                  children: [
                    Icon(Icons.check_circle, color: Colors.green, size: 20),
                    SizedBox(width: 8),
                    Text('App theme and colors'),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildShopInfoPage() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Shop Information',
            style: Theme.of(context).textTheme.headlineSmall?.copyWith(
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 24),
          TextField(
            controller: _shopNameController,
            decoration: InputDecoration(
              labelText: 'Shop Name',
              hintText: 'Enter your shop name',
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              prefixIcon: const Icon(Icons.store),
            ),
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _addressController,
            decoration: InputDecoration(
              labelText: 'Shop Address',
              hintText: 'Enter your shop address',
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              prefixIcon: const Icon(Icons.location_on),
            ),
            maxLines: 2,
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _exchangeRateController,
            decoration: InputDecoration(
              labelText: 'USD to ZWL Exchange Rate',
              hintText: 'Enter current exchange rate',
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              prefixIcon: const Icon(Icons.currency_exchange),
            ),
            keyboardType: TextInputType.number,
          ),
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.blue.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: const Row(
              children: [
                Icon(Icons.info, color: Colors.blue),
                SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'The exchange rate helps convert USD prices to ZWL. You can update this anytime in settings.',
                    style: TextStyle(color: Colors.blue),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCustomizationPage() {
    final themeModel = context.read<ThemeModel>();
    
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Customize Your App',
            style: Theme.of(context).textTheme.headlineSmall?.copyWith(
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 24),
          Text(
            'Choose your app\'s primary color:',
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(height: 16),
          Wrap(
            spacing: 12,
            runSpacing: 12,
            children: themeModel.availableColors.map((color) {
              final isSelected = color == _selectedColor;
              return GestureDetector(
                onTap: () => setState(() => _selectedColor = color),
                child: Container(
                  width: 60,
                  height: 60,
                  decoration: BoxDecoration(
                    color: color,
                    borderRadius: BorderRadius.circular(30),
                    border: Border.all(
                      color: isSelected ? Colors.black : Colors.transparent,
                      width: 3,
                    ),
                  ),
                  child: isSelected
                      ? const Icon(Icons.check, color: Colors.white, size: 30)
                      : null,
                ),
              );
            }).toList(),
          ),
          const SizedBox(height: 32),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: _selectedColor.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Column(
              children: [
                Icon(Icons.check_circle, color: _selectedColor, size: 48),
                const SizedBox(height: 12),
                Text(
                  'You\'re all set!',
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Your shop is ready to start making sales. You can always modify these settings later in the Settings tab.',
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.bodyMedium,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class SyncStatusButton extends StatefulWidget {
  const SyncStatusButton({super.key});

  @override
  State<SyncStatusButton> createState() => _SyncStatusButtonState();
}

class _SyncStatusButtonState extends State<SyncStatusButton> {
  late Future<int> _pendingCountFuture;
  bool _syncing = false;

  @override
  void initState() {
    super.initState();
    _pendingCountFuture = _loadPendingCount();
  }

  Future<int> _loadPendingCount() {
    return context.read<DatabaseService>().getRetryableSyncCount();
  }

  void _refresh() {
    setState(() {
      _pendingCountFuture = _loadPendingCount();
    });
  }

  Future<void> _showSyncDetails() async {
    final db = context.read<DatabaseService>();
    final pending = await db.getPendingSyncQueue(limit: 20, includeFailed: true);
    if (!mounted) return;

    await showModalBottomSheet<void>(
      context: context,
      builder: (sheetContext) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 18, 20, 20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                pending.isEmpty ? 'No retryable cloud changes' : '${pending.length} retryable cloud changes',
                style: Theme.of(sheetContext).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              Text(
                pending.isEmpty
                    ? 'Everything local is either synced or waiting for a new change.'
                    : 'These records are stored offline and will be retried on the next sync.',
              ),
              if (pending.isNotEmpty) ...[
                const SizedBox(height: 12),
                ConstrainedBox(
                  constraints: const BoxConstraints(maxHeight: 260),
                  child: ListView.separated(
                    shrinkWrap: true,
                    itemCount: pending.length,
                    separatorBuilder: (_, __) => const Divider(height: 1),
                    itemBuilder: (_, index) {
                      final item = pending[index];
                      return ListTile(
                        contentPadding: EdgeInsets.zero,
                        leading: Icon(
                          item['status'] == 'failed' ? Icons.error_outline : Icons.cloud_upload_outlined,
                          color: item['status'] == 'failed' ? Colors.redAccent : null,
                        ),
                        title: Text('${item['operation']} ${item['entity_type']}'),
                        subtitle: Text(
                          item['status'] == 'failed'
                              ? (item['last_error']?.toString() ?? 'Sync failed')
                              : (item['created_at']?.toString() ?? ''),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                      );
                    },
                  ),
                ),
              ],
              const SizedBox(height: 12),
              if (pending.isNotEmpty) ...[
                SizedBox(
                  width: double.infinity,
                  child: FilledButton.icon(
                    onPressed: () {
                      Navigator.pop(sheetContext);
                      _syncNow();
                    },
                    icon: const Icon(Icons.sync),
                    label: const Text('Retry Sync'),
                  ),
                ),
                const SizedBox(height: 8),
              ],
              SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  onPressed: () => Navigator.pop(sheetContext),
                  icon: const Icon(Icons.check),
                  label: const Text('Done'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
    _refresh();
  }

  Future<void> _syncNow() async {
    if (_syncing) return;
    setState(() => _syncing = true);

    final db = context.read<DatabaseService>();
    try {
      context.read<AuthSessionModel>().configureDatabase(db);
      await db.migrateLegacyTenantToActive();
      final result = await FirebaseSyncService(databaseService: db).syncPendingChanges(retryFailed: true);
      if (!mounted) return;

      final message = result.configured
          ? 'Synced ${result.synced} of ${result.attempted} changes${result.failed > 0 ? ', ${result.failed} failed' : ''}.'
          : result.message ?? 'Firebase is not configured yet.';
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Sync failed: $error')));
    } finally {
      if (mounted) {
        setState(() => _syncing = false);
        _refresh();
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<int>(
      future: _pendingCountFuture,
      builder: (context, snapshot) {
        final pendingCount = snapshot.data ?? 0;
        final icon = pendingCount > 0 ? Icons.cloud_upload_outlined : Icons.cloud_done;
        final label = pendingCount > 0 ? '$pendingCount changes ready to sync' : 'All local changes synced';

        return IconButton(
          tooltip: label,
          onPressed: _syncing ? null : _syncNow,
          onLongPress: _showSyncDetails,
          icon: Stack(
            clipBehavior: Clip.none,
            children: [
              if (_syncing)
                const SizedBox(
                  width: 24,
                  height: 24,
                  child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                )
              else
                Icon(icon, color: Colors.white),
              if (pendingCount > 0)
                Positioned(
                  right: -8,
                  top: -8,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                    decoration: BoxDecoration(
                      color: Colors.orangeAccent,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      pendingCount > 99 ? '99+' : pendingCount.toString(),
                      style: const TextStyle(color: Colors.black, fontSize: 10, fontWeight: FontWeight.bold),
                    ),
                  ),
                ),
            ],
          ),
        );
      },
    );
  }
}

// ================== MAIN SHELL ==================
class MainScreen extends StatefulWidget {
  const MainScreen({super.key});
  @override
  State<MainScreen> createState() => _MainScreenState();
}

class _MainScreenState extends State<MainScreen> {
  int _index = 0;

  Future<bool> _confirmExitWithSync() async {
    final db = context.read<DatabaseService>();
    context.read<AuthSessionModel>().configureDatabase(db);
    await db.migrateLegacyTenantToActive();
    final pending = await db.getRetryableSyncCount();
    if (!mounted || pending == 0) return true;

    final action = await showDialog<String>(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Sync before closing?'),
        content: Text('$pending local change${pending == 1 ? '' : 's'} still need to sync to the cloud. Sync now so records stay aligned?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(dialogContext, 'cancel'), child: const Text('Stay')),
          TextButton(onPressed: () => Navigator.pop(dialogContext, 'exit'), child: const Text('Exit without syncing')),
          FilledButton.icon(
            onPressed: () => Navigator.pop(dialogContext, 'sync'),
            icon: const Icon(Icons.sync),
            label: const Text('Sync now'),
          ),
        ],
      ),
    );

    if (action == 'exit') return true;
    if (action != 'sync') return false;

    final result = await FirebaseSyncService(databaseService: db).syncPendingChanges(retryFailed: true);
    if (!mounted) return false;
    if (!result.configured || result.failed > 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            result.configured
                ? 'Sync incomplete: ${result.failed} of ${result.attempted} failed.'
                : result.message ?? 'Firebase is not configured yet.',
          ),
        ),
      );
      return false;
    }
    return true;
  }

  @override
  Widget build(BuildContext context) {
    final isLandscape = MediaQuery.of(context).orientation == Orientation.landscape;
    final store = context.watch<StoreInfoModel>();
    final businessMode = context.watch<BusinessModeModel>();
    final auth = context.watch<AuthSessionModel>();
    final navItems = <_ShellNavItem>[
      const _ShellNavItem('POS', Icons.storefront_rounded, CheckoutScreen()),
      if (auth.canManageInventory) const _ShellNavItem('Products', Icons.inventory_2_outlined, ProductsScreen()),
      if (auth.canViewReports) const _ShellNavItem('Reports', Icons.analytics_outlined, ReportsScreen()),
      if (auth.canManageSettings) const _ShellNavItem('Settings', Icons.settings_outlined, SettingsScreen()),
    ];
    final activeIndex = _index >= navItems.length ? 0 : _index;
    if (activeIndex != _index) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) setState(() => _index = activeIndex);
      });
    }

    return WillPopScope(
      onWillPop: _confirmExitWithSync,
      child: Scaffold(
        appBar: AppBar(
        title: Row(children: [
          Icon(businessMode.isButchery ? Icons.set_meal : Icons.storefront, color: Colors.white),
          const SizedBox(width: 8),
          Flexible(
            child: Text(
              '${store.name} • ${businessModeLabel(businessMode.mode)}',
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(color: Colors.white),
            ),
          ),
        ]),
        actions: [
          Consumer<AuthSessionModel>(
            builder: (_, auth, __) => IconButton(
              tooltip: auth.ownerName.isEmpty ? 'Account' : auth.ownerName,
              icon: const Icon(Icons.account_circle, color: Colors.white),
              onPressed: () => _showAccountMenu(auth),
            ),
          ),
          const SyncStatusButton(),
        ],
        backgroundColor: Theme.of(context).colorScheme.primary,
      ),
      body: isLandscape ? Row(children: [
        NavigationRail(
          backgroundColor: Theme.of(context).colorScheme.primary,
          selectedIndex: activeIndex,
          onDestinationSelected: (i)=> setState(()=> _index = i),
          selectedIconTheme: const IconThemeData(color: Colors.white),
          unselectedIconTheme: IconThemeData(color: Colors.white.withValues(alpha: 0.6)),
          destinations: navItems
              .map((item) => NavigationRailDestination(
                    icon: Icon(item.icon, color: Colors.white),
                    label: Text(item.label, style: const TextStyle(color: Colors.white)),
                  ))
              .toList()),
        Expanded(child: navItems[activeIndex].page)
      ]) : navItems[activeIndex].page,
        bottomNavigationBar: isLandscape ? null : NavigationBar(
          backgroundColor: Theme.of(context).colorScheme.primary,
          indicatorColor: Colors.white.withValues(alpha: 0.15),
          selectedIndex: activeIndex,
          labelBehavior: NavigationDestinationLabelBehavior.alwaysShow,
          onDestinationSelected: (i)=> setState(()=> _index = i),
          destinations: navItems
              .map((item) => NavigationDestination(icon: Icon(item.icon, color: Colors.white), label: item.label))
              .toList(),
        ),
      ),
    );
  }

  Future<void> _showAccountMenu(AuthSessionModel auth) async {
    final shouldLogout = await showModalBottomSheet<bool>(
      context: context,
      builder: (sheetContext) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 18, 20, 20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                auth.companyName.isEmpty ? 'Company account' : auth.companyName,
                style: Theme.of(sheetContext).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 4),
              Text(auth.email.isEmpty ? auth.ownerName : auth.email),
              const SizedBox(height: 18),
              SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  onPressed: () => Navigator.pop(sheetContext, true),
                  icon: const Icon(Icons.logout),
                  label: const Text('Sign out'),
                ),
              ),
            ],
          ),
        ),
      ),
    );

    if (shouldLogout != true || !mounted) return;
    await context.read<AuthSessionModel>().logout();
    if (!mounted) return;
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(builder: (_) => const AuthGateScreen()),
    );
  }
}

class _ShellNavItem {
  final String label;
  final IconData icon;
  final Widget page;

  const _ShellNavItem(this.label, this.icon, this.page);
}

// ================== CHECKOUT / POS ==================
class CheckoutScreen extends StatefulWidget { const CheckoutScreen({super.key}); @override State<CheckoutScreen> createState()=> _CheckoutScreenState(); }
class _CheckoutScreenState extends State<CheckoutScreen> {
  late ValueNotifier<List<Map<String, dynamic>>> _cartNotifier;
  String query = '';
  int _searchReset = 0;
  bool listMode = true; // list default
  bool _loading = true;
  bool _showCart = true; // cart visibility
  List<Map<String, dynamic>> _products = [];
  late DatabaseService db;
  bool _didScheduleInitialLoad = false;

  BusinessModeModel get _businessMode => context.read<BusinessModeModel>();
  bool get _isButchery => _businessMode.isButchery;
  double get _quantityStep => _isButchery ? 0.25 : 1.0;

  Future<void> _printReceipt(Map<String, dynamic> sale, List<Map<String, dynamic>> items) async {
    try {
      final printerManager = context.read<PrinterManager>();
      final store = context.read<StoreInfoModel>();
      
      // Try printer if connected (either Bluetooth or Sunmi)
      if (printerManager.isConnected) {
        await printerManager.printReceipt(
          receiptNumber: sale['receipt_number'] ?? '',
          saleDate: DateTime.parse(sale['sale_date'] ?? DateTime.now().toString()),
          items: items,
          total: (sale['total_amount'] ?? 0.0).toDouble(),
          paymentMethod: sale['payment_method'] ?? 'Cash',
          storeName: store.name,
          storeAddress: store.address,
        );
      } else {
        // Fallback to PDF printing if no printer connected
        final pdf = pw.Document();
        pdf.addPage(
          pw.Page(
            pageFormat: PdfPageFormat.roll80,
            build: (pw.Context context) {
              return pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  pw.Text(store.name, style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 16)),
                  pw.Text(store.address, style: const pw.TextStyle(fontSize: 10)),
                  pw.SizedBox(height: 8),
                  pw.Divider(),
                  pw.Text('Receipt: ${sale['receipt_number']}'),
                  pw.Text('Date: ${sale['sale_date']}'),
                  pw.Divider(),
                  ...items.map((item) => pw.Text('${item['quantity']} x ${item['product_id']} @ ${item['unit_price']}')),
                  pw.Divider(),
                  pw.Text('Total: ${sale['total_amount']}', style: pw.TextStyle(fontWeight: pw.FontWeight.bold)),
                  pw.Text('Payment: ${sale['payment_method']}'),
                  pw.SizedBox(height: 8),
                  pw.Text('Thank you!'),
                ],
              );
            },
          ),
        );
        await Printing.layoutPdf(onLayout: (PdfPageFormat format) async => pdf.save());
      }
    } catch (e) {
      // Ignore print errors, just save sale
    }
  }

  @override
  void initState() {
    super.initState();
    _cartNotifier = ValueNotifier<List<Map<String, dynamic>>>([]);
  }

  @override
  void dispose() {
    _cartNotifier.dispose();
    super.dispose();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    db = context.read<DatabaseService>();
    if (_didScheduleInitialLoad) return;
    _didScheduleInitialLoad = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _load();
    });
  }

  Future<void> _load() async {
    if (mounted) setState(() => _loading = true);
    final rows = await db.getAllProducts();
    if (!mounted) return;
    _products = rows.map((p) => {...p, 'stock': p['stock_quantity']}).toList();
    setState(() => _loading = false);
  }

  List<Map<String, dynamic>> get filtered {
    if (query.isEmpty) {
      return _products;
    } else {
      final q = query.toLowerCase();
      return _products.where((p) {
        return (p['name'] ?? '').toString().toLowerCase().contains(q) ||
            (p['category'] ?? '').toString().toLowerCase().contains(q) ||
            (p['barcode'] ?? '').toString().contains(query);
      }).toList();
    }
  }

  double get totalUSD => _cartNotifier.value.fold(0.0, (s, i) => s + asDouble(i['price']) * asDouble(i['qty']));

  Future<double?> _showKgInputDialog({
    required String productName,
    required double maxKg,
    double? initialKg,
    String actionLabel = 'Add',
  }) async {
    FocusManager.instance.primaryFocus?.unfocus();
    await Future<void>.delayed(const Duration(milliseconds: 80));
    if (!mounted) return null;
    return showDialog<double>(
      context: context,
      builder: (_) => ButcheryWeightDialog(
        productName: productName,
        maxKg: maxKg,
        initialKg: initialKg,
        actionLabel: actionLabel,
      ),
    );
  }

  Future<void> _add(Map<String, dynamic> p) async {
    if (!context.read<AuthSessionModel>().canSell) {
      _snack('You do not have permission to sell.');
      return;
    }
    final newCart = List<Map<String, dynamic>>.from(_cartNotifier.value);
    final idx = newCart.indexWhere((c) => c['id'] == p['id']);
    final stock = asDouble(p['stock_quantity'] ?? p['stock'] ?? 0);

    if (idx == -1) {
      if (stock <= 0) {
        _snack('Out of stock');
        return;
      }
      double qtyToAdd = _quantityStep;
      if (_isButchery) {
        final entered = await _showKgInputDialog(
          productName: p['name']?.toString() ?? 'Item',
          maxKg: stock,
          initialKg: stock < _quantityStep ? stock : _quantityStep,
          actionLabel: 'Add',
        );
        if (entered == null) return;
        if (!mounted) return;
        qtyToAdd = entered;
      }
      newCart.add({'id': p['id'], 'name': p['name'], 'price': p['price'], 'qty': qtyToAdd, 'stock': stock});
    } else {
      double qtyIncrement = _quantityStep;
      if (_isButchery) {
        final currentQty = asDouble(newCart[idx]['qty']);
        final remaining = stock - currentQty;
        if (remaining <= 0.000001) {
          _snack('Max stock reached');
          return;
        }
        final entered = await _showKgInputDialog(
          productName: p['name']?.toString() ?? 'Item',
          maxKg: remaining,
          initialKg: remaining < _quantityStep ? remaining : _quantityStep,
          actionLabel: 'Add',
        );
        if (entered == null) return;
        if (!mounted) return;
        qtyIncrement = entered;
      }
      final nextQty = asDouble(newCart[idx]['qty']) + qtyIncrement;
      if (nextQty > stock + 0.000001) {
        _snack('Max stock reached');
        return;
      }
      newCart[idx] = {...newCart[idx], 'qty': nextQty};
    }
    _cartNotifier.value = newCart;
    setState(() => _showCart = true);
  }

  Future<void> _setButcheryQty(int index) async {
    if (!_isButchery) return;
    final newCart = List<Map<String, dynamic>>.from(_cartNotifier.value);
    if (index >= newCart.length) return;
    final item = newCart[index];
    final stock = asDouble(item['stock']);
    final currentQty = asDouble(item['qty']);
    final entered = await _showKgInputDialog(
      productName: item['name']?.toString() ?? 'Item',
      maxKg: stock,
      initialKg: currentQty,
      actionLabel: 'Set',
    );
    if (entered == null) return;
    if (!mounted) return;
    newCart[index] = {...item, 'qty': entered};
    _cartNotifier.value = newCart;
  }

  void _changeQty(int index, double delta) {
    final newCart = List<Map<String, dynamic>>.from(_cartNotifier.value);
    if (index >= newCart.length) return;
    final item = newCart[index];
    final newQty = asDouble(item['qty']) + delta;
    final stock = asDouble(item['stock']);
    if (newQty > stock + 0.000001) {
      _snack('Max stock reached');
      return;
    }
    if (newQty <= 0.000001) {
      newCart.removeAt(index);
    } else {
      newCart[index] = {...item, 'qty': newQty};
    }
    _cartNotifier.value = newCart;
  }

  void _remove(int index) {
    final newCart = List<Map<String, dynamic>>.from(_cartNotifier.value);
    if (index >= 0 && index < newCart.length) {
      newCart.removeAt(index);
    }
    _cartNotifier.value = newCart;
  }

  void _snack(String m) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(m), duration: const Duration(seconds: 1)));
  }

  Future<void> _checkout() async {
    if (!context.read<AuthSessionModel>().canSell) {
      _snack('You do not have permission to sell.');
      return;
    }
    if (_cartNotifier.value.isEmpty) {
      _snack('Cart is empty');
      return;
    }
    final currentTotal = totalUSD;
    final method = await showDialog<String>(context: context, builder: (_) => _PaymentDialog(total: currentTotal));
    if (method == null) return;
    final sale = {
      'total_amount': currentTotal,
      'payment_method': method,
      'sale_date': DateTime.now().toIso8601String(),
      'receipt_number': 'RCP${DateTime.now().millisecondsSinceEpoch}'
    };
    final items = _cartNotifier.value.map((c) => ({
      'product_id': c['id'],
      'quantity': c['qty'],
      'unit_price': c['price'],
      'total_price': asDouble(c['price']) * asDouble(c['qty'])
    })).toList();
    
    // Create items with names for printing
    final itemsWithNames = _cartNotifier.value.map((c) => ({
      'product_id': c['id'],
      'name': c['name'],
      'quantity': c['qty'],
      'unit_price': c['price'],
      'total_price': asDouble(c['price']) * asDouble(c['qty'])
    })).toList();
    
  await db.addSale(sale, items);
  // Try to print receipt if printer is connected, but always save sale
  _printReceipt(sale, itemsWithNames);
    for (final c in _cartNotifier.value) {
      final prodIdx = _products.indexWhere((p) => p['id'] == c['id']);
      if (prodIdx != -1) {
        _products[prodIdx]['stock_quantity'] = asDouble(_products[prodIdx]['stock_quantity']) - asDouble(c['qty']);
      }
    }
    _cartNotifier.value = [];
    setState(() {
      query = '';
      _searchReset++;
      _showCart = false;
    });
    _load();
    if (!mounted) return;
    showDialog(
        context: context,
        builder: (_) => AlertDialog(
              title: const Text('Payment Successful'),
              content: Text('Total: \$${currentTotal.toStringAsFixed(2)}\nPayment method: $method\n\nReady for next customer!'),
              actions: [TextButton(onPressed: () => Navigator.pop(context), child: const Text('OK'))],
            ));
  }

  @override
  Widget build(BuildContext context) {
    final rate = context.watch<ExchangeRateModel>().rate;
    final width = MediaQuery.of(context).size.width;
    final wide = width > 820; // dual pane threshold
    return SafeArea(
      child: Scaffold(
        resizeToAvoidBottomInset: false,
        body: Stack(
          children: [
            Column(
              children: [
                _buildSearchBar(),
                Expanded(
                  child: wide
                      ? Row(
                          children: [
                            Expanded(child: _buildProducts()),
                            if (_showCart) ...[
                              const VerticalDivider(width: 1),
                              SizedBox(width: 380, child: _buildCartPanel(rate)),
                            ],
                          ],
                        )
                      : _buildProducts(),
                ),
              ],
            ),
            if (!wide) _buildBottomCartBar(rate),
          ],
        ),
      ),
    );
  }

  Widget _buildSearchBar(){
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(color: Colors.white, border: Border(bottom: BorderSide(color: Colors.grey.shade200))),
      child: Row(children: [
        Expanded(child: TextField(
          key: ValueKey('checkout-search-$_searchReset'),
          onChanged: (v)=> setState(()=> query = v),
          decoration: InputDecoration(
            prefixIcon: const Icon(Icons.search),
            suffixIcon: query.isNotEmpty? IconButton(icon: const Icon(Icons.clear), onPressed: (){ setState(() { query=''; _searchReset++; }); }): null,
            hintText: 'Search name / category / barcode',
            filled: true, fillColor: Colors.grey.shade100, border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide.none),
          ),
       )),

        const SizedBox(width: 8),
        IconButton.filledTonal(onPressed: ()=> setState(()=> listMode = !listMode), icon: Icon(listMode? Icons.grid_view: Icons.view_list)),
        const SizedBox(width: 8),
        IconButton.filledTonal(
          onPressed: ()=> setState(()=> _showCart = !_showCart), 
          icon: Icon(_showCart ? Icons.shopping_cart : Icons.shopping_cart_outlined),
          style: IconButton.styleFrom(
            backgroundColor: _showCart ? Theme.of(context).colorScheme.primary : null,
            foregroundColor: _showCart ? Colors.white : null,
          ),
        ),
      ]),
    );
  }

  Widget _buildProducts(){
    if(_loading){ return const Center(child: CircularProgressIndicator()); }
    final data = filtered;
    if(data.isEmpty){ return const Center(child: Text('No products')); }
    if(listMode){
      return ListView.builder(padding: const EdgeInsets.all(12), itemCount: data.length, itemBuilder: (_,i){
        final p = data[i];
        final stock = asDouble(p['stock_quantity'] ?? 0);
        final minStock = asDouble(p['min_stock_level'] ?? 5);
        final low = stock < minStock;
        return Card(
          elevation: 1,
          margin: const EdgeInsets.only(bottom: 8),
          child: ListTile(
            leading: CircleAvatar(backgroundColor: low? Colors.orange.shade100: Colors.green.shade100, child: Text(p['name'].toString().characters.first.toUpperCase())),
            title: Text(p['name']??'', style: const TextStyle(fontWeight: FontWeight.w600)),
                      subtitle: Text('Stock: ${formatQuantityDisplay(stock, isWeight: _isButchery)} • ${p['category']??'No Cat'}', maxLines: 1, overflow: TextOverflow.ellipsis),
            trailing: Wrap(
              spacing: 6,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                Text(
                  _isButchery ? '\$${asDouble(p['price']).toStringAsFixed(2)}/kg' : '\$${asDouble(p['price']).toStringAsFixed(2)}',
                  style: TextStyle(color: Theme.of(context).colorScheme.primary, fontWeight: FontWeight.bold, fontSize: 14),
                ),
                if (stock > 0)
                  IconButton(onPressed: ()=> _add(p), icon: const Icon(Icons.add_circle_outline))
                else
                  const Text('OOS', style: TextStyle(color: Colors.red, fontSize: 12)),
              ],
            ),
            onTap: stock > 0 ? () => _add(p) : null,
          ),
        );
      });
    }
    // grid
    final width = MediaQuery.of(context).size.width;
    final cross = width>1100?5: width>900?4:3;
    return GridView.builder(
      padding: const EdgeInsets.all(12),
      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: cross,
        crossAxisSpacing: 12,
        mainAxisSpacing: 12,
        childAspectRatio: 0.9,
      ),
      itemCount: data.length,
      itemBuilder: (_, i) {
        final p = data[i];
        final stock = asDouble(p['stock_quantity'] ?? 0);
        final outOfStock = stock <= 0;
        return Card(
          clipBehavior: Clip.antiAlias,
          elevation: 2,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          child: InkWell(
            onTap: outOfStock ? null : () => _add(p),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Expanded(
                  child: Container(
                    color: Colors.grey.shade100,
                    child: Icon(outOfStock? Icons.block: Icons.inventory_2, color: outOfStock? Colors.redAccent: Theme.of(context).colorScheme.primary),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.all(12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(p['name']??'', maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontWeight: FontWeight.w600)),
                      const SizedBox(height: 4),
                      Text(
                        _isButchery
                            ? '\$${asDouble(p['price']).toStringAsFixed(2)}/kg • Stock: ${formatQuantityDisplay(stock, isWeight: true)}'
                            : '\$${asDouble(p['price']).toStringAsFixed(2)} • Stock: ${formatQuantityDisplay(stock, isWeight: false)}',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(fontSize: 12, color: Colors.black54),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildCartPanel(double rate) {
    return ValueListenableBuilder<List<Map<String, dynamic>>>(
      valueListenable: _cartNotifier,
      builder: (context, cart, _) {
        return Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text('Current Order', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                  Text('${cart.length} items'),
                ],
              ),
            ),
            Expanded(
              child: cart.isEmpty
                  ? const Center(
                      child: Text('Your cart is empty', style: TextStyle(fontSize: 16, color: Colors.grey)),
                    )
                  : ListView.builder(
                      padding: const EdgeInsets.symmetric(horizontal: 12),
                      itemCount: cart.length,
                      itemBuilder: (context, index) {
                        final item = cart[index];
                        return _buildCartItem(item, index);
                      },
                    ),
            ),
            _cartTotals(rate, cart),
          ],
        );
      },
    );
  }

  Widget _buildCartItem(Map<String, dynamic> item, int index) {
    final qty = asDouble(item['qty']);
    final price = (item['price'] as num?)?.toDouble() ?? 0.0;
    final itemId = item['id'];
    return Card(
      key: ValueKey('$itemId-$qty'),
      margin: const EdgeInsets.only(bottom: 8),
      elevation: 1,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      child: Padding(
        padding: const EdgeInsets.all(8.0),
        child: Row(
          children: [
            Container(
              width: 40,
              height: 40,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: Colors.grey.shade200,
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Icon(Icons.fastfood, color: Colors.grey),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(item['name']?.toString() ?? '', style: const TextStyle(fontWeight: FontWeight.w600)),
                  const SizedBox(height: 2),
                  Text(
                    _isButchery ? '\$${price.toStringAsFixed(2)} per kg' : '\$${price.toStringAsFixed(2)} each',
                    style: const TextStyle(fontSize: 12, color: Colors.black54),
                  ),
                ],
              ),
            ),
            Container(
              decoration: BoxDecoration(
                color: Colors.grey.shade100,
                borderRadius: BorderRadius.circular(20),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  IconButton(
                    onPressed: () => _changeQty(index, -_quantityStep),
                    icon: const Icon(Icons.remove_circle_outline, size: 20),
                    constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
                    padding: EdgeInsets.zero,
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8),
                    child: InkWell(
                      onTap: _isButchery ? () => _setButcheryQty(index) : null,
                      borderRadius: BorderRadius.circular(6),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
                        child: Text(
                          formatQuantityDisplay(qty, isWeight: _isButchery),
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            decoration: _isButchery ? TextDecoration.underline : TextDecoration.none,
                          ),
                        ),
                      ),
                    ),
                  ),
                  IconButton(
                    onPressed: () => _changeQty(index, _quantityStep),
                    icon: const Icon(Icons.add_circle_outline, size: 20),
                    constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
                    padding: EdgeInsets.zero,
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            SizedBox(
              width: 64,
              child: Text(
                '\$${(price * qty).toStringAsFixed(2)}',
                textAlign: TextAlign.end,
                style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
              ),
            ),
            IconButton(
              onPressed: () => _remove(index),
              icon: const Icon(Icons.delete_outline, size: 22, color: Colors.redAccent),
              constraints: const BoxConstraints(),
              padding: const EdgeInsets.only(left: 8),
            ),
          ],
        ),
      ),
    );
  }

  Widget _cartTotals(double rate, List<Map<String, dynamic>> cart) {
    final totalItems = cart.fold<double>(0, (s, i) => s + asDouble(i['qty']));
    final currentTotalUSD = cart.fold(0.0, (s, i) => s + asDouble(i['price']) * asDouble(i['qty']));
    return Material(
      elevation: 10,
      child: Container(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
        decoration: BoxDecoration(
          color: Theme.of(context).scaffoldBackgroundColor,
          border: Border(top: BorderSide(color: Colors.grey.shade200, width: 1)),
        ),
        child: Column(
          children: [
            Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
              AnimatedSwitcher(
                duration: const Duration(milliseconds: 200),
                child: Text(
                  _isButchery
                      ? 'Subtotal (${formatQuantityDisplay(totalItems, isWeight: true)})'
                      : 'Subtotal (${formatDecimal(totalItems)} items)',
                  key: ValueKey(totalItems.toStringAsFixed(3)),
                  style: TextStyle(fontSize: 14, color: Colors.grey.shade700),
                ),
              ),
              AnimatedSwitcher(
                duration: const Duration(milliseconds: 300),
                transitionBuilder: (Widget child, Animation<double> animation) {
                  return SlideTransition(
                    position: animation.drive(Tween(begin: const Offset(0.3, 0), end: Offset.zero)),
                    child: FadeTransition(opacity: animation, child: child),
                  );
                },
                child: Text(
                  "\$${currentTotalUSD.toStringAsFixed(2)}",
                  key: ValueKey(currentTotalUSD.toStringAsFixed(2)),
                  style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
                ),
              ),
            ]),
            const SizedBox(height: 4),
            Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
              Text('Total in ZWL', style: TextStyle(fontSize: 14, color: Colors.grey.shade700)),
              AnimatedSwitcher(
                duration: const Duration(milliseconds: 300),
                transitionBuilder: (Widget child, Animation<double> animation) {
                  return SlideTransition(
                    position: animation.drive(Tween(begin: const Offset(0.3, 0), end: Offset.zero)),
                    child: FadeTransition(opacity: animation, child: child),
                  );
                },
                child: Text(
                  'ZWL ${(currentTotalUSD * rate).toStringAsFixed(2)}',
                  key: ValueKey((currentTotalUSD * rate).toStringAsFixed(2)),
                  style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
                ),
              ),
            ]),
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 8.0),
              child: Divider(),
            ),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text('Total', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                AnimatedSwitcher(
                  duration: const Duration(milliseconds: 300),
                  transitionBuilder: (Widget child, Animation<double> animation) {
                    return ScaleTransition(
                      scale: animation,
                      child: FadeTransition(opacity: animation, child: child),
                    );
                  },
                  child: Text(
                    "\$${currentTotalUSD.toStringAsFixed(2)}",
                    key: ValueKey('total-${currentTotalUSD.toStringAsFixed(2)}'),
                    style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: cart.isEmpty ? null : _checkout,
                icon: const Icon(Icons.payment),
                label: const Text('Proceed to Payment'),
                style: ElevatedButton.styleFrom(
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                ),
              ),
            )
          ],
        ),
      ),
    );
  }

  Widget _buildBottomCartBar(double rate) {
    return ValueListenableBuilder<List<Map<String, dynamic>>>(
      valueListenable: _cartNotifier,
      builder: (context, cart, _) {
        final preview = cart.take(3).map((e) => e['name']).join(', ');
        final totalQty = cart.fold<double>(0, (s, i) => s + asDouble(i['qty']));
        return Positioned(
          bottom: 0,
          left: 0,
          right: 0,
          child: Material(
            elevation: 8,
            child: InkWell(
              onTap: () {
                showModalBottomSheet(
                  context: context,
                  isScrollControlled: true,
                  builder: (_) => DraggableScrollableSheet(
                    initialChildSize: .85,
                    expand: false,
                    builder: (c, scroll) => Column(
                      children: [
                        Expanded(child: _buildCartPanel(rate)),
                      ],
                    ),
                  ),
                );
              },
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                color: Theme.of(context).colorScheme.primary,
                child: Row(
                  children: [
                    const Icon(Icons.shopping_cart, color: Colors.white),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        cart.isEmpty
                            ? 'Cart is empty'
                            : _isButchery
                                ? '${formatQuantityDisplay(totalQty, isWeight: true)} • $preview'
                                : '${formatDecimal(totalQty)} items • $preview',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(color: Colors.white),
                      ),
                    ),
                    const SizedBox(width: 8),
                    const Icon(Icons.expand_less, color: Colors.white),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}

class ButcheryWeightDialog extends StatefulWidget {
  final String productName;
  final double maxKg;
  final double? initialKg;
  final String actionLabel;

  const ButcheryWeightDialog({
    super.key,
    required this.productName,
    required this.maxKg,
    this.initialKg,
    required this.actionLabel,
  });

  @override
  State<ButcheryWeightDialog> createState() => _ButcheryWeightDialogState();
}

class _ButcheryWeightDialogState extends State<ButcheryWeightDialog> {
  late String _weightText;
  String? _error;

  @override
  void initState() {
    super.initState();
    _weightText = widget.initialKg != null ? formatDecimal(widget.initialKg!, decimals: 3) : '';
  }

  double? _parseKgInput() {
    return double.tryParse(_weightText.trim().replaceAll(',', '.'));
  }

  void _appendInput(String token) {
    setState(() {
      _error = null;
      if (token == '.') {
        if (_weightText.contains('.')) return;
        _weightText = _weightText.isEmpty ? '0.' : '$_weightText.';
        return;
      }
      if (_weightText == '0') {
        _weightText = token;
      } else {
        _weightText = '$_weightText$token';
      }
    });
  }

  void _backspace() {
    setState(() {
      _error = null;
      if (_weightText.isNotEmpty) {
        _weightText = _weightText.substring(0, _weightText.length - 1);
      }
    });
  }

  void _clearInput() {
    setState(() {
      _weightText = '';
      _error = null;
    });
  }

  void _submit([double? selectedKg]) {
    if (!mounted) return;
    if (selectedKg != null) {
      Navigator.pop(context, selectedKg);
      return;
    }

    final parsed = _parseKgInput();
    if (parsed == null || parsed <= 0) {
      setState(() => _error = 'Enter a valid kg amount');
      return;
    }
    if (parsed > widget.maxKg + 0.000001) {
      setState(() => _error = 'Cannot exceed available stock (${formatDecimal(widget.maxKg, decimals: 3)} kg)');
      return;
    }
    Navigator.pop(context, parsed);
  }

  @override
  Widget build(BuildContext context) {
    final displayText = _weightText.trim().isEmpty ? '0' : _weightText.trim();
    return AlertDialog(
      title: Text('${widget.actionLabel} Weight'),
      content: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 360),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(widget.productName, style: const TextStyle(fontWeight: FontWeight.w600)),
            const SizedBox(height: 8),
            Text('Available: ${formatDecimal(widget.maxKg, decimals: 3)} kg'),
            const SizedBox(height: 12),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              decoration: BoxDecoration(
                border: Border.all(color: Theme.of(context).dividerColor),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                '$displayText kg',
                textAlign: TextAlign.right,
                style: Theme.of(context).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w700),
              ),
            ),
            const SizedBox(height: 10),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [0.25, 0.5, 0.75, 1.0, 2.0].map((q) {
                return ActionChip(
                  label: Text('${formatDecimal(q, decimals: 2)} kg'),
                  onPressed: q > widget.maxKg + 0.000001 ? null : () => _submit(q),
                );
              }).toList(),
            ),
            const SizedBox(height: 12),
            _WeightKeypad(
              onDigit: _appendInput,
              onBackspace: _backspace,
              onClear: _clearInput,
            ),
            if (_error != null) ...[
              const SizedBox(height: 10),
              Text(_error!, style: const TextStyle(color: Colors.red)),
            ],
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        ElevatedButton(onPressed: _submit, child: Text(widget.actionLabel)),
      ],
    );
  }
}

class _WeightKeypad extends StatelessWidget {
  final ValueChanged<String> onDigit;
  final VoidCallback onBackspace;
  final VoidCallback onClear;

  const _WeightKeypad({
    required this.onDigit,
    required this.onBackspace,
    required this.onClear,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        _row(['1', '2', '3']),
        const SizedBox(height: 8),
        _row(['4', '5', '6']),
        const SizedBox(height: 8),
        _row(['7', '8', '9']),
        const SizedBox(height: 8),
        Row(
          children: [
            Expanded(child: _key('C', onClear)),
            const SizedBox(width: 8),
            Expanded(child: _key('0', () => onDigit('0'))),
            const SizedBox(width: 8),
            Expanded(child: _key('.', () => onDigit('.'))),
            const SizedBox(width: 8),
            SizedBox(
              width: 54,
              height: 44,
              child: OutlinedButton(
                onPressed: onBackspace,
                child: const Icon(Icons.backspace_outlined, size: 20),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _row(List<String> values) {
    return Row(
      children: [
        for (var i = 0; i < values.length; i++) ...[
          if (i > 0) const SizedBox(width: 8),
          Expanded(child: _key(values[i], () => onDigit(values[i]))),
        ],
      ],
    );
  }

  Widget _key(String label, VoidCallback onPressed) {
    return SizedBox(
      height: 44,
      child: OutlinedButton(
        onPressed: onPressed,
        child: Text(label),
      ),
    );
  }
}

// ================== SETTINGS ==================
class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});
  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  final _nameCtrl = TextEditingController();
  final _addrCtrl = TextEditingController();
  final _rateCtrl = TextEditingController();
  bool _busy = false;

  @override void initState(){ 
    super.initState(); 
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final store = context.read<StoreInfoModel>(); 
    _nameCtrl.text = store.name; 
    _addrCtrl.text = store.address; 
    _rateCtrl.text = context.read<ExchangeRateModel>().rate.toStringAsFixed(2); 
  }

  Future<void> _saveStore() async { final store = context.read<StoreInfoModel>(); await store.updateName(_nameCtrl.text); await store.updateAddress(_addrCtrl.text); if(!mounted) return; ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Store info saved'))); }
  Future<void> _saveRate() async { final rateModel = context.read<ExchangeRateModel>(); final v = double.tryParse(_rateCtrl.text); if(v==null || v<=0){ ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Invalid rate'))); return; } await rateModel.update(v); if(!mounted) return; ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Rate updated'))); }

  Future<void> _changeBusinessMode(BusinessMode mode) async {
    final businessMode = context.read<BusinessModeModel>();
    if (businessMode.mode == mode) return;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Switch Business Mode'),
        content: Text(
          mode == BusinessMode.butchery
              ? 'Switch to Butchery mode? Quantity controls will allow fractional kilograms.'
              : 'Switch to Shop mode? Quantity controls will use whole-item increments.',
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
          ElevatedButton(onPressed: () => Navigator.pop(context, true), child: const Text('Switch')),
        ],
      ),
    );

    if (confirmed != true) return;
    await businessMode.update(mode);
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Business mode changed to ${businessModeLabel(mode)}')),
    );
  }

  Future<void> _exportData() async {
    setState(()=> _busy = true);
    final db = context.read<DatabaseService>();
    final data = await db.exportData();
    final dir = await getTemporaryDirectory();
    final file = File('${dir.path}/backup_${DateTime.now().millisecondsSinceEpoch}.json');
    await file.writeAsString(const JsonEncoder.withIndent('  ').convert(data));
    await Share.shareXFiles([XFile(file.path)], text: 'ShopaFlow Backup');
    if(mounted) setState(()=> _busy = false);
  }

  Future<void> _clearAll() async {
    final db = context.read<DatabaseService>();
    final ok = await showDialog<bool>(context: context, builder: (_)=> AlertDialog(title: const Text('Confirm'), content: const Text('Delete ALL local data? This cannot be undone.'), actions:[TextButton(onPressed: ()=> Navigator.pop(context,false), child: const Text('Cancel')), ElevatedButton(style: ElevatedButton.styleFrom(backgroundColor: Colors.red), onPressed: ()=> Navigator.pop(context,true), child: const Text('Delete'))]));
    if(ok==true){ await db.clearAllData(); if(!mounted) return; ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Data cleared'))); }
  }

  @override
  Widget build(BuildContext context) {
    if (!context.watch<AuthSessionModel>().canManageSettings) {
      return const Center(child: Text('You do not have permission to manage settings.'));
    }
    final businessMode = context.watch<BusinessModeModel>();
    return SingleChildScrollView(padding: const EdgeInsets.all(16), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children:[
      const Text('Settings', style: TextStyle(fontSize:24, fontWeight: FontWeight.bold)), const SizedBox(height:16),
      _section('Store Information', [
        TextField(controller: _nameCtrl, decoration: const InputDecoration(labelText: 'Store Name', border: OutlineInputBorder())), const SizedBox(height:12),
        TextField(controller: _addrCtrl, decoration: const InputDecoration(labelText: 'Address', border: OutlineInputBorder())), const SizedBox(height:12),
        ElevatedButton(onPressed: _saveStore, child: const Text('Save Store Info')),
      ]),
      const SizedBox(height:24),
      _section('Printer Settings', [
        ElevatedButton.icon(
          icon: const Icon(Icons.print),
          label: const Text('Configure Printer'),
          onPressed: () {
            Navigator.of(context).push(
              MaterialPageRoute(builder: (_) => const PrinterSettingsPage()),
            );
          },
        ),
      ]),
      _section('Currency & Rates', [
        TextField(controller: _rateCtrl, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'USD -> ZWL Rate', border: OutlineInputBorder())), const SizedBox(height:12),
        ElevatedButton(onPressed: _saveRate, child: const Text('Update Rate')),
      ]),
      const SizedBox(height:24),
      _section('Business Mode', [
        const Text('Select operating mode', style: TextStyle(fontWeight: FontWeight.w600)),
        const SizedBox(height: 10),
        RadioListTile<BusinessMode>(
          value: BusinessMode.shop,
          groupValue: businessMode.mode,
          title: const Text('Shop'),
          subtitle: const Text('Whole-item quantities (1, 2, 3...)'),
          onChanged: (mode) {
            if (mode != null) {
              _changeBusinessMode(mode);
            }
          },
        ),
        RadioListTile<BusinessMode>(
          value: BusinessMode.butchery,
          groupValue: businessMode.mode,
          title: const Text('Butchery'),
          subtitle: const Text('Fractional quantities in kg (for example 0.25, 0.5, 1.75)'),
          onChanged: (mode) {
            if (mode != null) {
              _changeBusinessMode(mode);
            }
          },
        ),
      ]),
      const SizedBox(height:24),
      _section('App Appearance', [
        const Text('Theme Color', style: TextStyle(fontWeight: FontWeight.w600)),
        const SizedBox(height: 8),
        Consumer<ThemeModel>(
          builder: (context, themeModel, _) => Wrap(
            spacing: 8,
            children: themeModel.availableColors.map((color) => GestureDetector(
              onTap: () => themeModel.updateColor(color),
              child: Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: color,
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: themeModel.primaryColor == color ? Colors.black : Colors.transparent,
                    width: 3,
                  ),
                ),
                child: themeModel.primaryColor == color ? const Icon(Icons.check, color: Colors.white) : null,
              ),
            )).toList(),
          ),
        ),
      ]),
      const SizedBox(height:24),
      _section('Data & Backup', [
        Row(
          children: [
            Expanded(
              child: ElevatedButton.icon(
                onPressed: _busy? null: _exportData, 
                icon: const Icon(Icons.file_download), 
                label: Text(_busy? 'Exporting...':'Export Backup'),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: ElevatedButton.icon(
                style: ElevatedButton.styleFrom(backgroundColor: Colors.red), 
                onPressed: _clearAll, 
                icon: const Icon(Icons.delete_forever), 
                label: const Text('Clear All Data'),
              ),
            ),
          ],
        ),
      ]),
      const SizedBox(height:24),
      _section('About', [
        const Text('ShopaFlow POS v1.0.0', style: TextStyle(fontWeight: FontWeight.w600)), const SizedBox(height:4), const Text('A lightweight offline-first POS application. A product of ILOC.'), const SizedBox(height:4), const Text('© 2025 Infinity Lines of Code Pvt Ltd'), const SizedBox(height:8), const Text('Website: https://infinitylinesofcode.com'), const SizedBox(height:4), const Text('Email: sales@infinitylinesofcode.com')
      ])
    ]));
  }

  Widget _section(String title, List<Widget> children){
    return Card(child: Padding(padding: const EdgeInsets.all(16), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children:[Text(title, style: const TextStyle(fontSize:18, fontWeight: FontWeight.bold)), const SizedBox(height:12), ...children] )));
  }
}

// ================== ADD PRODUCT DIALOG ==================
class AddProductDialog extends StatefulWidget { final Map<String,dynamic>? product; const AddProductDialog({super.key, this.product}); @override State<AddProductDialog> createState()=> _AddProductDialogState(); }
class _AddProductDialogState extends State<AddProductDialog>{
  final _form = GlobalKey<FormState>();
  final _name = TextEditingController();
  final _desc = TextEditingController();
  final _price = TextEditingController();
  final _cost = TextEditingController();
  final _stock = TextEditingController();
  final _minStock = TextEditingController(text: '5');
  final _barcode = TextEditingController();
  final _category = TextEditingController();
  final _sku = TextEditingController();

  @override void initState(){ super.initState(); final p = widget.product; if(p!=null){ _name.text = p['name']??''; _desc.text = p['description']??''; _price.text = (p['price']??'').toString(); _cost.text=(p['cost']??'').toString(); _stock.text = (p['stock_quantity']??'').toString(); _minStock.text = (p['min_stock_level']??5).toString(); _barcode.text = p['barcode']??''; _category.text = p['category']??''; _sku.text = p['sku']??''; }}

  @override void dispose(){ _name.dispose(); _desc.dispose(); _price.dispose(); _cost.dispose(); _stock.dispose(); _minStock.dispose(); _barcode.dispose(); _category.dispose(); _sku.dispose(); super.dispose(); }

  void _submit(){
    if(!_form.currentState!.validate()) return;
    Navigator.pop(context, {
      'name': _name.text.trim(),
      'description': _desc.text.trim(),
      'price': double.parse(_price.text),
      'cost': double.tryParse(_cost.text)??0,
      'stock': double.parse(_stock.text),
      'min_stock': double.parse(_minStock.text),
      'barcode': _barcode.text.trim(),
      'category': _category.text.trim(),
      'sku': _sku.text.trim(),
    });
  }

  @override
  Widget build(BuildContext context) {
    final isButchery = context.watch<BusinessModeModel>().isButchery;
    return AlertDialog(title: Text(widget.product==null? 'Add Product':'Edit Product'), content: ConstrainedBox(constraints: const BoxConstraints(maxWidth: 400), child: Form(key: _form, child: SingleChildScrollView(child: Column(children:[
      TextFormField(controller: _name, decoration: const InputDecoration(labelText: 'Name'), validator: (v)=> v==null||v.trim().isEmpty? 'Required': null),
      const SizedBox(height:8),
      TextFormField(controller: _desc, decoration: const InputDecoration(labelText: 'Description')),
      const SizedBox(height:8),
      Row(children:[ Expanded(child: TextFormField(controller: _price, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'Price'), validator: (v)=> double.tryParse(v??'')==null? 'Number': null)), const SizedBox(width:8), Expanded(child: TextFormField(controller: _cost, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'Cost'))) ]),
      const SizedBox(height:8),
      Row(children:[ Expanded(child: TextFormField(controller: _stock, keyboardType: const TextInputType.numberWithOptions(decimal: true), decoration: InputDecoration(labelText: isButchery ? 'Stock (kg)' : 'Stock'), validator: (v)=> double.tryParse(v??'')==null? 'Number': null)), const SizedBox(width:8), Expanded(child: TextFormField(controller: _minStock, keyboardType: const TextInputType.numberWithOptions(decimal: true), decoration: InputDecoration(labelText: isButchery ? 'Min Stock (kg)' : 'Min Stock'), validator: (v)=> double.tryParse(v??'')==null? 'Number': null)) ]),
      const SizedBox(height:8),
      TextFormField(controller: _barcode, decoration: const InputDecoration(labelText: 'Barcode (Optional)', hintText: 'Leave blank if not available')),
      const SizedBox(height:8),
      TextFormField(controller: _category, decoration: const InputDecoration(labelText: 'Category')),
      const SizedBox(height:8),
      TextFormField(controller: _sku, decoration: const InputDecoration(labelText: 'SKU (Optional)', hintText: 'Leave blank if not available')),
    ])))), actions: [TextButton(onPressed: ()=> Navigator.pop(context), child: const Text('Cancel')), ElevatedButton(onPressed: _submit, child: const Text('Save'))]);
  }
}

// ================== PAYMENT DIALOG ==================
class _PaymentDialog extends StatefulWidget {
  final double total;
  const _PaymentDialog({required this.total});
  @override State<_PaymentDialog> createState()=> _PaymentDialogState();
}

class _PaymentDialogState extends State<_PaymentDialog> {
  String method = 'Cash';
  final _amount = TextEditingController();
  double? _amountReceived;
  double get _change => (_amountReceived ?? 0) - widget.total;

  @override
  void initState(){
    super.initState();
    _amount.text = widget.total.toStringAsFixed(2);
    _amountReceived = widget.total;
  }

  @override
  void dispose(){
    _amount.dispose();
    super.dispose();
  }

  void _processPayment() {
    FocusScope.of(context).unfocus();
    if(method == 'Cash'){
      final paid = double.tryParse(_amount.text) ?? 0;
      if(paid < widget.total){
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('Insufficient amount'),
            backgroundColor: Theme.of(context).colorScheme.error,
          )
        );
        return;
      }
      _amountReceived = paid;
    }
    Navigator.pop(context, method);
  }

  @override
  Widget build(BuildContext context){
    final primary = Theme.of(context).colorScheme.primary;
    return AlertDialog(
      title: Row(
        children: [
          Icon(Icons.payment, color: primary),
          const SizedBox(width: 8),
          const Text('Select Payment Method'),
        ],
      ),
      content: SingleChildScrollView(
        padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 400),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: primary.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: primary.withValues(alpha: 0.3)),
                ),
                child: Column(
                  children: [
                    Text('Total: \$${widget.total.toStringAsFixed(2)}', style: const TextStyle(fontWeight: FontWeight.bold)),
                    if (method == 'Cash' && _amountReceived != null) ...[
                      const SizedBox(height: 6),
                      Text('Change: \$${_change.toStringAsFixed(2)}'),
                    ],
                  ],
                ),
              ),
              const SizedBox(height: 16),
              _buildPaymentMethodCard('Cash', Icons.payments, 'Pay with cash', primary),
              const SizedBox(height: 8),
              _buildPaymentMethodCard('Card', Icons.credit_card, 'Pay with card', Theme.of(context).colorScheme.secondary),
              const SizedBox(height: 8),
              _buildPaymentMethodCard('Mobile Money', Icons.phone_android, 'Pay with mobile money', Colors.orange),
              if(method == 'Cash') ...[
                const SizedBox(height: 16),
                const Text('Amount Received'),
                const SizedBox(height: 6),
                TextField(
                  controller: _amount,
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  onChanged: (value){ setState((){ _amountReceived = double.tryParse(value) ?? 0.0; }); },
                  decoration: const InputDecoration(prefixText: '\$', hintText: '0.00'),
                ),
              ],
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        ElevatedButton.icon(
          onPressed: _processPayment,
          icon: const Icon(Icons.check),
          label: const Text('Complete'),
        ),
      ],
    );
  }

  Widget _buildPaymentMethodCard(String methodName, IconData icon, String description, Color color) {
    final isSelected = method == methodName;

    return InkWell(
      onTap: () => setState(() => method = methodName),
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isSelected ? color : Colors.grey.shade300,
            width: isSelected ? 2 : 1,
          ),
          color: isSelected ? color.withValues(alpha: 0.08) : Colors.white,
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(8),
                color: color.withValues(alpha: 0.1),
              ),
              child: Icon(icon, size: 24, color: color),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(methodName, style: const TextStyle(fontWeight: FontWeight.w600)),
                  const SizedBox(height: 4),
                  Text(description, style: const TextStyle(fontSize: 12, color: Colors.black54)),
                ],
              ),
            ),
            if (isSelected)
              Icon(Icons.check_circle, size: 24, color: color),
          ],
        ),
      ),
    );
  }
}

// ================== PRODUCTS SCREEN ==================
class ProductsScreen extends StatefulWidget {
  const ProductsScreen({super.key});
  @override
  State<ProductsScreen> createState() => _ProductsScreenState();
}

class _ProductsScreenState extends State<ProductsScreen> {
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';
  String _selectedCategory = 'All';
  bool _loading = true;
  List<Map<String, dynamic>> _products = [];
  List<String> _categories = ['All'];
  late DatabaseService _db;
  bool _didScheduleInitialLoad = false;

  @override
  void initState() {
    super.initState();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _db = context.read<DatabaseService>();
    if (_didScheduleInitialLoad) return;
    _didScheduleInitialLoad = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _loadProducts();
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadProducts() async {
    if (mounted) setState(() => _loading = true);
    try {
      final products = await _db.getAllProducts();
      final categories = <String>{'All'};
      for (final product in products) {
        final category = product['category']?.toString().trim();
        if (category != null && category.isNotEmpty) {
          categories.add(category);
        }
      }
      if (mounted) {
        setState(() {
          _products = products;
          _categories = categories.toList()..sort();
          _loading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _loading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error loading products: $e')),
        );
      }
    }
  }

  List<Map<String, dynamic>> get _filteredProducts {
    return _products.where((product) {
      final matchesSearch = _searchQuery.isEmpty ||
          product['name']?.toString().toLowerCase().contains(_searchQuery.toLowerCase()) == true ||
          product['category']?.toString().toLowerCase().contains(_searchQuery.toLowerCase()) == true ||
          product['barcode']?.toString().contains(_searchQuery) == true;

      final matchesCategory = _selectedCategory == 'All' ||
          product['category']?.toString() == _selectedCategory;

      return matchesSearch && matchesCategory;
    }).toList();
  }

  Future<void> _addOrEdit([Map<String, dynamic>? product]) async {
    if (!context.read<AuthSessionModel>().canManageInventory) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('You do not have permission to manage inventory.')));
      return;
    }
    final result = await showDialog<Map<String, dynamic>>(
      context: context,
      builder: (_) => AddProductDialog(product: product),
    );

    if (result != null) {
      try {
        final productData = Map<String, dynamic>.from(result);
        if ((productData['sku']?.toString() ?? '').trim().isEmpty) productData['sku'] = null;
        if ((productData['barcode']?.toString() ?? '').trim().isEmpty) productData['barcode'] = null;

        if (product == null) {
          // Adding new product
          await _db.addProduct({
            'name': productData['name'], 'description': productData['description'], 'price': productData['price'],
            'cost': productData['cost'], 'stock_quantity': productData['stock'], 'min_stock_level': productData['min_stock'],
            'barcode': productData['barcode'], 'category': productData['category'], 'sku': productData['sku'],
          });
          if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Product added')));
        } else {
          // Editing existing product
          await _db.updateProduct(product['id'], {
            'name': productData['name'], 'description': productData['description'], 'price': productData['price'],
            'cost': productData['cost'], 'stock_quantity': productData['stock'], 'min_stock_level': productData['min_stock'],
            'barcode': productData['barcode'], 'category': productData['category'], 'sku': productData['sku'],
          });
          if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Product updated')));
        }
        _loadProducts();
      } catch (e) {
        if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
      }
    }
  }

  Future<void> _deleteProduct(Map<String, dynamic> product) async {
    if (!context.read<AuthSessionModel>().canManageInventory) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('You do not have permission to delete products.')));
      return;
    }
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Delete Product'),
        content: Text('Are you sure you want to delete "${product['name']}"?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
          ElevatedButton(style: ElevatedButton.styleFrom(backgroundColor: Colors.red), onPressed: () => Navigator.pop(context, true), child: const Text('Delete')),
        ],
      ),
    );

    if (confirmed == true) {
      try {
        await _db.deleteProduct(product['id']);
        _loadProducts();
        if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Product deleted')));
      } catch (e) {
        if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
      }
    }
  }

  Future<void> _exportProducts() async {
    if (!context.read<AuthSessionModel>().canManageInventory) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('You do not have permission to export products.')));
      return;
    }
    try {
      final products = await _db.getAllProducts();
      if (products.isEmpty) {
        if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('No products to export')));
        return;
      }
      List<List<dynamic>> csvData = [['Name', 'Description', 'Price', 'Cost', 'Stock', 'Min Stock', 'Barcode', 'Category', 'SKU']];
      for (final p in products) {
        csvData.add([p['name']??'', p['description']??'', p['price']??0, p['cost']??0, p['stock_quantity']??0, p['min_stock_level']??5, p['barcode']??'', p['category']??'', p['sku']??'']);
      }
      String csvString = const ListToCsvConverter().convert(csvData);
      final dir = await getApplicationDocumentsDirectory();
      final file = File('${dir.path}/products_export_${DateTime.now().millisecondsSinceEpoch}.csv');
      await file.writeAsString(csvString);
      await Share.shareXFiles([XFile(file.path)], text: 'Products Export');
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Products exported')));
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
    }
  }

  Future<void> _importProducts() async {
    if (!context.read<AuthSessionModel>().canManageInventory) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('You do not have permission to import products.')));
      return;
    }
    final result = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Import Products'),
        content: const SingleChildScrollView(child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text('CSV Format:'), SizedBox(height: 8),
          Text('Columns: Name, Description, Price, Cost, Stock, Min Stock, Barcode, Category, SKU', style: TextStyle(fontFamily: 'monospace', fontSize: 12)),
        ])),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
          TextButton(onPressed: () => Navigator.pop(context, 'sample'), child: const Text('Download Sample')),
          ElevatedButton(onPressed: () => Navigator.pop(context, 'import'), child: const Text('Import CSV')),
        ],
      ),
    );
    if (result == 'sample') {
      await _downloadSampleCSV();
    } else if (result == 'import') await _performCSVImport();
  }

  Future<void> _downloadSampleCSV() async {
    try {
      List<List<dynamic>> sampleData = [
        ['Name', 'Description', 'Price', 'Cost', 'Stock', 'Min Stock', 'Barcode', 'Category', 'SKU'],
        ['Sample 1', 'Desc 1', 10.99, 5.50, 100, 10, '123', 'Cat A', 'S1'],
      ];
      String csvString = const ListToCsvConverter().convert(sampleData);
      final dir = await getApplicationDocumentsDirectory();
      final file = File('${dir.path}/sample_products.csv');
      await file.writeAsString(csvString);
      await Share.shareXFiles([XFile(file.path)], text: 'Sample Products CSV');
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Sample CSV created')));
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
    }
  }

  Future<void> _performCSVImport() async {
    final csvController = TextEditingController();
    final csvContent = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Paste CSV Content'),
        content: TextField(controller: csvController, maxLines: 10, decoration: const InputDecoration(border: OutlineInputBorder(), hintText: 'Name,Desc,Price...')),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
          ElevatedButton(onPressed: () => Navigator.pop(context, csvController.text), child: const Text('Import')),
        ],
      ),
    );
    csvController.dispose();
    if (csvContent != null && csvContent.trim().isNotEmpty) await _processCsvContent(csvContent);
  }

  Future<void> _processCsvContent(String csvContent) async {
    try {
      List<List<dynamic>> csvTable = const CsvToListConverter().convert(csvContent);
      if (csvTable.isEmpty) throw 'CSV is empty';
      final dataRows = csvTable.skip(1).toList();
      if (dataRows.isEmpty) throw 'No data rows';

      int imported = 0, errors = 0;
      String errorMessages = '';

      for (int i = 0; i < dataRows.length; i++) {
        try {
          final row = dataRows[i];
          if (row.length < 3) throw 'Row ${i+2}: Missing required columns';
          final name = row[0]?.toString().trim();
          if (name == null || name.isEmpty) throw 'Row ${i+2}: Name is required';
          
          final barcodeValue = row.length > 6 ? row[6]?.toString().trim() : null;
          final skuValue = row.length > 8 ? row[8]?.toString().trim() : null;

          await _db.addProduct({
            'name': name, 'description': row.length > 1 ? row[1]?.toString().trim() : '',
            'price': double.tryParse(row[2]?.toString() ?? '0') ?? 0, 'cost': row.length > 3 ? (double.tryParse(row[3]?.toString() ?? '0') ?? 0) : 0,
            'stock_quantity': double.tryParse(row[4]?.toString() ?? '0') ?? 0, 'min_stock_level': row.length > 5 ? (double.tryParse(row[5]?.toString() ?? '5') ?? 5) : 5,
            'barcode': (barcodeValue == null || barcodeValue.isEmpty) ? null : barcodeValue,
            'category': row.length > 7 ? row[7]?.toString().trim() : '', 
            'sku': (skuValue == null || skuValue.isEmpty) ? null : skuValue,
          });
          imported++;
        } catch (e) {
          errors++;
          errorMessages += 'Row ${i+2}: $e\n';
        }
      }
      _loadProducts();
      String message = 'Imported: $imported, Errors: $errors';
      if (errors > 0 && mounted) {
        showDialog(context: context, builder: (c) => AlertDialog(title: const Text('Import Errors'), content: SingleChildScrollView(child: Text(errorMessages)), actions: [TextButton(onPressed: ()=>Navigator.pop(c), child: const Text('OK'))]));
      }
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error processing CSV: $e')));
    }
  }



  @override
  Widget build(BuildContext context) {
    final isButchery = context.watch<BusinessModeModel>().isButchery;
    return Scaffold(
      body: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(color: Colors.white, border: Border(bottom: BorderSide(color: Colors.grey.shade200))),
            child: Column(
              children: [
                Row(children: [
                  Expanded(child: TextField(controller: _searchController, decoration: const InputDecoration(hintText: 'Search...', prefixIcon: Icon(Icons.search)), onChanged: (v) => setState(() => _searchQuery = v))),
                  const SizedBox(width:  12),
                  DropdownButton<String>(value: _selectedCategory, items: _categories.map((c) => DropdownMenuItem(value: c, child: Text(c))).toList(), onChanged: (v) => setState(() => _selectedCategory = v ?? 'All')),
                  const SizedBox(width: 12),
                  ElevatedButton.icon(onPressed: () => _addOrEdit(), icon: const Icon(Icons.add), label: const Text('Add')),
                ]),
                const SizedBox(height: 12),
                Row(children: [
                  Expanded(child: OutlinedButton.icon(onPressed: _importProducts, icon: const Icon(Icons.file_upload), label: const Text('Import'))),
                  const SizedBox(width: 12),
                  Expanded(child: OutlinedButton.icon(onPressed: _exportProducts, icon: const Icon(Icons.file_download), label: const Text('Export'))),
                ]),
              ],
            ),
          ),
          Expanded(
            child: _loading ? const Center(child: CircularProgressIndicator()) : _filteredProducts.isEmpty ? const Center(child: Text('No products')) : ListView.builder(
              itemCount: _filteredProducts.length,
              itemBuilder: (context, index) {
                final p = _filteredProducts[index];
                final stock = asDouble(p['stock_quantity'] ?? 0);
                final minStock = asDouble(p['min_stock_level'] ?? 5);
                final low = stock < minStock;
                return Card(
                  margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  child: ListTile(
                    leading: CircleAvatar(backgroundColor: low ? Colors.orange.shade100 : Colors.green.shade100, child: Text(p['name']?.toString().characters.first.toUpperCase() ?? '?')),
                    title: Text(p['name']?.toString() ?? ''),
                    subtitle: Text('Stock: ${formatQuantityDisplay(stock, isWeight: isButchery)} • ${p['category'] ?? 'No Cat'}', maxLines: 1, overflow: TextOverflow.ellipsis),
                    trailing: Wrap(spacing: 8, children: [
                      IconButton(onPressed: () => _addOrEdit(p), icon: const Icon(Icons.edit)),
                      IconButton(onPressed: () => _deleteProduct(p), icon: const Icon(Icons.delete, color: Colors.red)),
                    ]),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

// ================== REPORTS SCREEN ==================
class ReportsScreen extends StatefulWidget {
  const ReportsScreen({super.key});
  @override
  State<ReportsScreen> createState() => _ReportsScreenState();
}

class _ReportsScreenState extends State<ReportsScreen> with TickerProviderStateMixin {
  late TabController _tabController;
  bool _loading = true;
  Map<String, dynamic> _salesData = {};
  List<Map<String, dynamic>> _recentSales = [];
  Map<String, dynamic> _inventoryData = {};
  int _todayTransactions = 0;
  bool _didScheduleInitialLoad = false;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _tabController.addListener(() => setState(() {}));
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_didScheduleInitialLoad) return;
    _didScheduleInitialLoad = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _loadReportsData();
    });
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _loadReportsData() async {
    if (mounted) setState(() => _loading = true);
    try {
      final db = context.read<DatabaseService>();
      final sales = await db.getAllSales();
      final products = await db.getAllProducts();

      final today = DateTime.now();
      final startOfDay = DateTime(today.year, today.month, today.day);
      final startOfWeek = today.subtract(Duration(days: today.weekday - 1));
      final startOfMonth = DateTime(today.year, today.month, 1);

      double todaySales = 0;
      double weekSales = 0;
      double monthSales = 0;
      double totalSales = 0;
      int todayTransactions = 0;

      Map<String, int> paymentMethods = {};

      for (final sale in sales) {
        final saleDate = DateTime.parse(sale['sale_date']);
        final amount = (sale['total_amount'] as num).toDouble();
        totalSales += amount;

        if (saleDate.isAfter(startOfDay)) {
          todaySales += amount;
          todayTransactions++;
        }
        if (saleDate.isAfter(startOfWeek)) weekSales += amount;
        if (saleDate.isAfter(startOfMonth)) monthSales += amount;

        // Track payment methods
        final method = sale['payment_method'] ?? 'Unknown';
        paymentMethods[method] = (paymentMethods[method] ?? 0) + 1;
      }

      // Calculate inventory metrics
      int totalProducts = products.length;
      int lowStockProducts = 0;
      int outOfStockProducts = 0;
      double totalInventoryValue = 0;

      for (final product in products) {
        final stock = asDouble(product['stock_quantity'] ?? 0);
        final minStock = asDouble(product['min_stock_level'] ?? 5);
        final cost = (product['cost'] as num?)?.toDouble() ?? 0;

        totalInventoryValue += stock * cost;

        if (stock == 0) {
          outOfStockProducts++;
        } else if (stock <= minStock) {
          lowStockProducts++;
        }
      }

      setState(() {
        _salesData = {
          'today': todaySales,
          'week': weekSales,
          'month': monthSales,
          'total': totalSales,
          'paymentMethods': paymentMethods,
          'totalTransactions': sales.length,
        };

        _inventoryData = {
          'totalProducts': totalProducts,
          'lowStock': lowStockProducts,
          'outOfStock': outOfStockProducts,
          'totalValue': totalInventoryValue,
        };

        _recentSales = sales.take(10).toList();
        _todayTransactions = todayTransactions;
        _loading = false;
      });
    } catch (e) {
      setState(() => _loading = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error loading reports: $e')),
        );
      }
    }
  }

  Future<void> _exportSales() async {
    final db = context.read<DatabaseService>();
    final sales = await db.getAllSales();
    if (sales.isEmpty) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('No sales to export')));
      return;
    }

    List<List<dynamic>> rows = [['ID', 'Total Amount', 'Payment Method', 'Date']];
    for (var sale in sales) {
      rows.add([sale['id'], sale['total_amount'], sale['payment_method'], sale['sale_date']]);
    }

    String csv = const ListToCsvConverter().convert(rows);
    final dir = await getTemporaryDirectory();
    final file = File('${dir.path}/sales_report_${DateTime.now().toIso8601String().split('T').first}.csv');
    await file.writeAsString(csv);
    await Share.shareXFiles([XFile(file.path)], text: 'Sales Report');
  }

  Future<void> _showSaleDetails(Map<String, dynamic> sale) async {
    final db = context.read<DatabaseService>();
    final items = await db.getSaleItems(sale['id']);
    
    if (mounted) {
      showDialog(
        context: context,
        builder: (_) => AlertDialog(
          title: Text('Sale #${sale['id']} Details'),
          content: SizedBox(
            width: double.maxFinite,
            child: ListView.builder(
              shrinkWrap: true,
              itemCount: items.length,
              itemBuilder: (context, index) {
                final item = items[index];
                final isButchery = context.read<BusinessModeModel>().isButchery;
                return ListTile(
                  title: Text(item['product_name']?.toString() ?? 'Unknown'),
                  subtitle: Text('Qty: ${formatQuantityDisplay(asDouble(item['quantity']), isWeight: isButchery)} @ \$${asDouble(item['unit_price']).toStringAsFixed(2)}'),
                  trailing: Text('\$${(item['total_price'] as num).toStringAsFixed(2)}'),
                );
              },
            ),
          ),
          actions: [TextButton(onPressed: () => Navigator.pop(context), child: const Text('Close'))],
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    if (!context.watch<AuthSessionModel>().canViewReports) {
      return const Center(child: Text('You do not have permission to view reports.'));
    }
    return Scaffold(
      floatingActionButton: _tabController.index == 2
          ? FloatingActionButton.extended(onPressed: _exportSales, label: const Text('Export Sales'), icon: const Icon(Icons.download))
          : null,
      body: Column(
        children: [
          Container(
            color: Colors.white,
            child: TabBar(
              controller: _tabController,
              labelColor: Theme.of(context).colorScheme.primary,
              unselectedLabelColor: Colors.grey,
              indicatorColor: Theme.of(context).colorScheme.primary,
              tabs: const [
                Tab(icon: Icon(Icons.bar_chart), text: 'Sales'),
                Tab(icon: Icon(Icons.inventory_2), text: 'Inventory'),
                Tab(icon: Icon(Icons.receipt_long), text: 'Transactions'),
              ],
            ),
          ),
          Expanded(
            child: _loading
                ? const Center(child: CircularProgressIndicator())
                : TabBarView(
                    controller: _tabController,
                    children: [_buildSalesTab(), _buildInventoryTab(), _buildTransactionsTab()],
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildSalesTab() {
    final payment = (_salesData['paymentMethods'] as Map<String, int>? ) ?? {};
    final todaySales = asDouble(_salesData['today']);
    final averageTicket = _todayTransactions > 0 ? todaySales / _todayTransactions : 0.0;
    final modeLabel = businessModeLabel(context.watch<BusinessModeModel>().mode);
    return RefreshIndicator(
      onRefresh: _loadReportsData,
      child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            GridView.count(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              crossAxisCount: 2,
              crossAxisSpacing: 16,
              mainAxisSpacing: 16,
              childAspectRatio: 1.5,
              children: [
                _buildMetricCard('Today', "\$${((_salesData['today'] ?? 0) as num).toStringAsFixed(2)}", Icons.today, Colors.blue),
                _buildMetricCard('This Week', "\$${((_salesData['week'] ?? 0) as num).toStringAsFixed(2)}", Icons.view_week, Colors.indigo),
                _buildMetricCard('This Month', "\$${((_salesData['month'] ?? 0) as num).toStringAsFixed(2)}", Icons.calendar_month, Colors.teal),
                _buildMetricCard('Total', "\$${((_salesData['total'] ?? 0) as num).toStringAsFixed(2)}", Icons.ssid_chart, Colors.green),
              ],
            ),
            const SizedBox(height: 24),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('End of Day Snapshot ($modeLabel)', style: const TextStyle(fontWeight: FontWeight.bold)),
                    const SizedBox(height: 10),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text('Today\'s transactions'),
                        Text('$_todayTransactions'),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text('Average ticket'),
                        Text('\$${averageTicket.toStringAsFixed(2)}'),
                      ],
                    ),
                    const SizedBox(height: 10),
                    const Divider(),
                    const SizedBox(height: 4),
                    const Text('Payment Methods', style: TextStyle(fontWeight: FontWeight.bold)),
                    const SizedBox(height: 12),
                    if (payment.isEmpty) const Text('No data') else ...payment.entries.map((e) => Padding(
                      padding: const EdgeInsets.only(bottom: 6),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(e.key),
                          Text('${e.value} txns'),
                        ],
                      ),
                    )),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildInventoryTab() {
    final isButchery = context.watch<BusinessModeModel>().isButchery;
    return RefreshIndicator(
      onRefresh: _loadReportsData,
      child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            GridView.count(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              crossAxisCount: 2,
              crossAxisSpacing: 16,
              mainAxisSpacing: 16,
              childAspectRatio: 1.5,
              children: [
                _buildMetricCard('Products', (_inventoryData['totalProducts'] ?? 0).toString(), Icons.inventory, Colors.blueGrey),
                _buildMetricCard(isButchery ? 'Low Stock Items' : 'Low Stock', (_inventoryData['lowStock'] ?? 0).toString(), Icons.warning_amber, Colors.orange),
                _buildMetricCard('Out of Stock', (_inventoryData['outOfStock'] ?? 0).toString(), Icons.block, Colors.redAccent),
                _buildMetricCard('Inventory Value', 'ZWL ${asDouble(_inventoryData['totalValue']).toStringAsFixed(2)}', Icons.price_change, Colors.green),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTransactionsTab() {
    return RefreshIndicator(
      onRefresh: _loadReportsData,
      child: _recentSales.isEmpty
          ? const Center(child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
              Icon(Icons.receipt_long, size: 64, color: Colors.grey),
              SizedBox(height: 16),
              Text('No transactions yet', style: TextStyle(fontSize: 18, color: Colors.grey)),
            ]))
          : ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: _recentSales.length,
              itemBuilder: (context, index) {
                final sale = _recentSales[index];
                final date = DateTime.parse(sale['sale_date']);

                return Card(
                  margin: const EdgeInsets.only(bottom: 8),
                  child: ListTile(
                    leading: const Icon(Icons.receipt_long),
                    title: Text("\$${(sale['total_amount'] as num).toStringAsFixed(2)}"),
                    subtitle: Text(_formatDate(date)),
                    trailing: Text(sale['payment_method']?.toString() ?? 'Unknown'),
                    onTap: () => _showSaleDetails(sale),
                  ),
                );
              },
            ),
    );
  }

  Widget _buildMetricCard(String title, String value, IconData icon, Color color) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(color: color.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(10)),
                  child: Icon(icon, color: color),
                ),
                const SizedBox(width: 12),
                Text(title, style: const TextStyle(fontWeight: FontWeight.w600)),
              ],
            ),
            const Spacer(),
            Text(
              value,
              style: const TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 18,
              ),
            ),
            const SizedBox(height: 2),
            const Text(
              '',
              style: TextStyle(
                fontSize: 12,
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _formatDate(DateTime date) {
    return '${date.day}/${date.month}/${date.year} ${date.hour.toString().padLeft(2, '0')}:${date.minute.toString().padLeft(2, '0')}';
  }
}
