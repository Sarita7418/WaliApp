import 'package:flutter/material.dart';
import 'package:webview_flutter/webview_flutter.dart';

class ChatView extends StatefulWidget {
  const ChatView({super.key});

  @override
  State<ChatView> createState() => _ChatViewState();
}

class _ChatViewState extends State<ChatView> {
  late final WebViewController _controller;

  static const String _botpressHtml = '''
<!DOCTYPE html>
<html>
  <head>
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <style>
      * {
        margin: 0;
        padding: 0;
        box-sizing: border-box;
      }
      html, body {
        width: 100%;
        height: 100vh;
        overflow: hidden;
      }
      #new {
        width: 100%;
        height: 100%;
        overflow-y: auto;
      }
    </style>
  </head>
  <body style="margin:0;padding:0;">
    <div id="new"></div>
    <script src="https://cdn.botpress.cloud/webchat/v3.6/inject.js"></script>
    <script src="https://files.bpcontent.cloud/2026/05/13/01/20260513013932-PZ37KGPQ.js" defer></script>
  </body>
</html>
''';

  @override
  void initState() {
    super.initState();
    _controller = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setNavigationDelegate(
        NavigationDelegate(
          onWebResourceError: (error) {
            // Ignoramos errores de bloqueo de ORB para que el UI no muestre una alerta.
          },
        ),
      )
      ..enableZoom(false)
      ..loadHtmlString(
        _botpressHtml,
        baseUrl: 'https://cdn.botpress.cloud',
      );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Asistente Wali')),
      body: WebViewWidget(controller: _controller),
    );
  }
}
