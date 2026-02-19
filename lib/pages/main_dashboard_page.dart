import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import '../models/product.dart';
import '../config/api.dart';
import 'login_page.dart'; // Added for Logout navigation

class MainDashboardPage extends StatefulWidget {
  final String username;
  final String token;
  final String role; // OWNER or CASHIER
  const MainDashboardPage({
    super.key,
    required this.username,
    required this.token,
    required this.role,
  });

  @override
  State<MainDashboardPage> createState() => _MainDashboardPageState();
}

class _MainDashboardPageState extends State<MainDashboardPage> {
  int _index = 0;

  String _nameFromToken(String token, String fallback) {
    try {
      final parts = token.split('.');
      if (parts.length != 3) return fallback;
      String normalized = parts[1].replaceAll('-', '+').replaceAll('_', '/');
      // Pad base64 if needed
      while (normalized.length % 4 != 0) {
        normalized += '=';
      }
      final payload = utf8.decode(base64.decode(normalized));
      final map = jsonDecode(payload) as Map<String, dynamic>;
      final name = (map['name'] as String?)?.trim();
      if (name != null && name.isNotEmpty) return name;
    } catch (_) {}
    return fallback;
  }

  void _goToTransactions() {
    setState(() {
      _index = 2; // Transactions tab index
    });
  }

  @override
  Widget build(BuildContext context) {
    final greetingName = _nameFromToken(widget.token, widget.username);
    final views = [
      HomeView(username: greetingName, token: widget.token, onViewAllActivity: _goToTransactions),
      ItemsView(token: widget.token),
      TransactionsView(token: widget.token, role: widget.role), // pass role
      SettingsView(token: widget.token, role: widget.role),
    ];

    return Scaffold(
      appBar: AppBar(
        backgroundColor: const Color(0xFFFFF3E6),
        centerTitle: true,
        title: const SizedBox.shrink(),
        // Left: profile avatar + hello username, inset from edge
        leadingWidth: 150,
        leading: Padding(
          padding: const EdgeInsets.only(left: 8),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              CircleAvatar(
                radius: 14,
                backgroundColor: Colors.blue.withValues(alpha: 0.15),
                child: const Icon(Icons.person, color: Colors.black87, size: 16),
              ),
              const SizedBox(width: 8),
              Flexible(
                child: Text(
                  'Hello, $greetingName',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: Colors.black87),
                ),
              ),
            ],
          ),
        ),
        // Right: notification icon (slightly inset) and Logout for OWNER
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 8),
            child: IconButton(
              tooltip: 'Notifications',
              icon: const Icon(Icons.notifications_none, color: Colors.black87),
              onPressed: () {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Notifications coming soon')),
                );
              },
            ),
          ),
          if (widget.role == 'OWNER')
            Padding(
              padding: const EdgeInsets.only(right: 8),
              child: IconButton(
                tooltip: 'Logout',
                icon: const Icon(Icons.logout, color: Colors.black87),
                onPressed: () {
                  Navigator.pushAndRemoveUntil(
                    context,
                    MaterialPageRoute(builder: (_) => const LoginPage()),
                    (route) => false,
                  );
                },
              ),
            ),
        ],
      ),
      body: views[_index],
      bottomNavigationBar: NavigationBar(
        selectedIndex: _index,
        onDestinationSelected: (i) => setState(() => _index = i),
        elevation: 8,
        labelBehavior: NavigationDestinationLabelBehavior.alwaysShow,
        destinations: const [
          NavigationDestination(icon: Icon(Icons.home_outlined), selectedIcon: Icon(Icons.home), label: 'Home'),
          NavigationDestination(icon: Icon(Icons.inventory_2_outlined), selectedIcon: Icon(Icons.inventory_2), label: 'Items'),
          NavigationDestination(icon: Icon(Icons.receipt_long_outlined), selectedIcon: Icon(Icons.receipt_long), label: 'Transactions'),
          NavigationDestination(icon: Icon(Icons.settings_outlined), selectedIcon: Icon(Icons.settings), label: 'Settings'),
        ],
      ),
    );
  }
}

class HomeView extends StatefulWidget {
  final String username;
  final String token;
  final VoidCallback? onViewAllActivity;
  const HomeView({super.key, required this.username, required this.token, this.onViewAllActivity});

  @override
  State<HomeView> createState() => _HomeViewState();
}

class _HomeViewState extends State<HomeView> {
  final String baseUrl = ApiConfig.baseUrl;
  Map<String, dynamic>? summary;
  Map<String, dynamic>? periodSummary; // week/month/year -> {revenue, items}
  List<_HeatDay> heatmap = [];
  bool loadingSummary = true;
  bool loadingPeriodSummary = true;
  bool loadingHeatmap = true;
  // NEW: activity feed state
  List<_ActivityItem> activity = [];
  bool loadingActivity = true;

