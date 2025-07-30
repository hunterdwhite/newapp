import 'package:flutter/material.dart';
import 'package:webview_flutter/webview_flutter.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../widgets/retro_button_widget.dart';
import '../widgets/grainy_background_widget.dart';
import '../services/discogs_service.dart';

class LinkDiscogsScreen extends StatefulWidget {
  const LinkDiscogsScreen({Key? key}) : super(key: key);

  @override
  State<LinkDiscogsScreen> createState() => _LinkDiscogsScreenState();
}

class _LinkDiscogsScreenState extends State<LinkDiscogsScreen> {
  final DiscogsService _discogsService = DiscogsService();
  
  Map<String, String>? _tempCredentials;
  late final WebViewController _webViewController;

  final TextEditingController _pinController = TextEditingController();
  bool _isLoading = true;
  String? _error;
  bool _alreadyLinked = false;

  @override
  void initState() {
    super.initState();
    _checkIfAlreadyLinked();
  }

  Future<void> _checkIfAlreadyLinked() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;
    
    final authData = await _discogsService.loadAuthData(user.uid);
    if (authData != null) {
      setState(() {
        _alreadyLinked = true;
        _isLoading = false;
      });
    } else {
      _startOAuthFlow();
    }
  }

  Future<void> _startOAuthFlow() async {
    try {
      final oauthData = await _discogsService.startOAuthFlow();
      _tempCredentials = oauthData['tempCredentials'] as Map<String, String>;
      final authUrl = oauthData['authUrl'] as String;

      _webViewController = WebViewController()
        ..setJavaScriptMode(JavaScriptMode.unrestricted)
        ..loadRequest(Uri.parse(authUrl));

      setState(() => _isLoading = false);
    } catch (e) {
      setState(() {
        _error = 'Failed to initiate OAuth: $e';
        _isLoading = false;
      });
    }
  }

  Future<void> _submitPin() async {
    final pin = _pinController.text.trim();
    if (_tempCredentials == null || pin.isEmpty) {
      setState(() => _error = 'Missing temp credentials or PIN');
      return;
    }

    setState(() {
      _error = null;
      _isLoading = true;
    });

    try {
      final tokens = await _discogsService.exchangePinForTokens(_tempCredentials!, pin);
      final accessToken = tokens['accessToken']!;
      final accessSecret = tokens['accessSecret']!;

      final username = await _discogsService.getUsername(accessToken, accessSecret);

      await _discogsService.storeAuthData(accessToken, accessSecret, username);

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Discogs linked successfully')),
      );
      Navigator.pop(context);
    } catch (e) {
      setState(() => _error = 'PIN exchange failed: $e');
    } finally {
      setState(() => _isLoading = false);
    }
  }



  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Link Discogs')),
      body: GrainyBackgroundWidget(
        child: _isLoading
            ? const Center(child: CircularProgressIndicator())
            : _alreadyLinked
                ? Center(
                    child: Padding(
                      padding: const EdgeInsets.all(24.0),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Text(
                            'You already have a Discogs account linked.',
                            style: TextStyle(fontSize: 16),
                            textAlign: TextAlign.center,
                          ),
                          const SizedBox(height: 16),
                          RetroButtonWidget(
                            text: 'Relink Discogs Account',
                            style: RetroButtonStyle.dark,
                            leading: Image.asset('assets/discogs_logo.png', height: 20, width: 20),
                            onPressed: () {
                              setState(() {
                                _alreadyLinked = false;
                                _isLoading = true;
                              });
                              _startOAuthFlow();
                            },
                          ),
                        ],
                      ),
                    ),
                  )
                : Column(
                    children: [
                      Expanded(child: WebViewWidget(controller: _webViewController)),
                      Padding(
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          children: [
                            TextField(
                              controller: _pinController,
                              decoration: const InputDecoration(
                                labelText: 'Enter PIN from Discogs',
                              ),
                            ),
                            const SizedBox(height: 12),
                            RetroButtonWidget(
                              text: 'Submit PIN',
                              style: RetroButtonStyle.dark,
                              leading: Image.asset('assets/discogs_logo.png', height: 20, width: 20),
                              onPressed: _submitPin,
                            ),
                            if (_error != null)
                              Padding(
                                padding: const EdgeInsets.only(top: 8),
                                child: Text(_error!, style: const TextStyle(color: Colors.red)),
                              ),
                          ],
                        ),
                      ),
                    ],
                  ),
      ),
    );
  }
}