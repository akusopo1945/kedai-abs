import 'dart:convert';

class BankAccount {
  /// Bank or e-wallet name, e.g. BCA, BRI, DANA.
  final String bankName;
  final String accountNumber;
  final String accountHolder;

  const BankAccount({
    required this.bankName,
    required this.accountNumber,
    required this.accountHolder,
  });

  String get label => '$bankName $accountNumber a.n. $accountHolder';

  Map<String, dynamic> toJson() => {
        'bank_name': bankName,
        'account_number': accountNumber,
        'account_holder': accountHolder,
      };

  factory BankAccount.fromJson(Map<String, dynamic> json) => BankAccount(
        bankName: json['bank_name'] as String? ?? '',
        accountNumber: json['account_number'] as String? ?? '',
        accountHolder: json['account_holder'] as String? ?? '',
      );
}

class PaymentSettings {
  final bool qrisEnabled;
  final bool transferEnabled;
  final bool debtEnabled;

  /// Requires a reference number for QRIS and transfer payments.
  final bool requireReference;
  final List<BankAccount> bankAccounts;

  const PaymentSettings({
    this.qrisEnabled = true,
    this.transferEnabled = true,
    this.debtEnabled = true,
    this.requireReference = false,
    this.bankAccounts = const [],
  });

  PaymentSettings copyWith({
    bool? qrisEnabled,
    bool? transferEnabled,
    bool? debtEnabled,
    bool? requireReference,
    List<BankAccount>? bankAccounts,
  }) {
    return PaymentSettings(
      qrisEnabled: qrisEnabled ?? this.qrisEnabled,
      transferEnabled: transferEnabled ?? this.transferEnabled,
      debtEnabled: debtEnabled ?? this.debtEnabled,
      requireReference: requireReference ?? this.requireReference,
      bankAccounts: bankAccounts ?? this.bankAccounts,
    );
  }

  String encode() => jsonEncode({
        'qris_enabled': qrisEnabled,
        'transfer_enabled': transferEnabled,
        'debt_enabled': debtEnabled,
        'require_reference': requireReference,
        'bank_accounts': [for (final account in bankAccounts) account.toJson()],
      });

  factory PaymentSettings.decode(String? raw) {
    if (raw == null || raw.isEmpty) return const PaymentSettings();
    try {
      final json = jsonDecode(raw) as Map<String, dynamic>;
      return PaymentSettings(
        qrisEnabled: json['qris_enabled'] as bool? ?? true,
        transferEnabled: json['transfer_enabled'] as bool? ?? true,
        debtEnabled: json['debt_enabled'] as bool? ?? true,
        requireReference: json['require_reference'] as bool? ?? false,
        bankAccounts: [
          for (final item in (json['bank_accounts'] as List? ?? const []))
            if (item is Map<String, dynamic>) BankAccount.fromJson(item),
        ],
      );
    } on Object {
      return const PaymentSettings();
    }
  }
}

class PrinterSettings {
  final String? address;
  final String? name;
  final bool autoPrint;
  final int copies;
  final bool autoCut;
  final bool openCashDrawer;

  const PrinterSettings({
    this.address,
    this.name,
    this.autoPrint = false,
    this.copies = 1,
    this.autoCut = false,
    this.openCashDrawer = false,
  });

  bool get isConfigured => address != null && address!.isNotEmpty;

  PrinterSettings copyWith({
    String? address,
    String? name,
    bool? autoPrint,
    int? copies,
    bool? autoCut,
    bool? openCashDrawer,
  }) {
    return PrinterSettings(
      address: address ?? this.address,
      name: name ?? this.name,
      autoPrint: autoPrint ?? this.autoPrint,
      copies: copies ?? this.copies,
      autoCut: autoCut ?? this.autoCut,
      openCashDrawer: openCashDrawer ?? this.openCashDrawer,
    );
  }

  PrinterSettings withoutPrinter() => PrinterSettings(
        autoPrint: autoPrint,
        copies: copies,
        autoCut: autoCut,
        openCashDrawer: openCashDrawer,
      );

  String encode() => jsonEncode({
        'address': address,
        'name': name,
        'auto_print': autoPrint,
        'copies': copies,
        'auto_cut': autoCut,
        'open_cash_drawer': openCashDrawer,
      });

  factory PrinterSettings.decode(String? raw) {
    if (raw == null || raw.isEmpty) return const PrinterSettings();
    try {
      final json = jsonDecode(raw) as Map<String, dynamic>;
      final copies = (json['copies'] as num?)?.toInt() ?? 1;
      return PrinterSettings(
        address: json['address'] as String?,
        name: json['name'] as String?,
        autoPrint: json['auto_print'] as bool? ?? false,
        copies: copies.clamp(1, 3),
        autoCut: json['auto_cut'] as bool? ?? false,
        openCashDrawer: json['open_cash_drawer'] as bool? ?? false,
      );
    } on Object {
      return const PrinterSettings();
    }
  }
}
