import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import '../models/product.dart';
import 'login_page.dart';
import '../config/api.dart';

class DashboardPage extends StatefulWidget {
  final String username;
  final String token;

  const DashboardPage({
    super.key,
    required this.username,
    required this.token,
  });

  @override
  State<DashboardPage> createState() => _DashboardPageState();
}

/* ================= EXTRA UI META ================= */

class ProductMeta {
  String priority; // optional, can represent category or status
  String? notes; // optional description or notes

  ProductMeta({this.priority = 'medium', this.notes});
}

class _DashboardPageState extends State<DashboardPage> {
  final List<Product> products = [];
  final Map<int, ProductMeta> meta = {};

  final TextEditingController controller = TextEditingController();
  final TextEditingController searchController = TextEditingController();

  String filter = 'all';
  final String baseUrl = ApiConfig.baseUrl;

  Map<String, dynamic>? summary; // {totalProducts,totalCashiers,revenue,orders,items}
  List<_HeatDay> heatmap = []; // [{date,count,revenue} -> model]
  bool loadingSummary = true;
  bool loadingHeatmap = true;

  List<_ActivityItem> activity = [];
  bool loadingActivity = true;

  /* ================= FETCH ================= */

  Future<void> fetchProducts() async {
    try {
      final res = await http.get(
        Uri.parse('$baseUrl/products'),
        headers: {'Authorization': 'Bearer ${widget.token}'},
      );

      if (res.statusCode == 200) {
        final data = jsonDecode(res.body) as List;

        setState(() {
          products.clear();
          meta.clear();

          for (final t in data) {
            final product = Product.fromJson(t);
            products.add(product);

            meta[product.id] = ProductMeta(
              priority: t['priority'] ?? 'medium',
              notes: (t['notes'] as String?)?.trim(),
            );
          }
        });
      }
    } catch (e) {
      debugPrint('Fetch error: $e');
    }
  }

  Future<void> fetchSummary() async {
    setState(() => loadingSummary = true);
    try {
      final res = await http.get(
        Uri.parse('$baseUrl/reports/summary'),
        headers: {'Authorization': 'Bearer ${widget.token}'},
      );
      if (res.statusCode == 200) {
        summary = jsonDecode(res.body) as Map<String, dynamic>;
      }
    } catch (e) {
      debugPrint('summary error: $e');
    } finally {
      if (mounted) setState(() => loadingSummary = false);
    }
  }

