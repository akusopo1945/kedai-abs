import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/constants/app_constants.dart';
import '../../core/theme/app_theme.dart';
import '../../core/utils/currency_formatter.dart';
import '../../providers/pos_provider.dart';
import '../../widgets/empty_state.dart';
import '../../widgets/product_card.dart';
import 'checkout_sheet.dart';

class PosScreen extends StatelessWidget {
  const PosScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final pos = context.watch<PosProvider>();

    return Scaffold(
      backgroundColor: AppTheme.background,
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              pos.storeProfile.name,
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w700,
                color: AppTheme.textPrimary,
              ),
            ),
            const Text(
              'Mesin Kasir Utama',
              style: TextStyle(
                fontSize: 11,
                color: AppTheme.textSecondary,
                fontWeight: FontWeight.w400,
              ),
            ),
          ],
        ),
        actions: [
          if (pos.cartCount > 0)
            IconButton(
              icon: const Icon(Icons.delete_sweep_outlined, color: AppTheme.danger),
              tooltip: 'Kosongkan Keranjang',
              onPressed: () {
                _showClearCartDialog(context, pos);
              },
            ),
        ],
      ),
      body: Column(
        children: [
          // Search & Filter Bar
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
            child: TextField(
              onChanged: pos.setSearchQuery,
              decoration: InputDecoration(
                hintText: 'Cari produk atau scan SKU...',
                prefixIcon: const Icon(Icons.search, size: 20, color: AppTheme.textMuted),
                suffixIcon: pos.searchQuery.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.clear, size: 18),
                        onPressed: () => pos.setSearchQuery(''),
                      )
                    : null,
                filled: true,
                fillColor: AppTheme.surface,
              ),
            ),
          ),

          // Categories Horizontal List
          SizedBox(
            height: 38,
            child: ListView.separated(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              scrollDirection: Axis.horizontal,
              itemCount: AppConstants.defaultCategories.length,
              separatorBuilder: (_, __) => const SizedBox(width: 8),
              itemBuilder: (context, index) {
                final category = AppConstants.defaultCategories[index];
                final isSelected = pos.selectedCategory == category;

                return ChoiceChip(
                  label: Text(category),
                  selected: isSelected,
                  onSelected: (_) => pos.selectCategory(category),
                  selectedColor: AppTheme.primary,
                  backgroundColor: AppTheme.surface,
                  labelStyle: TextStyle(
                    fontSize: 12,
                    fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                    color: isSelected ? Colors.white : AppTheme.textSecondary,
                  ),
                  side: BorderSide(
                    color: isSelected ? AppTheme.primary : AppTheme.border,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(20),
                  ),
                  showCheckmark: false,
                );
              },
            ),
          ),
          const SizedBox(height: 12),

          // Product Grid
          Expanded(
            child: pos.isLoading
                ? const Center(child: CircularProgressIndicator())
                : pos.products.isEmpty
                    ? const EmptyState(
                        icon: Icons.inventory_2_outlined,
                        title: 'Tidak Ada Produk',
                        message: 'Belum ada produk untuk kategori ini atau kata kunci yang dicari.',
                      )
                    : GridView.builder(
                        padding: const EdgeInsets.fromLTRB(16, 0, 16, 80),
                        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                          crossAxisCount: 2,
                          crossAxisSpacing: 12,
                          mainAxisSpacing: 12,
                          childAspectRatio: 0.88,
                        ),
                        itemCount: pos.products.length,
                        itemBuilder: (context, index) {
                          final product = pos.products[index];
                          final cartQty = pos.cart[product.id]?.quantity ?? 0;

                          return ProductCard(
                            product: product,
                            cartQuantity: cartQty,
                            onAdd: () => pos.addToCart(product),
                            onRemove: () => pos.decreaseQuantity(product.id!),
                          );
                        },
                      ),
          ),
        ],
      ),

      // Floating Bottom Cart Bar
      bottomNavigationBar: pos.cartCount > 0
          ? Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: BoxDecoration(
                color: AppTheme.surface,
                border: const Border(top: BorderSide(color: AppTheme.border)),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.06),
                    blurRadius: 10,
                    offset: const Offset(0, -3),
                  ),
                ],
              ),
              child: SafeArea(
                child: Row(
                  children: [
                    // Cart Info & Badge
                    InkWell(
                      onTap: () => _showCartDetails(context, pos),
                      borderRadius: BorderRadius.circular(10),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
                        child: Row(
                          children: [
                            Badge(
                              label: Text('${pos.cartCount}'),
                              backgroundColor: AppTheme.accent,
                              child: const Icon(
                                Icons.shopping_bag_outlined,
                                color: AppTheme.primary,
                                size: 26,
                              ),
                            ),
                            const SizedBox(width: 14),
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const Text(
                                  'Total Tagihan',
                                  style: TextStyle(
                                    fontSize: 11,
                                    color: AppTheme.textSecondary,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                                Text(
                                  CurrencyFormatter.format(pos.cartTotal),
                                  style: const TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.w700,
                                    color: AppTheme.textPrimary,
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ),
                    const Spacer(),
                    // Checkout Button
                    ElevatedButton(
                      onPressed: () {
                        showModalBottomSheet(
                          context: context,
                          isScrollControlled: true,
                          builder: (_) => const CheckoutSheet(),
                        );
                      },
                      style: ElevatedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 12),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      child: const Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            'Bayar',
                            style: TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          SizedBox(width: 6),
                          Icon(Icons.arrow_forward, size: 16),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            )
          : null,
    );
  }

  void _showCartDetails(BuildContext context, PosProvider pos) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (context) {
        return Container(
          padding: const EdgeInsets.all(20),
          height: MediaQuery.of(context).size.height * 0.65,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Keranjang Belanja (${pos.cartCount})',
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                      color: AppTheme.textPrimary,
                    ),
                  ),
                  TextButton(
                    onPressed: () {
                      pos.clearCart();
                      Navigator.pop(context);
                    },
                    child: const Text('Hapus Semua', style: TextStyle(color: AppTheme.danger)),
                  ),
                ],
              ),
              const Divider(color: AppTheme.border),
              Expanded(
                child: ListView.separated(
                  itemCount: pos.cartItems.length,
                  separatorBuilder: (_, __) => const Divider(color: AppTheme.borderSubtle),
                  itemBuilder: (context, index) {
                    final item = pos.cartItems[index];
                    return ListTile(
                      contentPadding: EdgeInsets.zero,
                      title: Text(
                        item.product.name,
                        style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
                      ),
                      subtitle: Text(CurrencyFormatter.format(item.product.sellPrice)),
                      trailing: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          IconButton(
                            icon: const Icon(Icons.remove_circle_outline, size: 20),
                            onPressed: () => pos.decreaseQuantity(item.product.id!),
                          ),
                          Text(
                            '${item.quantity}',
                            style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14),
                          ),
                          IconButton(
                            icon: const Icon(Icons.add_circle_outline, size: 20, color: AppTheme.primary),
                            onPressed: () => pos.addToCart(item.product),
                          ),
                        ],
                      ),
                    );
                  },
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  void _showClearCartDialog(BuildContext context, PosProvider pos) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Kosongkan Keranjang?'),
        content: const Text('Semua produk di dalam keranjang akan dihapus.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Batal'),
          ),
          ElevatedButton(
            onPressed: () {
              pos.clearCart();
              Navigator.pop(ctx);
            },
            style: ElevatedButton.styleFrom(backgroundColor: AppTheme.danger),
            child: const Text('Kosongkan'),
          ),
        ],
      ),
    );
  }
}
