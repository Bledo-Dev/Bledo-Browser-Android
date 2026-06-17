import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';
import 'dart:io';
import 'package:path/path.dart' as p;
import 'package:dio/dio.dart';
import 'dart:math';
import 'privacy_logic.dart';
import 'doh_proxy.dart';
import 'package:flutter/foundation.dart';

class VpnLocation {
  final String name;
  final double lat;
  final double lng;
  VpnLocation({required this.name, required this.lat, required this.lng});

  Map<String, dynamic> toJson() => {'name': name, 'lat': lat, 'lng': lng};
  factory VpnLocation.fromJson(Map<String, dynamic> json) => VpnLocation(
    name: json['name'],
    lat: json['lat'],
    lng: json['lng'],
  );
}

class DownloadItem {
  final String id;
  String name;
  final String url;
  String path;
  final DateTime timestamp;
  double progress;
  bool isDownloading;
  String? error;

  DownloadItem({
    required this.id,
    required this.name,
    required this.url,
    required this.path,
    required this.timestamp,
    this.progress = 0.0,
    this.isDownloading = false,
    this.error,
  });

  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'url': url,
    'path': path,
    'timestamp': timestamp.toIso8601String(),
  };

  factory DownloadItem.fromJson(Map<String, dynamic> json) => DownloadItem(
    id: json['id'],
    name: json['name'],
    url: json['url'],
    path: json['path'],
    timestamp: DateTime.parse(json['timestamp']),
    isDownloading: false,
    progress: 1.0,
  );
}

class BrowserTab {
  final String id;
  String url;
  String title;
  bool isPrivate;
  String? proxyType;
  String? password;
  bool useBiometrics;
  bool isDesktopMode = false;
  bool isLoading = false;

  InAppWebViewController? webViewController;

  BrowserTab({
    required this.id,
    this.url = 'bledo://dashboard',
    this.title = 'New Tab',
    this.isPrivate = false,
    this.proxyType,
    this.password,
    this.useBiometrics = false,
  });
}

class AntiVirusRule {
  final String id;
  final String name;
  final String pattern;
  bool enabled;

  AntiVirusRule({required this.id, required this.name, required this.pattern, this.enabled = true});

  Map<String, dynamic> toJson() => {'id': id, 'name': name, 'pattern': pattern, 'enabled': enabled};
  factory AntiVirusRule.fromJson(Map<String, dynamic> json) => AntiVirusRule(
    id: json['id'],
    name: json['name'],
    pattern: json['pattern'],
    enabled: json['enabled'],
  );
}

class BrowserModel extends ChangeNotifier with WidgetsBindingObserver {
  List<BrowserTab> _tabs = [];
  int _currentTabIndex = 0;

  DohProxyServer? _dohProxy;
  int _dohPort = 0;

  // Settings
  bool _isVpnActive = false;
  int _selectedVpnLocationIndex = -1; // -1 for Random, -2 for Map
  double _customVpnLat = 0.0;
  double _customVpnLng = 0.0;

  final List<VpnLocation> _vpnLocations = [
    VpnLocation(name: 'New York, USA', lat: 40.7128, lng: -74.0060),
    VpnLocation(name: 'London, UK', lat: 51.5074, lng: -0.1278),
    VpnLocation(name: 'Tokyo, Japan', lat: 35.6762, lng: 139.6503),
    VpnLocation(name: 'Paris, France', lat: 48.8566, lng: 2.3522),
    VpnLocation(name: 'Berlin, Germany', lat: 52.5200, lng: 13.4050),
    VpnLocation(name: 'Sydney, Australia', lat: -33.8688, lng: 151.2093),
    VpnLocation(name: 'Dubai, UAE', lat: 25.2048, lng: 55.2708),
    VpnLocation(name: 'Singapore', lat: 1.3521, lng: 103.8198),
  ];

  bool _isAdBlockerEnabled = true;
  bool _isAntiVirusEnabled = true;
  bool _notificationsEnabled = false;
  bool _isHardenedMode = false;
  bool _isEnhancedSecurityEnabled = true;
  bool _isEnhancedPrivacyEnabled = true;
  String _currentTheme = 'Dark';
  String _currentLanguage = 'English';
  String _homepageUrl = 'bledo://dashboard';
  String _searchEngineBase = 'https://duckduckgo.com/?q=';