  @override
  void initState() {
    super.initState();
    _fetchSummary();
    _fetchPeriodSummary();
    _fetchHeatmap();
    _fetchActivity();
  }

  Future<void> _fetchSummary() async {
    setState(() => loadingSummary = true);
    try {
      final res = await http.get(
        Uri.parse('$baseUrl/reports/summary'),
        headers: {'Authorization': 'Bearer ${widget.token}'},
      );
      if (res.statusCode == 200) {
        summary = jsonDecode(res.body) as Map<String, dynamic>;
      }
    } catch (_) {}
    if (mounted) setState(() => loadingSummary = false);
  }

  Future<void> _fetchPeriodSummary() async {
    setState(() => loadingPeriodSummary = true);
    try {
      final headers = {'Authorization': 'Bearer ${widget.token}'};
      final weekReq = http.get(Uri.parse('$baseUrl/reports/summary?period=week'), headers: headers);
      final monthReq = http.get(Uri.parse('$baseUrl/reports/summary?period=month'), headers: headers);
      final yearReq = http.get(Uri.parse('$baseUrl/reports/summary?period=year'), headers: headers);
      final res = await Future.wait([weekReq, monthReq, yearReq]);

      final Map<String, dynamic> map = {};
      if (res[0].statusCode == 200) {
        map['week'] = jsonDecode(res[0].body) as Map<String, dynamic>;
      }
      if (res[1].statusCode == 200) {
        map['month'] = jsonDecode(res[1].body) as Map<String, dynamic>;
      }
      if (res[2].statusCode == 200) {
        map['year'] = jsonDecode(res[2].body) as Map<String, dynamic>;
      }
      if (map.isNotEmpty) periodSummary = map;
    } catch (_) {}
    if (mounted) setState(() => loadingPeriodSummary = false);
  }

  Future<void> _fetchHeatmap() async {
    setState(() => loadingHeatmap = true);
    try {
      final res = await http.get(
        Uri.parse('$baseUrl/reports/heatmap?days=90'),
        headers: {'Authorization': 'Bearer ${widget.token}'},
      );
      if (res.statusCode == 200) {
        final list = jsonDecode(res.body) as List;
        heatmap = list.map((e) => _HeatDay.fromJson(e)).toList();
      }
    } catch (_) {}
    if (mounted) setState(() => loadingHeatmap = false);
  }

  Future<void> _fetchActivity() async {
    setState(() => loadingActivity = true);
    try {
      final res = await http.get(
        Uri.parse('$baseUrl/activity?limit=200'),
        headers: {'Authorization': 'Bearer ${widget.token}'},
      );
      if (res.statusCode == 200) {
        final list = jsonDecode(res.body) as List;
        activity = list.map((e) => _ActivityItem.fromJson(e as Map<String, dynamic>)).toList();
      }
    } catch (_) {}
    if (mounted) setState(() => loadingActivity = false);
  }

  @override
  Widget build(BuildContext context) {
    // Derive latest 5 sales from the full activity list (backend is newest-first)
    final List<_ActivityItem> recentSales = activity
        .where((it) => it.action == 'SALE_RECORD')
        .take(5)
        .toList();

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _OverallSummaryCard(loading: loadingSummary, summary: summary),
          const SizedBox(height: 16),
          if (periodSummary != null)
            _PeriodKpiRow(summary: periodSummary!, loading: loadingPeriodSummary),
          const SizedBox(height: 16),
          Card(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(children: const [Icon(Icons.grid_on), SizedBox(width: 8), Text('Sales Activity')]),
                  const SizedBox(height: 12),
                  _HeatmapGrid(heatmap: heatmap, loading: loadingHeatmap),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),
          Card(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Row(
                        children: [
                          Icon(Icons.track_changes),
                          SizedBox(width: 8),
                          Text('Recent Activity'),
                        ],
                      ),
                      TextButton(
                        onPressed: widget.onViewAllActivity,
                        child: const Text('View All'),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  _ActivityList(items: recentSales, loading: loadingActivity),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _OverallSummaryCard extends StatelessWidget {
  final bool loading;
  final Map<String, dynamic>? summary;
  const _OverallSummaryCard({required this.loading, required this.summary});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    if (loading) {
      return const Center(child: CircularProgressIndicator());
    }
    final s = summary ?? const {};
    String money(num v) => v.toStringAsFixed(2);

    Widget row(IconData icon, Color color, String label, String value) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 6),
        child: Row(
          children: [
            Container(
              height: 32,
              width: 32,
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(icon, color: color, size: 18),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(label, style: TextStyle(color: scheme.onSurfaceVariant, fontSize: 13)),
                  const SizedBox(height: 2),
                  Text(
                    value,
                    style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w700),
                  ),
                ],
              ),
            ),
          ],
        ),
      );
    }

    return Card(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            row(Icons.inventory_2, Colors.blue, 'Total Products', '${s['totalProducts'] ?? 0}'),
            const Divider(height: 16),
            row(Icons.badge, Colors.purple, 'Total Cashiers', '${s['totalCashiers'] ?? 0}'),
            const Divider(height: 16),
            row(Icons.receipt_long, Colors.teal, 'Orders', '${s['orders'] ?? 0}'),
            const Divider(height: 16),
            row(Icons.attach_money, Colors.green, 'Revenue', 'ETB ${money((s['revenue'] ?? 0) as num)}'),
            const Divider(height: 16),
            row(Icons.shopping_cart_checkout, Colors.orange, 'Items Sold', '${s['items'] ?? 0}'),
          ],
        ),
      ),
    );
  }
}

