import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import '../models/product.dart';
import '../config/api.dart';
import 'login_page.dart';
import 'report_page.dart';

class ProductPage extends StatefulWidget {
  final String username;
  final String token;
  final String role; // OWNER or CASHIER

  const ProductPage({
    super.key,
    required this.username,
    required this.token,
    required this.role,
  });

  @override
  State<ProductPage> createState() => _ProductPageState();
}

class _ProductPageState extends State<ProductPage> {
  final List<Product> products = [];
  final TextEditingController searchController = TextEditingController();

  final String baseUrl = ApiConfig.baseUrl;

  bool get isOwner => widget.role == 'OWNER';
  bool get isCashier => widget.role == 'CASHIER';

  /* ================= FETCH PRODUCTS ================= */

  Future<void> fetchProducts() async {
    try {
      final res = await http.get(
        Uri.parse('$baseUrl/products'),
        headers: {'Authorization': 'Bearer ${widget.token}'},
      );

      if (res.statusCode == 200) {
        final list = jsonDecode(res.body) as List;

        setState(() {
          products
            ..clear()
            ..addAll(
              list.map(
                    (e) => Product.fromJson(e as Map<String, dynamic>),
              ),
            );
        });
      }
    } catch (e) {
      debugPrint('fetchProducts error: $e');
    }
  }

  /* ================= ADD PRODUCT (OWNER) ================= */

  Future<void> addProduct(String name, double price, int qty) async {
    try {
      final res = await http.post(
        Uri.parse('$baseUrl/products'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer ${widget.token}',
        },
        body: jsonEncode({
          'name': name,
          'price': price,
          'stock_quantity': qty,
        }),
      );

      if (res.statusCode == 201) {
        await fetchProducts();
      }
    } catch (e) {
      debugPrint('addProduct error: $e');
    }
  }

  /* ================= UPDATE PRODUCT (OWNER) ================= */

  Future<void> updateProduct(Product p) async {
    try {
      final res = await http.put(
        Uri.parse('$baseUrl/products/${p.id}'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer ${widget.token}',
        },
        body: jsonEncode(p.toJson()),
      );

      if (res.statusCode == 200) {
        await fetchProducts();
      }
    } catch (e) {
      debugPrint('updateProduct error: $e');
    }
  }

  /* ================= DELETE PRODUCT (OWNER) ================= */

  Future<void> deleteProduct(Product p) async {
    try {
      final res = await http.delete(
        Uri.parse('$baseUrl/products/${p.id}'),
        headers: {'Authorization': 'Bearer ${widget.token}'},
      );

      if (res.statusCode == 200) {
        await fetchProducts();
      }
    } catch (e) {
      debugPrint('deleteProduct error: $e');
    }
  }

  /* ================= SELL PRODUCT (CASHIER) ================= */

