import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'services/auth_service.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        Provider(create: (context) => AuthService()),
      ],
      child: MaterialApp(
        title: 'ShopaFlow',
        theme: ThemeData(
          primarySwatch: Colors.green,
          visualDensity: VisualDensity.adaptivePlatformDensity,
          colorScheme: ColorScheme.fromSeed(
            seedColor: Colors.green,
            brightness: Brightness.light,
          ),
        ),
        home: const HomeScreen(),
      ),
    );
  }
}

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int _selectedIndex = 0;

  final List<Widget> _pages = [
    const POSScreen(),
    const ProductsScreen(),
    const ReportsScreen(),
    const SettingsScreen(),
  ];

  void _onItemTapped(int index) {
    setState(() {
      _selectedIndex = index;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Row(
          children: [
            Icon(Icons.storefront, color: Colors.white),
            SizedBox(width: 8),
            Text('ShopaFlow', style: TextStyle(color: Colors.white)),
          ],
        ),
        backgroundColor: Theme.of(context).colorScheme.primary,
        actions: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            margin: const EdgeInsets.only(right: 8),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.15),
              borderRadius: BorderRadius.circular(6),
            ),
            child: const Text(
              '1 USD = 320.00 ZWL',
              style: TextStyle(color: Colors.white, fontSize: 12),
            ),
          ),
          IconButton(
            icon: const Icon(Icons.cloud_done, color: Colors.white),
            onPressed: () => ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('All data synced')),
            ),
          ),
        ],
      ),
      body: _pages[_selectedIndex],
      bottomNavigationBar: BottomNavigationBar(
        type: BottomNavigationBarType.fixed,
        backgroundColor: Theme.of(context).colorScheme.primary,
        selectedItemColor: Colors.white,
        unselectedItemColor: Colors.white70,
        currentIndex: _selectedIndex,
        onTap: _onItemTapped,
        items: const [
          BottomNavigationBarItem(
            icon: Icon(Icons.storefront_rounded),
            label: 'POS',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.inventory_2_outlined),
            label: 'Products',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.analytics_outlined),
            label: 'Reports',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.settings_outlined),
            label: 'Settings',
          ),
        ],
      ),
    );
  }
}

// Data models
class Product {
  final String id;
  final String name;
  final double price;
  final String barcode;
  final int stock;

  Product({
    required this.id,
    required this.name,
    required this.price,
    required this.barcode,
    required this.stock,
  });
}

class CartItem {
  final Product product;
  int quantity;

  CartItem({required this.product, required this.quantity});
}

// POS Screen - Interactive Point of Sale
class POSScreen extends StatefulWidget {
  const POSScreen({super.key});

  @override
  State<POSScreen> createState() => _POSScreenState();
}

class _POSScreenState extends State<POSScreen> {
  List<CartItem> cartItems = [];
  double subtotal = 0.0;
  double tax = 0.0;
  double total = 0.0;
  final TextEditingController barcodeController = TextEditingController();
  
  // Sample products for demonstration
  final List<Product> sampleProducts = [
    Product(id: '1', name: 'Coca Cola 500ml', price: 1.50, barcode: '123456789', stock: 50),
    Product(id: '2', name: 'White Bread', price: 2.25, barcode: '987654321', stock: 30),
    Product(id: '3', name: 'Milk 1L', price: 3.00, barcode: '456789123', stock: 25),
    Product(id: '4', name: 'Bananas (1kg)', price: 1.80, barcode: '789123456', stock: 40),
    Product(id: '5', name: 'Chicken Breast (1kg)', price: 8.50, barcode: '321654987', stock: 15),
  ];

  void addToCart(Product product) {
    setState(() {
      final existingIndex = cartItems.indexWhere((item) => item.product.id == product.id);
      if (existingIndex >= 0) {
        cartItems[existingIndex].quantity++;
      } else {
        cartItems.add(CartItem(product: product, quantity: 1));
      }
      calculateTotals();
    });
  }