  static const _securityChannel = MethodChannel('com.bledo.browser/security');

  // Site Settings
  bool _allowLocation = false;
  bool _allowCamera = false;
  bool _allowMic = false;
  bool _allowJs = true;
  bool _allowCookies = true;

  String? _externalIntentUrl;
  String? get externalIntentUrl => _externalIntentUrl;

  List<Map<String, String>> _history = [];
  List<DownloadItem> _downloads = [];
  List<AntiVirusRule> _avRules = [
    AntiVirusRule(id: '1', name: 'Global Tracker Block', pattern: '.*tracker.*'),
    AntiVirusRule(id: '2', name: 'Analytic Shield', pattern: '.*analytics.*'),
    AntiVirusRule(id: '3', name: 'Fingerprint Protection', pattern: '.*fingerprint.*'),
  ];

  List<BrowserTab> get tabs => _tabs;
  int get currentTabIndex => _currentTabIndex;
  bool get isVpnActive => _isVpnActive;
  int get selectedVpnLocationIndex => _selectedVpnLocationIndex;
  double get customVpnLat => _customVpnLat;
  double get customVpnLng => _customVpnLng;
  List<VpnLocation> get vpnLocations => _vpnLocations;

  VpnLocation? get activeVpnLocation {
    if (!_isVpnActive) return null;
    if (_selectedVpnLocationIndex == -1) {
      return _vpnLocations[Random().nextInt(_vpnLocations.length)];
    }
    if (_selectedVpnLocationIndex == -2) {
      return VpnLocation(name: 'Custom Location', lat: _customVpnLat, lng: _customVpnLng);
    }
    if (_selectedVpnLocationIndex >= 0 && _selectedVpnLocationIndex < _vpnLocations.length) {
      return _vpnLocations[_selectedVpnLocationIndex];
    }
    return null;
  }

  bool get isAdBlockerEnabled => _isAdBlockerEnabled;
  bool get isAntiVirusEnabled => _isAntiVirusEnabled;
  bool get notificationsEnabled => _notificationsEnabled;
  bool get isHardenedMode => _isHardenedMode;
  bool get isEnhancedSecurityEnabled => _isEnhancedSecurityEnabled;
  bool get isEnhancedPrivacyEnabled => _isEnhancedPrivacyEnabled;
  String get currentTheme => _currentTheme;
  String get currentLanguage => _currentLanguage;
  String get homepageUrl => _homepageUrl;
  String get searchEngineBase => _searchEngineBase;

  bool get allowLocation => _allowLocation;
  bool get allowCamera => _allowCamera;
  bool get allowMic => _allowMic;
  bool get allowJs => _allowJs;
  bool get allowCookies => _allowCookies;

  List<AntiVirusRule> get avRules => _avRules;
  List<Map<String, String>> get history => _history;
  List<DownloadItem> get downloads => _downloads;

  BrowserTab get currentTab => _tabs[_currentTabIndex];

