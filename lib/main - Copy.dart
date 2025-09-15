import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'dart:async';
import 'dart:io';
import 'dart:convert';
import 'package:share_plus/share_plus.dart';
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'services/db_service.dart';
import 'services/sales_data.dart';

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
        Provider<DatabaseService>(create: (_) => DatabaseService()),
        ChangeNotifierProvider(create: (_) => ExchangeRateModel()..load()),
        ChangeNotifierProvider(create: (_) => StoreInfoModel()..load()),
      ],
      child: MaterialApp(
        title: 'ShopaFlow',
        theme: ThemeData(
          colorScheme: ColorScheme.fromSeed(
            seedColor: const Color(0xFF2E7D32), // Modern green primary
            primary: const Color(0xFF2E7D32),
            secondary: const Color(0xFF1976D2), // Blue for secondary actions
            error: const Color(0xFFD32F2F), // Red for destructive actions
            surface: Colors.white,
            surfaceContainerLowest: const Color(0xFFFAFAFA), // Light gray background
          ),
          useMaterial3: true,
          scaffoldBackgroundColor: const Color(0xFFFAFAFA),
          // Enhanced card theme with more white space
          cardTheme: const CardThemeData(
            elevation: 2,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.all(Radius.circular(16))),
            color: Colors.white,
            margin: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          ),
          // Enhanced button themes with icons + labels for accessibility
          elevatedButtonTheme: ElevatedButtonThemeData(
            style: ElevatedButton.styleFrom(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              elevation: 2,
              textStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
              minimumSize: const Size(120, 48), // Larger buttons for better accessibility
            ),
          ),
          // Special styling for destructive actions
          textButtonTheme: TextButtonThemeData(
            style: TextButton.styleFrom(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
              textStyle: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500),
            ),
          ),
          outlinedButtonTheme: OutlinedButtonThemeData(
            style: OutlinedButton.styleFrom(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
              textStyle: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500),
              minimumSize: const Size(100, 40),
            ),
          ),
          // Enhanced input decoration with better visual hierarchy
          inputDecorationTheme: InputDecorationTheme(
            filled: true,
            fillColor: Colors.grey.shade50,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(color: Colors.grey.shade300),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(color: Colors.grey.shade300),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: Color(0xFF2E7D32), width: 2),
            ),
            contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
          ),
          // Improved typography with better contrast and readability
          textTheme: const TextTheme(
            headlineLarge: TextStyle(fontSize: 32, fontWeight: FontWeight.bold, color: Color(0xFF1A1A1A), height: 1.2),
            headlineMedium: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: Color(0xFF1A1A1A), height: 1.3),
            headlineSmall: TextStyle(fontSize: 20, fontWeight: FontWeight.w600, color: Color(0xFF1A1A1A), height: 1.3),
            titleLarge: TextStyle(fontSize: 18, fontWeight: FontWeight.w600, color: Color(0xFF1A1A1A), height: 1.4),
            bodyLarge: TextStyle(fontSize: 16, fontWeight: FontWeight.normal, color: Color(0xFF333333), height: 1.5),
            bodyMedium: TextStyle(fontSize: 14, fontWeight: FontWeight.normal, color: Color(0xFF555555), height: 1.4),
            bodySmall: TextStyle(fontSize: 12, fontWeight: FontWeight.normal, color: Color(0xFF777777), height: 1.3),
          ),
        ),
        debugShowCheckedModeBanner: false,
        home: const SplashScreen(),
      ),
    );
  }
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
    Timer(const Duration(seconds: 2), () => Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => const MainScreen())));
  }
  @override
  void dispose() { _controller.dispose(); super.dispose(); }
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [
              Color(0xFF2E7D32), // Main green
              Color(0xFF1B5E20), // Darker green
              Color(0xFF0D47A1), // Deep blue accent
            ],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
        ),
        child: Center(
          child: FadeTransition(
            opacity: _fade,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Modern tech-style icon with subtle animation
                Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(24),
                    border: Border.all(
                      color: Colors.white.withValues(alpha: 0.3),
                      width: 2,
                    ),
                  ),
                  child: const Icon(
                    Icons.storefront_rounded,
                    color: Colors.white,
                    size: 48,
                  ),
                ),
                const SizedBox(height: 24),
                const Text(
                  'ShopaFlow',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 32,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 1.2,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Modern POS System',
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.9),
                    fontSize: 16,
                    fontWeight: FontWeight.w400,
                    letterSpacing: 0.5,
                  ),
                ),
                const SizedBox(height: 32),
                SizedBox(
                  width: 200,
                  child: LinearProgressIndicator(
                    backgroundColor: Colors.white.withValues(alpha: 0.3),
                    valueColor: const AlwaysStoppedAnimation<Color>(Colors.white),
                    minHeight: 3,
                  ),
                ),
              ],
            ),
          ),
        ),
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
              decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.15), borderRadius: BorderRadius.circular(6)),
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
             unselectedIconTheme: IconThemeData(color: Colors.white.withValues(alpha: 0.6)),
            destinations: const [
              NavigationRailDestination(icon: Icon(Icons.storefront_rounded), label: Text('POS', style: TextStyle(color: Colors.white))),
              NavigationRailDestination(icon: Icon(Icons.inventory_2_outlined), label: Text('Products', style: TextStyle(color: Colors.white))),
              NavigationRailDestination(icon: Icon(Icons.analytics_outlined), label: Text('Reports', style: TextStyle(color: Colors.white))),
              NavigationRailDestination(icon: Icon(Icons.settings_outlined), label: Text('Settings', style: TextStyle(color: Colors.white))),
            ]),
        Expanded(child: _pages[_index])
      ]) : _pages[_index],
      bottomNavigationBar: isLandscape ? null : NavigationBar(
        backgroundColor: Theme.of(context).colorScheme.primary,
        indicatorColor: Colors.white.withValues(alpha: 0.15),
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
  final GlobalKey<AnimatedListState> _listKey = GlobalKey<AnimatedListState>();
  final List<Map<String,dynamic>> _cart = [];
  final TextEditingController _search = TextEditingController();
  String query = '';
  bool listMode = true; // list default
  bool _loading = true;
  List<Map<String,dynamic>> _products = [];
  late DatabaseService db;

  @override
  void initState(){
    super.initState();
    db = context.read<DatabaseService>();
    _load();
  }

  Future<void> _load() async {
    setState(()=> _loading = true);
    final rows = await db.getAllProducts();
    _products = rows.map((p)=> {...p, 'stock': p['stock_quantity']}).toList();
    if(mounted) setState(()=> _loading = false);
  }

  List<Map<String,dynamic>> get filtered => query.isEmpty ? _products : _products.where((p){
    final q = query.toLowerCase();
    return (p['name']??'').toString().toLowerCase().contains(q) || (p['category']??'').toString().toLowerCase().contains(q) || (p['barcode']??'').toString().contains(query);
  }).toList();

  double get totalUSD => _cart.fold(0.0, (s, i) => s + (i['price'] as num) * (i['qty'] as int));

  void _add(Map<String,dynamic> p){
    final idx = _cart.indexWhere((c) => c['id']==p['id']);
    final stock = (p['stock_quantity'] ?? p['stock'] ?? 0) as int;
    if(idx==-1){
      if(stock<=0){ _snack('Out of stock'); return; }
      _cart.add({'id':p['id'],'name':p['name'],'price':p['price'],'qty':1,'stock':stock});
      if (_listKey.currentState != null) {
        _listKey.currentState!.insertItem(_cart.length - 1);
      }
    } else {
      if(_cart[idx]['qty']>=stock){ _snack('Max stock reached'); return; }
      _cart[idx]['qty']++;
    }
    setState((){});
  }

  void _changeQty(int index, int delta){
    setState(() {
      _cart[index]['qty'] += delta;
      if (_cart[index]['qty'] <= 0) {
        final removedItem = _cart.removeAt(index);
        if (_listKey.currentState != null) {
          _listKey.currentState!.removeItem(
            index,
            (context, animation) => _buildCartItem(removedItem, index, animation),
            duration: const Duration(milliseconds: 300),
          );
        }
      }
    });
  }

  void _remove(int index){
    final removedItem = _cart.removeAt(index);
    if (_listKey.currentState != null) {
      _listKey.currentState!.removeItem(
        index,
        (context, animation) => _buildCartItem(removedItem, index, animation),
        duration: const Duration(milliseconds: 300),
      );
    }
    setState((){});
  }

  void _snack(String m){ ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(m), duration: const Duration(seconds: 1))); }

  Future<void> _checkout() async {
    if(_cart.isEmpty){ _snack('Cart is empty'); return; }
    final method = await showDialog<String>(context: context, builder: (_)=> _PaymentDialog(total: totalUSD));
    if(method==null) return;
    // build sale
    final sale = {
      'total_amount': totalUSD,
      'payment_method': method,
      'sale_date': DateTime.now().toIso8601String(),
      'receipt_number': 'RCP${DateTime.now().millisecondsSinceEpoch}'
    };
    final items = _cart.map((c)=> {
      'product_id': c['id'],
      'quantity': c['qty'],
      'unit_price': c['price'],
      'total_price': (c['price'] as num) * (c['qty'] as num)
    }).toList();
    await db.addSale(sale, items);
    // reduce local stock
    for(final c in _cart){
      final prodIdx = _products.indexWhere((p)=> p['id']==c['id']);
      if(prodIdx!=-1){
        _products[prodIdx]['stock_quantity'] = (_products[prodIdx]['stock_quantity'] as int) - c['qty'];
      }
    }
    SalesData.addTransaction({'items': _cart.map((c)=> c['name']).toList(), 'total': totalUSD, 'payment': method});
    if(!mounted) return;
    showDialog(context: context, builder: (_)=> AlertDialog(title: const Text('Payment Successful'), content: Text('Total: \$${totalUSD.toStringAsFixed(2)}'), actions: [TextButton(onPressed: ()=> Navigator.pop(context), child: const Text('OK'))]));
    setState(()=> _cart.clear());
  }

  @override
  Widget build(BuildContext context) {
    final rate = context.watch<ExchangeRateModel>().rate;
    final width = MediaQuery.of(context).size.width;
    final wide = width > 820; // dual pane threshold
    return SafeArea(
      child: Scaffold(
        resizeToAvoidBottomInset: false, // Prevents resizing when keyboard appears
        body: Stack(
          children: [
            Column(
              children: [
                _buildSearchBar(),
                Expanded(
                  child: wide
                      ? Row(children: [
                          Expanded(flex: 3, child: _buildProducts()),
                          Container(
                            width: 380,
                            decoration: BoxDecoration(border: Border(left: BorderSide(color: Colors.grey.shade300))),
                            child: _buildCartPanel(rate),
                          ),
                        ])
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
            leading: CircleAvatar(backgroundColor: low? Colors.orange.shade100: Colors.green.shade100, child: Text(p['name'].toString().characters.first)),
            title: Text(p['name']??'', style: const TextStyle(fontWeight: FontWeight.w600)),
            subtitle: Text('Stock: $stock • ${p['category']??'No Cat'}'),
            trailing: Wrap(
              spacing: 4,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                Text('\$${(p['price'] as num).toStringAsFixed(2)}', style: TextStyle(color: Theme.of(context).colorScheme.primary, fontWeight: FontWeight.bold, fontSize: 14)),
                if (stock > 0)
                  OutlinedButton(
                    onPressed: () => _add(p),
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 0),
                      minimumSize: const Size(0, 24),
                      textStyle: const TextStyle(fontSize: 10),
                    ),
                    child: const Text('ADD'),
                  )
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
    final cross = MediaQuery.of(context).size.width>1100?5: MediaQuery.of(context).size.width>900?4:3;
    return GridView.builder(
      padding: const EdgeInsets.all(12),
      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: cross,
        crossAxisSpacing: 12,
        mainAxisSpacing: 12,
        childAspectRatio: 0.85,
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
                    color: Colors.grey.shade200,
                    child: Stack(
                      fit: StackFit.expand,
                      children: [
                        // Placeholder for an image
                        Center(
                          child: Icon(
                            Icons.inventory_2_outlined,
                            color: Colors.grey.shade400,
                            size: 40,
                          ),
                        ),
                        if (outOfStock)
                          Container(
                            color: Colors.black.withValues(alpha: 0.5),
                            child: const Center(
                              child: Text(
                                'OUT OF\nSTOCK',
                                textAlign: TextAlign.center,
                                style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14),
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.all(8.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        p['name'] ?? '',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        p['category'] ?? '',
                        style: TextStyle(fontSize: 11, color: Colors.grey.shade600),
                      ),
                      const SizedBox(height: 4),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            '\$${(p['price'] as num).toStringAsFixed(2)}',
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 15,
                              color: Theme.of(context).colorScheme.primary,
                            ),
                          ),
                          if (!outOfStock)
                            IconButton(
                              onPressed: () => _add(p),
                              icon: const Icon(Icons.add_shopping_cart),
                              iconSize: 20,
                              color: Theme.of(context).colorScheme.secondary,
                              constraints: const BoxConstraints(),
                              padding: EdgeInsets.zero,
                            )
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
          );
        };
      },
    );
  }

  Widget _buildCartPanel(double rate) {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text('Current Order', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
              Text('${_cart.length} items'),
            ],
          ),
        ),
        Expanded(
          child: _cart.isEmpty
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.shopping_cart_outlined, size: 60, color: Colors.grey.shade400),
                      const SizedBox(height: 16),
                      const Text('Your cart is empty', style: TextStyle(fontSize: 16, color: Colors.grey)),
                    ],
                  ),
                )
              : AnimatedList(
                  key: _listKey,
                  initialItemCount: _cart.length,
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  itemBuilder: (context, index, animation) {
                    if (index >= _cart.length) return const SizedBox.shrink();
                    final item = _cart[index];
                    return _buildCartItem(item, index, animation);
                  },
                ),
        ),
        _cartTotals(rate),
      ],
    );
  }

  Widget _buildCartItem(Map<String, dynamic> item, int index, Animation<double> animation) {
    return SizeTransition(
      sizeFactor: CurvedAnimation(parent: animation, curve: Curves.easeOut),
      child: Card(
        margin: const EdgeInsets.only(bottom: 8),
        elevation: 1,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        child: Padding(
          padding: const EdgeInsets.all(8.0),
          child: Row(
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: Container(
                  width: 48,
                  height: 48,
                  color: Colors.grey.shade200,
                  child: Icon(Icons.fastfood, color: Colors.grey.shade400),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      item['name'],
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '\$${(item['price'] as num).toStringAsFixed(2)}',
                      style: TextStyle(fontSize: 13, color: Theme.of(context).colorScheme.primary, fontWeight: FontWeight.bold),
                    ),
                  ],
                ),
              ),
              Row(
                children: [
                  IconButton(
                    onPressed: () => _changeQty(index, -1),
                    icon: const Icon(Icons.remove_circle_outline, size: 22),
                    constraints: const BoxConstraints(),
                    padding: const EdgeInsets.symmetric(horizontal: 4),
                  ),
                  SizedBox(
                    width: 24,
                    child: Text(
                      item['qty'].toString(),
                      textAlign: TextAlign.center,
                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                    ),
                  ),
                  IconButton(
                    onPressed: () => _changeQty(index, 1),
                    icon: Icon(Icons.add_circle_outline, size: 22, color: Theme.of(context).colorScheme.primary),
                    constraints: const BoxConstraints(),
                    padding: const EdgeInsets.symmetric(horizontal: 4),
                  ),
                ],
              ),
              const SizedBox(width: 8),
              SizedBox(
                width: 60,
                child: Text(
                  '\$${((item['price'] as num) * item['qty']).toStringAsFixed(2)}',
                  textAlign: TextAlign.right,
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

  Widget _cartTotals(double rate){
    final totalItems = _cart.fold<int>(0, (s, i) => s + ((i['qty'] as num?)?.toInt() ?? 0));
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
              Text('Subtotal ($totalItems items)', style: TextStyle(fontSize: 14, color: Colors.grey.shade700)),
              Text('\$${totalUSD.toStringAsFixed(2)}', style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600)),
            ]),
            const SizedBox(height: 4),
            Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
              Text('Total in ZWL', style: TextStyle(fontSize: 14, color: Colors.grey.shade700)),
              Text('ZWL ${(totalUSD * rate).toStringAsFixed(2)}', style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600)),
            ]),
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 8.0),
              child: Divider(),
            ),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text('Total', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                Text('\$${totalUSD.toStringAsFixed(2)}', style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
              ],
            ),
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: _cart.isEmpty ? null : _checkout,
                icon: const Icon(Icons.payment),
                label: const Text('Proceed to Payment'),
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  textStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                ),
              ),
            )
          ],
        ),
      ),
    );
  }

  Widget _buildBottomCartBar(double rate){
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
                    Container(
                      height: 4,
                      width: 60,
                      margin: const EdgeInsets.symmetric(vertical: 10),
                      decoration: BoxDecoration(
                        color: Colors.grey.shade400,
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                    Expanded(child: _buildCartPanel(rate))
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
                // Items + preview names
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        '${_cart.fold<int>(0, (s, i) => s + ((i['qty'] as num?)?.toInt() ?? 0))} items  •  '
                        '\$${totalUSD.toStringAsFixed(2)}',
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                          fontSize: 13,
                        ),
                      ),
                      if (_cart.isNotEmpty)
                        Text(
                          _cart.length <= 2
                              ? _cart.map((e) => e['name']).join(', ')
                              : _cart.take(2).map((e) => e['name']).join(', ') +
                                  ' +${_cart.length - 2} more',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            color: Colors.white.withValues(alpha: 0.85),
                            fontSize: 11,
                          ),
                        ),
                    ],
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
  }
}