class _PeriodKpiRow extends StatelessWidget {
  final Map<String, dynamic> summary;
  final bool loading;
  const _PeriodKpiRow({required this.summary, required this.loading});

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

  @override
  Widget build(BuildContext context) {
    final week = _period('week');
    final month = _period('month');
    final year = _period('year');

    final items = [
      {'label': 'Weekly Revenue', 'value': 'ETB ${_money(_num(week['revenue']))}'},
      {'label': 'Monthly Revenue', 'value': 'ETB ${_money(_num(month['revenue']))}'},
      {'label': 'Yearly Revenue', 'value': 'ETB ${_money(_num(year['revenue']))}'},
      {'label': 'Weekly Items Sold', 'value': '${_int(week['items'])}'},
      {'label': 'Monthly Items Sold', 'value': '${_int(month['items'])}'},
      {'label': 'Yearly Items Sold', 'value': '${_int(year['items'])}'},
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const Text(
          'Revenue Summary',
          style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
        ),
        const SizedBox(height: 8),
        LayoutBuilder(
          builder: (context, constraints) {
            final maxW = constraints.maxWidth;
            const gap = 10.0;
            final twoCols = maxW >= 500;
            final itemW = twoCols ? (maxW - gap) / 2 : maxW;
            const itemH = 64.0;

            return Wrap(
              spacing: gap,
              runSpacing: gap,
              children: items.map((it) {
                return SizedBox(
                  width: itemW,
                  height: itemH,
                  child: _StatPill(
                    icon: Icons.insights,
                    label: it['label'] as String,
                    value: loading ? '...' : (it['value'] as String),
                    color: Colors.indigo,
                  ),
                );
              }).toList(),
            );
          },
        ),
      ],
    );
  }
}

class _ActivityItem {
  final int id;
  final String actorName;
  final String actorRole;
  final String action;
  final String? productName;
  final Map<String, dynamic> details;
  final String createdAt;
  _ActivityItem({
    required this.id,
    required this.actorName,
    required this.actorRole,
    required this.action,
    required this.productName,
    required this.details,
    required this.createdAt,
  });
  factory _ActivityItem.fromJson(Map<String, dynamic> j) => _ActivityItem(
    id: j['id'] as int,
    actorName: (j['actor_name'] as String?) ?? (j['actor_email'] as String?) ?? 'Unknown',
    actorRole: (j['actor_role'] as String?) ?? '',
    action: j['action'] as String,
    productName: (j['product_name'] as String?) ?? ((j['details'] as Map?)?['name'] as String?),
    details: (j['details'] as Map?)?.cast<String, dynamic>() ?? {},
    createdAt: j['created_at'] as String,
  );
  String get label {
    switch (action) {
      case 'PRODUCT_ADD':
        return 'Added product';
      case 'PRODUCT_UPDATE':
        return 'Updated product';
      case 'PRODUCT_DELETE':
        return 'Deleted product';
      case 'SALE_RECORD':
        return 'Sale recorded';
      default:
        return action;
    }
  }
}

class _ActivityList extends StatelessWidget {
  final List<_ActivityItem> items;
  final bool loading;
  const _ActivityList({required this.items, required this.loading});

  IconData _icon(String action) {
    switch (action) {
      case 'PRODUCT_ADD':
        return Icons.add_box;
      case 'PRODUCT_UPDATE':
        return Icons.edit;
      case 'PRODUCT_DELETE':
        return Icons.delete_outline;
      case 'SALE_RECORD':
        return Icons.point_of_sale;
      default:
        return Icons.event_note;
    }
  }

