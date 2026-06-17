import 'package:flutter/material.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';
import 'package:provider/provider.dart';
import 'browser_model.dart';
import 'privacy_logic.dart';
import 'bledo_notification.dart';
import 'package:local_auth/local_auth.dart';
import 'package:path_provider/path_provider.dart';
import 'dart:io';
import 'dart:collection';
import 'package:path/path.dart' as p;
import 'package:permission_handler/permission_handler.dart';
import 'browser_screen.dart';

class WebViewTab extends StatefulWidget {
  final int tabIndex;

  const WebViewTab({required Key key, required this.tabIndex}) : super(key: key);

  @override
  _WebViewTabState createState() => _WebViewTabState();
}

class _WebViewTabState extends State<WebViewTab> {
  double _progress = 0;
  bool _isLocked = false;
  bool _biometricVerified = false;
  bool _passwordVerified = false;
  final TextEditingController _passwordController = TextEditingController();
  PullToRefreshController? _pullToRefreshController;
  final LocalAuthentication _auth = LocalAuthentication();

  @override
  void initState() {
    super.initState();
    _checkLockState();
    _initPullToRefresh();
  }

  void _checkLockState() {
    final model = Provider.of<BrowserModel>(context, listen: false);
    if (widget.tabIndex < model.tabs.length) {
      final tab = model.tabs[widget.tabIndex];
      if (tab.isPrivate && (tab.password != null || tab.useBiometrics)) {
        _isLocked = true;
        _biometricVerified = false;
        _passwordVerified = false;
        _passwordController.clear();
      }
    }
  }

  Future<void> _authenticateBiometric(BrowserTab tab) async {
    try {
      bool authenticated = await _auth.authenticate(
        localizedReason: 'Scan fingerprint to unlock private tab',
        options: const AuthenticationOptions(stickyAuth: true, biometricOnly: true),
      );
      if (authenticated) {
        setState(() {
          _biometricVerified = true;
          _checkUnlockStatus(tab);
        });
      }
    } catch (e) {
      BledoNotification.show(context, 'Biometric Error: $e');
    }
  }

  void _checkUnlockStatus(BrowserTab tab) {
    bool needsBio = tab.useBiometrics;
    bool needsPass = tab.password != null;

    if ((!needsBio || _biometricVerified) && (!needsPass || _passwordVerified)) {
      setState(() {
        _isLocked = false;
        _passwordController.clear();
      });
    }
  }

  void _initPullToRefresh() {
    _pullToRefreshController = PullToRefreshController(
      settings: PullToRefreshSettings(
        color: Colors.blueAccent,
        backgroundColor: const Color(0xFF1E222B),
      ),
      onRefresh: () async {
        final model = Provider.of<BrowserModel>(context, listen: false);
        if (widget.tabIndex < model.tabs.length) {
          final tab = model.tabs[widget.tabIndex];
          if (tab.url == 'bledo://dashboard' || tab.url.contains('bledo.dashboard')) {
            _pullToRefreshController?.endRefreshing();
          } else {
            tab.webViewController?.reload();
          }
        }
      },
    );
  }

