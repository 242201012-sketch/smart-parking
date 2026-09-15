class PaymentConfig {
  const PaymentConfig({
    required this.provider,
    required this.enabled,
    required this.currency,
    required this.hostedCheckout,
    required this.virtualPos,
    required this.qrPayment,
    required this.offlinePaymentsSupported,
    required this.sandbox,
  });

  final String provider;
  final bool enabled;
  final String currency;
  final bool hostedCheckout;
  final bool virtualPos;
  final bool qrPayment;
  final bool offlinePaymentsSupported;
  final bool sandbox;

  factory PaymentConfig.fromJson(Map<String, dynamic> json) => PaymentConfig(
    provider: json['provider']?.toString() ?? 'disabled',
    enabled: json['enabled'] == true,
    currency: json['currency']?.toString() ?? 'TRY',
    hostedCheckout: json['hostedCheckout'] == true,
    virtualPos: json['virtualPos'] == true || json['hostedCheckout'] == true,
    qrPayment: json['qrPayment'] == true || json['hostedCheckout'] == true,
    offlinePaymentsSupported: json['offlinePaymentsSupported'] == true,
    sandbox: json['sandbox'] == true,
  );
}

class PayableSession {
  const PayableSession({
    required this.id,
    required this.parkingLotName,
    required this.vehiclePlate,
    required this.endedAt,
    required this.totalAmount,
    required this.paymentStatus,
  });

  final String id;
  final String parkingLotName;
  final String vehiclePlate;
  final DateTime? endedAt;
  final double totalAmount;
  final String paymentStatus;

  factory PayableSession.fromJson(Map<String, dynamic> json) => PayableSession(
    id: json['id']?.toString() ?? '',
    parkingLotName: json['parkingLotName']?.toString() ?? '',
    vehiclePlate: json['vehiclePlate']?.toString() ?? '',
    endedAt: DateTime.tryParse(json['endedAt']?.toString() ?? ''),
    totalAmount: _asDouble(json['totalAmount']),
    paymentStatus: json['paymentStatus']?.toString() ?? 'pending',
  );
}

class PaymentItem {
  const PaymentItem({
    required this.id,
    required this.parkingSessionId,
    required this.provider,
    required this.amount,
    required this.currency,
    required this.status,
    required this.createdAt,
    this.paidAt,
    this.failureReason,
  });

  final String id;
  final String parkingSessionId;
  final String provider;
  final double amount;
  final String currency;
  final String status;
  final DateTime? createdAt;
  final DateTime? paidAt;
  final String? failureReason;

  factory PaymentItem.fromJson(Map<String, dynamic> json) => PaymentItem(
    id: json['id']?.toString() ?? '',
    parkingSessionId: json['parkingSessionId']?.toString() ?? '',
    provider: json['provider']?.toString() ?? '',
    amount: _asDouble(json['amount']),
    currency: json['currency']?.toString() ?? 'TRY',
    status: json['status']?.toString() ?? 'pending',
    createdAt: DateTime.tryParse(json['createdAt']?.toString() ?? ''),
    paidAt: DateTime.tryParse(json['paidAt']?.toString() ?? ''),
    failureReason: json['failureReason']?.toString(),
  );
}

class CheckoutSession {
  const CheckoutSession({
    required this.paymentId,
    required this.checkoutUrl,
    required this.qrPayload,
    required this.provider,
    required this.sandbox,
  });

  final String paymentId;
  final Uri checkoutUrl;
  final Uri qrPayload;
  final String provider;
  final bool sandbox;

  factory CheckoutSession.fromJson(Map<String, dynamic> json) {
    final checkoutUrl = Uri.tryParse(json['checkoutUrl']?.toString() ?? '');
    if (checkoutUrl == null || !checkoutUrl.isScheme('https')) {
      throw const FormatException('Ödeme sayfası adresi geçersiz.');
    }
    final qrPayloadText = json['qrPayload']?.toString() ?? '';
    final qrPayload = qrPayloadText.isEmpty
        ? checkoutUrl
        : Uri.tryParse(qrPayloadText) ?? checkoutUrl;
    if (!qrPayload.isScheme('https')) {
      throw const FormatException('QR ödeme adresi geçersiz.');
    }
    return CheckoutSession(
      paymentId: json['paymentId']?.toString() ?? '',
      checkoutUrl: checkoutUrl,
      qrPayload: qrPayload,
      provider: json['provider']?.toString() ?? '',
      sandbox: json['sandbox'] == true,
    );
  }
}

double _asDouble(dynamic value) {
  if (value is num) return value.toDouble();
  return double.tryParse(value?.toString() ?? '') ?? 0;
}