  Color _color(BuildContext ctx, String action) {
    final s = Theme.of(ctx).colorScheme;
    switch (action) {
      case 'PRODUCT_ADD':
        return Colors.green;
      case 'PRODUCT_UPDATE':
        return s.primary;
      case 'PRODUCT_DELETE':
        return Colors.redAccent;
      case 'SALE_RECORD':
        return Colors.orange;
      default:
        return s.onSurfaceVariant;
    }
  }

  @override
  Widget build(BuildContext context) {
    if (loading) return const Center(child: CircularProgressIndicator());
    if (items.isEmpty) return const Text('No recent activity');
    return ListView.separated(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: items.length.clamp(0, 20),
      separatorBuilder: (_, __) => const Divider(height: 1),
      itemBuilder: (_, i) {
        final it = items[i];
        final displayName = it.productName ?? (it.details['name'] as String?);
        final subtitle = displayName != null
            ? '${it.label} • $displayName'
            : it.label;
        return ListTile(
          leading: CircleAvatar(
            backgroundColor: _color(context, it.action).withValues(alpha: 0.15),
            child: Icon(_icon(it.action), color: _color(context, it.action)),
          ),
          title: Text(subtitle),
          subtitle: Text('${it.actorName} (${it.actorRole}) • ${_formatDateTime(it.createdAt)}'),
        );
      },
    );
  }
}

String _formatDateTime(String iso) {
  try {
    final dt = DateTime.parse(iso).toLocal();
    String two(int n) => n.toString().padLeft(2, '0');
    return '${dt.year}-${two(dt.month)}-${two(dt.day)} ${two(dt.hour)}:${two(dt.minute)}:${two(dt.second)}';
  } catch (_) {
    return iso;
  }
}

class ItemsView extends StatefulWidget {
  final String token;
  const ItemsView({super.key, required this.token});
  @override
  State<ItemsView> createState() => _ItemsViewState();
}

class _ItemsViewState extends State<ItemsView> {
  final String baseUrl = ApiConfig.baseUrl;
  List<Product> products = [];
  bool loading = true;
  String query = '';

  @override
  void initState() {
    super.initState();
    _fetchProducts();
  }

  Future<void> _fetchProducts() async {
    setState(() => loading = true);
    try {
      final res = await http.get(
        Uri.parse('$baseUrl/products'),
        headers: {'Authorization': 'Bearer ${widget.token}'},
      );
      if (res.statusCode == 200) {
        final list = jsonDecode(res.body) as List;
        products = list.map((e) => Product.fromJson(e as Map<String, dynamic>)).toList();
      }
    } catch (_) {}
    if (mounted) setState(() => loading = false);
  }

  List<Product> get _filtered {
    final q = query.toLowerCase();
    if (q.isEmpty) return products;
    return products.where((p) => p.name.toLowerCase().contains(q)).toList();
  }

