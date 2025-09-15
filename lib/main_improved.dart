// Improved version of main.dart with smaller product cards and list/grid toggle
// This file contains the improved _buildProductGrid method and related functions

  Widget _buildProductGrid() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.all(16.0),
          child: Row(
            children: [
              const Icon(Icons.inventory_2, size: 24),
              const SizedBox(width: 8),
              const Text(
                'Products',
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
              ),
              const Spacer(),
              // View toggle buttons
              Container(
                decoration: BoxDecoration(
                  border: Border.all(color: Colors.grey[300]!),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    InkWell(
                      onTap: () => setState(() => _isGridView = true),
                      borderRadius: const BorderRadius.only(
                        topLeft: Radius.circular(8),
                        bottomLeft: Radius.circular(8),
                      ),
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                        decoration: BoxDecoration(
                          color: _isGridView ? Theme.of(context).colorScheme.primary : Colors.transparent,
                          borderRadius: const BorderRadius.only(
                            topLeft: Radius.circular(8),
                            bottomLeft: Radius.circular(8),
                          ),
                        ),
                        child: Icon(
                          Icons.grid_view,
                          size: 18,
                          color: _isGridView ? Colors.white : Colors.grey[600],
                        ),
                      ),
                    ),
                    InkWell(
                      onTap: () => setState(() => _isGridView = false),
                      borderRadius: const BorderRadius.only(
                        topRight: Radius.circular(8),
                        bottomRight: Radius.circular(8),
                      ),
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                        decoration: BoxDecoration(
                          color: !_isGridView ? Theme.of(context).colorScheme.primary : Colors.transparent,
                          borderRadius: const BorderRadius.only(
                            topRight: Radius.circular(8),
                            bottomRight: Radius.circular(8),
                          ),
                        ),
                        child: Icon(
                          Icons.view_list,
                          size: 18,
                          color: !_isGridView ? Colors.white : Colors.grey[600],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Text(
                '${filteredProducts.length} items',
                style: TextStyle(color: Colors.grey[600]),
              ),
            ],
          ),
        ),
        Expanded(
          child: _isGridView ? _buildGridView() : _buildListView(),
        ),
      ],
    );
  }

  Widget _buildGridView() {
    return GridView.builder(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: MediaQuery.of(context).size.width > 1200 ? 6 :
                      MediaQuery.of(context).size.width > 800 ? 5 : 4,
        childAspectRatio: 0.85, // More compact aspect ratio
        crossAxisSpacing: 8,
        mainAxisSpacing: 8,
      ),
      itemCount: filteredProducts.length,
      itemBuilder: (context, index) {
        final product = filteredProducts[index];
        final isLowStock = product['stock'] < 10;
        final isOutOfStock = product['stock'] <= 0;

        return Card(
          elevation: 1,
          child: InkWell(
            onTap: isOutOfStock ? null : () => _addToCart(product),
            borderRadius: BorderRadius.circular(12),
            child: Padding(
              padding: const EdgeInsets.all(8),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Product image/emoji - smaller
                  Center(
                    child: Text(
                      product['image'],
                      style: const TextStyle(fontSize: 20), // Reduced from 32
                    ),
                  ),
                  const SizedBox(height: 4),

                  // Product name - more compact
                  Text(
                    product['name'],
                    style: const TextStyle(
                      fontWeight: FontWeight.w600,
                      fontSize: 11, // Reduced from 14
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),

                  // Category - smaller
                  Text(
                    product['category'],
                    style: TextStyle(
                      fontSize: 9, // Reduced from 12
                      color: Colors.grey[600],
                    ),
                  ),

                  const Spacer(),

                  // Price - slightly smaller
                  Text(
                    '\$${product['price'].toStringAsFixed(2)}',
                    style: TextStyle(
                      fontSize: 13, // Reduced from 16
                      fontWeight: FontWeight.bold,
                      color: Theme.of(context).colorScheme.primary,
                    ),
                  ),

                  // Stock info - more compact
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          isOutOfStock
                              ? 'Out'
                              : '${product['stock']}',
                          style: TextStyle(
                            fontSize: 9, // Reduced from 12
                            color: isOutOfStock
                                ? Colors.red
                                : isLowStock
                                    ? Colors.orange
                                    : Colors.grey[600],
                            fontWeight: isOutOfStock || isLowStock
                                ? FontWeight.bold
                                : FontWeight.normal,
                          ),
                        ),
                      ),
                      if (isLowStock || isOutOfStock) ...[
                        Icon(
                          isOutOfStock ? Icons.error : Icons.warning,
                          size: 10, // Reduced from 16
                          color: isOutOfStock ? Colors.red : Colors.orange,
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
    );
  }

  Widget _buildListView() {
    return ListView.builder(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      itemCount: filteredProducts.length,
      itemBuilder: (context, index) {
        final product = filteredProducts[index];
        final isLowStock = product['stock'] < 10;
        final isOutOfStock = product['stock'] <= 0;

        return Card(
          elevation: 1,
          margin: const EdgeInsets.only(bottom: 6),
          child: ListTile(
            dense: true,
            contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
            leading: CircleAvatar(
              radius: 18,
              backgroundColor: Theme.of(context).colorScheme.primaryContainer,
              child: Text(product['image'], style: const TextStyle(fontSize: 16)),
            ),
            title: Text(
              product['name'],
              style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
            ),
            subtitle: Row(
              children: [
                Text(
                  product['category'],
                  style: TextStyle(fontSize: 11, color: Colors.grey[600]),
                ),
                const SizedBox(width: 8),
                Text(
                  isOutOfStock
                      ? 'Out of Stock'
                      : 'Stock: ${product['stock']}',
                  style: TextStyle(
                    fontSize: 11,
                    color: isOutOfStock
                        ? Colors.red
                        : isLowStock
                            ? Colors.orange
                            : Colors.grey[600],
                    fontWeight: isOutOfStock || isLowStock
                        ? FontWeight.bold
                        : FontWeight.normal,
                  ),
                ),
                if (isLowStock || isOutOfStock) ...[
                  const SizedBox(width: 4),
                  Icon(
                    isOutOfStock ? Icons.error : Icons.warning,
                    size: 12,
                    color: isOutOfStock ? Colors.red : Colors.orange,
                  ),
                ],
              ],
            ),
            trailing: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  '\$${product['price'].toStringAsFixed(2)}',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                    color: Theme.of(context).colorScheme.primary,
                  ),
                ),
              ],
            ),
            onTap: isOutOfStock ? null : () => _addToCart(product),
          ),
        );
      },
    );
  }