  BrowserModel() {
    WidgetsBinding.instance.addObserver(this);
    _loadData().then((_) {
      if (_tabs.isEmpty) {
        addTab();
      }
    });
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.paused) {
      if (_isHardenedMode) {
        _securityChannel.invokeMethod('clearClipboard');
      }
    }
  }

  Future<void> _loadData() async {
    final prefs = await SharedPreferences.getInstance();
    final historyJson = prefs.getString('history');
    if (historyJson != null) {
      _history = List<Map<String, String>>.from(json.decode(historyJson).map((item) => Map<String, String>.from(item)));
    }

    final downloadsJson = prefs.getString('downloads_v2');
    if (downloadsJson != null) {
      _downloads = List<DownloadItem>.from(json.decode(downloadsJson).map((item) => DownloadItem.fromJson(item)));
    }

    _isAdBlockerEnabled = prefs.getBool('adBlocker') ?? true;
    _isAntiVirusEnabled = prefs.getBool('antiVirus') ?? true;
    _isVpnActive = prefs.getBool('vpn') ?? false;
    _selectedVpnLocationIndex = prefs.getInt('vpnLocationIndex') ?? -1;
    _customVpnLat = prefs.getDouble('customVpnLat') ?? 0.0;
    _customVpnLng = prefs.getDouble('customVpnLng') ?? 0.0;
    _notificationsEnabled = prefs.getBool('notifications') ?? false;
    _isHardenedMode = prefs.getBool('hardenedMode') ?? false;
    _isEnhancedSecurityEnabled = prefs.getBool('enhancedSecurity') ?? true;
    _isEnhancedPrivacyEnabled = prefs.getBool('enhancedPrivacy') ?? true;
    _currentTheme = prefs.getString('theme') ?? 'Dark';
    _currentLanguage = prefs.getString('language') ?? 'English';
    _homepageUrl = prefs.getString('homepage') ?? 'bledo://dashboard';
    _searchEngineBase = prefs.getString('searchEngineBase') ?? 'https://duckduckgo.com/?q=';

    _allowLocation = prefs.getBool('allowLocation') ?? false;
    _allowCamera = prefs.getBool('allowCamera') ?? false;
    _allowMic = prefs.getBool('allowMic') ?? false;
    _allowJs = prefs.getBool('allowJs') ?? true;
    _allowCookies = prefs.getBool('allowCookies') ?? true;

    if (_isHardenedMode) {
      try {
        _dohProxy = DohProxyServer();
        _dohProxy!.start().then((port) {
          _dohPort = port;
          _syncProxy();
        }).catchError((e) {
          debugPrint("DohProxy start error: $e");
        });
      } catch (e) {
        debugPrint("DohProxy creation error: $e");
      }
      Future.delayed(const Duration(milliseconds: 500), () {
        _securityChannel.invokeMethod('setSecureMode', {'enabled': true}).catchError((e) {
          debugPrint("Error setting initial secure mode: $e");
        });
      });
    }

    final avRulesJson = prefs.getString('avRules');
    if (avRulesJson != null) {
      _avRules = List<AntiVirusRule>.from(json.decode(avRulesJson).map((item) => AntiVirusRule.fromJson(item)));
    }
    notifyListeners();
  }

  Future<void> _saveSettings() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('adBlocker', _isAdBlockerEnabled);
    await prefs.setBool('antiVirus', _isAntiVirusEnabled);
    await prefs.setBool('vpn', _isVpnActive);
    await prefs.setInt('vpnLocationIndex', _selectedVpnLocationIndex);
    await prefs.setDouble('customVpnLat', _customVpnLat);
    await prefs.setDouble('customVpnLng', _customVpnLng);
    await prefs.setBool('notifications', _notificationsEnabled);
    await prefs.setBool('hardenedMode', _isHardenedMode);
    await prefs.setBool('enhancedSecurity', _isEnhancedSecurityEnabled);
    await prefs.setBool('enhancedPrivacy', _isEnhancedPrivacyEnabled);
    await prefs.setString('theme', _currentTheme);
    await prefs.setString('language', _currentLanguage);
    await prefs.setString('homepage', _homepageUrl);
    await prefs.setString('searchEngineBase', _searchEngineBase);

    await prefs.setBool('allowLocation', _allowLocation);
    await prefs.setBool('allowCamera', _allowCamera);
    await prefs.setBool('allowMic', _allowMic);
    await prefs.setBool('allowJs', _allowJs);
    await prefs.setBool('allowCookies', _allowCookies);
  }

  Future<void> _saveHistory() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('history', json.encode(_history));
  }

  Future<void> _saveDownloads() async {
    final prefs = await SharedPreferences.getInstance();
    final completed = _downloads.where((d) => !d.isDownloading).toList();
    await prefs.setString('downloads_v2', json.encode(completed.map((e) => e.toJson()).toList()));
  }

  Future<void> _saveAVRules() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('avRules', json.encode(_avRules.map((e) => e.toJson()).toList()));
  }

  void setAdBlocker(bool enabled) { _isAdBlockerEnabled = enabled; _saveSettings(); notifyListeners(); }
  void setAntiVirus(bool enabled) { _isAntiVirusEnabled = enabled; _saveSettings(); notifyListeners(); }
  void setVpn(bool enabled) { _isVpnActive = enabled; _saveSettings(); notifyListeners(); }
  void setVpnLocation(int index) { _selectedVpnLocationIndex = index; _saveSettings(); notifyListeners(); }
  void setCustomVpnLocation(double lat, double lng) {
    _customVpnLat = lat;
    _customVpnLng = lng;
    _selectedVpnLocationIndex = -2;
    _saveSettings();
    notifyListeners();
  }
  void setNotifications(bool enabled) { _notificationsEnabled = enabled; _saveSettings(); notifyListeners(); }
  void setHardenedMode(bool enabled) async {
    if (_isHardenedMode == enabled) return;
    _isHardenedMode = enabled;
    _securityChannel.invokeMethod('setSecureMode', {'enabled': enabled}).catchError((e) => debugPrint("setSecureMode error: $e"));
    
    if (enabled) {
      try {
        _dohProxy = DohProxyServer();
        _dohPort = await _dohProxy!.start();
      } catch (e) {
        debugPrint("DohProxy start error: $e");
        _isHardenedMode = false; // Revert if failed to start
      }
    } else {
      try {
        await _dohProxy?.stop();
      } catch (e) {
        debugPrint("DohProxy stop error: $e");
      }
      _dohProxy = null;
      _dohPort = 0;
    }

    _saveSettings();
    _syncProxy();
    notifyListeners();
  }
  void setEnhancedSecurity(bool enabled) {
    _isEnhancedSecurityEnabled = enabled;
    _saveSettings();
    notifyListeners();
  }
  void setEnhancedPrivacy(bool enabled) {
    _isEnhancedPrivacyEnabled = enabled;
    _saveSettings();
    notifyListeners();
  }
  void setTheme(String theme) { _currentTheme = theme; _saveSettings(); notifyListeners(); }
  void setLanguage(String lang) { _currentLanguage = lang; _saveSettings(); notifyListeners(); }
  void setHomepage(String url) { _homepageUrl = url; _saveSettings(); notifyListeners(); }
  void setSearchEngine(String base) { _searchEngineBase = base; _saveSettings(); notifyListeners(); }

  void setAllowLocation(bool val) { _allowLocation = val; _saveSettings(); notifyListeners(); }
  void setAllowCamera(bool val) { _allowCamera = val; _saveSettings(); notifyListeners(); }
  void setAllowMic(bool val) { _allowMic = val; _saveSettings(); notifyListeners(); }
  void setAllowJs(bool val) { _allowJs = val; _saveSettings(); notifyListeners(); }
  void setAllowCookies(bool val) { _allowCookies = val; _saveSettings(); notifyListeners(); }

  void setExternalIntentUrl(String? url) {
    _externalIntentUrl = url;
    notifyListeners();
  }

  void openInFullBrowser() {
    if (_externalIntentUrl != null) {
      addTab(url: _externalIntentUrl);
      _externalIntentUrl = null;
      notifyListeners();
    }
  }

  void closeMiniBrowser() {
    _externalIntentUrl = null;
    notifyListeners();
    SystemNavigator.pop();
  }

  void toggleAVRule(int index) {
    _avRules[index].enabled = !_avRules[index].enabled;
    _saveAVRules();
    notifyListeners();
  }

  void toggleDesktopMode(int index) {
    if (index < _tabs.length) {
      _tabs[index].isDesktopMode = !_tabs[index].isDesktopMode;
      notifyListeners();
    }
  }

  void addTab({String? url, bool isPrivate = false, String? proxyType, String? password, bool useBiometrics = false}) {
    final id = DateTime.now().millisecondsSinceEpoch.toString();
    _tabs.add(BrowserTab(
      id: id,
      isPrivate: isPrivate,
      url: url ?? _homepageUrl,
      proxyType: proxyType,
      password: password,
      useBiometrics: useBiometrics,
    ));
    _currentTabIndex = _tabs.length - 1;
    _syncProxy();
    notifyListeners();
  }

  void closeTab(int index) {
    if (index < _tabs.length) {
      _tabs[index].webViewController = null; // Help GC
      _tabs.removeAt(index);
    }
    if (_currentTabIndex >= _tabs.length) {
      _currentTabIndex = _tabs.length - 1;
    }
    if (_tabs.isEmpty) {
      addTab();
    } else {
      _syncProxy();
    }
    notifyListeners();
  }

  void switchTab(int index) {
    _currentTabIndex = index;
    _syncProxy();
    notifyListeners();
  }

  Future<void> _syncProxy() async {
    try {
      String? proxyType;
      if (_tabs.isNotEmpty && _currentTabIndex < _tabs.length) {
        proxyType = _tabs[_currentTabIndex].proxyType;
      }
      await PrivacyLogic.applyProxy(proxyType, 9050, dohPort: _isHardenedMode ? _dohPort : 0);
    } catch (e) {
      debugPrint("SyncProxy error: $e");
    }
  }

  void updateTab(int index, String url) {
    if (index < _tabs.length) {
      if (_tabs[index].url != url && !url.contains('bledo.dashboard')) {
        _tabs[index].isDesktopMode = false;
      }
      _tabs[index].url = url;
      notifyListeners();
    }
  }

  void updateTabTitle(int index, String title, {bool isManualRename = false}) {
    if (index < _tabs.length) {
      _tabs[index].title = title;
      if (!isManualRename && !_tabs[index].isPrivate && _tabs[index].url.startsWith('http')) {
        addToHistory(title, _tabs[index].url);
      }
      notifyListeners();
    }
  }

  void renameTab(int index, String newTitle) {
    updateTabTitle(index, newTitle, isManualRename: true);
  }

  void addToHistory(String title, String url) {
    if (_history.isNotEmpty && _history.first['url'] == url) return;
    _history.insert(0, {'title': title, 'url': url});
    if (_history.length > 100) _history.removeLast();
    _saveHistory();
    notifyListeners();
  }

  void startDownload(String name, String url, String path, {String? userAgent, String? cookies}) async {
    final id = DateTime.now().millisecondsSinceEpoch.toString();
    final item = DownloadItem(
      id: id,
      name: name,
      url: url,
      path: path,
      timestamp: DateTime.now(),
      isDownloading: true,
      progress: 0.0,
    );
    _downloads.insert(0, item);
    notifyListeners();

    try {
      final dio = Dio(BaseOptions(
        connectTimeout: const Duration(seconds: 30),
        receiveTimeout: const Duration(minutes: 60),
      ));
      
      // Direct Download (Tor removed)

      await dio.download(
        url,
        path,
        options: Options(
          headers: {
            if (userAgent != null) 'User-Agent': userAgent,
            if (cookies != null) 'Cookie': cookies,
          },
        ),
        onReceiveProgress: (received, total) {
          if (total != -1) {
            item.progress = received / total;
          } else {
            item.progress = -1; // Indeterminate
          }
          notifyListeners();
        },
      );
      item.isDownloading = false;
      item.progress = 1.0;
      item.error = null;
      _saveDownloads();
      notifyListeners();
    } catch (e) {
      debugPrint("DEBUG: Download error for $name: $e");
      item.isDownloading = false;
      item.error = "Download Failed: ${e.toString()}";
      notifyListeners();
    }
  }

  Future<void> renameDownload(int index, String newName) async {
    if (index >= _downloads.length) return;
    final item = _downloads[index];
    final oldFile = File(item.path);
    final directory = oldFile.parent.path;
    final newPath = p.join(directory, newName);

    if (await oldFile.exists()) {
      await oldFile.rename(newPath);
    }

    item.name = newName;
    item.path = newPath;
    _saveDownloads();
    notifyListeners();
  }

  Future<void> deleteDownloadPermanently(int index) async {
    final item = _downloads[index];
    final file = File(item.path);
    if (await file.exists()) {
      await file.delete();
    }
    _downloads.removeAt(index);
    _saveDownloads();
    notifyListeners();
  }

  Future<void> moveDownloadToTrash(int index) async {
    final item = _downloads[index];
    final file = File(item.path);
    if (await file.exists()) {
      await file.delete();
    }
    _downloads.removeAt(index);
    _saveDownloads();
    notifyListeners();
  }

  void clearHistory() {
    _history.clear();
    _saveHistory();
    notifyListeners();
  }

  void clearDownloads() {
    _downloads.clear();
    _saveDownloads();
    notifyListeners();
  }

  Future<void> deleteAllData() async {
    await InAppWebViewController.clearAllCache();
    await CookieManager.instance().deleteAllCookies();
    _history.clear();
    await _saveHistory();
    _downloads.clear();
    await _saveDownloads();
    notifyListeners();
  }
}