  void _showAddItemDialog() {
    final nameCtrl = TextEditingController();
    final priceCtrl = TextEditingController();
    final stockCtrl = TextEditingController();

    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Add Item'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(controller: nameCtrl, decoration: const InputDecoration(labelText: 'Name')),
            const SizedBox(height: 12),
            TextField(controller: priceCtrl, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'Price')),
            const SizedBox(height: 12),
            TextField(controller: stockCtrl, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'Stock')),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () async {
              final name = nameCtrl.text.trim();
              final price = double.tryParse(priceCtrl.text.trim()) ?? 0.0;
              final stock = int.tryParse(stockCtrl.text.trim()) ?? 0;
              if (name.isEmpty) return;
              try {
                final res = await http.post(
                  Uri.parse('$baseUrl/products'),
                  headers: {
                    'Authorization': 'Bearer ${widget.token}',
                    'Content-Type': 'application/json',
                  },
                  body: jsonEncode({'name': name, 'price': price, 'stock_quantity': stock}),
                );
                if (res.statusCode == 201) {
                  Navigator.pop(context);
                  await _fetchProducts();
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Item added')),
                  );
                } else {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Add failed: ${res.body}')),
                  );
                }
              } catch (e) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('Error: $e')),
                );
              }
            },
            child: const Text('Save'),
          ),
        ],
      ),
    );
  }

  void _showItemPreview(Product p) {
    final nameCtrl = TextEditingController(text: p.name);
    final priceCtrl = TextEditingController(text: p.price.toString());
    final stockCtrl = TextEditingController(text: p.stockQuantity.toString());

    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: Text(p.name),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Price: ${p.price.toStringAsFixed(2)}'),
            const SizedBox(height: 6),
            Text('Stock: ${p.stockQuantity}')
          ],
        ),
        actions: [
          // Edit first
          ElevatedButton(
            onPressed: () async {
              // Edit -> open inline edit form
              showDialog(
                context: context,
                builder: (_) => AlertDialog(
                  title: const Text('Edit Item'),
                  content: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      TextField(controller: nameCtrl, decoration: const InputDecoration(labelText: 'Name')),
                      const SizedBox(height: 12),
                      TextField(controller: priceCtrl, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'Price')),
                      const SizedBox(height: 12),
                      TextField(controller: stockCtrl, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'Stock')),
                    ],
                  ),
                  actions: [
                    TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
                    ElevatedButton(
                      onPressed: () async {
                        final name = nameCtrl.text.trim();
                        final price = double.tryParse(priceCtrl.text.trim()) ?? 0.0;
                        final stock = int.tryParse(stockCtrl.text.trim()) ?? p.stockQuantity;
                        try {
                          final res = await http.put(
                            Uri.parse('$baseUrl/products/${p.id}'),
                            headers: {
                              'Authorization': 'Bearer ${widget.token}',
                              'Content-Type': 'application/json',
                            },
                            body: jsonEncode({'name': name, 'price': price, 'stock_quantity': stock}),
                          );
                          if (res.statusCode == 200) {
                            Navigator.pop(context); // close edit
                            Navigator.pop(context); // close preview
                            await _fetchProducts();
                            ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Item updated')));
                          } else {
                            ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Update failed: ${res.body}')));
                          }
                        } catch (e) {
                          ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
                        }
                      },
                      child: const Text('Save'),
                    ),
                  ],
                ),
              );
            },
            child: const Text('Edit'),
          ),
          // Delete second
          TextButton(
            onPressed: () async {
              try {
                final res = await http.delete(
                  Uri.parse('$baseUrl/products/${p.id}'),
                  headers: {'Authorization': 'Bearer ${widget.token}'},
                );
                if (res.statusCode == 200) {
                  Navigator.pop(context);
                  await _fetchProducts();
                  ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Item deleted')));
                } else {
                  ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Delete failed: ${res.body}')));
                }
              } catch (e) {
                ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
              }
            },
            child: const Text('Delete'),
          ),
          // Close last
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Close')),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (loading) return const Center(child: CircularProgressIndicator());
    return RefreshIndicator(
      onRefresh: _fetchProducts,
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Row(
            children: [
              Expanded(
                child: TextField(
                  decoration: const InputDecoration(
                    hintText: 'Search products...',
                    prefixIcon: Icon(Icons.search),
                    filled: true,
                  ),
                  onChanged: (v) => setState(() => query = v),
                ),
              ),
              const SizedBox(width: 8),
              ElevatedButton.icon(
                onPressed: _showAddItemDialog,
                icon: const Icon(Icons.add),
                label: const Text('Add Item'),
              ),
            ],
          ),
          const SizedBox(height: 12),
          if (_filtered.isEmpty)
            const Center(child: Text('No products'))
          else
            ..._filtered.map((p) => Card(
              child: ListTile(
                leading: const Icon(Icons.inventory_2),
                title: Text(p.name),
                subtitle: Text('Price: ${p.price.toStringAsFixed(2)}'),
                onTap: () => _showItemPreview(p),
              ),
            )),
        ],
      ),
    );
  }
}



class TransactionsView extends StatefulWidget {
  final String token;
  final String? role; // optional role to enable activity feed for OWNER
  const TransactionsView({super.key, required this.token, this.role});

  @override
  State<TransactionsView> createState() => _TransactionsViewState();
}

class _TransactionsViewState extends State<TransactionsView> {
  final String baseUrl = ApiConfig.baseUrl;
  bool loading = true;
  List<_Sale> transactions = [];
  // NEW: activity feed
  List<_ActivityItem> activity = [];
  bool loadingActivity = false;
  bool get isOwner => (widget.role ?? '') == 'OWNER';

  @override
  void initState() {
    super.initState();
    _fetchTransactions();
    if (isOwner) _fetchActivity();
  }

  Future<void> _fetchTransactions() async {
    setState(() => loading = true);
    try {
      final res = await http.get(
        Uri.parse('$baseUrl/sales'),
        headers: {'Authorization': 'Bearer ${widget.token}'},
      );

      if (res.statusCode == 200) {
        final list = jsonDecode(res.body) as List;
        transactions = list.map((e) => _Sale.fromJson(e as Map<String, dynamic>)).toList();
      }
    } catch (e) {
      debugPrint('Transaction fetch error: $e');
    }
    if (mounted) setState(() => loading = false);
  }

