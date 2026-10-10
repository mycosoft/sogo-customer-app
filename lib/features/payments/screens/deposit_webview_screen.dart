import 'package:flutter/material.dart';
import 'package:webview_flutter/webview_flutter.dart';
import '../../../core/theme/app_text.dart';

/// In-app Flutterwave checkout sheet.
///
/// Opens the payment link inside the app, watches for our return URL
/// (`/wallet-payment/return`) or the `sogo://` deep link, then closes and
/// hands the tx ref back so the caller can verify + refresh. The old
/// external-browser flow with a blind 6s wait is gone; deep links stay as
/// a backup (the webhook may settle first).
class DepositWebViewScreen extends StatefulWidget {
  const DepositWebViewScreen(
      {super.key, required this.link, required this.txRef});

  final String link;
  final String txRef;

  @override
  State<DepositWebViewScreen> createState() => _DepositWebViewScreenState();
}

class _DepositWebViewScreenState extends State<DepositWebViewScreen> {
  late final WebViewController _controller;
  bool _loading = true;
  bool _finished = false;

  @override
  void initState() {
    super.initState();
    _controller = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setNavigationDelegate(NavigationDelegate(
        onProgress: (_) {
          if (mounted && _loading) setState(() => _loading = false);
        },
        onPageFinished: (url) => _checkReturnUrl(url),
        onNavigationRequest: (request) {
          if (_isReturnUrl(request.url)) {
            _done();
            return NavigationDecision.prevent;
          }
          return NavigationDecision.navigate;
        },
      ))
      ..loadRequest(Uri.parse(widget.link));
  }

  bool _isReturnUrl(String url) {
    final uri = Uri.tryParse(url);
    if (uri == null) return false;
    if (uri.scheme == 'sogo') return true;
    return uri.path.contains('wallet-payment/return');
  }

  void _checkReturnUrl(String url) {
    if (_isReturnUrl(url)) _done();
  }

  void _done() {
    if (_finished) return;
    _finished = true;
    if (mounted) Navigator.of(context).pop(widget.txRef);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Top up wallet'),
        leading: IconButton(
          icon: const Icon(Icons.close_rounded),
          // Closing early still verifies — payment may have gone through.
          onPressed: _done,
        ),
        actions: [
          TextButton(
            onPressed: _done,
            child: Text('Done',
                style: SogoText.button.copyWith(color: Colors.white)),
          ),
        ],
      ),
      body: Stack(
        children: [
          WebViewWidget(controller: _controller),
          if (_loading)
            const Center(child: CircularProgressIndicator()),
        ],
      ),
    );
  }
}
