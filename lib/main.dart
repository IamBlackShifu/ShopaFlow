import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'services/db_service.dart';

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
      ],
      child: MaterialApp(
        title: 'ShopaFlow POS',
        theme: ThemeData(
          colorScheme: ColorScheme.fromSeed(
            seedColor: const Color(0xFF2E7D32), // Green for retail/money theme
            brightness: Brightness.light,
          ),
          useMaterial3: true,
          // Large, touch-friendly buttons theme
          elevatedButtonTheme: ElevatedButtonThemeData(
            style: ElevatedButton.styleFrom(
              minimumSize: const Size(120, 56),
              textStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
          ),
          // Card theme for product tiles
          cardTheme: CardTheme(
            elevation: 2,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
          ),
        ),
        home: const MainScreen(),
        debugShowCheckedModeBanner: false,
      ),
    );
  }
}

class MainScreen extends StatefulWidget {
  const MainScreen({super.key});

  @override
  State<MainScreen> createState() => _MainScreenState();
}

class _MainScreenState extends State<MainScreen> {
  int _selectedIndex = 0;

  // Placeholder pages for main navigation
  final List<Widget> _pages = [
    const CheckoutScreen(),
    const ProductsScreen(),
    const SettingsScreen(),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('ShopaFlow POS'),
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
        actions: [
          // Currency display - placeholder for USD/ZWL conversion
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            margin: const EdgeInsets.only(right: 8),
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.surface,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: Theme.of(context).colorScheme.outline),
            ),
            child: const Text(
              'USD: \$1 = ZWL 320',
              style: TextStyle(fontWeight: FontWeight.w500),
            ),
          ),
          // Sync status indicator
          IconButton(
            icon: Icon(
              Icons.cloud_sync,
              color: Theme.of(context).colorScheme.primary,
            ),
            onPressed: () {
              // TODO: Implement sync functionality
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Sync functionality coming soon')),
              );
            },
          ),
        ],
      ),
      body: _pages[_selectedIndex],
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _selectedIndex,
        onTap: (index) {
          setState(() {
            _selectedIndex = index;
          });
        },
        items: const [
          BottomNavigationBarItem(
            icon: Icon(Icons.shopping_cart),
            label: 'Checkout',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.inventory_2),
            label: 'Products',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.settings),
            label: 'Settings',
          ),
        ],
      ),
    );
  }
}

// Checkout Screen - Main POS interface
class CheckoutScreen extends StatefulWidget {
  const CheckoutScreen({super.key});

  @override
  State<CheckoutScreen> createState() => _CheckoutScreenState();
}

class _CheckoutScreenState extends State<CheckoutScreen> {
  final List<Map<String, dynamic>> _cartItems = [];
  double _totalAmount = 0.0;

  // Sample products for demo
  final List<Map<String, dynamic>> _sampleProducts = [
    {'id': 1, 'name': 'Coca Cola 500ml', 'price': 1.50, 'stock': 25},
    {'id': 2, 'name': 'Bread Loaf', 'price': 0.80, 'stock': 15},
    {'id': 3, 'name': 'Milk 1L', 'price': 2.20, 'stock': 8}, // Low stock example
    {'id': 4, 'name': 'Rice 2kg', 'price': 4.50, 'stock': 12},
  ];

  void _addToCart(Map<String, dynamic> product) {
    setState(() {
      // Check if product already in cart
      final existingIndex = _cartItems.indexWhere((item) => item['id'] == product['id']);
      
      if (existingIndex >= 0) {
        _cartItems[existingIndex]['quantity']++;
      } else {
        _cartItems.add({
          ...product,
          'quantity': 1,
        });
      }
      
      _calculateTotal();
    });
  }

  void _removeFromCart(int index) {
    setState(() {
      _cartItems.removeAt(index);
      _calculateTotal();
    });
  }

  void _calculateTotal() {
    _totalAmount = _cartItems.fold(0.0, (total, item) {
      return total + (item['price'] * item['quantity']);
    });
  }

  void _processPayment() {
    if (_cartItems.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Cart is empty')),
      );
      return;
    }