  Future<void> sellProduct(Product p, int qty) async {
    try {
      // Assumption: backend provides POST /sales to record a sale and update stock
      final res = await http.post(
        Uri.parse('$baseUrl/sales'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer ${widget.token}',
        },
        body: jsonEncode({
          'product_id': p.id,
          'quantity': qty,
        }),
      );

      if (res.statusCode == 201 || res.statusCode == 200) {
        await fetchProducts();
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Sale recorded')),
          );
        }
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Sale failed (${res.statusCode})')),
          );
        }
      }
    } catch (e) {
      debugPrint('sellProduct error: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Network error while selling')),
        );
      }
    }
  }

  @override
  void initState() {
    super.initState();
    fetchProducts();
  }

  @override
  void dispose() {
    searchController.dispose();
    super.dispose();
  }

  /* ================= UI ================= */

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    final filtered = products.where((p) {
      final q = searchController.text.toLowerCase();
      return q.isEmpty || p.name.toLowerCase().contains(q);
    }).toList();

    return Scaffold(
      appBar: AppBar(
        title: Text("${widget.username}'s Products"),
        centerTitle: true,
        backgroundColor: const Color(0xFFFFF3E6),
        actions: [
          if (isOwner)
            IconButton(
              tooltip: 'Reports',
              icon: const Icon(Icons.bar_chart),
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => ReportPage(
                      username: widget.username,
                      token: widget.token,
                      role: widget.role,
                    ),
                  ),
                );
              },
            ),
          IconButton(
            icon: const Icon(Icons.logout),
            onPressed: () {
              Navigator.pushAndRemoveUntil(
                context,
                MaterialPageRoute(builder: (_) => const LoginPage()),
                    (_) => false,
              );
            },
          ),
        ],
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: TextField(
              controller: searchController,
              onChanged: (_) => setState(() {}),
              decoration: const InputDecoration(
                hintText: 'Search products...',
                prefixIcon: Icon(Icons.search),
                filled: true,
              ),
            ),
          ),
          Expanded(
            child: filtered.isEmpty
                ? _EmptyState(colorScheme: scheme)
                : ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: filtered.length,
              itemBuilder: (_, i) {
                final p = filtered[i];

                return Card(
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: ListTile(
                    onTap: () => showProductPreview(p),
                    title: Text(
                      p.name,
                      style: const TextStyle(fontWeight: FontWeight.w600),
                    ),
                    subtitle: Row(
                      children: [
                        const Icon(Icons.sell, size: 16),
                        const SizedBox(width: 4),
                        Text('Price: ${p.price.toStringAsFixed(2)}'),
                        const SizedBox(width: 12),
                        const Icon(Icons.inventory_2, size: 16),
                        const SizedBox(width: 4),
                        Text('Stock: ${p.stockQuantity}'),
                      ],
                    ),
                    trailing: isOwner
                        ? IconButton(
                      icon: const Icon(
                        Icons.delete_outline,
                        color: Colors.redAccent,
                      ),
                      onPressed: () => deleteProduct(p),
                    )
                        : isCashier
                        ? IconButton(
                      icon: const Icon(Icons.point_of_sale),
                      onPressed: () => showSellSheet(context, p),
                    )
                        : null,
                  ),
                );
              },
            ),
          ),
        ],
      ),
      floatingActionButton: isOwner
          ? FloatingActionButton(
        onPressed: () => showAddProductSheet(context),
        child: const Icon(Icons.add),
      )
          : null,
    );
  }

  /* ================= ADD PRODUCT SHEET ================= */

  void showAddProductSheet(BuildContext context) {
    final nameCtrl = TextEditingController();
    final priceCtrl = TextEditingController();
    final qtyCtrl = TextEditingController();

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (_) => Padding(
        padding: EdgeInsets.only(
          left: 16,
          right: 16,
          bottom: MediaQuery.of(context).viewInsets.bottom + 16,
          top: 16,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('Add Product', style: TextStyle(fontSize: 18)),
            const SizedBox(height: 12),
            TextField(
              controller: nameCtrl,
              decoration: const InputDecoration(
                labelText: 'Name',
                prefixIcon: Icon(Icons.shopping_bag_outlined),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: priceCtrl,
              keyboardType:
              const TextInputType.numberWithOptions(decimal: true),
              decoration: const InputDecoration(
                labelText: 'Price',
                prefixIcon: Icon(Icons.sell_outlined),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: qtyCtrl,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(
                labelText: 'Stock quantity',
                prefixIcon: Icon(Icons.inventory_2_outlined),
              ),
            ),
            const SizedBox(height: 12),
            ElevatedButton(
              onPressed: () {
                final name = nameCtrl.text.trim();
                final price =
                    double.tryParse(priceCtrl.text.trim()) ?? 0.0;
                final qty = int.tryParse(qtyCtrl.text.trim()) ?? 0;

                Navigator.pop(context);
                addProduct(name, price, qty);
              },
              child: const Text('Add'),
            ),
          ],
        ),
      ),
    );
  }

  /* ================= SELL SHEET (CASHIER) ================= */

  void showSellSheet(BuildContext context, Product p) {
    final qtyCtrl = TextEditingController();

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (_) => Padding(
        padding: EdgeInsets.only(
          left: 16,
          right: 16,
          bottom: MediaQuery.of(context).viewInsets.bottom + 16,
          top: 16,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.point_of_sale),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Sell: ${p.name}',
                    style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Text('Current stock: ${p.stockQuantity}'),
            const SizedBox(height: 12),
            TextField(
              controller: qtyCtrl,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(
                labelText: 'Quantity to sell',
                prefixIcon: Icon(Icons.numbers),
              ),
            ),
            const SizedBox(height: 12),
            ElevatedButton(
              onPressed: () {
                final qty = int.tryParse(qtyCtrl.text.trim()) ?? 0;
                if (qty <= 0) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Enter a valid quantity')),
                  );
                  return;
                }
                if (qty > p.stockQuantity) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Quantity exceeds stock')),
                  );
                  return;
                }
                Navigator.pop(context);
                sellProduct(p, qty);
              },
              child: const Text('Confirm Sale'),
            ),
          ],
        ),
      ),
    );
  }

  /* ================= PRODUCT PREVIEW ================= */

  void showProductPreview(Product p) {
    final scheme = Theme.of(context).colorScheme;

    showDialog(
      context: context,
      builder: (_) => Dialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(24),
        ),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(Icons.shopping_bag, color: scheme.primary),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      p.name,
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Text('Price: ${p.price.toStringAsFixed(2)}'),
              const SizedBox(height: 8),
              Text('Stock: ${p.stockQuantity}'),
              const SizedBox(height: 16),
              if (isOwner)
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton.icon(
                        icon: const Icon(Icons.edit),
                        label: const Text('Edit'),
                        onPressed: () {
                          Navigator.pop(context);
                          showEditProductDialog(p);
                        },
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: OutlinedButton.icon(
                        icon: const Icon(
                          Icons.delete_outline,
                          color: Colors.redAccent,
                        ),
                        label: const Text('Delete'),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: Colors.redAccent,
                        ),
                        onPressed: () {
                          Navigator.pop(context);
                          deleteProduct(p);
                        },
                      ),
                    ),
                  ],
                )
              else if (isCashier)
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton.icon(
                        icon: const Icon(Icons.point_of_sale),
                        label: const Text('Sell'),
                        onPressed: () {
                          Navigator.pop(context);
                          showSellSheet(context, p);
                        },
                      ),
                    ),
                  ],
                ),
            ],
          ),
        ),
      ),
    );
  }

  /* ================= EDIT PRODUCT ================= */

  void showEditProductDialog(Product p) {
    final nameCtrl = TextEditingController(text: p.name);
    final priceCtrl =
    TextEditingController(text: p.price.toStringAsFixed(2));
    final qtyCtrl =
    TextEditingController(text: p.stockQuantity.toString());

    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Edit Product'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(controller: nameCtrl),
            const SizedBox(height: 12),
            TextField(
              controller: priceCtrl,
              keyboardType:
              const TextInputType.numberWithOptions(decimal: true),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: qtyCtrl,
              keyboardType: TextInputType.number,
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);

              final updated = p.copyWith(
                name: nameCtrl.text.trim(),
                price:
                double.tryParse(priceCtrl.text.trim()) ?? p.price,
                stockQuantity:
                int.tryParse(qtyCtrl.text.trim()) ?? p.stockQuantity,
              );

              updateProduct(updated);
            },
            child: const Text('Save'),
          ),
        ],
      ),
    );
  }
}

/* ================= EMPTY STATE ================= */

class _EmptyState extends StatelessWidget {
  final ColorScheme colorScheme;

  const _EmptyState({required this.colorScheme});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Text(
        'No products yet 🛍️',
        style: TextStyle(color: colorScheme.outline, fontSize: 18),
      ),
    );
  }
}
