import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import '../models/product.dart';
import '../config/api.dart';

class ReportPage extends StatefulWidget {
  final String username;
  final String token;
  final String role; // OWNER or CASHIER

  const ReportPage({
    super.key,
    required this.username,
    required this.token,
    required this.role,
  });

  @override
  State<ReportPage> createState() => _ReportPageState();
}

class _ReportPageState extends State<ReportPage> {
  final String baseUrl = ApiConfig.baseUrl;

  final List<Product> products = [];
  Map<int, int> totalSoldByProduct = {}; // productId -> total sold (optional)
  bool loading = true;

  bool get isOwner => widget.role == 'OWNER';

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    await Future.wait([
      _fetchProducts(),
      _tryFetchProductSales(),
    ]);
    if (mounted) setState(() => loading = false);
  }

  Future<void> _fetchProducts() async {
    try {
      final res = await http.get(
        Uri.parse('$baseUrl/products'),
        headers: {'Authorization': 'Bearer ${widget.token}'},
      );
      if (res.statusCode == 200) {
        final list = jsonDecode(res.body) as List;
        products
          ..clear()
          ..addAll(list.map((e) => Product.fromJson(e as Map<String, dynamic>)));
      }
    } catch (e) {
      debugPrint('report fetchProducts error: $e');
    }
  }

  // Optional: aggregated sales per product if backend provides it
  Future<void> _tryFetchProductSales() async {
    try {
      final res = await http.get(
        Uri.parse('$baseUrl/reports/products'),
        headers: {'Authorization': 'Bearer ${widget.token}'},
      );
      if (res.statusCode == 200) {
        final list = jsonDecode(res.body) as List;
        // Expect [{product_id, total_sold}]
        totalSoldByProduct = {
          for (final e in list)
            (e['product_id'] as int): (e['total_sold'] as int)
        };
      }
    } catch (e) {
      // Silently ignore if not available
      debugPrint('report sales aggregate not available: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    if (!isOwner) {
      return Scaffold(
        appBar: AppBar(title: const Text('Reports')),
        body: const Center(child: Text('OWNER only')),
      );
    }

    final scheme = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: Text("${widget.username}'s Product Reports"),
        centerTitle: true,
        backgroundColor: const Color(0xFFFFF3E6),
      ),
      body: loading
          ? const Center(child: CircularProgressIndicator())
          : products.isEmpty
              ? _EmptyReport(colorScheme: scheme)
              : Padding(
                  padding: const EdgeInsets.all(16),
                  child: _ReportGrid(
                    products: products,
                    totalSoldByProduct: totalSoldByProduct,
                  ),
                ),
    );
  }
}

class _ReportGrid extends StatelessWidget {
  final List<Product> products;
  final Map<int, int> totalSoldByProduct;

  const _ReportGrid({
    required this.products,
    required this.totalSoldByProduct,
  });

  int _maxStock() {
    if (products.isEmpty) return 0;
    return products.map((p) => p.stockQuantity).reduce((a, b) => a > b ? a : b);
  }

  @override
  Widget build(BuildContext context) {
    final maxStock = _maxStock();
    final width = MediaQuery.of(context).size.width;
    final columns = width > 900 ? 3 : 2;
    // Increase height further on narrow phones
    final aspect = width < 480 ? 0.65 : (width < 600 ? 0.8 : 1.2);

    return GridView.builder(
      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: columns,
        crossAxisSpacing: 12,
        mainAxisSpacing: 12,
        childAspectRatio: aspect,
      ),
      itemCount: products.length,
      itemBuilder: (_, i) {
        final p = products[i];
        final sold = totalSoldByProduct[p.id] ?? 0;
        final stock = p.stockQuantity;
        final total = (maxStock == 0) ? stock : maxStock;
        final stockRatio = total == 0 ? 0.0 : stock / total;

        return _ReportCard(
          name: p.name,
          price: p.price,
          stock: stock,
          sold: sold,
          progress: stockRatio.clamp(0.0, 1.0),
        );
      },
    );
  }
}

class _ReportCard extends StatelessWidget {
  final String name;
  final double price;
  final int stock;
  final int sold;
  final double progress;

  const _ReportCard({
    required this.name,
    required this.price,
    required this.stock,
    required this.sold,
    required this.progress,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return Card(
      elevation: 1,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final cardWidth = constraints.maxWidth;
          final indicatorSize = cardWidth * 0.6; // responsive indicator size
          return Padding(
            padding: const EdgeInsets.all(12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.max,
              children: [
                Row(
                  children: [
                    CircleAvatar(
                      radius: 16,
                      backgroundColor: scheme.primaryContainer,
                      child: Text(
                        name.isNotEmpty ? name[0].toUpperCase() : '?',
                        style: const TextStyle(fontSize: 14),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        name,
                        style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                // Indicator section uses Flexible to adapt
                Flexible(
                  flex: 3,
                  child: Center(
                    child: SizedBox(
                      height: indicatorSize,
                      width: indicatorSize,
                      child: Stack(
                        alignment: Alignment.center,
                        children: [
                          SizedBox(
                            height: indicatorSize,
                            width: indicatorSize,
                            child: CircularProgressIndicator(
                              value: progress,
                              strokeWidth: 10,
                              backgroundColor: scheme.surfaceContainerHighest,
                              valueColor: AlwaysStoppedAnimation<Color>(
                                progress < 0.3
                                    ? Colors.redAccent
                                    : (progress < 0.7
                                        ? Colors.amber
                                        : scheme.primary),
                              ),
                            ),
                          ),
                          const Text('Stock', style: TextStyle(fontSize: 12)),
                        ],
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 6),
                Center(
                  child: Text(
                    '$stock',
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                const SizedBox(height: 8),
                // Bottom info rows wrapped in Flexible to avoid overflow
                Flexible(
                  fit: FlexFit.tight,
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Expanded(
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(Icons.sell, size: 14),
                            const SizedBox(width: 4),
                            Flexible(
                              child: Text(
                                price.toStringAsFixed(2),
                                style: const TextStyle(fontSize: 13),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 6),
                      Expanded(
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(Icons.shopping_cart_checkout, size: 14),
                            const SizedBox(width: 4),
                            Flexible(
                              child: Text(
                                'Sold: $sold',
                                style: const TextStyle(fontSize: 13),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}

class _EmptyReport extends StatelessWidget {
  final ColorScheme colorScheme;
  const _EmptyReport({required this.colorScheme});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Text(
        'No products to report',
        style: TextStyle(color: colorScheme.outline, fontSize: 18),
      ),
    );
  }
}