  Future<void> _fetchActivity() async {
    setState(() => loadingActivity = true);
    try {
      final res = await http.get(
        Uri.parse('$baseUrl/activity?limit=200'),
        headers: {'Authorization': 'Bearer ${widget.token}'},
      );
      if (res.statusCode == 200) {
        final list = jsonDecode(res.body) as List;
        activity = list.map((e) => _ActivityItem.fromJson(e as Map<String, dynamic>)).toList();
      }
    } catch (e) {
      debugPrint('Activity fetch error: $e');
    }
    if (mounted) setState(() => loadingActivity = false);
  }

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        if (isOwner) ...[
          Card(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(children: const [Icon(Icons.track_changes), SizedBox(width: 8), Text('Recent Activity')]),
                  const SizedBox(height: 12),
                  _ActivityList(items: activity, loading: loadingActivity),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),
        ],
        if (loading)
          const Center(child: CircularProgressIndicator())
        else if (transactions.isEmpty)
          const Center(child: Text('No transactions found'))
        else
          ...List.generate(transactions.length, (i) {
            final t = transactions[i];
            final title = 'Sold ${t.quantity} × ${t.productName}';
            final subtitle = 'Cashier: ${t.cashierName ?? 'N/A'} • Total: ${t.totalPrice.toStringAsFixed(2)} • ${_formatDateTime(t.createdAt)}';
            return Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Card(
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                child: ListTile(
                  leading: const Icon(Icons.receipt_long),
                  title: Text(title, style: const TextStyle(fontWeight: FontWeight.w600)),
                  subtitle: Text(subtitle),
                  onTap: () {
                    showDialog(
                      context: context,
                      builder: (_) => AlertDialog(
                        title: Text('Sale #${t.id}'),
                        content: Column(
                          mainAxisSize: MainAxisSize.min,
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('Product: ${t.productName}'),
                            const SizedBox(height: 6),
                            Text('Cashier: ${t.cashierName ?? 'N/A'}'),
                            const SizedBox(height: 6),
                            Text('Quantity: ${t.quantity}'),
                            const SizedBox(height: 6),
                            Text('Unit price: ${t.unitPrice.toStringAsFixed(2)}'),
                            const SizedBox(height: 6),
                            Text('Total: ${t.totalPrice.toStringAsFixed(2)}'),
                            const SizedBox(height: 6),
                            Text('Date: ${_formatDateTime(t.createdAt)}'),
                          ],
                        ),
                        actions: [
                          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Close')),
                        ],
                      ),
                    );
                  },
                ),
              ),
            );
          }),
      ],
    );
  }
}


class _Sale {
  final int id;
  final int productId;
  final String productName;
  final int cashierId;
  final String? cashierName;
  final int quantity;
  final double unitPrice;
  final double totalPrice;
  final String createdAt;
  _Sale({
    required this.id,
    required this.productId,
    required this.productName,
    required this.cashierId,
    required this.cashierName,
    required this.quantity,
    required this.unitPrice,
    required this.totalPrice,
    required this.createdAt,
  });
  static double _toDouble(dynamic v) {
    if (v == null) return 0.0;
    if (v is num) return v.toDouble();
    if (v is String) return double.tryParse(v) ?? 0.0;
    return 0.0;
  }
  static int _toInt(dynamic v) {
    if (v == null) return 0;
    if (v is num) return v.toInt();
    if (v is String) return int.tryParse(v) ?? 0;
    return 0;
  }
  factory _Sale.fromJson(Map<String, dynamic> j) => _Sale(
    id: _toInt(j['id']),
    productId: _toInt(j['product_id']),
    productName: (j['product_name'] ?? '') as String,
    cashierId: _toInt(j['cashier_id']),
    cashierName: (j['cashier_name'] as String?) ?? (j['cashier_email'] as String?),
    quantity: _toInt(j['quantity']),
    unitPrice: _toDouble(j['unit_price']),
    totalPrice: _toDouble(j['total_price']),
    createdAt: (j['created_at'] ?? '') as String,
  );
}

class SettingsView extends StatefulWidget {
  final String token;
  final String role; // OWNER or CASHIER
  const SettingsView({super.key, required this.token, required this.role});
  @override
  State<SettingsView> createState() => _SettingsViewState();
}

class _SettingsViewState extends State<SettingsView> {
  final String baseUrl = ApiConfig.baseUrl;
  final TextEditingController _nameCtrl = TextEditingController();
  final TextEditingController _userCtrl = TextEditingController();
  final TextEditingController _passCtrl = TextEditingController();
  List<Map<String, dynamic>> cashiers = [];
  bool loading = true;

  @override
  void initState() {
    super.initState();
    _fetchCashiers();
  }