  @override
  void dispose() {
    _pullToRefreshController = null;
    final model = Provider.of<BrowserModel>(context, listen: false);
    if (widget.tabIndex < model.tabs.length) {
      model.tabs[widget.tabIndex].webViewController = null;
    }
    _passwordController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final model = Provider.of<BrowserModel>(context);
    if (widget.tabIndex >= model.tabs.length) return const SizedBox.shrink();

    final tab = model.tabs[widget.tabIndex];

    // AUTO-LOCK LOGIC: If we are NOT the current tab, reset verification and lock
    if (model.currentTabIndex != widget.tabIndex && (tab.password != null || tab.useBiometrics)) {
      if (!_isLocked) {
        _isLocked = true;
        _biometricVerified = false;
        _passwordVerified = false;
        _passwordController.clear();
      }
    }

    if (_isLocked && model.currentTabIndex == widget.tabIndex) {
      bool needsBio = tab.useBiometrics;
      bool needsPass = tab.password != null;

      return Scaffold(
        backgroundColor: const Color(0xFF1E1B4B),
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(32.0),
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: const BoxDecoration(color: Colors.blue, shape: BoxShape.circle),
                    child: const Icon(Icons.security, color: Colors.white, size: 64),
                  ),
                  const SizedBox(height: 24),
                  const Text('Private Tab Locked', style: TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 12),
                  const Text('Multi-Factor Verification Required', style: TextStyle(color: Colors.grey, fontSize: 14)),
                  const SizedBox(height: 32),

                  if (needsBio) ...[
                    Opacity(
                      opacity: _biometricVerified ? 0.3 : 1.0,
                      child: Column(
                        children: [
                          IconButton(
                            icon: Icon(
                              _biometricVerified ? Icons.check_circle : Icons.fingerprint,
                              color: _biometricVerified ? Colors.green : Colors.purpleAccent,
                              size: 80
                            ),
                            onPressed: _biometricVerified ? null : () => _authenticateBiometric(tab),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            _biometricVerified ? 'Fingerprint Verified' : 'Step 1: Scan Fingerprint',
                            style: TextStyle(color: _biometricVerified ? Colors.green : Colors.purpleAccent, fontSize: 12)
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 32),
                  ],

                  if (needsPass) ...[
                    Opacity(
                      opacity: _passwordVerified ? 0.3 : 1.0,
                      child: Column(
                        children: [
                          if (!needsBio) const Text('Step 1: Enter Password', style: TextStyle(color: Colors.grey, fontSize: 12)),
                          if (needsBio) Text('Step 2: Enter Password', style: TextStyle(color: _biometricVerified ? Colors.purpleAccent : Colors.grey, fontSize: 12)),
                          const SizedBox(height: 16),
                          TextField(
                            controller: _passwordController,
                            obscureText: true,
                            enabled: !needsBio || _biometricVerified,
                            style: const TextStyle(color: Colors.white),
                            textAlign: TextAlign.center,
                            decoration: InputDecoration(
                              hintText: 'Password',
                              hintStyle: const TextStyle(color: Colors.grey),
                              filled: true,
                              fillColor: Colors.white.withOpacity(0.05),
                              border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                              enabledBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12),
                                borderSide: BorderSide(color: (!needsBio || _biometricVerified) ? Colors.purpleAccent : Colors.grey, width: 1)
                              ),
                            ),
                          ),
                          const SizedBox(height: 24),
                          SizedBox(
                            width: double.infinity,
                            height: 50,
                            child: ElevatedButton(
                              onPressed: (!needsBio || _biometricVerified) ? () {
                                if (_passwordController.text == tab.password) {
                                  setState(() {
                                    _passwordVerified = true;
                                    _checkUnlockStatus(tab);
                                  });
                                } else {
                                  BledoNotification.show(context, 'Incorrect Password');
                                  _passwordController.clear();
                                }
                              } : null,
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.purpleAccent,
                                disabledBackgroundColor: Colors.grey[800],
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))
                              ),
                              child: const Text('Verify Password', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ),
      );
    }

    return Stack(
      children: [
        InAppWebView(
          initialUrlRequest: tab.url == 'bledo://dashboard' ? null : URLRequest(url: WebUri(tab.url)),
          initialData: tab.url == 'bledo://dashboard'
              ? InAppWebViewInitialData(
                  data: PrivacyLogic.getDashboardHtml(
                    isPrivate: tab.isPrivate,
                    proxyType: tab.proxyType,
                    currentEngine: model.searchEngineBase
                  ),
                  baseUrl: WebUri("https://bledo.dashboard")
                )
              : null,
          initialSettings: PrivacyLogic.getWebViewSettings(
            isPrivate: tab.isPrivate,
            adBlockEnabled: model.isAdBlockerEnabled,
            antiVirusEnabled: model.isAntiVirusEnabled,
            avRules: model.avRules,
            allowJs: model.allowJs,
            allowCookies: model.allowCookies,
            allowLocation: model.allowLocation,
            isDesktopMode: tab.isDesktopMode,
            vpnActive: model.isVpnActive,
            isHardenedMode: model.isHardenedMode,
            isEnhancedPrivacyEnabled: model.isEnhancedPrivacyEnabled,
          ),
          initialUserScripts: UnmodifiableListView<UserScript>([
            ...(model.isVpnActive ? PrivacyLogic.getVpnUserScripts(model.activeVpnLocation) ?? [] : []),
            ...(model.isEnhancedSecurityEnabled ? PrivacyLogic.getHardeningScripts() : []),
            ...(model.isEnhancedPrivacyEnabled ? PrivacyLogic.getEnhancedPrivacyScripts() : []),
          ]),
          pullToRefreshController: _pullToRefreshController,
          onWebViewCreated: (controller) async {
            tab.webViewController = controller;

            controller.addJavaScriptHandler(handlerName: 'onNavigate', callback: (args) {
              if (args.isEmpty) return;
              String val = args[0];
              String? searchBase = args.length > 1 ? args[1] : model.searchEngineBase;
              String formatted = PrivacyLogic.formatSearchUrl(val, searchBase: searchBase);
              controller.loadUrl(urlRequest: URLRequest(url: WebUri(formatted)));
            });
            controller.addJavaScriptHandler(handlerName: 'onEngineChange', callback: (args) {
              if (args.isNotEmpty) {
                model.setSearchEngine(args[0].toString());
              }
            });
          },
          shouldOverrideUrlLoading: (controller, navigationAction) async {
            var uri = navigationAction.request.url;
            if (uri != null && uri.scheme == "bledo-nav") {
              String path = Uri.decodeComponent(uri.host + uri.path);
              if (path.contains("bledo://dashboard")) {
                model.updateTab(widget.tabIndex, 'bledo://dashboard');
                controller.loadData(
                  data: PrivacyLogic.getDashboardHtml(
                    isPrivate: tab.isPrivate,
                    proxyType: tab.proxyType,
                    currentEngine: model.searchEngineBase
                  ),
                  baseUrl: WebUri("https://bledo.dashboard")
                );
              } else {
                String? searchBase = uri.queryParameters['search'] ?? model.searchEngineBase;
                String formattedUrl = PrivacyLogic.formatSearchUrl(path, searchBase: searchBase);
                controller.loadUrl(urlRequest: URLRequest(url: WebUri(formattedUrl)));
              }
              return NavigationActionPolicy.CANCEL;
            }
            return NavigationActionPolicy.ALLOW;
          },
          onLoadStart: (controller, url) {
            if (url != null) {
              String urlStr = url.toString();
              if (urlStr != 'about:blank' && !urlStr.startsWith('data:text/html') && urlStr != 'https://bledo.dashboard/') {
                model.updateTab(widget.tabIndex, urlStr);
              }
            }
          },
          onLoadStop: (controller, url) async {
            _pullToRefreshController?.endRefreshing();
            if (url != null) {
              final title = await controller.getTitle();
              if (title != null && title.isNotEmpty) {
                model.updateTabTitle(widget.tabIndex, title);
              }
            }
          },
          onProgressChanged: (controller, progress) {
            if (progress == 100) _pullToRefreshController?.endRefreshing();
            setState(() {
              _progress = progress / 100;
            });
          },
          onReceivedError: (controller, request, error) {
            _pullToRefreshController?.endRefreshing();
          },
          onGeolocationPermissionsShowPrompt: (controller, origin) async {
            final model = Provider.of<BrowserModel>(context, listen: false);
            if (model.isVpnActive) {
              return GeolocationPermissionShowPromptResponse(origin: origin, allow: true, retain: true);
            }
            return null;
          },
          onDownloadStartRequest: (controller, downloadStartRequest) async {
            if (Platform.isAndroid) {
               await [Permission.storage, Permission.manageExternalStorage].request();
            }

            final url = downloadStartRequest.url.toString();
            String fileName = downloadStartRequest.suggestedFilename ?? p.basename(url);

            if (fileName.endsWith('.bin')) {
               if (url.toLowerCase().contains('.apk') || downloadStartRequest.mimeType == 'application/vnd.android.package-archive') {
                 fileName = fileName.replaceAll('.bin', '.apk');
               }
            }

            String savePath = '';
            if (Platform.isAndroid) {
               savePath = p.join('/storage/emulated/0/Download', fileName);
            } else {
               final dir = await getApplicationDocumentsDirectory();
               savePath = p.join(dir.path, fileName);
            }

            // Sync cookies for the download
            CookieManager cookieManager = CookieManager.instance();
            List<Cookie> cookies = await cookieManager.getCookies(url: downloadStartRequest.url);
            String cookieString = cookies.map((c) => "${c.name}=${c.value}").join("; ");

            model.startDownload(
              fileName, 
              url, 
              savePath, 
              userAgent: downloadStartRequest.userAgent,
              cookies: cookieString.isNotEmpty ? cookieString : null,
            );
            
            BledoNotification.show(
              context, 
              'Download started: $fileName', 
              actionLabel: 'DETAILS', 
              onAction: () {
                Navigator.push(context, MaterialPageRoute(builder: (context) => const DownloadsPage()));
              }
            );
          },
        ),
        if (_progress < 1.0 && tab.url != 'bledo://dashboard' && tab.url != 'https://bledo.dashboard/')
          LinearProgressIndicator(
            value: _progress,
            backgroundColor: Colors.transparent,
            valueColor: const AlwaysStoppedAnimation<Color>(Colors.blue),
          ),
      ],
    );
  }
}
