import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:webview_flutter/webview_flutter.dart';
import 'package:oauth1/oauth1.dart' as oauth1;
import 'package:http/http.dart' as http;
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../widgets/retro_button_widget.dart';
import '../widgets/grainy_background_widget.dart';

class LinkDiscogsScreen extends StatefulWidget {
  const LinkDiscogsScreen({Key? key}) : super(key: key);

  @override
  State<LinkDiscogsScreen> createState() => _LinkDiscogsScreenState();
}

class _LinkDiscogsScreenState extends State<LinkDiscogsScreen> {
  static const _consumerKey = 'EzVdIgMVbCnRNcwacndA';
  static const _consumerSecret = 'CUqIDOCeEoFmREnzjKqTmKpstenTGnsE';

  final oauth1.Platform _platform = oauth1.Platform(
    'https://api.discogs.com/oauth/request_token',
    'https://www.discogs.com/oauth/authorize',
    'https://api.discogs.com/oauth/access_token',
    oauth1.SignatureMethods.hmacSha1,
  );

  late final oauth1.Authorization _auth;
  oauth1.Credentials? _tempCredentials;
  late final WebViewController _webViewController;

  final TextEditingController _pinController = TextEditingController();
  bool _isLoading = true;
  String? _error;
  bool _alreadyLinked = false;

  @override
  void initState() {
    super.initState();
    final clientCredentials = oauth1.ClientCredentials(_consumerKey, _consumerSecret);
    _auth = oauth1.Authorization(clientCredentials, _platform);
    _checkIfAlreadyLinked();
  }

  Future<void> _checkIfAlreadyLinked() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;
    final doc = await FirebaseFirestore.instance.collection('users').doc(user.uid).get();
    final linked = doc.data()?['discogsLinked'] == true;
    if (linked) {
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
      final response = await _auth.requestTemporaryCredentials('oob');
      _tempCredentials = response.credentials;

      final authUrl = _auth.getResourceOwnerAuthorizationURI(_tempCredentials!.token);

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
      final response = await _auth.requestTokenCredentials(_tempCredentials!, pin);
      final accessToken = response.credentials.token;
      final accessSecret = response.credentials.tokenSecret;

      final username = await _fetchDiscogsUsername(accessToken, accessSecret);

      await _storeDiscogsData(accessToken, accessSecret, username);

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

  Future<String> _fetchDiscogsUsername(String token, String secret) async {
    try {
      final uri = Uri.parse('https://api.discogs.com/oauth/identity');
      final client = oauth1.Client(
        oauth1.SignatureMethods.hmacSha1,
        oauth1.ClientCredentials(_consumerKey, _consumerSecret),
        oauth1.Credentials(token, secret),
      );

      final response = await client.get(uri);
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        return data['username'] ?? '';
      } else {
        print('Discogs identity error: ${response.statusCode} => ${response.body}');
        return '';
      }
    } catch (e) {
      print('Error fetching Discogs username: $e');
      return '';
    }
  }

  Future<void> _storeDiscogsData(String token, String secret, String username) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) throw Exception('Not signed in');

    await FirebaseFirestore.instance.collection('users').doc(user.uid).update({
      'discogsAccessToken': token,
      'discogsTokenSecret': secret,
      'discogsUsername': username,
      'discogsLinked': true,
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Link Discogs')),
      body: BackgroundWidget(
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
                          RetroButton(
                            text: 'Relink Discogs Account',
                            color: Color(0xFF333333),
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
                            RetroButton(
                              text: 'Submit PIN',
                              color: Color(0xFF333333),
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