// ================== SETTINGS ==================
class SettingsScreen extends StatefulWidget { const SettingsScreen({super.key}); @override State<SettingsScreen> createState()=> _SettingsScreenState(); }
class _SettingsScreenState extends State<SettingsScreen>{
  final _nameCtrl = TextEditingController();
  final _addrCtrl = TextEditingController();
  final _rateCtrl = TextEditingController();
  bool _busy = false;

  @override void initState(){ super.initState(); final store = context.read<StoreInfoModel>(); _nameCtrl.text = store.name; _addrCtrl.text = store.address; _rateCtrl.text = context.read<ExchangeRateModel>().rate.toStringAsFixed(2); }

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
      _section('Currency & Rates', [
        TextField(controller: _rateCtrl, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'USD -> ZWL Rate', border: OutlineInputBorder())), const SizedBox(height:12),
        ElevatedButton(onPressed: _saveRate, child: const Text('Update Rate')),
      ]),
      const SizedBox(height:24),
      _section('Data & Backup', [
        ElevatedButton.icon(onPressed: _busy? null: _exportData, icon: const Icon(Icons.file_download), label: Text(_busy? 'Exporting...':'Export Backup')), const SizedBox(height:12),
        ElevatedButton.icon(style: ElevatedButton.styleFrom(backgroundColor: Colors.red), onPressed: _clearAll, icon: const Icon(Icons.delete_forever), label: const Text('Clear All Data')),
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
      TextFormField(controller: _barcode, decoration: const InputDecoration(labelText: 'Barcode')),
      const SizedBox(height:8),
      TextFormField(controller: _category, decoration: const InputDecoration(labelText: 'Category')),
      const SizedBox(height:8),
      TextFormField(controller: _sku, decoration: const InputDecoration(labelText: 'SKU')),
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
    _showConfirmationScreen();
  }

  void _showConfirmationScreen() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        title: Row(
          children: [
            Icon(Icons.check_circle, color: Theme.of(context).colorScheme.primary, size: 32),
            const SizedBox(width: 12),
            const Text('Payment Confirmation'),
          ],
        ),
        content: Container(
          width: 320,
          padding: const EdgeInsets.symmetric(vertical: 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildConfirmationRow('Total Amount:', '\$${widget.total.toStringAsFixed(2)}'),
              const SizedBox(height: 8),
              _buildConfirmationRow('Payment Method:', method),
              if (method == 'Cash') ...[
                const SizedBox(height: 8),
                _buildConfirmationRow('Amount Received:', '\$${_amountReceived!.toStringAsFixed(2)}'),
                const SizedBox(height: 8),
                _buildConfirmationRow('Change to Give:', '\$${_change.toStringAsFixed(2)}', isHighlight: _change > 0),
              ],
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.primary.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  children: [
                    Icon(Icons.info, color: Theme.of(context).colorScheme.primary),
                    const SizedBox(width: 8),
                    const Expanded(
                      child: Text(
                        'Please confirm the payment details before completing the transaction.',
                        style: TextStyle(fontSize: 13),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Back'),
          ),
          ElevatedButton.icon(
            onPressed: () {
              Navigator.pop(context);
              Navigator.pop(context, method);
            },
            icon: const Icon(Icons.check),
            label: const Text('Complete Payment'),
            style: ElevatedButton.styleFrom(
              backgroundColor: Theme.of(context).colorScheme.primary,
              foregroundColor: Colors.white,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildConfirmationRow(String label, String value, {bool isHighlight = false}) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label, style: const TextStyle(fontSize: 14)),
        Text(
          value,
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.bold,
            color: isHighlight ? Theme.of(context).colorScheme.secondary : null,
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context){
    final rate = context.watch<ExchangeRateModel>().rate;

    return AlertDialog(
      title: Row(
        children: [
          Icon(Icons.payment, color: Theme.of(context).colorScheme.primary),
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
                color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.3)),
              ),
              child: Column(
                children: [
                  const Text('Total Amount', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w500)),
                  const SizedBox(height: 4),
                  Text(
                    '\$${widget.total.toStringAsFixed(2)}',
                    style: TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                      color: Theme.of(context).colorScheme.primary,
                    ),
                  ),
                  Text(
                    'ZWL ${(widget.total * rate).toStringAsFixed(2)}',
                    style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),
            const Text('Payment Method', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
            const SizedBox(height: 12),
            _buildPaymentMethodCard('Cash', Icons.payments, 'Pay with physical cash', Theme.of(context).colorScheme.primary),
            const SizedBox(height: 8),
            _buildPaymentMethodCard('Card', Icons.credit_card, 'Pay with debit/credit card', Theme.of(context).colorScheme.secondary),
            const SizedBox(height: 8),
            _buildPaymentMethodCard('Mobile Money', Icons.phone_android, 'Pay with mobile money service', Colors.orange),
            if(method == 'Cash') ...[
              const SizedBox(height: 20),
              const Text('Amount Received', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
              const SizedBox(height: 8),
              TextField(
                controller: _amount,
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                onChanged: (value) {
                  setState(() {
                    _amountReceived = double.tryParse(value);
                  });
                },
                decoration: InputDecoration(
                  labelText: 'Cash Amount',
                  prefixText: '\$',
                  suffixIcon: IconButton(
                    icon: const Icon(Icons.clear),
                    onPressed: () {
                      _amount.clear();
                      setState(() => _amountReceived = null);
                    },
                  ),
                ),
              ),
              if (_amountReceived != null && _amountReceived! >= widget.total) ...[
                const SizedBox(height: 12),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.green.shade50,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.green.shade200),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text('Change to Give:', style: TextStyle(fontWeight: FontWeight.w500)),
                      Text(
                        '\$${_change.toStringAsFixed(2)}',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: Colors.green.shade700,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
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
          icon: const Icon(Icons.arrow_forward),
          label: const Text('Continue'),
          style: ElevatedButton.styleFrom(
            backgroundColor: Theme.of(context).colorScheme.primary,
            foregroundColor: Colors.white,
            minimumSize: const Size(120, 44),
          ),
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
          color: isSelected ? color.withValues(alpha: 0.1) : Colors.white,
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: isSelected ? color.withValues(alpha: 0.2) : Colors.grey.shade100,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(
                icon,
                color: isSelected ? color : Colors.grey.shade600,
                size: 24,
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    methodName,
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: isSelected ? color : Colors.black87,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    description,
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.grey.shade600,
                    ),
                  ),
                ],
              ),
            ),
            if (isSelected)
              Icon(
                Icons.check_circle,
                color: color,
                size: 24,
              ),
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
      setState(() {
        _products = products;
        _categories = categories.toList()..sort();
        _loading = false;
      });
    } catch (e) {
      setState(() => _loading = false);
      if (mounted) {
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
        if (product == null) {
          // Adding new product - handle empty SKU by setting to null
          final productData = Map<String, dynamic>.from(result);
          if (productData['sku']?.toString().trim().isEmpty == true) {
            productData['sku'] = null;
          }
          if (productData['barcode']?.toString().trim().isEmpty == true) {
            productData['barcode'] = null;
          }

          await _db.addProduct({
            'name': productData['name'],
            'description': productData['description'],
            'price': productData['price'],
            'cost': productData['cost'],
            'stock_quantity': productData['stock'],
            'min_stock_level': productData['min_stock'],
            'barcode': productData['barcode'],
            'category': productData['category'],
            'sku': productData['sku'],
          });
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Product added successfully')),
            );
          }
        } else {
          // Editing existing product
          final productData = Map<String, dynamic>.from(result);
          if (productData['sku']?.toString().trim().isEmpty == true) {
            productData['sku'] = null;
          }
          if (productData['barcode']?.toString().trim().isEmpty == true) {
            productData['barcode'] = null;
          }

          await _db.updateProduct(product['id'], {
            'name': productData['name'],
            'description': productData['description'],
            'price': productData['price'],
            'cost': productData['cost'],
            'stock_quantity': productData['stock'],
            'min_stock_level': productData['min_stock'],
            'barcode': productData['barcode'],
            'category': productData['category'],
            'sku': productData['sku'],
          });
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Product updated successfully')),
            );
          }
        }
        _loadProducts();
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Error: $e')),
          );
        }
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
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      try {
        await _db.deleteProduct(product['id']);
        _loadProducts();
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Product deleted successfully')),
          );
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Error deleting product: $e')),
          );
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Column(
        children: [
          // Search and Filter Bar
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white,
              border: Border(bottom: BorderSide(color: Colors.grey.shade200)),
            ),
            child: Column(
              children: [
                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: _searchController,
                        onChanged: (value) => setState(() => _searchQuery = value),
                        decoration: InputDecoration(
                          hintText: 'Search products...',
                          prefixIcon: const Icon(Icons.search),
                          suffixIcon: _searchQuery.isNotEmpty
                              ? IconButton(
                                  icon: const Icon(Icons.clear),
                                  onPressed: () {
                                    _searchController.clear();
                                    setState(() => _searchQuery = '');
                                  },
                                )
                              : null,
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: BorderSide.none,
                          ),
                          filled: true,
                          fillColor: Colors.grey.shade100,
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    ElevatedButton.icon(
                      onPressed: () => _addOrEdit(),
                      icon: const Icon(Icons.add),
                      label: const Text('Add Product'),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    const Text('Category: ', style: TextStyle(fontWeight: FontWeight.w500)),
                    Expanded(
                      child: SingleChildScrollView(
                        scrollDirection: Axis.horizontal,
                        child: Row(
                          children: _categories.map((category) {
                            final isSelected = _selectedCategory == category;
                            return Padding(
                              padding: const EdgeInsets.only(right: 8),
                              child: FilterChip(
                                label: Text(category),
                                selected: isSelected,
                                onSelected: (_) => setState(() => _selectedCategory = category),
                                backgroundColor: Colors.grey.shade100,
                                selectedColor: Theme.of(context).colorScheme.primary.withOpacity(0.2),
                                checkmarkColor: Theme.of(context).colorScheme.primary,
                              ),
                            );
                          }).toList(),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          // Products List
          Expanded(
            child: _loading
                ? const Center(child: CircularProgressIndicator())
                : _filteredProducts.isEmpty
                    ? Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.inventory_2_outlined, size: 64, color: Colors.grey.shade400),
                            const SizedBox(height: 16),
                            Text(
                              _searchQuery.isNotEmpty || _selectedCategory != 'All'
                                  ? 'No products match your search'
                                  : 'No products yet',
                              style: TextStyle(fontSize: 18, color: Colors.grey.shade600),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              _searchQuery.isNotEmpty || _selectedCategory != 'All'
                                  ? 'Try adjusting your search or filters'
                                  : 'Add your first product to get started',
                              style: TextStyle(color: Colors.grey.shade500),
                            ),
                            if (_searchQuery.isEmpty && _selectedCategory == 'All') ...[
                              const SizedBox(height: 16),
                              ElevatedButton.icon(
                                onPressed: () => _addOrEdit(),
                                icon: const Icon(Icons.add),
                                label: const Text('Add Product'),
                              ),
                            ],
                          ],
                        ),
                      )
                    : RefreshIndicator(
                        onRefresh: _loadProducts,
                        child: ListView.builder(
                          padding: const EdgeInsets.all(16),
                          itemCount: _filteredProducts.length,
                          itemBuilder: (context, index) {
                            final product = _filteredProducts[index];
                            final stock = product['stock_quantity'] as int? ?? 0;
                            final minStock = product['min_stock_level'] as int? ?? 5;
                            final isLowStock = stock <= minStock;

                            return Card(
                              margin: const EdgeInsets.only(bottom: 12),
                              child: ListTile(
                                contentPadding: const EdgeInsets.all(16),
                                leading: CircleAvatar(
                                  backgroundColor: isLowStock
                                      ? Colors.orange.shade100
                                      : Colors.green.shade100,
                                  child: Icon(
                                    isLowStock ? Icons.warning : Icons.inventory_2,
                                    color: isLowStock ? Colors.orange : Colors.green,
                                  ),
                                ),
                                title: Text(
                                  product['name'] ?? '',
                                  style: const TextStyle(fontWeight: FontWeight.bold),
                                ),
                                subtitle: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    if (product['description']?.toString().isNotEmpty == true)
                                      Text(product['description']),
                                    const SizedBox(height: 4),
                                    Row(
                                      children: [
                                        Text('Stock: $stock'),
                                        if (isLowStock) ...[
                                          const SizedBox(width: 8),
                                          Container(
                                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                            decoration: BoxDecoration(
                                              color: Colors.orange.shade100,
                                              borderRadius: BorderRadius.circular(4),
                                            ),
                                            child: Text(
                                              'LOW',
                                              style: TextStyle(
                                                fontSize: 10,
                                                fontWeight: FontWeight.bold,
                                                color: Colors.orange.shade800,
                                              ),
                                            ),
                                          ),
                                        ],
                                        const Spacer(),
                                        Text(
                                          'Category: ${product['category'] ?? 'None'}',
                                          style: TextStyle(color: Colors.grey.shade600),
                                        ),
                                      ],
                                    ),
                                  ],
                                ),
                                trailing: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Column(
                                      mainAxisAlignment: MainAxisAlignment.center,
                                      crossAxisAlignment: CrossAxisAlignment.end,
                                      children: [
                                        Text(
                                          '\$${(product['price'] as num?)?.toStringAsFixed(2) ?? '0.00'}',
                                          style: TextStyle(
                                            fontSize: 16,
                                            fontWeight: FontWeight.bold,
                                            color: Theme.of(context).colorScheme.primary,
                                          ),
                                        ),
                                        if (product['cost'] != null)
                                          Text(
                                            'Cost: \$${(product['cost'] as num).toStringAsFixed(2)}',
                                            style: TextStyle(
                                              fontSize: 12,
                                              color: Colors.grey.shade600,
                                            ),
                                          ),
                                      ],
                                    ),
                                    const SizedBox(width: 8),
                                    PopupMenuButton<String>(
                                      onSelected: (value) {
                                        switch (value) {
                                          case 'edit':
                                            _addOrEdit(product);
                                            break;
                                          case 'delete':
                                            _deleteProduct(product);
                                            break;
                                        }
                                      },
                                      itemBuilder: (_) => [
                                        const PopupMenuItem(
                                          value: 'edit',
                                          child: Row(
                                            children: [
                                              Icon(Icons.edit, size: 20),
                                              SizedBox(width: 8),
                                              Text('Edit'),
                                            ],
                                          ),
                                        ),
                                        const PopupMenuItem(
                                          value: 'delete',
                                          child: Row(
                                            children: [
                                              Icon(Icons.delete, size: 20, color: Colors.red),
                                              SizedBox(width: 8),
                                              Text('Delete', style: TextStyle(color: Colors.red)),
                                            ],
                                          ),
                                        ),
                                      ],
                                    ),
                                  ],
                                ),
                                onTap: () => _addOrEdit(product),
                              ),
                            );
                          },
                        ),
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

      // Load sales data
      final sales = await db.getAllSales();
      final products = await db.getAllProducts();

      // Calculate sales metrics
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
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
                Tab(icon: Icon(Icons.analytics), text: 'Sales'),
                Tab(icon: Icon(Icons.inventory), text: 'Inventory'),
                Tab(icon: Icon(Icons.receipt_long), text: 'Transactions'),
              ],
            ),
          ),
          Expanded(
            child: _loading
                ? const Center(child: CircularProgressIndicator())
                : TabBarView(
                    controller: _tabController,
                    children: [
                      _buildSalesTab(),
                      _buildInventoryTab(),
                      _buildTransactionsTab(),
                    ],
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildSalesTab() {
    return RefreshIndicator(
      onRefresh: _loadReportsData,
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Sales Overview Cards
            GridView.count(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              crossAxisCount: 2,
              crossAxisSpacing: 16,
              mainAxisSpacing: 16,
              childAspectRatio: 1.5,
              children: [
                _buildMetricCard(
                  'Today\'s Sales',
                  '\$${_salesData['today']?.toStringAsFixed(2) ?? '0.00'}',
                  Icons.today,
                  Colors.green,
                ),
                _buildMetricCard(
                  'This Week',
                  '\$${_salesData['week']?.toStringAsFixed(2) ?? '0.00'}',
                  Icons.date_range,
                  Colors.blue,
                ),
                _buildMetricCard(
                  'This Month',
                  '\$${_salesData['month']?.toStringAsFixed(2) ?? '0.00'}',
                  Icons.calendar_month,
                  Colors.orange,
                ),
                _buildMetricCard(
                  'Total Sales',
                  '\$${_salesData['total']?.toStringAsFixed(2) ?? '0.00'}',
                  Icons.trending_up,
                  Colors.purple,
                ),
              ],
            ),
            const SizedBox(height: 24),

            // Payment Methods
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Payment Methods',
                      style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 16),
                    ...(_salesData['paymentMethods'] as Map<String, int>? ?? {}).entries.map(
                      (entry) => Padding(
                        padding: const EdgeInsets.symmetric(vertical: 4),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(entry.key),
                            Text('${entry.value} transactions'),
                          ],
                        ),
                      ),
                    ),
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
                _buildMetricCard(
                  'Total Products',
                  '${_inventoryData['totalProducts'] ?? 0}',
                  Icons.inventory_2,
                  Colors.blue,
                ),
                _buildMetricCard(
                  'Low Stock',
                  '${_inventoryData['lowStock'] ?? 0}',
                  Icons.warning,
                  Colors.orange,
                ),
                _buildMetricCard(
                  'Out of Stock',
                  '${_inventoryData['outOfStock'] ?? 0}',
                  Icons.error,
                  Colors.red,
                ),
                _buildMetricCard(
                  'Inventory Value',
                  '\$${(_inventoryData['totalValue'] as double?)?.toStringAsFixed(2) ?? '0.00'}',
                  Icons.attach_money,
                  Colors.green,
                ),
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
          ? const Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.receipt_long, size: 64, color: Colors.grey),
                  SizedBox(height: 16),
                  Text('No transactions yet', style: TextStyle(fontSize: 18, color: Colors.grey)),
                ],
              ),
            )
          : ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: _recentSales.length,
              itemBuilder: (context, index) {
                final sale = _recentSales[index];
                final date = DateTime.parse(sale['sale_date']);

                return Card(
                  margin: const EdgeInsets.only(bottom: 8),
                  child: ListTile(
                    leading: CircleAvatar(
                      backgroundColor: Theme.of(context).colorScheme.primary.withOpacity(0.1),
                      child: Icon(
                        Icons.receipt,
                        color: Theme.of(context).colorScheme.primary,
                      ),
                    ),
                    title: Text(
                      'Receipt #${sale['receipt_number'] ?? 'N/A'}',
                      style: const TextStyle(fontWeight: FontWeight.bold),
                    ),
                    subtitle: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('${sale['payment_method']} • ${_formatDate(date)}'),
                        Text('Items: ${sale['item_count'] ?? 'N/A'}'),
                      ],
                    ),
                    trailing: Text(
                      '\$${(sale['total_amount'] as num).toStringAsFixed(2)}',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: Theme.of(context).colorScheme.primary,
                      ),
                    ),
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
                Icon(icon, color: color, size: 24),
                const Spacer(),
                Container(
                  padding: const EdgeInsets.all(4),
                  decoration: BoxDecoration(
                    color: color.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Icon(icon, color: color, size: 16),
                ),
              ],
            ),
            const Spacer(),
            Text(
              value,
              style: const TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
              ),
            ),
            Text(
              title,
              style: TextStyle(
                color: Colors.grey.shade600,
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
