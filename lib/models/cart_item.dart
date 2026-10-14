import 'product.dart';

class CartItem {
  final Product product;
  int quantity;
  String? note;
  String? selectedOption;

  CartItem({
    required this.product,
    this.quantity = 1,
    this.note,
    this.selectedOption,
  });

  double get subtotal => product.sellPrice * quantity;
  double get totalProfit => (product.sellPrice - product.buyPrice) * quantity;

  CartItem copyWith({
    Product? product,
    int? quantity,
    String? note,
    String? selectedOption,
  }) {
    return CartItem(
      product: product ?? this.product,
      quantity: quantity ?? this.quantity,
      note: note ?? this.note,
      selectedOption: selectedOption ?? this.selectedOption,
    );
  }
}
