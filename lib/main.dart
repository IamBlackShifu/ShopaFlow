import 'package:quick_print/quick_print.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'dart:async';
import 'dart:io';
import 'dart:convert';
import 'package:share_plus/share_plus.dart';
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'services/db_service.dart';
import 'printer_settings.dart';
import 'package:csv/csv.dart';

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
    await prefs.setInt(_colorKey, color.value);
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

// ================== APP ENTRY ==================
void main() {
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
  final db = DatabaseService();
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
  @override
  void initState() {
    super.initState();
    _controller = AnimationController(vsync: this, duration: const Duration(seconds: 2))..forward();
    _fade = CurvedAnimation(parent: _controller, curve: Curves.easeIn);
    _initializeApp();
  }

  Future<void> _initializeApp() async {
    // Load all models
    await context.read<StoreInfoModel>().load();
    await context.read<ExchangeRateModel>().load();
    await context.read<ThemeModel>().load();
    await context.read<SetupStatusModel>().load();
    
    // Navigate after loading
    Timer(const Duration(seconds: 2), () {
      final isSetupCompleted = context.read<SetupStatusModel>().isSetupCompleted;
      Navigator.pushReplacement(
        context, 
        MaterialPageRoute(
          builder: (_) => isSetupCompleted ? const MainScreen() : const SetupWizardScreen()
        )
      );
    });
  }

  @override
  void dispose() { _controller.dispose(); super.dispose(); }
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [Color(0xFF2E7D32), Color(0xFF1B5E20), Color(0xFF0D47A1)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
        ),
        child: Center(
          child: FadeTransition(
            opacity: _fade,
            child: const Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.point_of_sale, color: Colors.white, size: 80),
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
    // Save all settings
    await context.read<StoreInfoModel>().updateName(_shopNameController.text);
    await context.read<StoreInfoModel>().updateAddress(_addressController.text);
    await context.read<ExchangeRateModel>().update(double.tryParse(_exchangeRateController.text) ?? 320);
    await context.read<ThemeModel>().updateColor(_selectedColor);
    await context.read<SetupStatusModel>().markSetupCompleted();

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
    return Padding(
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
              color: _selectedColor.withOpacity(0.1),
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
    return Padding(
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
              color: Colors.blue.withOpacity(0.1),
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
    
    return Padding(
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
              color: _selectedColor.withOpacity(0.1),
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

// ================== MAIN SHELL ==================
class MainScreen extends StatefulWidget {
  const MainScreen({super.key});
  @override
  State<MainScreen> createState() => _MainScreenState();
}

class _MainScreenState extends State<MainScreen> {
  int _index = 0;
  late final List<Widget> _pages;

  @override
  void initState() {
    super.initState();
    _pages = const [CheckoutScreen(), ProductsScreen(), ReportsScreen(), SettingsScreen()];
  }

  @override
  Widget build(BuildContext context) {
    final isLandscape = MediaQuery.of(context).orientation == Orientation.landscape;
    final store = context.watch<StoreInfoModel>();
    return Scaffold(
      appBar: AppBar(
        title: Row(children: [
          const Icon(Icons.storefront, color: Colors.white),
          const SizedBox(width: 8),
          Text(store.name, style: const TextStyle(color: Colors.white)),
        ]),
        actions: [
          Consumer<ExchangeRateModel>(
            builder: (_, rateModel, __) => Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              margin: const EdgeInsets.only(right: 8),
              decoration: BoxDecoration(color: Colors.white.withOpacity(0.15), borderRadius: BorderRadius.circular(6)),
              child: Text('1 USD = ${rateModel.rate.toStringAsFixed(2)} ZWL', style: const TextStyle(color: Colors.white, fontSize: 12)),
            ),
          ),
          IconButton(
            icon: const Icon(Icons.cloud_done, color: Colors.white),
            onPressed: () => ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('All data synced'))),
          ),
        ],
        backgroundColor: Theme.of(context).colorScheme.primary,
      ),
      body: isLandscape ? Row(children: [
        NavigationRail(
          backgroundColor: Theme.of(context).colorScheme.primary,
          selectedIndex: _index,
          onDestinationSelected: (i)=> setState(()=> _index = i),
          selectedIconTheme: const IconThemeData(color: Colors.white),
          unselectedIconTheme: IconThemeData(color: Colors.white.withOpacity(0.6)),
          destinations: const [
            NavigationRailDestination(icon: Icon(Icons.storefront_rounded, color: Colors.white), label: Text('POS', style: TextStyle(color: Colors.white))),
            NavigationRailDestination(icon: Icon(Icons.inventory_2_outlined, color: Colors.white), label: Text('Products', style: TextStyle(color: Colors.white))),
            NavigationRailDestination(icon: Icon(Icons.analytics_outlined, color: Colors.white), label: Text('Reports', style: TextStyle(color: Colors.white))),
            NavigationRailDestination(icon: Icon(Icons.settings_outlined, color: Colors.white), label: Text('Settings', style: TextStyle(color: Colors.white))),
          ]),
        Expanded(child: _pages[_index])
      ]) : _pages[_index],
      bottomNavigationBar: isLandscape ? null : NavigationBar(
        backgroundColor: Theme.of(context).colorScheme.primary,
        indicatorColor: Colors.white.withOpacity(0.15),
        selectedIndex: _index,
        labelBehavior: NavigationDestinationLabelBehavior.alwaysShow,
        onDestinationSelected: (i)=> setState(()=> _index = i),
        destinations: const [
          NavigationDestination(icon: Icon(Icons.storefront_rounded, color: Colors.white), label: 'POS'),
          NavigationDestination(icon: Icon(Icons.inventory_2_outlined, color: Colors.white), label: 'Products'),
          NavigationDestination(icon: Icon(Icons.analytics_outlined, color: Colors.white), label: 'Reports'),
          NavigationDestination(icon: Icon(Icons.settings_outlined, color: Colors.white), label: 'Settings'),
        ],
      ),
    );
  }
}

// ================== CHECKOUT / POS ==================
class CheckoutScreen extends StatefulWidget { const CheckoutScreen({super.key}); @override State<CheckoutScreen> createState()=> _CheckoutScreenState(); }
class _CheckoutScreenState extends State<CheckoutScreen> {
  Future<void> _printReceipt(Map<String, dynamic> sale, List<Map<String, dynamic>> items) async {
    try {
      final store = context.read<StoreInfoModel>();
      final buffer = StringBuffer();
      buffer.writeln(store.name);
      buffer.writeln(store.address);
      buffer.writeln('-----------------------------');
      buffer.writeln('Receipt: ${sale['receipt_number']}');
      buffer.writeln('Date: ${sale['sale_date']}');
      buffer.writeln('-----------------------------');
      for (final item in items) {
        buffer.writeln('${item['quantity']} x ${item['product_id']} @ ${item['unit_price']}');
      }
      buffer.writeln('-----------------------------');
      buffer.writeln('Total: ${sale['total_amount']}');
      buffer.writeln('Payment: ${sale['payment_method']}');
      buffer.writeln('Thank you!');
  final quickPrint = QuickPrint();
  await quickPrint.printText(buffer.toString());
    } catch (e) {
      // Ignore print errors, just save sale
    }
  }
  late ValueNotifier<List<Map<String, dynamic>>> _cartNotifier;
  final TextEditingController _search = TextEditingController();
  String query = '';
  bool listMode = true; // list default
  bool _loading = true;
  bool _showCart = true; // cart visibility
  List<Map<String, dynamic>> _products = [];
  late DatabaseService db;

  @override
  void initState() {
    super.initState();
    _cartNotifier = ValueNotifier<List<Map<String, dynamic>>>([]);
  }

  @override
  void dispose() {
    _cartNotifier.dispose();
    _search.dispose();
    super.dispose();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    db = context.read<DatabaseService>();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    final rows = await db.getAllProducts();
    _products = rows.map((p) => {...p, 'stock': p['stock_quantity']}).toList();
    if (mounted) setState(() => _loading = false);
  }

  List<Map<String, dynamic>> get filtered => query.isEmpty
      ? _products
      : _products.where((p) {
          final q = query.toLowerCase();
          return (p['name'] ?? '').toString().toLowerCase().contains(q) ||
              (p['category'] ?? '').toString().toLowerCase().contains(q) ||
              (p['barcode'] ?? '').toString().contains(query);
        }).toList();

  double get totalUSD => _cartNotifier.value.fold(0.0, (s, i) => s + (i['price'] as num) * (i['qty'] as int));

  void _add(Map<String, dynamic> p) {
    final newCart = List<Map<String, dynamic>>.from(_cartNotifier.value);
    final idx = newCart.indexWhere((c) => c['id'] == p['id']);
    final stock = (p['stock_quantity'] ?? p['stock'] ?? 0) as int;

    if (idx == -1) {
      if (stock <= 0) {
        _snack('Out of stock');
        return;
      }
      newCart.add({'id': p['id'], 'name': p['name'], 'price': p['price'], 'qty': 1, 'stock': stock});
    } else {
      if (newCart[idx]['qty'] >= stock) {
        _snack('Max stock reached');
        return;
      }
      newCart[idx] = {...newCart[idx], 'qty': (newCart[idx]['qty'] as int) + 1};
    }
    _cartNotifier.value = newCart;
    setState(() => _showCart = true);
  }

  void _changeQty(int index, int delta) {
    final newCart = List<Map<String, dynamic>>.from(_cartNotifier.value);
    if (index >= newCart.length) return;
    final item = newCart[index];
    final newQty = (item['qty'] as int) + delta;
    final stock = (item['stock'] as int);
    if (newQty > stock) {
      _snack('Max stock reached');
      return;
    }
    if (newQty <= 0) {
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
      'total_price': (c['price'] as num) * (c['qty'] as num)
    })).toList();
  await db.addSale(sale, items);
  // Try to print receipt if printer is connected, but always save sale
  _printReceipt(sale, items);
    for (final c in _cartNotifier.value) {
      final prodIdx = _products.indexWhere((p) => p['id'] == c['id']);
      if (prodIdx != -1) {
        _products[prodIdx]['stock_quantity'] = (_products[prodIdx]['stock_quantity'] as int) - (c['qty'] as int);
      }
    }
    _cartNotifier.value = [];
    setState(() {
      query = '';
      _search.clear();
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
          controller: _search,
          onChanged: (v)=> setState(()=> query = v),
          decoration: InputDecoration(
            prefixIcon: const Icon(Icons.search),
            suffixIcon: query.isNotEmpty? IconButton(icon: const Icon(Icons.clear), onPressed: (){ _search.clear(); setState(()=> query=''); }): null,
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
        final stock = (p['stock_quantity'] ?? 0) as int;
        final low = stock < (p['min_stock_level']??5);
        return Card(
          elevation: 1,
          margin: const EdgeInsets.only(bottom: 8),
          child: ListTile(
            leading: CircleAvatar(backgroundColor: low? Colors.orange.shade100: Colors.green.shade100, child: Text(p['name'].toString().characters.first.toUpperCase())),
            title: Text(p['name']??'', style: const TextStyle(fontWeight: FontWeight.w600)),
            subtitle: Text('Stock: $stock • ${p['category']??'No Cat'}'),
            trailing: Wrap(
              spacing: 6,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                Text('\$${(p['price'] as num).toStringAsFixed(2)}', style: TextStyle(color: Theme.of(context).colorScheme.primary, fontWeight: FontWeight.bold, fontSize: 14)),
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
        final stock = (p['stock_quantity'] ?? 0) as int;
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
                      Text('\$${(p['price'] as num).toStringAsFixed(2)} • Stock: $stock', style: const TextStyle(fontSize: 12, color: Colors.black54)),
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
    final qty = (item['qty'] as num?)?.toInt() ?? 0;
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
                  Text('\$${price.toStringAsFixed(2)} each', style: const TextStyle(fontSize: 12, color: Colors.black54)),
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
                    onPressed: () => _changeQty(index, -1),
                    icon: const Icon(Icons.remove_circle_outline, size: 20),
                    constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
                    padding: EdgeInsets.zero,
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8),
                    child: Text(
                      '$qty',
                      style: const TextStyle(fontWeight: FontWeight.bold),
                    ),
                  ),
                  IconButton(
                    onPressed: () => _changeQty(index, 1),
                    icon: const Icon(Icons.add_circle_outline, size: 20),
                    constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
                    padding: EdgeInsets.zero,
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            SizedBox(
              width: 70,
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
    final totalItems = cart.fold<int>(0, (s, i) => s + ((i['qty'] as num?)?.toInt() ?? 0));
    final currentTotalUSD = cart.fold(0.0, (s, i) => s + (i['price'] as num) * (i['qty'] as int));
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
                  'Subtotal ($totalItems items)',
                  key: ValueKey(totalItems),
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
                        cart.isEmpty ? 'Cart is empty' : '${cart.length} items • $preview',
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

// ================== SETTINGS ==================
class SettingsScreen extends StatefulWidget { const SettingsScreen({super.key}); @override State<SettingsScreen> createState()=> _SettingsScreenState(); }
class _SettingsScreenState extends State<SettingsScreen>{
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
    final ok = await showDialog<bool>(context: context, builder: (_)=> AlertDialog(title: const Text('Confirm'), content: const Text('Delete ALL local data? This cannot be undone.'), actions:[TextButton(onPressed: ()=> Navigator.pop(context,false), child: const Text('Cancel')), ElevatedButton(style: ElevatedButton.styleFrom(backgroundColor: Colors.red), onPressed: ()=> Navigator.pop(context,true), child: const Text('Delete'))]));
    if(ok==true){ await context.read<DatabaseService>().clearAllData(); if(!mounted) return; ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Data cleared'))); }
  }

  @override
  Widget build(BuildContext context) {
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
      'stock': int.parse(_stock.text),
      'min_stock': int.parse(_minStock.text),
      'barcode': _barcode.text.trim(),
      'category': _category.text.trim(),
      'sku': _sku.text.trim(),
    });
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(title: Text(widget.product==null? 'Add Product':'Edit Product'), content: SizedBox(width: 400, child: Form(key: _form, child: SingleChildScrollView(child: Column(children:[
      TextFormField(controller: _name, decoration: const InputDecoration(labelText: 'Name'), validator: (v)=> v==null||v.trim().isEmpty? 'Required': null),
      const SizedBox(height:8),
      TextFormField(controller: _desc, decoration: const InputDecoration(labelText: 'Description')),
      const SizedBox(height:8),
      Row(children:[ Expanded(child: TextFormField(controller: _price, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'Price'), validator: (v)=> double.tryParse(v??'')==null? 'Number': null)), const SizedBox(width:8), Expanded(child: TextFormField(controller: _cost, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'Cost'))) ]),
      const SizedBox(height:8),
      Row(children:[ Expanded(child: TextFormField(controller: _stock, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'Stock'), validator: (v)=> int.tryParse(v??'')==null? 'Int': null)), const SizedBox(width:8), Expanded(child: TextFormField(controller: _minStock, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'Min Stock'))) ]),
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
      content: SizedBox(
        width: 400,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: primary.withOpacity(0.08),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: primary.withOpacity(0.3)),
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
          color: isSelected ? color.withOpacity(0.08) : Colors.white,
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(8),
                color: color.withOpacity(0.1),
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

  @override
  void initState() {
    super.initState();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _db = context.read<DatabaseService>();
    _loadProducts();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadProducts() async {
    setState(() => _loading = true);
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
    if (result == 'sample') await _downloadSampleCSV();
    else if (result == 'import') await _performCSVImport();
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
            'stock_quantity': int.tryParse(row[4]?.toString() ?? '0') ?? 0, 'min_stock_level': row.length > 5 ? (int.tryParse(row[5]?.toString() ?? '5') ?? 5) : 5,
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
                final stock = (p['stock_quantity'] ?? 0) as int;
                final low = stock < (p['min_stock_level']??5);
                return Card(
                  margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  child: ListTile(
                    leading: CircleAvatar(backgroundColor: low ? Colors.orange.shade100 : Colors.green.shade100, child: Text(p['name']?.toString().characters.first.toUpperCase() ?? '?')),
                    title: Text(p['name']?.toString() ?? ''),
                    subtitle: Text('Stock: $stock • ${p['category'] ?? 'No Cat'}'),
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

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _tabController.addListener(() => setState(() {}));
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _loadReportsData();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _loadReportsData() async {
    setState(() => _loading = true);
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

      Map<String, int> paymentMethods = {};

      for (final sale in sales) {
        final saleDate = DateTime.parse(sale['sale_date']);
        final amount = (sale['total_amount'] as num).toDouble();
        totalSales += amount;

        if (saleDate.isAfter(startOfDay)) todaySales += amount;
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
        final stock = product['stock_quantity'] as int? ?? 0;
        final minStock = product['min_stock_level'] as int? ?? 5;
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
                return ListTile(
                  title: Text(item['product_name']?.toString() ?? 'Unknown'),
                  subtitle: Text('Qty: ${item['quantity']} @ \$${(item['unit_price'] as num).toStringAsFixed(2)}'),
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
                _buildMetricCard('Low Stock', (_inventoryData['lowStock'] ?? 0).toString(), Icons.warning_amber, Colors.orange),
                _buildMetricCard('Out of Stock', (_inventoryData['outOfStock'] ?? 0).toString(), Icons.block, Colors.redAccent),
                _buildMetricCard('Inventory Value', 'ZWL ${(_inventoryData['totalValue'] ?? 0).toStringAsFixed(2)}', Icons.price_change, Colors.green),
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
                  decoration: BoxDecoration(color: color.withOpacity(0.12), borderRadius: BorderRadius.circular(10)),
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
