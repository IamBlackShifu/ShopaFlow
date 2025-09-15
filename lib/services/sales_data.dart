// Sales Data Model for tracking actual transactions
class SalesData {
  static final List<Map<String, dynamic>> _transactions = [];
  static final List<Map<String, dynamic>> _products = [];

  static List<Map<String, dynamic>> get transactions => _transactions;
  static List<Map<String, dynamic>> get products => _products;

  static void addTransaction(Map<String, dynamic> transaction) {
    _transactions.add({
      ...transaction,
      'id': 'TXN${(_transactions.length + 1).toString().padLeft(3, '0')}',
      'date': DateTime.now().toString().substring(0, 10),
      'time': '${DateTime.now().hour.toString().padLeft(2, '0')}:${DateTime.now().minute.toString().padLeft(2, '0')}',
    });
  }

  static void addProduct(Map<String, dynamic> product) {
    _products.add({
      ...product,
      'id': _products.length + 1,
      'lastUpdated': DateTime.now().toString().substring(0, 10),
    });
  }

  static void updateProduct(int id, Map<String, dynamic> updatedProduct) {
    final index = _products.indexWhere((p) => p['id'] == id);
    if (index != -1) {
      _products[index] = {
        ...updatedProduct,
        'id': id,
        'lastUpdated': DateTime.now().toString().substring(0, 10),
      };
    }
  }

  static void deleteProduct(int id) {
    _products.removeWhere((p) => p['id'] == id);
  }

  static void updateProductStock(int productId, int newStock) {
    final index = _products.indexWhere((p) => p['id'] == productId);
    if (index != -1) {
      _products[index]['stock'] = newStock;
    }
  }

  static void clearProducts() {
    _products.clear();
  }

  static void clearTransactions() {
    _transactions.clear();
  }

  // Generate daily report data
  static Map<String, dynamic> getDailyReport([DateTime? date]) {
    final targetDate = date ?? DateTime.now();
    final dateString = targetDate.toString().substring(0, 10);

    final dayTransactions = _transactions.where((t) => t['date'] == dateString).toList();

    final totalSales = dayTransactions.fold(0.0, (sum, t) => sum + (t['total'] ?? 0.0));
    final totalCosts = dayTransactions.fold(0.0, (sum, t) => sum + (t['cost'] ?? 0.0));
    final totalProfit = totalSales - totalCosts;
    final transactionCount = dayTransactions.length;

    return {
      'date': dateString,
      'transactions': dayTransactions,
      'totalSales': totalSales,
      'totalCosts': totalCosts,
      'totalProfit': totalProfit,
      'transactionCount': transactionCount,
      'averageTransaction': transactionCount > 0 ? totalSales / transactionCount : 0.0,
      'profitMargin': totalSales > 0 ? (totalProfit / totalSales * 100) : 0.0,
    };
  }

  // Export report to CSV format
  static String exportToCsv([DateTime? date]) {
    final report = getDailyReport(date);
    final transactions = report['transactions'] as List<Map<String, dynamic>>;

    String csv = 'Transaction ID,Time,Items,Total,Payment Method,Customer\n';

    for (var transaction in transactions) {
      final items = (transaction['items'] as List<String>).join('; ');
      csv += '${transaction['id']},${transaction['time']},"$items",${transaction['total']},${transaction['payment']},${transaction['customerId'] ?? 'WALK-IN'}\n';
    }

    return csv;
  }

  // Get products that need reordering
  static List<Map<String, dynamic>> getLowStockProducts() {
    return _products.where((p) => (p['stock'] ?? 0) < 10).toList();
  }

  // Get top selling products
  static List<Map<String, dynamic>> getTopProducts([int limit = 5]) {
    final productSales = <String, int>{};

    for (var transaction in _transactions) {
      final items = transaction['items'] as List<String>? ?? [];
      for (var item in items) {
        productSales[item] = (productSales[item] ?? 0) + 1;
      }
    }

    final sortedProducts = productSales.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));

    return sortedProducts.take(limit).map((entry) => {
      'name': entry.key,
      'soldCount': entry.value,
    }).toList();
  }
}
