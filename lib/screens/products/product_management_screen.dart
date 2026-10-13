import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/theme/app_theme.dart';
import '../../core/utils/currency_formatter.dart';
import '../../models/product.dart';
import '../../providers/pos_provider.dart';
import '../../widgets/empty_state.dart';
import 'product_form_dialog.dart';

class ProductManagementScreen extends StatelessWidget {
  const ProductManagementScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final pos = context.watch<PosProvider>();

    return Scaffold(
      backgroundColor: AppTheme.background,
      appBar: AppBar(
        title: const Text('Kelola Produk & Stok'),
        actions: [
          IconButton(
            icon: const Icon(Icons.add_circle_outline, color: AppTheme.primary),
            tooltip: 'Tambah Produk',
            onPressed: () => _openProductForm(context, pos, null),
          ),
        ],
      ),
      body: pos.products.isEmpty
          ? EmptyState(
              icon: Icons.inventory_2_outlined,
              title: 'Belum Ada Produk',
              message: 'Tambahkan produk pertama untuk mulai berjualan.',
              action: ElevatedButton.icon(
                icon: const Icon(Icons.add, size: 18),
                label: const Text('Tambah Produk'),
                onPressed: () => _openProductForm(context, pos, null),
              ),
            )
          : ListView.separated(
              padding: const EdgeInsets.all(16),
              itemCount: pos.products.length,
              separatorBuilder: (_, __) => const SizedBox(height: 10),
              itemBuilder: (context, index) {
                final product = pos.products[index];
                final isLowStock = product.stock <= 5;

                return Container(
                  decoration: BoxDecoration(
                    color: AppTheme.surface,
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: AppTheme.border),
                  ),
                  child: ListTile(
                    contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    title: Row(
                      children: [
                        Expanded(
                          child: Text(
                            product.name,
                            style: const TextStyle(
                              fontWeight: FontWeight.w600,
                              fontSize: 14,
                              color: AppTheme.textPrimary,
                            ),
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                          decoration: BoxDecoration(
                            color: isLowStock
                                ? AppTheme.danger.withOpacity(0.1)
                                : AppTheme.borderSubtle,
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text(
                            'Stok: ${product.stock}',
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                              color: isLowStock ? AppTheme.danger : AppTheme.textSecondary,
                            ),
                          ),
                        ),
                      ],
                    ),
                    subtitle: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const SizedBox(height: 4),
                        Text(
                          'Kategori: ${product.category}${product.sku != null ? ' • SKU: ${product.sku}' : ''}',
                          style: const TextStyle(fontSize: 12, color: AppTheme.textSecondary),
                        ),
                        const SizedBox(height: 4),
                        Row(
                          children: [
                            Text(
                              CurrencyFormatter.format(product.sellPrice),
                              style: const TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w700,
                                color: AppTheme.primary,
                              ),
                            ),
                            const SizedBox(width: 8),
                            Text(
                              '(Modal: ${CurrencyFormatter.format(product.buyPrice)})',
                              style: const TextStyle(
                                fontSize: 11,
                                color: AppTheme.textMuted,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                    trailing: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        IconButton(
                          icon: const Icon(Icons.edit_outlined, size: 20, color: AppTheme.textSecondary),
                          onPressed: () => _openProductForm(context, pos, product),
                        ),
                        IconButton(
                          icon: const Icon(Icons.delete_outline, size: 20, color: AppTheme.danger),
                          onPressed: () => _showDeleteConfirm(context, pos, product),
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
      floatingActionButton: FloatingActionButton.extended(
        backgroundColor: AppTheme.primary,
        foregroundColor: Colors.white,
        onPressed: () => _openProductForm(context, pos, null),
        icon: const Icon(Icons.add),
        label: const Text('Produk Baru'),
      ),
    );
  }

  void _openProductForm(BuildContext context, PosProvider pos, Product? product) async {
    final result = await showDialog<Product>(
      context: context,
      builder: (_) => ProductFormDialog(product: product),
    );
    if (result != null) {
      await pos.saveProduct(result);
    }
  }

  void _showDeleteConfirm(BuildContext context, PosProvider pos, Product product) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Hapus Produk?'),
        content: Text('Produk "${product.name}" akan dihapus dari sistem.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Batal'),
          ),
          ElevatedButton(
            onPressed: () {
              pos.deleteProduct(product.id!);
              Navigator.pop(ctx);
            },
            style: ElevatedButton.styleFrom(backgroundColor: AppTheme.danger),
            child: const Text('Hapus'),
          ),
        ],
      ),
    );
  }
}
