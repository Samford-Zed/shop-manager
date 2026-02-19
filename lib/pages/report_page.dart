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
  bool summaryLoading = true;
  Map<String, dynamic> periodSummary = const {};

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
      _fetchPeriodSummary(),
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

  Future<void> _fetchPeriodSummary() async {
    try {
      final headers = {'Authorization': 'Bearer ${widget.token}'};
      final weekReq = http.get(Uri.parse('$baseUrl/reports/summary?period=week'), headers: headers);
      final monthReq = http.get(Uri.parse('$baseUrl/reports/summary?period=month'), headers: headers);
      final yearReq = http.get(Uri.parse('$baseUrl/reports/summary?period=year'), headers: headers);
      final res = await Future.wait([weekReq, monthReq, yearReq]);

      if (res[0].statusCode == 200 && res[1].statusCode == 200 && res[2].statusCode == 200) {
        periodSummary = {
          'week': jsonDecode(res[0].body) as Map<String, dynamic>,
          'month': jsonDecode(res[1].body) as Map<String, dynamic>,
          'year': jsonDecode(res[2].body) as Map<String, dynamic>,
        };
      }
    } catch (e) {
      debugPrint('report period summary not available: $e');
    } finally {
      if (mounted) setState(() => summaryLoading = false);
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
          : Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                children: [
                  _PeriodSummary(summary: periodSummary, loading: summaryLoading),
                  const SizedBox(height: 12),
                  Expanded(
                    child: products.isEmpty
                        ? _EmptyReport(colorScheme: scheme)
                        : _ReportGrid(
                            products: products,
                            totalSoldByProduct: totalSoldByProduct,
                          ),
                  ),
                ],
              ),
            ),
    );
  }
}

class _PeriodSummary extends StatelessWidget {
  final Map<String, dynamic> summary;
  final bool loading;
  const _PeriodSummary({required this.summary, required this.loading});

  String _money(num v) => v.toStringAsFixed(2);

  Map<String, dynamic> _period(String key) {
    final data = summary[key];
    if (data is Map<String, dynamic>) return data;
    return const {};
  }

  int _int(dynamic v) {
    if (v == null) return 0;
    if (v is int) return v;
    if (v is num) return v.toInt();
    return 0;
  }

  num _num(dynamic v) {
    if (v == null) return 0;
    if (v is num) return v;
    return 0;
  }

  Widget _kpiCard(BuildContext context, String title, String value) {
    final scheme = Theme.of(context).colorScheme;
    return Card(
      elevation: 1,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title, style: TextStyle(color: scheme.outline, fontSize: 12)),
            const SizedBox(height: 6),
            if (loading)
              const SizedBox(
                height: 20,
                width: 20,
                child: CircularProgressIndicator(strokeWidth: 2),
              )
            else
              Text(value, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 18)),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final week = _period('week');
    final month = _period('month');
    final year = _period('year');

    final cards = [
      _kpiCard(context, 'Weekly Revenue', 'ETB ${_money(_num(week['revenue']))}'),
      _kpiCard(context, 'Monthly Revenue', 'ETB ${_money(_num(month['revenue']))}'),
      _kpiCard(context, 'Yearly Revenue', 'ETB ${_money(_num(year['revenue']))}'),
      _kpiCard(context, 'Weekly Items Sold', '${_int(week['items'])}'),
      _kpiCard(context, 'Monthly Items Sold', '${_int(month['items'])}'),
      _kpiCard(context, 'Yearly Items Sold', '${_int(year['items'])}'),
    ];

    return LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.maxWidth;
        final columns = width > 900 ? 3 : (width > 600 ? 2 : 1);
        final cardWidth = (width - ((columns - 1) * 12)) / columns;
        return Wrap(
          spacing: 12,
          runSpacing: 12,
          children: [
            for (final card in cards) SizedBox(width: cardWidth, child: card),
          ],
        );
      },
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
