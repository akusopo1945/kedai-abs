import 'package:flutter/material.dart';
import '../../core/constants/app_constants.dart';
import '../../core/theme/app_theme.dart';
import '../../models/product.dart';

class ProductFormDialog extends StatefulWidget {
  final Product? product;

  const ProductFormDialog({super.key, this.product});

  @override
  State<ProductFormDialog> createState() => _ProductFormDialogState();
}

class _ProductFormDialogState extends State<ProductFormDialog> {
  final _formKey = GlobalKey<FormState>();
  late TextEditingController _nameController;
  late TextEditingController _skuController;
  late TextEditingController _buyPriceController;
  late TextEditingController _sellPriceController;
  late TextEditingController _stockController;
  late String _selectedCategory;

  @override
  void initState() {
    super.initState();
    final p = widget.product;
    _nameController = TextEditingController(text: p?.name ?? '');
    _skuController = TextEditingController(text: p?.sku ?? '');
    _buyPriceController = TextEditingController(
      text: p != null ? p.buyPrice.toStringAsFixed(0) : '',
    );
    _sellPriceController = TextEditingController(
      text: p != null ? p.sellPrice.toStringAsFixed(0) : '',
    );
    _stockController = TextEditingController(
      text: p != null ? p.stock.toString() : '0',
    );
    _selectedCategory = p?.category ?? 'Sate-satean';
  }

  @override
  void dispose() {
    _nameController.dispose();
    _skuController.dispose();
    _buyPriceController.dispose();
    _sellPriceController.dispose();
    _stockController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isEditing = widget.product != null;
    final categories = AppConstants.defaultCategories.where((c) => c != 'Semua').toList();

    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Container(
        padding: const EdgeInsets.all(20),
        constraints: const BoxConstraints(maxWidth: 400),
        child: SingleChildScrollView(
          child: Form(
            key: _formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      isEditing ? 'Edit Produk' : 'Tambah Produk Baru',
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                        color: AppTheme.textPrimary,
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close, size: 20),
                      onPressed: () => Navigator.pop(context),
                    ),
                  ],
                ),
                const Divider(color: AppTheme.border),
                const SizedBox(height: 12),

                // Name Field
                TextFormField(
                  controller: _nameController,
                  decoration: const InputDecoration(labelText: 'Nama Produk *'),
                  validator: (val) => val == null || val.trim().isEmpty ? 'Nama wajib diisi' : null,
                ),
                const SizedBox(height: 12),

                // SKU / Barcode
                TextFormField(
                  controller: _skuController,
                  decoration: const InputDecoration(labelText: 'Kode SKU / Barcode'),
                ),
                const SizedBox(height: 12),

                // Category Dropdown
                DropdownButtonFormField<String>(
                  value: _selectedCategory,
                  decoration: const InputDecoration(labelText: 'Kategori *'),
                  items: categories.map((c) {
                    return DropdownMenuItem(value: c, child: Text(c));
                  }).toList(),
                  onChanged: (val) {
                    if (val != null) setState(() => _selectedCategory = val);
                  },
                ),
                const SizedBox(height: 12),

                // Prices: Buy & Sell
                Row(
                  children: [
                    Expanded(
                      child: TextFormField(
                        controller: _buyPriceController,
                        keyboardType: TextInputType.number,
                        decoration: const InputDecoration(
                          labelText: 'Harga Modal',
                          prefixText: 'Rp ',
                        ),
                        validator: (val) => val == null || double.tryParse(val) == null
                            ? 'Invalid'
                            : null,
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: TextFormField(
                        controller: _sellPriceController,
                        keyboardType: TextInputType.number,
                        decoration: const InputDecoration(
                          labelText: 'Harga Jual *',
                          prefixText: 'Rp ',
                        ),
                        validator: (val) => val == null || double.tryParse(val) == null
                            ? 'Invalid'
                            : null,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),

                // Stock
                TextFormField(
                  controller: _stockController,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(labelText: 'Jumlah Stok *'),
                  validator: (val) => val == null || int.tryParse(val) == null
                      ? 'Stok harus berupa angka'
                      : null,
                ),
                const SizedBox(height: 20),

                // Action Buttons
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    OutlinedButton(
                      onPressed: () => Navigator.pop(context),
                      child: const Text('Batal'),
                    ),
                    const SizedBox(width: 10),
                    ElevatedButton(
                      onPressed: () {
                        if (_formKey.currentState!.validate()) {
                          final product = Product(
                            id: widget.product?.id,
                            name: _nameController.text.trim(),
                            sku: _skuController.text.trim().isEmpty ? null : _skuController.text.trim(),
                            category: _selectedCategory,
                            buyPrice: double.parse(_buyPriceController.text),
                            sellPrice: double.parse(_sellPriceController.text),
                            stock: int.parse(_stockController.text),
                          );
                          Navigator.pop(context, product);
                        }
                      },
                      child: Text(isEditing ? 'Simpan' : 'Tambah'),
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