  Future<void> fetchHeatmap() async {
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
    } catch (e) {
      debugPrint('heatmap error: $e');
    } finally {
      if (mounted) setState(() => loadingHeatmap = false);
    }
  }

  Future<void> fetchActivity() async {
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
      debugPrint('activity error: $e');
    } finally {
      if (mounted) setState(() => loadingActivity = false);
    }
  }

  /* ================= ADD ================= */

  Future<void> addProduct() async {
    final name = controller.text.trim();
    if (name.isEmpty) return;

    try {
      final res = await http.post(
        Uri.parse('$baseUrl/products'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer ${widget.token}',
        },
        body: jsonEncode({
          'name': name,
          'price': 0.0,
          'stock_quantity': 0,
          'priority': 'medium',
          'notes': '',
        }),
      );

      if (res.statusCode == 201) {
        controller.clear();
        await fetchProducts();
      }
    } catch (e) {
      debugPrint('Add error: $e');
    }
  }

  /* ================= UPDATE ================= */

  Future<void> updateProduct(
      Product product,
      String name,
      double price,
      int stock,
      String priority,
      String? notes,
      ) async {
    try {
      await http.put(
        Uri.parse('$baseUrl/products/${product.id}'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer ${widget.token}',
        },
        body: jsonEncode({
          'name': name,
          'price': price,
          'stock_quantity': stock,
          'priority': priority,
          'notes': notes ?? '',
        }),
      );

      await fetchProducts();

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Product updated successfully ✅'),
          backgroundColor: Colors.green,
        ),
      );
    } catch (e) {
      debugPrint('Update error: $e');
    }
  }

  /* ================= DELETE ================= */

  Future<void> deleteProduct(Product product) async {
    try {
      await http.delete(
        Uri.parse('$baseUrl/products/${product.id}'),
        headers: {'Authorization': 'Bearer ${widget.token}'},
      );

      await fetchProducts();
      await fetchActivity();
    } catch (e) {
      debugPrint('Delete error: $e');
    }
  }

  /* ================= PREVIEW DIALOG ================= */

  void showProductPreview(Product product) {
    final m = meta[product.id] ?? ProductMeta();
    final scheme = Theme.of(context).colorScheme;

    showDialog(
      context: context,
      builder: (_) => Dialog(
        backgroundColor: scheme.surface.withValues(alpha: 0.95),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 20, 20, 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header
              Row(
                children: [
                  Icon(Icons.inventory_2, color: scheme.primary),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      product.name,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 14),

              // Stock & Price
              Row(
                children: [
                  const Icon(Icons.attach_money, size: 18),
                  const SizedBox(width: 6),
                  Text('${product.price.toStringAsFixed(2)}'),
                  const SizedBox(width: 20),
                  const Icon(Icons.storage, size: 18),
                  const SizedBox(width: 6),
                  Text('Stock: ${product.stockQuantity}'),
                ],
              ),

              if ((m.notes?.isNotEmpty ?? false)) ...[
                const SizedBox(height: 12),
                Row(
                  children: [
                    Icon(Icons.notes, size: 18, color: scheme.onSurfaceVariant),
                    const SizedBox(width: 8),
                    const Text('Notes', style: TextStyle(fontWeight: FontWeight.w600)),
                  ],
                ),
                const SizedBox(height: 6),
                Text(m.notes!, style: TextStyle(color: scheme.onSurface)),
              ],

              const SizedBox(height: 18),
              // Action buttons: Edit, Delete, Close
              Row(
                children: [
                  // Edit first
                  Expanded(
                    child: OutlinedButton.icon(
                      icon: const Icon(Icons.edit, size: 18),
                      label: const Text('Edit'),
                      style: OutlinedButton.styleFrom(
                        shape: const StadiumBorder(),
                        foregroundColor: scheme.onSurface,
                        side: BorderSide(color: scheme.outlineVariant),
                        padding: const EdgeInsets.symmetric(vertical: 12),
                      ),
                      onPressed: () {
                        Navigator.pop(context);
                        showEditDialog(product);
                      },
                    ),
                  ),
                  const SizedBox(width: 10),
                  // Delete second
                  Expanded(
                    child: OutlinedButton.icon(
                      icon: const Icon(Icons.delete_outline, size: 18, color: Colors.redAccent),
                      label: const Text('Delete'),
                      style: OutlinedButton.styleFrom(
                        shape: const StadiumBorder(),
                        foregroundColor: Colors.redAccent,
                        side: const BorderSide(color: Colors.redAccent),
                        padding: const EdgeInsets.symmetric(vertical: 12),
                      ),
                      onPressed: () {
                        Navigator.pop(context);
                        deleteProduct(product);
                      },
                    ),
                  ),
                  const SizedBox(width: 10),
                  // Close last
                  Expanded(
                    child: OutlinedButton(
                      style: OutlinedButton.styleFrom(
                        shape: const StadiumBorder(),
                        foregroundColor: scheme.onSurface,
                        side: BorderSide(color: scheme.outlineVariant),
                        padding: const EdgeInsets.symmetric(vertical: 12),
                      ),
                      onPressed: () => Navigator.pop(context),
                      child: const Text('Close'),
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

  /* ================= EDIT DIALOG ================= */

  void showEditDialog(Product product) {
    final nameCtrl = TextEditingController(text: product.name);
    final priceCtrl = TextEditingController(text: product.price.toString());
    final stockCtrl = TextEditingController(text: product.stockQuantity.toString());
    String priority = meta[product.id]?.priority ?? 'medium';
    final notesCtrl = TextEditingController(text: meta[product.id]?.notes ?? '');

    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Edit Product'),
        content: StatefulBuilder(
          builder: (context, setStateDialog) {
            return Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(controller: nameCtrl, decoration: const InputDecoration(labelText: 'Name')),
                const SizedBox(height: 12),
                TextField(controller: priceCtrl, decoration: const InputDecoration(labelText: 'Price'), keyboardType: TextInputType.number),
                const SizedBox(height: 12),
                TextField(controller: stockCtrl, decoration: const InputDecoration(labelText: 'Stock'), keyboardType: TextInputType.number),
                const SizedBox(height: 12),
                _PrioritySelector(onChanged: (p) => priority = p),
                const SizedBox(height: 12),
                TextField(
                  controller: notesCtrl,
                  maxLines: 3,
                  decoration: const InputDecoration(
                    labelText: 'Notes',
                    alignLabelWithHint: true,
                    border: OutlineInputBorder(),
                  ),
                ),
              ],
            );
          },
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              updateProduct(
                product,
                nameCtrl.text.trim(),
                double.tryParse(priceCtrl.text.trim()) ?? 0.0,
                int.tryParse(stockCtrl.text.trim()) ?? 0,
                priority,
                notesCtrl.text.trim(),
              );
            },
            child: const Text('Save'),
          ),
        ],
      ),
    );
  }

  /* ================= LIFE CYCLE ================= */

  @override
  void initState() {
    super.initState();
    fetchProducts();
    fetchSummary();
    fetchHeatmap();
    fetchActivity();
  }

  @override
  void dispose() {
    controller.dispose();
    searchController.dispose();
    super.dispose();
  }

  /* ================= UI (UNCHANGED) ================= */

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final filtered = products.where((p) {
      final q = searchController.text.toLowerCase();
      final matchText = q.isEmpty || p.name.toLowerCase().contains(q);
      return matchText;
    }).toList();

    return Scaffold(
      appBar: AppBar(
        backgroundColor: const Color(0xFFFFF3E6),
        centerTitle: true,
        title: const SizedBox.shrink(),
        // Left: profile avatar + hello username (inset from edge)
        leadingWidth: 140,
        leading: Padding(
          padding: const EdgeInsets.only(left: 8),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              CircleAvatar(
                radius: 19,
                backgroundColor: Colors.blue.withValues(alpha: 0.15),
                child: const Icon(Icons.person, color: Colors.black87, size: 22),
              ),
              const SizedBox(width: 8),
              Flexible(
                child: Text(
                  'Hello, ${widget.username}',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: Colors.black87),
                ),
              ),
            ],
          ),
        ),
        // Right: notification icon (slightly inset)
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
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _SummaryRow(loading: loadingSummary, summary: summary),
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
                    Row(children: const [Icon(Icons.track_changes), SizedBox(width: 8), Text('Recent Activity')]),
                    const SizedBox(height: 12),
                    _ActivityList(items: activity, loading: loadingActivity),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),
            // ... rest of your body
          ],
        ),
      ),
    );
  }
}