  Future<void> _fetchCashiers() async {
    if (widget.role != 'OWNER') { setState(() { loading = false; cashiers = []; }); return; }
    setState(() => loading = true);
    try {
      final res = await http.get(
        Uri.parse('$baseUrl/cashiers'),
        headers: {'Authorization': 'Bearer ${widget.token}'},
      );
      if (res.statusCode == 200) {
        final list = jsonDecode(res.body) as List;
        cashiers = list.map((e) => e as Map<String, dynamic>).toList();
      }
    } catch (_) {}
    if (mounted) setState(() => loading = false);
  }

    void _openAddCashierDialog() {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Add Cashier'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: _nameCtrl,
              decoration: const InputDecoration(
                labelText: 'Name',
                prefixIcon: Icon(Icons.person_outline),
                filled: true,
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _userCtrl,
              decoration: const InputDecoration(
                labelText: 'Email',
                prefixIcon: Icon(Icons.email_outlined),
                filled: true,
              ),
              keyboardType: TextInputType.emailAddress,
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _passCtrl,
              obscureText: true,
              decoration: const InputDecoration(
                labelText: 'Password',
                prefixIcon: Icon(Icons.lock_outline),
                filled: true,
              ),
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () async {
              final displayName = _nameCtrl.text.trim();
              final email = _userCtrl.text.trim();
              final password = _passCtrl.text.trim();
              if (displayName.isEmpty || email.isEmpty || password.isEmpty) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Please enter name, email and password')),
                );
                return;
              }
              try {
                final res = await http.post(
                  Uri.parse('$baseUrl/cashiers'),
                  headers: {
                    'Authorization': 'Bearer ${widget.token}',
                    'Content-Type': 'application/json',
                  },
                  body: jsonEncode({'name': displayName, 'email': email, 'password': password}),
                );
                if (res.statusCode == 201) {
                  _nameCtrl.clear();
                  _userCtrl.clear();
                  _passCtrl.clear();
                  Navigator.pop(context);
                  _fetchCashiers();
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Cashier created successfully')),
                  );
                } else {
                  final body = jsonDecode(res.body);
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Error: ${body['message']}')),
                  );
                }
              } catch (e) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Failed to create cashier')),
                );
              }
            },
            child: const Text('Create'),
          ),
        ],
      ),
    );
    }

    @override
    void dispose() {
    _nameCtrl.dispose();
    _userCtrl.dispose();
    _passCtrl.dispose();
    super.dispose();
    }

  @override
  Widget build(BuildContext context) {
    final isOwner = widget.role == 'OWNER';
    return Scaffold(
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Card(
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(children: const [Icon(Icons.account_circle_outlined), SizedBox(width: 8), Text('Account & Roles', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700))]),
                    const SizedBox(height: 12),
                    Text('Role: ${isOwner ? 'OWNER' : 'CASHIER'}'),
                    const SizedBox(height: 6),
                    const Text('OWNER can manage products, cashiers, and view full reports. CASHIER can sell and see own sales.'),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),
            Card(
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(children: const [Icon(Icons.badge_outlined), SizedBox(width: 8), Text('Cashier Management', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700))]),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Expanded(child: Text('Total cashiers: ${cashiers.length}')),
                        if (isOwner)
                          OutlinedButton.icon(
                            onPressed: _openAddCashierDialog,
                            icon: const Icon(Icons.person_add_alt_1),
                            label: const Text('Add Cashier'),
                          ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    SizedBox(
                      height: 360,
                      child: loading
                          ? const Center(child: CircularProgressIndicator())
                          : cashiers.isEmpty
                              ? const Center(child: Text('No cashiers found'))
                              : ListView.separated(
                                  itemCount: cashiers.length,
                                  separatorBuilder: (_, __) => const SizedBox(height: 8),
                                  itemBuilder: (_, i) {
                                    final c = cashiers[i];
                                    return Card(
                                      child: ListTile(
                                        leading: const Icon(Icons.person_outline),
                                        title: Text((c['name'] ?? '') as String),
                                        subtitle: Text('Email: ${(c['email'] ?? '') as String}\nCreated at: ${_formatDateTime((c['created_at'] ?? '') as String)}'),
                                        trailing: isOwner ? IconButton(
                                          icon: const Icon(Icons.refresh),
                                          onPressed: _fetchCashiers,
                                          tooltip: 'Refresh',
                                        ) : null,
                                      ),
                                    );
                                  },
                                ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
      floatingActionButton: isOwner
          ? FloatingActionButton.extended(
              onPressed: _openAddCashierDialog,
              icon: const Icon(Icons.add),
              label: const Text('Cashier'),
            )
          : null,
    );
  }
}

/* ===== Home Summary: SE-friendly stat pills ===== */
class _SummaryRow extends StatelessWidget {
  final bool loading;
  final Map<String, dynamic>? summary;
  const _SummaryRow({required this.loading, required this.summary});

  @override
  Widget build(BuildContext context) {
    if (loading) return const Center(child: CircularProgressIndicator());
    final s = summary ?? const {};
    String money(num v) => v.toStringAsFixed(2);

    final items = [
      {'icon': Icons.inventory_2, 'label': 'Total Products', 'value': '${s['totalProducts'] ?? 0}', 'color': Colors.blue},
      {'icon': Icons.badge, 'label': 'Total Cashiers', 'value': '${s['totalCashiers'] ?? 0}', 'color': Colors.purple},
      {'icon': Icons.receipt_long, 'label': 'Orders', 'value': '${s['orders'] ?? 0}', 'color': Colors.teal},
      {'icon': Icons.attach_money, 'label': 'Revenue', 'value': 'ETB ${money((s['revenue'] ?? 0) as num)}', 'color': Colors.green},
      {'icon': Icons.shopping_cart_checkout, 'label': 'Items Sold', 'value': '${s['items'] ?? 0}', 'color': Colors.orange},
    ];

    return LayoutBuilder(
      builder: (context, constraints) {
        final maxW = constraints.maxWidth;
        const gap = 10.0;
        final twoCols = maxW >= 500; // force single column under 500px
        final itemW = twoCols ? (maxW - gap) / 2 : maxW;
        const itemH = 72.0;

        return Wrap(
          spacing: gap,
          runSpacing: gap,
          children: items.map((it) {
            return SizedBox(
              width: itemW,
              height: itemH,
              child: _StatPill(
                icon: it['icon'] as IconData,
                label: it['label'] as String,
                value: it['value'] as String,
                color: it['color'] as Color,
              ),
            );
          }).toList(),
        );
      },
    );
  }
}

class _StatPill extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final Color color;
  const _StatPill({required this.icon, required this.label, required this.value, required this.color});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Card(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        child: Row(
          children: [
            Container(
              height: 28,
              width: 28,
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(9),
              ),
              child: Icon(icon, color: color, size: 16),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: scheme.onSurfaceVariant,
                      fontWeight: FontWeight.w600,
                      fontSize: 13,
                      height: 1.0,
                    ),
                  ),
                  const SizedBox(height: 2),
                  FittedBox(
                    fit: BoxFit.scaleDown,
                    alignment: Alignment.centerLeft,
                    child: Text(
                      value,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                        height: 1.0,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _HeatDay {
  final String date; // YYYY-MM-DD
  final int count;
  final double revenue;
  const _HeatDay({required this.date, required this.count, required this.revenue});
  factory _HeatDay.fromJson(Map<String, dynamic> j) => _HeatDay(
    date: j['date'] as String,
    count: (j['count'] as num).toInt(),
    revenue: (j['revenue'] as num).toDouble(),
  );
}

class _HeatmapGrid extends StatelessWidget {
  final List<_HeatDay> heatmap;
  final bool loading;
  const _HeatmapGrid({super.key, required this.heatmap, required this.loading});

  @override
  Widget build(BuildContext context) {
    if (loading) return const Center(child: CircularProgressIndicator());
    if (heatmap.isEmpty) return const Text('No sales data');

    final byDate = {for (final d in heatmap) d.date: d};
    final today = DateTime.now();
    final start = today.subtract(const Duration(days: 7 * 12));
    final days = <DateTime>[];
    for (int i = 0; i < 7 * 12; i++) {
      days.add(start.add(Duration(days: i)));
    }
    final weeks = <List<DateTime>>[];
    for (int i = 0; i < days.length; i += 7) {
      weeks.add(days.sublist(i, i + 7));
    }

    Color cellColor(int count) {
      if (count <= 0) return Colors.grey.shade200;
      if (count < 3) return Colors.green.shade200;
      if (count < 6) return Colors.green.shade400;
      return Colors.green.shade700;
    }

    String fmt(DateTime d) => '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';
    String human(DateTime d) => '${d.day}-${d.month}-${d.year}';

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: weeks.map((week) {
          return Padding(
            padding: const EdgeInsets.only(right: 6),
            child: Column(
              children: week.map((d) {
                final key = fmt(d);
                final day = byDate[key];
                final count = day?.count ?? 0;
                return Tooltip(
                  message: '${day?.count ?? 0} sales on ${human(d)}',
                  child: Container(
                    margin: const EdgeInsets.symmetric(vertical: 2),
                    width: 16,
                    height: 16,
                    decoration: BoxDecoration(
                      color: cellColor(count),
                      borderRadius: BorderRadius.circular(3),
                    ),
                  ),
                );
              }).toList(),
            ),
          );
        }).toList(),
      ),
    );
  }
}
