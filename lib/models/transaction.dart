class _Transaction {
  final int id;
  final String type;
  final String productName;
  final int quantity;
  final String context;
  final String date;

  _Transaction({
    required this.id,
    required this.type,
    required this.productName,
    required this.quantity,
    required this.context,
    required this.date,
  });

  factory _Transaction.fromJson(Map<String, dynamic> j) {
    final type = j['type'];

    String contextText;
    if (type == 'SALE') {
      contextText = 'Customer: ${j['cashier_name']}';
    } else if (type == 'PRODUCT_ADD') {
      contextText = 'New product added';
    } else if (type == 'PRODUCT_UPDATE') {
      contextText = 'Product updated';
    } else {
      contextText = 'Inventory change';
    }

    return _Transaction(
      id: j['id'],
      type: type,
      productName: j['product_name'],
      quantity: j['quantity'],
      context: contextText,
      date: j['created_at'],
    );
  }
}