  void removeFromCart(int index) {
    setState(() {
      if (cartItems[index].quantity > 1) {
        cartItems[index].quantity--;
      } else {
        cartItems.removeAt(index);
      }
      calculateTotals();
    });
  }

  void calculateTotals() {
    subtotal = cartItems.fold(0.0, (sum, item) => sum + (item.product.price * item.quantity));
    tax = subtotal * 0.08; // 8% tax
    total = subtotal + tax;
  }

  void scanBarcode() {
    final barcode = barcodeController.text.trim();
    if (barcode.isNotEmpty) {
      final product = sampleProducts.where((p) => p.barcode == barcode).firstOrNull;
      if (product != null) {
        addToCart(product);
        barcodeController.clear();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('${product.name} added to cart')),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Product not found')),
        );
      }
    }
  }

  void clearCart() {
    setState(() {
      cartItems.clear();
      calculateTotals();
    });
  }

  void processPayment() {
    if (cartItems.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Cart is empty')),
      );
      return;
    }
    
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Payment'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('Total: \$${total.toStringAsFixed(2)}'),
            const SizedBox(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                ElevatedButton(
                  onPressed: () {
                    Navigator.pop(context);
                    completeSale('Cash');
                  },
                  child: const Text('Cash'),
                ),
                ElevatedButton(
                  onPressed: () {
                    Navigator.pop(context);
                    completeSale('Card');
                  },
                  child: const Text('Card'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  void completeSale(String paymentMethod) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Sale Complete'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Payment Method: $paymentMethod'),
            Text('Total: \$${total.toStringAsFixed(2)}'),
            const SizedBox(height: 8),
            const Text('Receipt printed successfully!'),
            const Text('Thank you for your purchase!'),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              clearCart();
            },
            child: const Text('New Sale'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        // Left side - Product selection
        Expanded(
          flex: 2,
          child: Column(
            children: [
              // Barcode scanner section
              Container(
                padding: const EdgeInsets.all(16),
                color: Colors.grey[100],
                child: Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: barcodeController,
                        decoration: const InputDecoration(
                          hintText: 'Scan or enter barcode (try: 123456789)',
                          border: OutlineInputBorder(),
                          prefixIcon: Icon(Icons.qr_code_scanner),
                        ),
                        onSubmitted: (_) => scanBarcode(),
                      ),
                    ),
                    const SizedBox(width: 8),
                    ElevatedButton(
                      onPressed: scanBarcode,
                      child: const Text('Add'),
                    ),
                  ],
                ),
              ),
              // Product grid
              Expanded(
                child: GridView.builder(
                  padding: const EdgeInsets.all(16),
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 3,
                    childAspectRatio: 0.8,
                    crossAxisSpacing: 16,
                    mainAxisSpacing: 16,
                  ),
                  itemCount: sampleProducts.length,
                  itemBuilder: (context, index) {
                    final product = sampleProducts[index];
                    return Card(
                      elevation: 4,
                      child: InkWell(
                        onTap: () => addToCart(product),
                        child: Padding(
                          padding: const EdgeInsets.all(8),
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(
                                Icons.inventory_2,
                                size: 40,
                                color: Theme.of(context).primaryColor,
                              ),
                              const SizedBox(height: 8),
                              Text(
                                product.name,
                                textAlign: TextAlign.center,
                                style: const TextStyle(fontWeight: FontWeight.bold),
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                              ),
                              const SizedBox(height: 4),
                              Text(
                                '\$${product.price.toStringAsFixed(2)}',
                                style: TextStyle(
                                  color: Theme.of(context).primaryColor,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              Text(
                                'Stock: ${product.stock}',
                                style: const TextStyle(
                                  fontSize: 12,
                                  color: Colors.grey,
                                ),
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
        // Right side - Shopping cart
        Expanded(
          flex: 1,
          child: Container(
            decoration: BoxDecoration(
              border: Border(left: BorderSide(color: Colors.grey[300]!)),
            ),
            child: Column(
              children: [
                Container(
                  padding: const EdgeInsets.all(16),
                  color: Theme.of(context).primaryColor,
                  child: const Row(
                    children: [
                      Icon(Icons.shopping_cart, color: Colors.white),
                      SizedBox(width: 8),
                      Text(
                        'Current Sale',
                        style: TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                          fontSize: 18,
                        ),
                      ),
                    ],
                  ),
                ),
                Expanded(
                  child: cartItems.isEmpty
                      ? const Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(Icons.shopping_cart_outlined, size: 64, color: Colors.grey),
                              SizedBox(height: 16),
                              Text('Cart is empty'),
                              Text('Click products or scan barcode'),
                            ],
                          ),
                        )
                      : ListView.builder(
                          itemCount: cartItems.length,
                          itemBuilder: (context, index) {
                            final item = cartItems[index];
                            return ListTile(
                              title: Text(item.product.name),
                              subtitle: Text('\$${item.product.price.toStringAsFixed(2)} each'),
                              trailing: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  IconButton(
                                    onPressed: () => removeFromCart(index),
                                    icon: const Icon(Icons.remove),
                                  ),
                                  Text('${item.quantity}'),
                                  IconButton(
                                    onPressed: () => addToCart(item.product),
                                    icon: const Icon(Icons.add),
                                  ),
                                ],
                              ),
                            );
                          },
                        ),
                ),
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    border: Border(top: BorderSide(color: Colors.grey[300]!)),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text('Subtotal:'),
                          Text('\$${subtotal.toStringAsFixed(2)}'),
                        ],
                      ),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text('Tax (8%):'),
                          Text('\$${tax.toStringAsFixed(2)}'),
                        ],
                      ),
                      const Divider(),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text(
                            'Total:',
                            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
                          ),
                          Text(
                            '\$${total.toStringAsFixed(2)}',
                            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      Row(
                        children: [
                          Expanded(
                            child: OutlinedButton(
                              onPressed: cartItems.isNotEmpty ? clearCart : null,
                              child: const Text('Clear'),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            flex: 2,
                            child: ElevatedButton(
                              onPressed: processPayment,
                              style: ElevatedButton.styleFrom(
                                padding: const EdgeInsets.symmetric(vertical: 16),
                              ),
                              child: const Text(
                                'Pay',
                                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

// Products Screen - Interactive Product Management
class ProductsScreen extends StatefulWidget {
  const ProductsScreen({super.key});

  @override
  State<ProductsScreen> createState() => _ProductsScreenState();
}

class _ProductsScreenState extends State<ProductsScreen> {
  final List<Product> products = [
    Product(id: '1', name: 'Coca Cola', price: 2.50, stock: 50, barcode: '123456789'),
    Product(id: '2', name: 'Bread', price: 3.25, stock: 20, barcode: '987654321'),
    Product(id: '3', name: 'Milk', price: 4.50, stock: 15, barcode: '456789123'),
  ];

  String searchQuery = '';
  bool isAddingProduct = false;
  final TextEditingController nameController = TextEditingController();
  final TextEditingController priceController = TextEditingController();
  final TextEditingController stockController = TextEditingController();

  void addProduct() {
    if (nameController.text.isNotEmpty && priceController.text.isNotEmpty) {
      setState(() {
        products.add(Product(
          id: DateTime.now().millisecondsSinceEpoch.toString(),
          name: nameController.text,
          price: double.tryParse(priceController.text) ?? 0.0,
          stock: int.tryParse(stockController.text) ?? 0,
          barcode: DateTime.now().millisecondsSinceEpoch.toString(),
        ));
        nameController.clear();
        priceController.clear();
        stockController.clear();
        isAddingProduct = false;
      });
    }
  }

  void deleteProduct(String id) {
    setState(() {
      products.removeWhere((product) => product.id == id);
    });
  }

  List<Product> get filteredProducts {
    return products.where((product) => 
      product.name.toLowerCase().contains(searchQuery.toLowerCase())
    ).toList();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        // Header
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.blue[50],
            border: Border(bottom: BorderSide(color: Colors.grey[300]!)),
          ),
          child: Row(
            children: [
              const Icon(Icons.inventory_2, color: Colors.blue, size: 28),
              const SizedBox(width: 12),
              const Text(
                'Product Management',
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  color: Colors.blue,
                ),
              ),
              const Spacer(),
              ElevatedButton.icon(
                onPressed: () => setState(() => isAddingProduct = true),
                icon: const Icon(Icons.add),
                label: const Text('Add Product'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.blue,
                  foregroundColor: Colors.white,
                ),
              ),
            ],
          ),
        ),
        
        // Search Bar
        Padding(
          padding: const EdgeInsets.all(16),
          child: TextField(
            decoration: const InputDecoration(
              hintText: 'Search products...',
              prefixIcon: Icon(Icons.search),
              border: OutlineInputBorder(),
            ),
            onChanged: (value) => setState(() => searchQuery = value),
          ),
        ),

        // Add Product Form
        if (isAddingProduct)
          Container(
            margin: const EdgeInsets.symmetric(horizontal: 16),
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.grey[50],
              border: Border.all(color: Colors.grey[300]!),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Add New Product',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: nameController,
                        decoration: const InputDecoration(
                          labelText: 'Product Name',
                          border: OutlineInputBorder(),
                        ),
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: TextField(
                        controller: priceController,
                        decoration: const InputDecoration(
                          labelText: 'Price (\$)',
                          border: OutlineInputBorder(),
                        ),
                        keyboardType: TextInputType.number,
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: TextField(
                        controller: stockController,
                        decoration: const InputDecoration(
                          labelText: 'Stock Quantity',
                          border: OutlineInputBorder(),
                        ),
                        keyboardType: TextInputType.number,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    ElevatedButton(
                      onPressed: addProduct,
                      child: const Text('Save Product'),
                    ),
                    const SizedBox(width: 8),
                    TextButton(
                      onPressed: () => setState(() {
                        isAddingProduct = false;
                        nameController.clear();
                        priceController.clear();
                        stockController.clear();
                      }),
                      child: const Text('Cancel'),
                    ),
                  ],
                ),
              ],
            ),
          ),
        
        const SizedBox(height: 16),
        
        // Products List
        Expanded(
          child: filteredProducts.isEmpty
              ? const Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.inventory_2, size: 64, color: Colors.grey),
                      SizedBox(height: 16),
                      Text('No products found'),
                      Text('Add your first product to get started'),
                    ],
                  ),
                )
              : ListView.builder(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  itemCount: filteredProducts.length,
                  itemBuilder: (context, index) {
                    final product = filteredProducts[index];
                    return Card(
                      margin: const EdgeInsets.only(bottom: 8),
                      child: ListTile(
                        leading: CircleAvatar(
                          backgroundColor: Colors.blue[100],
                          child: const Icon(Icons.inventory_2, color: Colors.blue),
                        ),
                        title: Text(
                          product.name,
                          style: const TextStyle(fontWeight: FontWeight.bold),
                        ),
                        subtitle: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('Price: \$${product.price.toStringAsFixed(2)}'),
                            Text(
                              'Stock: ${product.stock} units',
                              style: TextStyle(
                                color: product.stock < 10 ? Colors.red : Colors.green,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ],
                        ),
                        trailing: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            IconButton(
                              onPressed: () {
                                showDialog(
                                  context: context,
                                  builder: (context) => AlertDialog(
                                    title: Text('Edit ${product.name}'),
                                    content: const Text('Edit functionality coming soon...'),
                                    actions: [
                                      TextButton(
                                        onPressed: () => Navigator.pop(context),
                                        child: const Text('OK'),
                                      ),
                                    ],
                                  ),
                                );
                              },
                              icon: const Icon(Icons.edit, color: Colors.blue),
                            ),
                            IconButton(
                              onPressed: () {
                                showDialog(
                                  context: context,
                                  builder: (context) => AlertDialog(
                                    title: const Text('Delete Product'),
                                    content: Text('Are you sure you want to delete ${product.name}?'),
                                    actions: [
                                      TextButton(
                                        onPressed: () => Navigator.pop(context),
                                        child: const Text('Cancel'),
                                      ),
                                      TextButton(
                                        onPressed: () {
                                          deleteProduct(product.id);
                                          Navigator.pop(context);
                                        },
                                        child: const Text('Delete'),
                                        style: TextButton.styleFrom(
                                          foregroundColor: Colors.red,
                                        ),
                                      ),
                                    ],
                                  ),
                                );
                              },
                              icon: const Icon(Icons.delete, color: Colors.red),
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
        ),
      ],
    );
  }

  @override
  void dispose() {
    nameController.dispose();
    priceController.dispose();
    stockController.dispose();
    super.dispose();
  }
}

// Reports Screen - Interactive Sales Analytics
class ReportsScreen extends StatefulWidget {
  const ReportsScreen({super.key});

  @override
  State<ReportsScreen> createState() => _ReportsScreenState();
}

class _ReportsScreenState extends State<ReportsScreen> {
  String selectedPeriod = 'Today';
  final List<String> periods = ['Today', 'Week', 'Month', 'Year'];
  
  final Map<String, Map<String, dynamic>> salesData = {
    'Today': {'sales': 1234.56, 'transactions': 45, 'items_sold': 127},
    'Week': {'sales': 8765.43, 'transactions': 203, 'items_sold': 892},
    'Month': {'sales': 34567.89, 'transactions': 1456, 'items_sold': 4231},
    'Year': {'sales': 456789.12, 'transactions': 15678, 'items_sold': 45892},
  };

  final List<Map<String, dynamic>> topProducts = [
    {'name': 'Coca Cola', 'sales': 450.75, 'quantity': 150},
    {'name': 'Bread', 'sales': 325.50, 'quantity': 100},
    {'name': 'Milk', 'sales': 270.00, 'quantity': 60},
    {'name': 'Coffee', 'sales': 188.25, 'quantity': 75},
  ];

  @override
  Widget build(BuildContext context) {
    final currentData = salesData[selectedPeriod]!;
    
    return Column(
      children: [
        // Header
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.orange[50],
            border: Border(bottom: BorderSide(color: Colors.grey[300]!)),
          ),
          child: Row(
            children: [
              const Icon(Icons.analytics, color: Colors.orange, size: 28),
              const SizedBox(width: 12),
              const Text(
                'Sales Reports',
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  color: Colors.orange,
                ),
              ),
              const Spacer(),
              // Period Selector
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12),
                decoration: BoxDecoration(
                  border: Border.all(color: Colors.orange[300]!),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: DropdownButton<String>(
                  value: selectedPeriod,
                  underline: const SizedBox(),
                  items: periods.map((period) => DropdownMenuItem(
                    value: period,
                    child: Text(period),
                  )).toList(),
                  onChanged: (value) => setState(() => selectedPeriod = value!),
                ),
              ),
            ],
          ),
        ),
        
        Expanded(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Key Metrics Cards
                Row(
                  children: [
                    Expanded(
                      child: Card(
                        color: Colors.green[50],
                        child: Padding(
                          padding: const EdgeInsets.all(16),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Icon(Icons.attach_money, color: Colors.green[700]),
                                  const SizedBox(width: 8),
                                  Text(
                                    'Total Sales',
                                    style: TextStyle(
                                      fontSize: 16,
                                      fontWeight: FontWeight.w500,
                                      color: Colors.green[700],
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 8),
                              Text(
                                '\$${currentData['sales'].toStringAsFixed(2)}',
                                style: TextStyle(
                                  fontSize: 24,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.green[700],
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Card(
                        color: Colors.blue[50],
                        child: Padding(
                          padding: const EdgeInsets.all(16),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Icon(Icons.receipt, color: Colors.blue[700]),
                                  const SizedBox(width: 8),
                                  Text(
                                    'Transactions',
                                    style: TextStyle(
                                      fontSize: 16,
                                      fontWeight: FontWeight.w500,
                                      color: Colors.blue[700],
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 8),
                              Text(
                                '${currentData['transactions']}',
                                style: TextStyle(
                                  fontSize: 24,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.blue[700],
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Card(
                        color: Colors.purple[50],
                        child: Padding(
                          padding: const EdgeInsets.all(16),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Icon(Icons.inventory, color: Colors.purple[700]),
                                  const SizedBox(width: 8),
                                  Text(
                                    'Items Sold',
                                    style: TextStyle(
                                      fontSize: 16,
                                      fontWeight: FontWeight.w500,
                                      color: Colors.purple[700],
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 8),
                              Text(
                                '${currentData['items_sold']}',
                                style: TextStyle(
                                  fontSize: 24,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.purple[700],
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
                
                const SizedBox(height: 24),
                
                // Top Products Section
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Icon(Icons.trending_up, color: Colors.orange[700]),
                            const SizedBox(width: 8),
                            Text(
                              'Top Products - $selectedPeriod',
                              style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                                color: Colors.orange[700],
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 16),
                        ...topProducts.map((product) => Padding(
                          padding: const EdgeInsets.only(bottom: 12),
                          child: Row(
                            children: [
                              Expanded(
                                flex: 2,
                                child: Text(
                                  product['name'],
                                  style: const TextStyle(
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              ),
                              Expanded(
                                child: Text(
                                  '\$${product['sales'].toStringAsFixed(2)}',
                                  textAlign: TextAlign.center,
                                  style: const TextStyle(
                                    color: Colors.green,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              ),
                              Expanded(
                                child: Text(
                                  '${product['quantity']} units',
                                  textAlign: TextAlign.right,
                                  style: TextStyle(
                                    color: Colors.grey[600],
                                  ),
                                ),
                              ),
                            ],
                          ),
                        )).toList(),
                      ],
                    ),
                  ),
                ),
                
                const SizedBox(height: 24),
                
                // Action Buttons
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: () {
                          showDialog(
                            context: context,
                            builder: (context) => AlertDialog(
                              title: const Text('Export Report'),
                              content: Text('Export $selectedPeriod report as PDF or CSV?'),
                              actions: [
                                TextButton(
                                  onPressed: () => Navigator.pop(context),
                                  child: const Text('Cancel'),
                                ),
                                TextButton(
                                  onPressed: () {
                                    Navigator.pop(context);
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      SnackBar(content: Text('Exporting $selectedPeriod report...')),
                                    );
                                  },
                                  child: const Text('Export PDF'),
                                ),
                              ],
                            ),
                          );
                        },
                        icon: const Icon(Icons.download),
                        label: const Text('Export Report'),
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: ElevatedButton.icon(
                        onPressed: () {
                          setState(() {
                            // Refresh data simulation
                          });
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text('Reports refreshed!')),
                          );
                        },
                        icon: const Icon(Icons.refresh),
                        label: const Text('Refresh Data'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.orange,
                          foregroundColor: Colors.white,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

// Settings Screen - Interactive System Configuration
class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  String storeName = 'ShopaFlow Store';
  String storeAddress = '123 Main Street, City, Country';
  String currency = 'USD';
  double taxRate = 8.5;
  bool receiptPrinting = true;
  bool barcodeScanning = true;
  bool inventoryTracking = true;
  bool loyaltyProgram = false;
  String receiptFooter = 'Thank you for shopping with us!';
  
  final List<String> currencies = ['USD', 'EUR', 'GBP', 'CAD', 'AUD'];
  final List<String> printerTypes = ['Thermal', 'Inkjet', 'Laser'];
  String selectedPrinter = 'Thermal';

  void saveSettings() {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Settings saved successfully!'),
        backgroundColor: Colors.green,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        // Header
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.purple[50],
            border: Border(bottom: BorderSide(color: Colors.grey[300]!)),
          ),
          child: Row(
            children: [
              const Icon(Icons.settings, color: Colors.purple, size: 28),
              const SizedBox(width: 12),
              const Text(
                'System Settings',
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  color: Colors.purple,
                ),
              ),
              const Spacer(),
              ElevatedButton.icon(
                onPressed: saveSettings,
                icon: const Icon(Icons.save),
                label: const Text('Save Changes'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.purple,
                  foregroundColor: Colors.white,
                ),
              ),
            ],
          ),
        ),
        
        Expanded(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Store Information Section
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Icon(Icons.store, color: Colors.purple[700]),
                            const SizedBox(width: 8),
                            Text(
                              'Store Information',
                              style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                                color: Colors.purple[700],
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 16),
                        TextField(
                          decoration: const InputDecoration(
                            labelText: 'Store Name',
                            border: OutlineInputBorder(),
                          ),
                          controller: TextEditingController(text: storeName),
                          onChanged: (value) => storeName = value,
                        ),
                        const SizedBox(height: 16),
                        TextField(
                          decoration: const InputDecoration(
                            labelText: 'Store Address',
                            border: OutlineInputBorder(),
                          ),
                          controller: TextEditingController(text: storeAddress),
                          onChanged: (value) => storeAddress = value,
                          maxLines: 2,
                        ),
                      ],
                    ),
                  ),
                ),
                
                const SizedBox(height: 16),
                
                // Financial Settings Section
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Icon(Icons.attach_money, color: Colors.green[700]),
                            const SizedBox(width: 8),
                            Text(
                              'Financial Settings',
                              style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                                color: Colors.green[700],
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 16),
                        Row(
                          children: [
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Text('Currency', style: TextStyle(fontWeight: FontWeight.w500)),
                                  const SizedBox(height: 8),
                                  DropdownButtonFormField<String>(
                                    value: currency,
                                    decoration: const InputDecoration(
                                      border: OutlineInputBorder(),
                                    ),
                                    items: currencies.map((curr) => DropdownMenuItem(
                                      value: curr,
                                      child: Text(curr),
                                    )).toList(),
                                    onChanged: (value) => setState(() => currency = value!),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(width: 16),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Text('Tax Rate (%)', style: TextStyle(fontWeight: FontWeight.w500)),
                                  const SizedBox(height: 8),
                                  TextFormField(
                                    decoration: const InputDecoration(
                                      border: OutlineInputBorder(),
                                      suffixText: '%',
                                    ),
                                    initialValue: taxRate.toString(),
                                    keyboardType: TextInputType.number,
                                    onChanged: (value) => taxRate = double.tryParse(value) ?? taxRate,
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
                
                const SizedBox(height: 16),
                
                // System Features Section
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Icon(Icons.tune, color: Colors.blue[700]),
                            const SizedBox(width: 8),
                            Text(
                              'System Features',
                              style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                                color: Colors.blue[700],
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 16),
                        SwitchListTile(
                          title: const Text('Receipt Printing'),
                          subtitle: const Text('Print receipts for transactions'),
                          value: receiptPrinting,
                          onChanged: (value) => setState(() => receiptPrinting = value),
                        ),
                        SwitchListTile(
                          title: const Text('Barcode Scanning'),
                          subtitle: const Text('Enable barcode scanner for products'),
                          value: barcodeScanning,
                          onChanged: (value) => setState(() => barcodeScanning = value),
                        ),
                        SwitchListTile(
                          title: const Text('Inventory Tracking'),
                          subtitle: const Text('Track stock levels automatically'),
                          value: inventoryTracking,
                          onChanged: (value) => setState(() => inventoryTracking = value),
                        ),
                        SwitchListTile(
                          title: const Text('Loyalty Program'),
                          subtitle: const Text('Enable customer loyalty rewards'),
                          value: loyaltyProgram,
                          onChanged: (value) => setState(() => loyaltyProgram = value),
                        ),
                      ],
                    ),
                  ),
                ),
                
                const SizedBox(height: 16),
                
                // Printer Settings Section
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Icon(Icons.print, color: Colors.orange[700]),
                            const SizedBox(width: 8),
                            Text(
                              'Printer Settings',
                              style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                                color: Colors.orange[700],
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 16),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text('Printer Type', style: TextStyle(fontWeight: FontWeight.w500)),
                            const SizedBox(height: 8),
                            DropdownButtonFormField<String>(
                              value: selectedPrinter,
                              decoration: const InputDecoration(
                                border: OutlineInputBorder(),
                              ),
                              items: printerTypes.map((printer) => DropdownMenuItem(
                                value: printer,
                                child: Text(printer),
                              )).toList(),
                              onChanged: (value) => setState(() => selectedPrinter = value!),
                            ),
                          ],
                        ),
                        const SizedBox(height: 16),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text('Receipt Footer', style: TextStyle(fontWeight: FontWeight.w500)),
                            const SizedBox(height: 8),
                            TextField(
                              decoration: const InputDecoration(
                                border: OutlineInputBorder(),
                                hintText: 'Custom message on receipts',
                              ),
                              controller: TextEditingController(text: receiptFooter),
                              onChanged: (value) => receiptFooter = value,
                              maxLines: 2,
                            ),
                          ],
                        ),
                        const SizedBox(height: 16),
                        Row(
                          children: [
                            Expanded(
                              child: OutlinedButton.icon(
                                onPressed: () {
                                  showDialog(
                                    context: context,
                                    builder: (context) => AlertDialog(
                                      title: const Text('Test Print'),
                                      content: const Text('Send a test receipt to the printer?'),
                                      actions: [
                                        TextButton(
                                          onPressed: () => Navigator.pop(context),
                                          child: const Text('Cancel'),
                                        ),
                                        TextButton(
                                          onPressed: () {
                                            Navigator.pop(context);
                                            ScaffoldMessenger.of(context).showSnackBar(
                                              const SnackBar(content: Text('Test receipt sent to printer!')),
                                            );
                                          },
                                          child: const Text('Print'),
                                        ),
                                      ],
                                    ),
                                  );
                                },
                                icon: const Icon(Icons.print),
                                label: const Text('Test Print'),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
                
                const SizedBox(height: 24),
                
                // System Information
                Card(
                  color: Colors.grey[50],
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Icon(Icons.info_outline, color: Colors.grey[700]),
                            const SizedBox(width: 8),
                            Text(
                              'System Information',
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                                color: Colors.grey[700],
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        const Text('ShopaFlow POS v1.0.0'),
                        const Text('Database: Connected'),
                        const Text('Last Backup: Today 09:30 AM'),
                        const SizedBox(height: 12),
                        Row(
                          children: [
                            TextButton.icon(
                              onPressed: () {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(content: Text('Backup completed successfully!')),
                                );
                              },
                              icon: const Icon(Icons.backup),
                              label: const Text('Backup Now'),
                            ),
                            const SizedBox(width: 16),
                            TextButton.icon(
                              onPressed: () {
                                showDialog(
                                  context: context,
                                  builder: (context) => AlertDialog(
                                    title: const Text('About ShopaFlow'),
                                    content: const Text(
                                      'ShopaFlow POS System\n\n'
                                      'Version: 1.0.0\n'
                                      'Built with Flutter\n\n'
                                      'A modern point-of-sale solution for your business.'
                                    ),
                                    actions: [
                                      TextButton(
                                        onPressed: () => Navigator.pop(context),
                                        child: const Text('OK'),
                                      ),
                                    ],
                                  ),
                                );
                              },
                              icon: const Icon(Icons.help_outline),
                              label: const Text('About'),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}