/* ===== Summary Row Widgets ===== */
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
      {'icon': Icons.attach_money, 'label': 'Revenue', 'value': '\ETB${money((s['revenue'] ?? 0) as num)}', 'color': Colors.green},
      {'icon': Icons.shopping_cart_checkout, 'label': 'Items Sold', 'value': '${s['items'] ?? 0}', 'color': Colors.orange},
    ];

    return LayoutBuilder(
      builder: (context, constraints) {
        final maxW = constraints.maxWidth;
        const gap = 10.0;
        // iPhone SE and similar: force single column under 500px
        final twoCols = maxW >= 500;
        final itemW = twoCols ? (maxW - gap) / 2 : maxW;
        const itemH = 72.0; // tighter height for small screens

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
    return Material(
      color: scheme.surface,
      borderRadius: BorderRadius.circular(14),
      elevation: 2,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: scheme.outlineVariant),
        ),
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

/* ===== Heatmap models and grid ===== */
class _HeatDay {
  final String date; // YYYY-MM-DD
  final int count;
  final double revenue;
  _HeatDay({required this.date, required this.count, required this.revenue});
  factory _HeatDay.fromJson(Map<String, dynamic> j) => _HeatDay(
    date: j['date'] as String,
    count: (j['count'] as num).toInt(),
    revenue: (j['revenue'] as num).toDouble(),
  );
}

class _HeatmapGrid extends StatelessWidget {
  final List<_HeatDay> heatmap;
  final bool loading;
  const _HeatmapGrid({required this.heatmap, required this.loading});

  @override
  Widget build(BuildContext context) {
    if (loading) return const Center(child: CircularProgressIndicator());
    if (heatmap.isEmpty) {
      return const Text('No sales data');
    }
    final byDate = { for (final d in heatmap) d.date: d };
    final today = DateTime.now();
    final start = today.subtract(const Duration(days: 7*12));
    final days = <DateTime>[];
    for (int i = 0; i < 7*12; i++) {
      days.add(start.add(Duration(days: i)));
    }
    final weeks = <List<DateTime>>[];
    for (int i = 0; i < days.length; i += 7) {
      weeks.add(days.sublist(i, i+7));
    }

    Color cellColor(int count) {
      if (count <= 0) return Colors.grey.shade200;
      if (count < 3) return Colors.green.shade200;
      if (count < 6) return Colors.green.shade400;
      return Colors.green.shade700;
    }

    String fmt(DateTime d) => '${d.year}-${d.month.toString().padLeft(2,'0')}-${d.day.toString().padLeft(2,'0')}';
    String human(DateTime d) => '${d.day}-${d.month}-${d.year}';

    return LayoutBuilder(
      builder: (context, constraints) {
        final maxH = 180.0; // cap heatmap area height for small screens
        return SizedBox(
          height: maxH,
          child: SingleChildScrollView(
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
          ),
        );
      },
    );
  }
}

/* ================= SMALL WIDGETS ================= */

class _EmptyState extends StatelessWidget {
  final ColorScheme colorScheme;
  const _EmptyState({required this.colorScheme});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Text(
        'No products yet 👀',
        style: TextStyle(color: colorScheme.outline, fontSize: 18),
      ),
    );
  }
}

