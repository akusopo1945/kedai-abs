import 'package:flutter/material.dart';
import '../core/theme/app_theme.dart';
import '../core/utils/currency_formatter.dart';
import '../models/product.dart';

class ProductCard extends StatelessWidget {
  final Product product;
  final int cartQuantity;
  final VoidCallback onAdd;
  final VoidCallback? onRemove;

  const ProductCard({
    super.key,
    required this.product,
    this.cartQuantity = 0,
    required this.onAdd,
    this.onRemove,
  });

  @override
  Widget build(BuildContext context) {
    final isOutOfStock = product.stock <= 0;
    final isInCart = cartQuantity > 0;

    return Container(
      decoration: BoxDecoration(
        color: AppTheme.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: isInCart ? AppTheme.primary : AppTheme.border,
          width: isInCart ? 1.5 : 1.0,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.02),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(14),
          onTap: isOutOfStock ? null : onAdd,
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Header: Category Pill & Stock/Cart Badge
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: AppTheme.borderSubtle,
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        product.category,
                        style: const TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.w600,
                          color: AppTheme.textSecondary,
                        ),
                      ),
                    ),
                    if (isInCart)
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                        decoration: BoxDecoration(
                          color: AppTheme.primary,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Text(
                          '$cartQuantity di keranjang',
                          style: const TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.w700,
                            color: Colors.white,
                          ),
                        ),
                      )
                    else
                      Text(
                        isOutOfStock ? 'Habis' : 'Stok: ${product.stock}',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w500,
                          color: isOutOfStock ? AppTheme.danger : AppTheme.textMuted,
                        ),
                      ),
                  ],
                ),
                const Spacer(),
                // Product Name
                Text(
                  product.name,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: isOutOfStock ? AppTheme.textMuted : AppTheme.textPrimary,
                    height: 1.25,
                  ),
                ),
                const SizedBox(height: 8),
                // Price & Quick Action
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          CurrencyFormatter.format(product.sellPrice),
                          style: TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w700,
                            color: isOutOfStock ? AppTheme.textMuted : AppTheme.primary,
                          ),
                        ),
                      ],
                    ),
                    Container(
                      width: 32,
                      height: 32,
                      decoration: BoxDecoration(
                        color: isOutOfStock
                            ? AppTheme.borderSubtle
                            : (isInCart ? AppTheme.primary : AppTheme.primaryLight),
                        shape: BoxShape.circle,
                      ),
                      child: Icon(
                        isInCart ? Icons.check : Icons.add,
                        size: 18,
                        color: isOutOfStock
                            ? AppTheme.textMuted
                            : (isInCart ? Colors.white : AppTheme.primary),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