    // TODO: Implement actual payment processing
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Payment Successful'),
        content: Text('Total: \$${_totalAmount.toStringAsFixed(2)}\nZWL ${(_totalAmount * 320).toStringAsFixed(2)}'),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.of(context).pop();
              setState(() {
                _cartItems.clear();
                _totalAmount = 0.0;
              });
            },
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        // Products side
        Expanded(
          flex: 2,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Padding(
                padding: EdgeInsets.all(16.0),
                child: Text(
                  'Products',
                  style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                ),
              ),
              Expanded(
                child: GridView.builder(
                  padding: const EdgeInsets.all(16),
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 2,
                    childAspectRatio: 1.2,
                    crossAxisSpacing: 16,
                    mainAxisSpacing: 16,
                  ),
                  itemCount: _sampleProducts.length,
                  itemBuilder: (context, index) {
                    final product = _sampleProducts[index];
                    final isLowStock = product['stock'] < 10;
                    
                    return Card(
                      child: InkWell(
                        onTap: () => _addToCart(product),
                        borderRadius: BorderRadius.circular(12),
                        child: Padding(
                          padding: const EdgeInsets.all(12),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                product['name'],
                                style: const TextStyle(
                                  fontWeight: FontWeight.w600,
                                  fontSize: 14,
                                ),
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                              ),
                              const Spacer(),
                              Text(
                                '\$${product['price'].toStringAsFixed(2)}',
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                  color: Theme.of(context).colorScheme.primary,
                                ),
                              ),
                              Row(
                                children: [
                                  Text(
                                    'Stock: ${product['stock']}',
                                    style: TextStyle(
                                      fontSize: 12,
                                      color: isLowStock ? Colors.red : Colors.grey[600],
                                      fontWeight: isLowStock ? FontWeight.bold : FontWeight.normal,
                                    ),
                                  ),
                                  if (isLowStock) ...[
                                    const SizedBox(width: 4),
                                    Icon(
                                      Icons.warning,
                                      size: 16,
                                      color: Colors.red,
                                    ),
                                  ],
                                ],
                              ),
                            ],
                          ),
                        ),
                      ),
                    );
                  },
                ),
              ),
            ],
          ),
        ),
        
        // Cart side
        Container(
          width: 300,
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.surface,
            border: Border(
              left: BorderSide(color: Theme.of(context).colorScheme.outline),
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Padding(
                padding: EdgeInsets.all(16.0),
                child: Text(
                  'Cart',
                  style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                ),
              ),
              Expanded(
                child: ListView.builder(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  itemCount: _cartItems.length,
                  itemBuilder: (context, index) {
                    final item = _cartItems[index];
                    return Card(
                      margin: const EdgeInsets.only(bottom: 8),
                      child: ListTile(
                        title: Text(item['name']),
                        subtitle: Text('\$${item['price'].toStringAsFixed(2)} x ${item['quantity']}'),
                        trailing: IconButton(
                          icon: const Icon(Icons.remove_circle_outline),
                          onPressed: () => _removeFromCart(index),
                        ),
                      ),
                    );
                  },
                ),
              ),
              
              // Total and payment section
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.primaryContainer,
                  borderRadius: const BorderRadius.only(
                    topLeft: Radius.circular(16),
                    topRight: Radius.circular(16),
                  ),
                ),
                child: Column(
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text('Total (USD):', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                        Text('\$${_totalAmount.toStringAsFixed(2)}', style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text('Total (ZWL):', style: TextStyle(fontSize: 16)),
                        Text('ZWL ${(_totalAmount * 320).toStringAsFixed(2)}', style: const TextStyle(fontSize: 16)),
                      ],
                    ),
                    const SizedBox(height: 16),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        onPressed: _processPayment,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Theme.of(context).colorScheme.primary,
                          foregroundColor: Theme.of(context).colorScheme.onPrimary,
                          minimumSize: const Size(double.infinity, 56),
                        ),
                        child: const Text('Process Payment'),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

// Products Screen - Inventory management
class ProductsScreen extends StatelessWidget {
  const ProductsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return const Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.inventory_2, size: 64, color: Colors.grey),
          SizedBox(height: 16),
          Text(
            'Product Management',
            style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
          ),
          SizedBox(height: 8),
          Text(
            'Coming in Phase 2',
            style: TextStyle(fontSize: 16, color: Colors.grey),
          ),
        ],
      ),
    );
  }
}

// Settings Screen - Configuration and preferences
class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        const Text(
          'Settings',
          style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 16),
        
        // Store Settings
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Store Information',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
                ),
                const SizedBox(height: 16),
                ListTile(
                  leading: const Icon(Icons.store),
                  title: const Text('Store Name'),
                  subtitle: const Text('My Shop'),
                  trailing: const Icon(Icons.edit),
                  onTap: () {
                    // TODO: Implement store name editing
                  },
                ),
                ListTile(
                  leading: const Icon(Icons.location_on),
                  title: const Text('Address'),
                  subtitle: const Text('123 Main Street, Harare'),
                  trailing: const Icon(Icons.edit),
                  onTap: () {
                    // TODO: Implement address editing
                  },
                ),
              ],
            ),
          ),
        ),
        
        const SizedBox(height: 16),
        
        // Currency Settings
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Currency Settings',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
                ),
                const SizedBox(height: 16),
                ListTile(
                  leading: const Icon(Icons.currency_exchange),
                  title: const Text('Exchange Rate (USD to ZWL)'),
                  subtitle: const Text('1 USD = 320 ZWL'),
                  trailing: const Icon(Icons.refresh),
                  onTap: () {
                    // TODO: Implement exchange rate update
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Exchange rate update coming in Phase 2')),
                    );
                  },
                ),
                ListTile(
                  leading: const Icon(Icons.monetization_on),
                  title: const Text('Default Currency'),
                  subtitle: const Text('USD'),
                  trailing: const Icon(Icons.arrow_forward_ios),
                  onTap: () {
                    // TODO: Implement currency selection
                  },
                ),
              ],
            ),
          ),
        ),
        
        const SizedBox(height: 16),
        
        // Sync Settings
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Sync & Backup',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
                ),
                const SizedBox(height: 16),
                ListTile(
                  leading: const Icon(Icons.cloud_sync),
                  title: const Text('Cloud Sync'),
                  subtitle: const Text('Last synced: 2 minutes ago'),
                  trailing: Switch(
                    value: true,
                    onChanged: (value) {
                      // TODO: Implement sync toggle
                    },
                  ),
                ),
                ListTile(
                  leading: const Icon(Icons.backup),
                  title: const Text('Auto Backup'),
                  subtitle: const Text('Daily at 2:00 AM'),
                  trailing: const Icon(Icons.arrow_forward_ios),
                  onTap: () {
                    // TODO: Implement backup settings
                  },
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}