class _PriorityTag extends StatelessWidget {
  final String priority;
  const _PriorityTag({required this.priority});

  @override
  Widget build(BuildContext context) {
    final color = priority == 'high'
        ? Colors.red
        : priority == 'low'
        ? Colors.green
        : Colors.orange;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(12)),
      child: Text(priority, style: const TextStyle(color: Colors.white)),
    );
  }
}

class _PrioritySelector extends StatelessWidget {
  final ValueChanged<String> onChanged;
  const _PrioritySelector({required this.onChanged});

  @override
  Widget build(BuildContext context) {
    return DropdownButtonFormField<String>(
      initialValue: 'medium',
      decoration: const InputDecoration(
        prefixIcon: Icon(Icons.flag_outlined),
        labelText: 'Priority',
        border: OutlineInputBorder(),
      ),
      items: const ['low', 'medium', 'high']
          .map(
            (e) => DropdownMenuItem(
          value: e,
          child: Text(e[0].toUpperCase() + e.substring(1)),
        ),
      )
          .toList(),
      onChanged: (v) => v != null ? onChanged(v) : null,
    );
  }
}

class _ActivityItem {
  final int id;
  final String actorName;
  final String actorRole;
  final String action; // PRODUCT_ADD/UPDATE/DELETE/SALE_RECORD
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
    actorName: (j['actor_name'] as String?) ?? 'Unknown',
    actorRole: (j['actor_role'] as String?) ?? '',
    action: j['action'] as String,
    productName: j['product_name'] as String?,
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
        final subtitle = it.productName != null
            ? '${it.label} • ${it.productName}'
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
