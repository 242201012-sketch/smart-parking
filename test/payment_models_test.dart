import 'package:flutter_test/flutter_test.dart';
import 'package:smart_parking_mobile/models/payment_models.dart';

void main() {
  test('hosted checkout sanal POS ve QR yeteneklerini destekler', () {
    final config = PaymentConfig.fromJson({
      'provider': 'iyzico',
      'enabled': true,
      'currency': 'TRY',
      'hostedCheckout': true,
      'virtualPos': true,
      'qrPayment': true,
      'sandbox': true,
    });

    expect(config.virtualPos, isTrue);
    expect(config.qrPayment, isTrue);
    expect(config.sandbox, isTrue);
  });

  test('QR payload yoksa güvenli checkout adresini kullanır', () {
    final checkout = CheckoutSession.fromJson({
      'paymentId': 'payment-1',
      'checkoutUrl': 'https://sandbox-api.iyzipay.com/checkout/test',
      'provider': 'iyzico',
      'sandbox': true,
    });

    expect(checkout.qrPayload, checkout.checkoutUrl);
  });
}
