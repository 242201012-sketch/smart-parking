import 'package:flutter/material.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:url_launcher/url_launcher.dart';

import '../config/app_config.dart';
import '../config/app_theme.dart';
import '../models/payment_models.dart';
import '../services/payment_service.dart';
import '../state/app_controller.dart';

class PaymentPage extends StatefulWidget {
  const PaymentPage({super.key, required this.controller});

  final AppController controller;

  @override
  State<PaymentPage> createState() => _PaymentPageState();
}

class _PaymentPageState extends State<PaymentPage> {
  final PaymentService _service = PaymentService();
  PaymentConfig? _config;
  List<PayableSession> _payable = const [];
  List<PaymentItem> _payments = const [];
  bool _loading = true;
  bool _startingCheckout = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _service.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final config = await _service.getConfig();
      if (widget.controller.isDemoMode) {
        if (!mounted) return;
        setState(() => _config = config);
        return;
      }
      final token = await widget.controller.getAccessToken();
      final results = await Future.wait([
        _service.getPayableSessions(token),
        _service.getPayments(token),
      ]);
      if (!mounted) return;
      setState(() {
        _config = config;
        _payable = results[0] as List<PayableSession>;
        _payments = results[1] as List<PaymentItem>;
      });
    } catch (error) {
      if (mounted) setState(() => _error = error.toString());
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  bool get _canPay =>
      !widget.controller.isDemoMode &&
      !widget.controller.isOfflineMode &&
      _config?.enabled == true &&
      _config?.hostedCheckout == true &&
      !_startingCheckout;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Ödemeler'),
        actions: [
          IconButton(
            tooltip: 'Yenile',
            onPressed: _loading ? null : _load,
            icon: const Icon(Icons.refresh_rounded),
          ),
        ],
      ),
      body: _loading && _config == null
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _load,
              child: ListView(
                padding: const EdgeInsets.fromLTRB(18, 8, 18, 32),
                children: [
                  const Card(
                    color: Color(0xFFE2F1EC),
                    child: ListTile(
                      leading: Icon(
                        Icons.verified_user_outlined,
                        color: AppTheme.primary,
                      ),
                      title: Text('Kart bilgileriniz SmartParking’e gelmez'),
                      subtitle: Text(
                        'Sanal POS ve QR ödeme aynı iyzico güvenli HTTPS sayfasını kullanır. Kart numarası ve CVV SmartParking’e gelmez.',
                      ),
                    ),
                  ),
                  if (widget.controller.isOfflineMode ||
                      widget.controller.isDemoMode) ...[
                    const SizedBox(height: 10),
                    Card(
                      color: const Color(0xFFFFEBC9),
                      child: ListTile(
                        leading: const Icon(Icons.cloud_off_rounded),
                        title: Text(
                          widget.controller.isDemoMode
                              ? 'Demo modunda ödeme kapalı'
                              : 'Çevrimdışıyken ödeme kapalı',
                        ),
                        subtitle: const Text(
                          'Ödeme için gerçek kullanıcı oturumu ve güvenli internet bağlantısı gerekir.',
                        ),
                      ),
                    ),
                  ],
                  if (_config != null && !_config!.enabled) ...[
                    const SizedBox(height: 10),
                    const Card(
                      color: Color(0xFFFFECE8),
                      child: ListTile(
                        leading: Icon(Icons.key_off_outlined),
                        title: Text('iyzico henüz yapılandırılmadı'),
                        subtitle: Text(
                          'Sandbox API anahtarları ve herkese açık HTTPS callback adresi eklenmelidir.',
                        ),
                      ),
                    ),
                  ],
                  if (_config?.enabled == true && _config?.sandbox == true) ...[
                    const SizedBox(height: 10),
                    const Card(
                      color: Color(0xFFE8F2FF),
                      child: ListTile(
                        leading: Icon(Icons.science_outlined),
                        title: Text('iyzico Sandbox / test modu'),
                        subtitle: Text(
                          'Bu yapılandırma gerçek karttan tahsilat yapmaz.',
                        ),
                      ),
                    ),
                  ],
                  if (_error != null) ...[
                    const SizedBox(height: 10),
                    Card(
                      color: const Color(0xFFFFECE8),
                      child: ListTile(
                        leading: const Icon(Icons.error_outline_rounded),
                        title: const Text('Ödeme servisine ulaşılamadı'),
                        subtitle: Text(_error!),
                      ),
                    ),
                  ],
                  const SizedBox(height: 22),
                  Text(
                    'Ödenecek park oturumları',
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 8),
                  if (_payable.isEmpty)
                    const Card(
                      child: ListTile(
                        leading: Icon(Icons.check_circle_outline_rounded),
                        title: Text('Bekleyen ödeme yok'),
                        subtitle: Text(
                          'Tamamlanmış ve ödenmemiş park oturumları burada görünür.',
                        ),
                      ),
                    )
                  else
                    ..._payable.map(
                      (session) => Card(
                        child: Padding(
                          padding: const EdgeInsets.all(16),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              Row(
                                children: [
                                  Expanded(
                                    child: Text(
                                      session.parkingLotName,
                                      style: const TextStyle(
                                        fontWeight: FontWeight.w800,
                                      ),
                                    ),
                                  ),
                                  Text(
                                    '${session.totalAmount.toStringAsFixed(2)} TL',
                                    style: const TextStyle(
                                      fontSize: 18,
                                      fontWeight: FontWeight.w900,
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 4),
                              Text(
                                '${session.vehiclePlate} · ${_date(session.endedAt)}',
                              ),
                              const SizedBox(height: 14),
                              FilledButton.icon(
                                onPressed: _canPay
                                    ? () => _startCheckout(session)
                                    : null,
                                icon: _startingCheckout
                                    ? const SizedBox(
                                        width: 18,
                                        height: 18,
                                        child: CircularProgressIndicator(
                                          strokeWidth: 2,
                                        ),
                                      )
                                    : const Icon(Icons.point_of_sale_rounded),
                                label: const Text('Sanal POS veya QR ile öde'),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  const SizedBox(height: 22),
                  Text(
                    'Ödeme geçmişi',
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 8),
                  if (_payments.isEmpty)
                    const Card(
                      child: ListTile(
                        leading: Icon(Icons.receipt_long_outlined),
                        title: Text('Henüz ödeme kaydı yok'),
                      ),
                    )
                  else
                    ..._payments.map(
                      (payment) => Card(
                        child: ListTile(
                          leading: CircleAvatar(
                            backgroundColor: _statusColor(
                              payment.status,
                            ).withValues(alpha: 0.15),
                            child: Icon(
                              _statusIcon(payment.status),
                              color: _statusColor(payment.status),
                            ),
                          ),
                          title: Text(
                            '${payment.amount.toStringAsFixed(2)} ${payment.currency}',
                            style: const TextStyle(fontWeight: FontWeight.w800),
                          ),
                          subtitle: Text(
                            '${_statusText(payment.status)} · ${_date(payment.createdAt)}',
                          ),
                          trailing: Text(
                            payment.provider.toUpperCase(),
                            style: Theme.of(context).textTheme.labelSmall,
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ),
    );
  }

  Future<void> _startCheckout(PayableSession session) async {
    final mode = await _chooseCheckoutMode(session);
    if (mode == null || !mounted) return;

    if (AppConfig.familyLinkMode) {
      final guardianApproved = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          icon: const Icon(Icons.family_restroom_rounded),
          title: const Text('Ebeveyn onayı'),
          content: const Text(
            '18 yaşın altındaysanız rezervasyon ve kart işlemi için '
            'ebeveyninizin veya vasinizin izni gerekir. Kart bilgileri '
            'SmartParking içinde değil, iyzico güvenli ödeme sayfasında girilir.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Vazgeç'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Ebeveynim onaylıyor'),
            ),
          ],
        ),
      );
      if (guardianApproved != true || !mounted) return;
    }

    final details = await _collectBuyerDetails();
    if (details == null || !mounted) return;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(
          mode == _CheckoutMode.qr
              ? 'QR ödemeyi hazırla'
              : 'Sanal POS’u başlat',
        ),
        content: Text(
          '${session.parkingLotName} için ${session.totalAmount.toStringAsFixed(2)} TL '
          'tutarında iyzico güvenli ödeme oturumu oluşturulacak.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Vazgeç'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Devam et'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    setState(() => _startingCheckout = true);
    try {
      final checkout = await _service.createCheckout(
        await widget.controller.getAccessToken(),
        parkingSessionId: session.id,
        gsmNumber: details.gsmNumber,
        identityNumber: details.identityNumber,
        registrationAddress: details.registrationAddress,
        city: details.city,
        zipCode: details.zipCode,
      );
      if (mode == _CheckoutMode.qr) {
        await _showQrCheckout(checkout, session);
      } else {
        await _openVirtualPos(checkout);
      }
      await _load();
    } catch (error) {
      if (mounted)
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(error.toString())));
    } finally {
      if (mounted) setState(() => _startingCheckout = false);
    }
  }

  Future<_CheckoutMode?> _chooseCheckoutMode(PayableSession session) {
    return showDialog<_CheckoutMode>(
      context: context,
      builder: (context) => SimpleDialog(
        title: Text(
          '${session.totalAmount.toStringAsFixed(2)} TL nasıl ödensin?',
        ),
        children: [
          if (_config?.virtualPos == true)
            SimpleDialogOption(
              onPressed: () => Navigator.pop(context, _CheckoutMode.virtualPos),
              child: const ListTile(
                contentPadding: EdgeInsets.zero,
                leading: CircleAvatar(child: Icon(Icons.point_of_sale_rounded)),
                title: Text('Sanal POS'),
                subtitle: Text('Kartla iyzico güvenli ödeme sayfasında öde'),
              ),
            ),
          if (_config?.qrPayment == true)
            SimpleDialogOption(
              onPressed: () => Navigator.pop(context, _CheckoutMode.qr),
              child: const ListTile(
                contentPadding: EdgeInsets.zero,
                leading: CircleAvatar(child: Icon(Icons.qr_code_2_rounded)),
                title: Text('QR ile ödeme'),
                subtitle: Text(
                  'QR’ı başka bir telefonla tarat veya bu cihazda aç',
                ),
              ),
            ),
        ],
      ),
    );
  }

  Future<void> _openVirtualPos(CheckoutSession checkout) async {
    final opened = await launchUrl(
      checkout.checkoutUrl,
      mode: LaunchMode.externalApplication,
    );
    if (!opened) throw Exception('Güvenli sanal POS sayfası açılamadı.');
    if (!mounted) return;
    await showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        icon: const Icon(Icons.point_of_sale_rounded),
        title: const Text('Sanal POS açıldı'),
        content: Text(
          '${checkout.sandbox ? 'SANDBOX/test işlemidir. ' : ''}'
          'Ödemeyi iyzico sayfasında tamamladıktan sonra uygulamaya dönün.',
        ),
        actions: [
          FilledButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Durumu yenile'),
          ),
        ],
      ),
    );
  }

  Future<void> _showQrCheckout(
    CheckoutSession checkout,
    PayableSession session,
  ) async {
    var checking = false;
    var statusMessage =
        'Ödeme tamamlanınca “Durumu kontrol et” düğmesine dokunun.';
    await showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          icon: const Icon(Icons.qr_code_2_rounded),
          title: const Text('QR ile güvenli ödeme'),
          content: SizedBox(
            width: 330,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    '${session.parkingLotName} · ${session.totalAmount.toStringAsFixed(2)} TL',
                    textAlign: TextAlign.center,
                    style: const TextStyle(fontWeight: FontWeight.w800),
                  ),
                  const SizedBox(height: 16),
                  Container(
                    padding: const EdgeInsets.all(12),
                    color: Colors.white,
                    child: QrImageView(
                      data: checkout.qrPayload.toString(),
                      size: 220,
                      errorCorrectionLevel: QrErrorCorrectLevel.M,
                    ),
                  ),
                  const SizedBox(height: 12),
                  const Text(
                    'Başka bir telefonun kamerasıyla taratın. QR yalnızca iyzico güvenli ödeme bağlantısını içerir.',
                    textAlign: TextAlign.center,
                  ),
                  if (checkout.sandbox) ...[
                    const SizedBox(height: 8),
                    const Text(
                      'SANDBOX / test modu — gerçek tahsilat yapılmaz.',
                      textAlign: TextAlign.center,
                      style: TextStyle(color: Color(0xFF8A6A37)),
                    ),
                  ],
                  const SizedBox(height: 10),
                  Text(
                    statusMessage,
                    textAlign: TextAlign.center,
                    style: const TextStyle(fontSize: 12),
                  ),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: checking
                  ? null
                  : () => launchUrl(
                      checkout.checkoutUrl,
                      mode: LaunchMode.externalApplication,
                    ),
              child: const Text('Bu telefonda aç'),
            ),
            OutlinedButton(
              onPressed: checking
                  ? null
                  : () async {
                      setDialogState(() => checking = true);
                      try {
                        final payment = await _service.getPaymentStatus(
                          await widget.controller.getAccessToken(),
                          checkout.paymentId,
                        );
                        if (!dialogContext.mounted) return;
                        if (payment.status.toLowerCase() == 'paid') {
                          Navigator.pop(dialogContext);
                          return;
                        }
                        setDialogState(
                          () => statusMessage =
                              'Güncel durum: ${_statusText(payment.status)}',
                        );
                      } catch (error) {
                        if (dialogContext.mounted) {
                          setDialogState(
                            () => statusMessage = 'Durum alınamadı: $error',
                          );
                        }
                      } finally {
                        if (dialogContext.mounted) {
                          setDialogState(() => checking = false);
                        }
                      }
                    },
              child: Text(checking ? 'Kontrol ediliyor…' : 'Durumu kontrol et'),
            ),
            FilledButton(
              onPressed: checking ? null : () => Navigator.pop(dialogContext),
              child: const Text('Kapat'),
            ),
          ],
        ),
      ),
    );
  }

  Future<_BuyerDetails?> _collectBuyerDetails() async {
    final gsm = TextEditingController();
    final identity = TextEditingController();
    final address = TextEditingController();
    final city = TextEditingController();
    final zip = TextEditingController();
    final controllers = [gsm, identity, address, city, zip];
    final accepted = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Fatura bilgileri'),
        content: SizedBox(
          width: 430,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: gsm,
                  keyboardType: TextInputType.phone,
                  decoration: const InputDecoration(
                    labelText: 'Telefon',
                    hintText: '+905551112233',
                  ),
                ),
                const SizedBox(height: 10),
                TextField(
                  controller: identity,
                  keyboardType: TextInputType.number,
                  obscureText: true,
                  decoration: const InputDecoration(
                    labelText: 'T.C. kimlik no',
                    helperText: 'Yalnızca ödeme sağlayıcısına iletilir',
                  ),
                ),
                const SizedBox(height: 10),
                TextField(
                  controller: address,
                  decoration: const InputDecoration(labelText: 'Fatura adresi'),
                  maxLines: 2,
                ),
                const SizedBox(height: 10),
                TextField(
                  controller: city,
                  decoration: const InputDecoration(labelText: 'Şehir'),
                ),
                const SizedBox(height: 10),
                TextField(
                  controller: zip,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(labelText: 'Posta kodu'),
                ),
              ],
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Vazgeç'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('Devam et'),
          ),
        ],
      ),
    );
    final result = _BuyerDetails(
      gsmNumber: gsm.text.trim(),
      identityNumber: identity.text.trim(),
      registrationAddress: address.text.trim(),
      city: city.text.trim(),
      zipCode: zip.text.trim(),
    );
    for (final controller in controllers) {
      controller.dispose();
    }
    if (accepted != true) return null;
    final identityValid = RegExp(r'^\d{11}$').hasMatch(result.identityNumber);
    final phoneValid = RegExp(
      r'^\+?\d{10,15}$',
    ).hasMatch(result.gsmNumber.replaceAll(' ', ''));
    if (!identityValid ||
        !phoneValid ||
        result.registrationAddress.length < 5 ||
        result.city.length < 2) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Telefon, 11 haneli kimlik no ve adres bilgilerini kontrol edin.',
            ),
          ),
        );
      }
      return null;
    }
    return result;
  }

  String _date(DateTime? value) {
    if (value == null) return '-';
    final local = value.toLocal();
    return '${local.day.toString().padLeft(2, '0')}.${local.month.toString().padLeft(2, '0')}.${local.year}';
  }

  String _statusText(String value) => switch (value.toLowerCase()) {
    'paid' => 'Ödendi',
    'failed' => 'Başarısız',
    'review' => 'İnceleniyor',
    'checkout_ready' => 'Ödeme bekliyor',
    'abandoned' => 'Süresi doldu',
    _ => 'Bekliyor',
  };

  Color _statusColor(String value) => switch (value.toLowerCase()) {
    'paid' => AppTheme.primary,
    'failed' => Colors.red.shade700,
    'review' => Colors.orange.shade800,
    _ => Colors.blueGrey,
  };

  IconData _statusIcon(String value) => switch (value.toLowerCase()) {
    'paid' => Icons.check_rounded,
    'failed' => Icons.close_rounded,
    'review' => Icons.hourglass_top_rounded,
    _ => Icons.credit_card_rounded,
  };
}

class _BuyerDetails {
  const _BuyerDetails({
    required this.gsmNumber,
    required this.identityNumber,
    required this.registrationAddress,
    required this.city,
    required this.zipCode,
  });

  final String gsmNumber;
  final String identityNumber;
  final String registrationAddress;
  final String city;
  final String zipCode;
}

enum _CheckoutMode { virtualPos, qr }
