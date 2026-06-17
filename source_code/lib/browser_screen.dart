import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'browser_model.dart';
import 'webview_tab.dart';
import 'mini_browser.dart';
import 'privacy_logic.dart';
import 'bledo_notification.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:open_file/open_file.dart';
import 'package:local_auth/local_auth.dart';
import 'package:window_manager/window_manager.dart';
import 'dart:io';

class BrowserScreen extends StatefulWidget {
  const BrowserScreen({super.key});

  @override
  _BrowserScreenState createState() => _BrowserScreenState();
}

class _BrowserScreenState extends State<BrowserScreen> {
  final TextEditingController _urlController = TextEditingController();
  final FocusNode _urlFocusNode = FocusNode();
  bool _isSearchFocused = false;
  List<Map<String, String>> _filteredHistory = [];

  @override
  void initState() {
    super.initState();
    _urlFocusNode.addListener(() {
      setState(() {
        _isSearchFocused = _urlFocusNode.hasFocus;
        if (!_isSearchFocused) {
          _filteredHistory = [];
        }
      });
    });
  }

  void _onSearchChanged(String query, BrowserModel model) {
    if (query.isEmpty) {
      setState(() => _filteredHistory = []);
      return;
    }

    final filtered = model.history.where((item) {
      final title = item['title']?.toLowerCase() ?? '';
      final url = item['url']?.toLowerCase() ?? '';
      return title.contains(query.toLowerCase()) || url.contains(query.toLowerCase());
    }).toList();

    setState(() {
      _filteredHistory = filtered;
    });
  }

  void _submitSearch(String value, BrowserModel model) {
    _urlFocusNode.unfocus();
    String formatted = PrivacyLogic.formatSearchUrl(value);
    model.currentTab.webViewController?.loadUrl(urlRequest: URLRequest(url: WebUri(formatted)));
  }

  void _showMenu(BuildContext context, BrowserModel model) {
    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF111318).withOpacity(0.9),
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (context) {
        final currentTab = model.currentTab;
        return ListView(
          shrinkWrap: true,
          padding: const EdgeInsets.symmetric(vertical: 20),
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                _circularMenuBtn(context, Icons.refresh, 'Refresh', () {
                  model.currentTab.webViewController?.reload();
                  Navigator.pop(context);
                }),
                _circularMenuBtn(context, Icons.arrow_back, 'Undo', () {
                  model.currentTab.webViewController?.goBack();
                  Navigator.pop(context);
                }),
                _circularMenuBtn(context, Icons.arrow_forward, 'Redo', () {
                  model.currentTab.webViewController?.goForward();
                  Navigator.pop(context);
                }),
              ],
            ),
            const Divider(color: Colors.grey, height: 30),
            _menuTile(
              context, 
              Icons.computer, 
              'Desktop Screen', 
              () {
                model.toggleDesktopMode(model.currentTabIndex);
                model.currentTab.webViewController?.reload();
                Navigator.pop(context);
              },
              trailing: Switch(
                value: currentTab.isDesktopMode,
                onChanged: (val) {
                  model.toggleDesktopMode(model.currentTabIndex);
                  model.currentTab.webViewController?.reload();
                  Navigator.pop(context);
                },
                activeColor: Colors.blueAccent,
              )
            ),
            _menuTile(context, Icons.settings, 'Bledo Settings', () => _navigateTo(context, const SettingsPage())),
            _menuTile(context, Icons.history, 'History', () => _navigateTo(context, const HistoryPage())),
            _menuTile(context, Icons.download, 'Downloads', () => _navigateTo(context, const DownloadsPage())),
            _menuTile(context, Icons.security, 'New Private Tab', () {
              Navigator.pop(context);
              showPrivateTabDialog(context, model);
            }),
            _menuTile(context, Icons.add_box, 'New Tab', () {
              model.addTab();
              Navigator.pop(context);
            }),
            _menuTile(context, Icons.delete_forever, 'Delete browsing history', () {
              model.clearHistory();
              Navigator.pop(context);
              BledoNotification.show(context, 'History cleared');
            }),
            _menuTile(context, Icons.info, 'About Bledo', () => _showAbout(context)),
          ],
        );
      },
    );
  }

  Widget _circularMenuBtn(BuildContext context, IconData icon, String label, Function() onTap) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        IconButton(
          icon: Icon(icon, color: Colors.blueAccent),
          onPressed: onTap,
          style: IconButton.styleFrom(backgroundColor: const Color(0xFF1E222B)),
        ),
        Text(label, style: const TextStyle(color: Colors.white, fontSize: 10)),
      ],
    );
  }

  Widget _menuTile(BuildContext context, IconData icon, String title, Function() onTap, {Widget? trailing}) {
    return ListTile(
      leading: Icon(icon, color: Colors.blueAccent),
      title: Text(title, style: const TextStyle(color: Colors.white)),
      trailing: trailing,
      onTap: onTap,
    );
  }

  void _navigateTo(BuildContext context, Widget page) {
    Navigator.pop(context);
    Navigator.push(context, MaterialPageRoute(builder: (context) => page));
  }

  void _showAbout(BuildContext context) {
    Navigator.pop(context);
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF1E222B),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 80,
              height: 80,
              decoration: const BoxDecoration(color: Colors.blueAccent, shape: BoxShape.circle),
              child: const Icon(Icons.security, size: 50, color: Colors.white),
            ),
            const SizedBox(height: 16),
            const Text('Bledo Browser', style: TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.bold)),
            const Text('Version 1.0.0', style: TextStyle(color: Colors.grey, fontSize: 14)),
            const SizedBox(height: 20),
            const Text(
              "A fast, secure, and privacy-focused browser.",
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.white70),
            ),
            const Divider(color: Colors.grey, height: 32),
            const Text('CREATOR', style: TextStyle(color: Colors.blueAccent, fontSize: 12, fontWeight: FontWeight.bold, letterSpacing: 1.2)),
            const SizedBox(height: 8),
            const Text('Woopskidds', style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w500)),
            const SizedBox(height: 12),
            ElevatedButton.icon(
              onPressed: () => _launchURL('https://m.youtube.com/@Woopskidd'),
              icon: const Icon(Icons.play_circle_fill, color: Colors.white),
              label: const Text('Visit YouTube Channel'),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.redAccent,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30)),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('CLOSE', style: TextStyle(color: Colors.blueAccent)),
          ),
        ],
      ),
    );
  }

  Future<void> _launchURL(String url) async {
    final uri = Uri.parse(url);
    if (!await launchUrl(uri, mode: LaunchMode.externalApplication)) {
      if (mounted) {
        BledoNotification.show(context, 'Could not launch $url');
      }
    }
  }

  static void showPrivateTabDialog(BuildContext context, BrowserModel model) {
    String? selectedProxy;
    bool useBiometrics = false;
    final passwordController = TextEditingController();
    final LocalAuthentication auth = LocalAuthentication();

    showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setState) {
            return AlertDialog(
              backgroundColor: const Color(0xFF1E1B4B),
              title: const Text('Open Private Tab', style: TextStyle(color: Colors.white)),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Text('Secure your private session with optional biometric locking:', style: TextStyle(color: Colors.grey, fontSize: 14)),
                    const SizedBox(height: 10),
                    CheckboxListTile(
                      title: const Text('Use Fingerprint', style: TextStyle(color: Colors.white, fontSize: 14)),
                      value: useBiometrics,
                      onChanged: (val) async {
                        if (val == true) {
                          try {
                            bool authenticated = await auth.authenticate(
                              localizedReason: 'Verify your fingerprint to secure this tab',
                              options: const AuthenticationOptions(stickyAuth: true, biometricOnly: true),
                            );
                            if (authenticated) {
                              setState(() => useBiometrics = true);
                            } else {
                              setState(() => useBiometrics = false);
                            }
                          } catch (e) {
                            BledoNotification.show(context, 'Fingerprint not supported: $e');
                            setState(() => useBiometrics = false);
                          }
                        } else {
                          setState(() => useBiometrics = false);
                        }
                      },
                      activeColor: Colors.purpleAccent,
                      checkColor: Colors.white,
                      controlAffinity: ListTileControlAffinity.leading,
                    ),
                    const SizedBox(height: 10),
                    TextField(
                      controller: passwordController,
                      obscureText: true,
                      style: const TextStyle(color: Colors.white),
                      decoration: const InputDecoration(
                        hintText: 'Enter password (optional)',
                        hintStyle: TextStyle(color: Colors.grey, fontSize: 14),
                        enabledBorder: UnderlineInputBorder(borderSide: BorderSide(color: Colors.purpleAccent)),
                      ),
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
                TextButton(
                  onPressed: () {
                    model.addTab(
                      isPrivate: true, 
                      proxyType: selectedProxy, 
                      password: passwordController.text.isEmpty ? null : passwordController.text,
                      useBiometrics: useBiometrics,
                    );
                    Navigator.pop(context);
                  },
                  child: const Text('Open'),
                ),
              ],
            );
          }
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final model = Provider.of<BrowserModel>(context);
    if (model.tabs.isEmpty) return const Scaffold(body: Center(child: CircularProgressIndicator()));
    
    final currentTab = model.currentTab;

    if (!_urlFocusNode.hasFocus) {
      _urlController.text = (currentTab.url == 'Bledo://dashboard' || currentTab.url == 'https://Bledo.dashboard/') ? '' : currentTab.url;
    }

    bool isDesktop = Platform.isWindows || Platform.isMacOS || Platform.isLinux;

    if (isDesktop) {
      return _buildDesktopLayout(context, model, currentTab);
    }

    return _buildMobileLayout(context, model, currentTab);
  }

  Widget _buildDesktopLayout(BuildContext context, BrowserModel model, BrowserTab currentTab) {
    return Scaffold(
      backgroundColor: const Color(0xFF0F1116),
      body: Column(
        children: [
          // 0. CUSTOM WINDOW TITLE BAR
          _buildCustomTitleBar(context, model),
          
          Expanded(
            child: Row(
              children: [
                // 1. VERTICAL SIDEBAR
                _buildSidebar(context, model, currentTab),

                // 2. MAIN CONTENT AREA
                Expanded(
                  child: Column(
                    children: [
                      // NAVIGATION TOOLBAR
                      _buildToolbar(context, model, currentTab),

                      // WEBVIEW
                      Expanded(
                        child: IndexedStack(
                          index: model.currentTabIndex,
                          children: model.tabs.map((tab) => WebViewTab(key: ValueKey(tab.id), tabIndex: model.tabs.indexOf(tab))).toList(),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCustomTitleBar(BuildContext context, BrowserModel model) {
    return DragToMoveArea(
      child: Container(
        height: 44,
        color: const Color(0xFF111318),
        child: Row(
          children: [
            const SizedBox(width: 80), // Offset for sidebar alignment or logo
            // TABS AREA
            Expanded(
              child: ListView.builder(
                scrollDirection: Axis.horizontal,
                itemCount: model.tabs.length + 1,
                itemBuilder: (context, index) {
                  if (index == model.tabs.length) {
                    return IconButton(
                      icon: const Icon(Icons.add, color: Colors.white70, size: 18),
                      onPressed: () => model.addTab(),
                      padding: EdgeInsets.zero,
                    );
                  }
                  final tab = model.tabs[index];
                  final isSelected = model.currentTabIndex == index;
                  return GestureDetector(
                  onTap: () => model.switchTab(index),
                    onSecondaryTap: () => _showTabContextMenu(context, model, index),
                    child: Container(
                      margin: const EdgeInsets.only(top: 6, right: 4),
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      decoration: BoxDecoration(
                        color: isSelected ? const Color(0xFF1E222B) : Colors.transparent,
                        borderRadius: const BorderRadius.vertical(top: Radius.circular(10)),
                        border: isSelected ? const Border(top: BorderSide(color: Colors.blueAccent, width: 2)) : null,
                      ),
                      child: Row(
                        children: [
                          Icon(tab.isPrivate ? Icons.security : Icons.public, color: isSelected ? Colors.blueAccent : Colors.grey, size: 14),
                          const SizedBox(width: 8),
                          SizedBox(
                            width: 100,
                            child: Text(
                              tab.title, 
                              style: TextStyle(color: isSelected ? Colors.white : Colors.grey, fontSize: 11, fontWeight: isSelected ? FontWeight.bold : FontWeight.normal),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          GestureDetector(
                            onTap: () => model.closeTab(index),
                            child: const Icon(Icons.close, color: Colors.white30, size: 14),
                          ),
                        ],
                      ),
                    ),
                  );
                },
              ),
            ),
            // WINDOW CONTROLS
            _buildWindowControls(),
          ],
        ),
      ),
    );
  }

  Widget _buildWindowControls() {
    return Row(
      children: [
        _controlBtn(Icons.minimize, () => windowManager.minimize()),
        _controlBtn(Icons.crop_square, () async {
          if (await windowManager.isMaximized()) {
            windowManager.unmaximize();
          } else {
            windowManager.maximize();
          }
        }),
        _controlBtn(Icons.close, () => windowManager.close(), isClose: true),
      ],
    );
  }

  Widget _controlBtn(IconData icon, VoidCallback onTap, {bool isClose = false}) {
    return InkWell(
      onTap: onTap,
      hoverColor: isClose ? Colors.red : Colors.white10,
      child: SizedBox(
        width: 46,
        height: 44,
        child: Icon(icon, color: Colors.white70, size: 16),
      ),
    );
  }

  void _showTabContextMenu(BuildContext context, BrowserModel model, int index) {
    final RenderBox overlay = Overlay.of(context).context.findRenderObject() as RenderBox;
    showMenu(
      context: context,
      position: RelativeRect.fromRect(
        Rect.fromPoints(Offset.zero, Offset.zero), // Approximate
        Offset.zero & overlay.size,
      ),
      color: const Color(0xFF1E222B),
      items: [
        PopupMenuItem(
          onTap: () => Future.delayed(Duration.zero, () => _showRenameDialog(context, model, index)),
          child: const Text("Rename Tab", style: TextStyle(color: Colors.white)),
        ),
        PopupMenuItem(
          onTap: () => model.closeTab(index),
          child: const Text("Close Tab", style: TextStyle(color: Colors.redAccent)),
        ),
      ],
    );
  }

  void _showRenameDialog(BuildContext context, BrowserModel model, int index) {
    final controller = TextEditingController(text: model.tabs[index].title);
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF111318),
        title: const Text("Rename Tab", style: TextStyle(color: Colors.white)),
        content: TextField(
          controller: controller,
          autofocus: true,
          style: const TextStyle(color: Colors.white),
          decoration: const InputDecoration(
            hintText: "Enter new title",
            hintStyle: TextStyle(color: Colors.grey),
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text("Cancel")),
          ElevatedButton(
            onPressed: () {
              model.renameTab(index, controller.text);
              Navigator.pop(context);
            },
            child: const Text("Rename"),
          ),
        ],
      ),
    );
  }

  Widget _buildSidebar(BuildContext context, BrowserModel model, BrowserTab currentTab) {
    return Container(
      width: 70,
      color: const Color(0xFF161920),
      child: Column(
        children: [
          const SizedBox(height: 10),
          // Home Button (Maroon)
          GestureDetector(
            onTap: () {
              model.updateTab(model.currentTabIndex, 'Bledo://dashboard');
              currentTab.webViewController?.loadData(
                data: PrivacyLogic.getDashboardHtml(isPrivate: currentTab.isPrivate, proxyType: currentTab.proxyType),
                baseUrl: WebUri("https://Bledo.dashboard")
              );
            },
            child: Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: const Color(0xFF450A0A), 
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Icon(Icons.home_filled, color: Colors.white, size: 24),
            ),
          ),
          const Spacer(),
          IconButton(icon: const Icon(Icons.security, color: Colors.green), onPressed: () => showPrivateTabDialog(context, model)),
          IconButton(icon: const Icon(Icons.settings, color: Colors.grey), onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (context) => const SettingsPage()))),
          const SizedBox(height: 20),
        ],
      ),
    );
  }

  Widget _buildToolbar(BuildContext context, BrowserModel model, BrowserTab currentTab) {
    return Container(
      color: const Color(0xFF111318),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      child: Row(
        children: [
          IconButton(icon: const Icon(Icons.arrow_back, color: Colors.white70, size: 18), onPressed: () => currentTab.webViewController?.goBack()),
          IconButton(icon: const Icon(Icons.arrow_forward, color: Colors.white70, size: 18), onPressed: () => currentTab.webViewController?.goForward()),
          IconButton(icon: const Icon(Icons.refresh, color: Colors.white70, size: 18), onPressed: () => currentTab.webViewController?.reload()),
          const SizedBox(width: 12),
          Expanded(
            child: Container(
              height: 36,
              decoration: BoxDecoration(
                color: const Color(0xFF1E222B),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Row(
                children: [
                  const SizedBox(width: 12),
                  const Icon(Icons.search, color: Colors.white30, size: 14),
                  const SizedBox(width: 10),
                  Expanded(
                    child: TextField(
                      controller: _urlController,
                      focusNode: _urlFocusNode,
                      style: const TextStyle(color: Colors.white, fontSize: 13),
                      decoration: const InputDecoration(
                        hintText: "Search the Web...",
                        hintStyle: TextStyle(color: Colors.white24),
                        border: InputBorder.none,
                        isDense: true,
                      ),
                      onSubmitted: (val) => _submitSearch(val, model),
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(width: 12),
          IconButton(icon: const Icon(Icons.more_vert, color: Colors.white70, size: 18), onPressed: () => _showMenu(context, model)),
        ],
      ),
    );
  }

  Widget _buildMobileLayout(BuildContext context, BrowserModel model, BrowserTab currentTab) {
    Color bgColor = const Color(0xFF111318);
    Color appBarColor = const Color(0xFF1E222B);
    if (currentTab.isPrivate) {
      bgColor = const Color(0xFF1E1B4B);
      appBarColor = const Color(0xFF2E1065);
    } else {
      switch (model.currentTheme) {
        case 'Blue': bgColor = const Color(0xFF0F172A); appBarColor = const Color(0xFF1E293B); break;
        case 'Light': bgColor = Colors.white; appBarColor = Colors.grey[200]!; break;
        case 'Green': bgColor = const Color(0xFF064E3B); appBarColor = const Color(0xFF065F46); break;
      }
    }

    return Scaffold(
      backgroundColor: bgColor,
      appBar: AppBar(
        backgroundColor: appBarColor,
        elevation: 0,
        title: AnimatedContainer(
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeInOut,
          width: _isSearchFocused ? MediaQuery.of(context).size.width : MediaQuery.of(context).size.width * 0.7,
          padding: const EdgeInsets.symmetric(horizontal: 12),
          decoration: BoxDecoration(
            color: currentTab.isPrivate ? const Color(0xFF4C1D95).withOpacity(0.3) : const Color(0xFF282C37),
            borderRadius: BorderRadius.circular(10),
            border: currentTab.isPrivate ? Border.all(color: Colors.purpleAccent.withOpacity(0.5)) : null,
          ),
          child: TextField(
            controller: _urlController,
            focusNode: _urlFocusNode,
            onChanged: (val) => _onSearchChanged(val, model),
            style: TextStyle(color: model.currentTheme == 'Light' && !currentTab.isPrivate ? Colors.black : Colors.white),
            decoration: InputDecoration(
              hintText: currentTab.isPrivate ? 'Private Search' : 'Search or enter URL',
              hintStyle: const TextStyle(color: Colors.grey),
              border: InputBorder.none,
            ),
            onSubmitted: (value) => _submitSearch(value, model),
          ),
        ),
        actions: _isSearchFocused 
          ? [] 
          : [
            IconButton(
              icon: Icon(Icons.home, color: currentTab.isPrivate ? Colors.purpleAccent : const Color(0xFF00BFFF)),
              onPressed: () {
                model.updateTab(model.currentTabIndex, 'Bledo://dashboard');
                currentTab.webViewController?.loadData(
                  data: PrivacyLogic.getDashboardHtml(isPrivate: currentTab.isPrivate, proxyType: currentTab.proxyType),
                  baseUrl: WebUri("https://Bledo.dashboard")
                );
              }
            ),
            IconButton(
              icon: Icon(currentTab.isPrivate ? Icons.security : Icons.security_outlined, color: Colors.green),
              onPressed: () => showPrivateTabDialog(context, model)
            ),
            IconButton(
              icon: Icon(Icons.more_vert, color: model.currentTheme == 'Light' && !currentTab.isPrivate ? Colors.black : Colors.white), 
              onPressed: () => _showMenu(context, model)
            ),
          ],
      ),
      body: Stack(
        children: [
          IndexedStack(
            index: model.currentTabIndex,
            children: model.tabs.map((tab) => WebViewTab(key: ValueKey(tab.id), tabIndex: model.tabs.indexOf(tab))).toList(),
          ),
          if (_isSearchFocused)
            Positioned.fill(
              child: GestureDetector(
                onTap: () => _urlFocusNode.unfocus(),
                child: Container(
                  color: const Color(0xFF111318).withOpacity(0.95),
                  child: ListView(
                    children: [
                      if (_urlController.text.isNotEmpty)
                        ListTile(
                          leading: const Icon(Icons.search, color: Colors.blueAccent),
                          title: Text(_urlController.text, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                          subtitle: const Text('Search the internet', style: TextStyle(color: Colors.grey, fontSize: 10)),
                          onTap: () => _submitSearch(_urlController.text, model),
                        ),
                      ..._filteredHistory.map((item) => ListTile(
                        leading: const Icon(Icons.history, color: Colors.grey),
                        title: Text(item['title'] ?? 'No Title', style: const TextStyle(color: Colors.white), maxLines: 1, overflow: TextOverflow.ellipsis),
                        subtitle: Text(item['url'] ?? '', style: const TextStyle(color: Colors.blueAccent, fontSize: 10), maxLines: 1, overflow: TextOverflow.ellipsis),
                        onTap: () => _submitSearch(item['url']!, model),
                      )).toList(),
                    ],
                  ),
                ),
              ),
            ),
        ],
      ),
      bottomNavigationBar: BottomAppBar(
        color: appBarColor,
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceAround,
          children: [
            IconButton(icon: Icon(Icons.arrow_back, color: model.currentTheme == 'Light' && !currentTab.isPrivate ? Colors.black : Colors.white), onPressed: () => currentTab.webViewController?.goBack()),
            IconButton(icon: Icon(Icons.arrow_forward, color: model.currentTheme == 'Light' && !currentTab.isPrivate ? Colors.black : Colors.white), onPressed: () => currentTab.webViewController?.goForward()),
            IconButton(icon: Icon(Icons.refresh, color: model.currentTheme == 'Light' && !currentTab.isPrivate ? Colors.black : Colors.white), onPressed: () => currentTab.webViewController?.reload()),
            IconButton(
              icon: Badge(
                label: Text('${model.tabs.length}'), 
                backgroundColor: currentTab.isPrivate ? Colors.purple : Colors.blue,
                child: Icon(Icons.tab, color: model.currentTheme == 'Light' && !currentTab.isPrivate ? Colors.black : Colors.white)
              ),
              onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (context) => const TabSwitcherPage())),
            ),
          ],
        ),
      ),
    );
  }
}

class SettingsPage extends StatelessWidget {
  const SettingsPage({super.key});

  @override
  Widget build(BuildContext context) {
    final model = Provider.of<BrowserModel>(context);
    final isDark = model.currentTheme == 'Dark' || model.currentTheme == 'Blue' || model.currentTheme == 'Green';
    
    return Theme(
      data: isDark ? ThemeData.dark().copyWith(
        scaffoldBackgroundColor: const Color(0xFF111318),
        appBarTheme: const AppBarTheme(backgroundColor: Color(0xFF1E222B)),
      ) : ThemeData.light(),
      child: Scaffold(
        backgroundColor: const Color(0xFF111318),
        appBar: AppBar(title: const Text('Bledo Settings', style: TextStyle(color: Colors.white)), backgroundColor: const Color(0xFF1E222B)),
        body: ListView(
          children: [
            _settingsHeader('Privacy & Security'),
            SwitchListTile(
              title: const Text('Hardened Mode', style: TextStyle(color: Colors.white)),
              subtitle: const Text('Blocks screenshots, clears clipboard on exit, and enforces strict security policies', style: TextStyle(color: Colors.grey)),
              value: model.isHardenedMode,
              onChanged: (val) => model.setHardenedMode(val),
              activeColor: Colors.redAccent,
            ),
            SwitchListTile(
              title: const Text('Enhanced Privacy', style: TextStyle(color: Colors.white)),
              subtitle: const Text('Includes Referer trimming, Font protection, and CNAME uncloaking', style: TextStyle(color: Colors.grey)),
              value: model.isEnhancedPrivacyEnabled,
              onChanged: (val) => model.setEnhancedPrivacy(val),
              activeColor: Colors.purpleAccent,
            ),
            SwitchListTile(
              title: const Text('Enhanced Security', style: TextStyle(color: Colors.white)),
              subtitle: const Text('Advanced protection against fingerprinting, WebRTC leaks, and tracking APIs', style: TextStyle(color: Colors.grey)),
              value: model.isEnhancedSecurityEnabled,
              onChanged: (val) => model.setEnhancedSecurity(val),
              activeColor: Colors.greenAccent,
            ),
            SwitchListTile(
              title: const Text('Ad Blocker', style: TextStyle(color: Colors.white)),
              subtitle: const Text('Block trackers and annoying ads', style: TextStyle(color: Colors.grey)),
              value: model.isAdBlockerEnabled,
              onChanged: (val) => model.setAdBlocker(val),
              activeColor: Colors.blueAccent,
            ),
          SwitchListTile(
            title: const Text('Bledo VPN (Experimental)', style: TextStyle(color: Colors.white)),
            subtitle: Text(
              model.isVpnActive 
                ? 'Active: Spoofing location to ${model.activeVpnLocation?.name ?? "Unknown"}' 
                : 'Enhance your privacy with encrypted routing and location spoofing', 
              style: const TextStyle(color: Colors.grey, fontSize: 12)
            ),
            value: model.isVpnActive,
            onChanged: (val) {
              model.setVpn(val);
              if (val) {
                BledoNotification.show(context, 'VPN Active: Geolocation spoofing enabled.');
              }
            },
          ),
          ListTile(
            title: const Text('VPN Location', style: TextStyle(color: Colors.white)),
            subtitle: Text(
              model.selectedVpnLocationIndex == -1 ? 'Random' : (model.selectedVpnLocationIndex == -2 ? 'Custom' : model.vpnLocations[model.selectedVpnLocationIndex].name),
              style: const TextStyle(color: Colors.grey)
            ),
            enabled: model.isVpnActive,
            onTap: () => Navigator.push(context, MaterialPageRoute(builder: (context) => const VpnLocationSettingsPage())),
          ),
          SwitchListTile(
            title: const Text('Anti-Virus Shield', style: TextStyle(color: Colors.white)),
            subtitle: const Text('Automatically deletes all unknown trackers', style: TextStyle(color: Colors.grey)),
            value: model.isAntiVirusEnabled,
            onChanged: (val) => model.setAntiVirus(val),
          ),
          ListTile(
            title: const Text('Manage Anti-Virus', style: TextStyle(color: Colors.white)),
            onTap: () => Navigator.push(context, MaterialPageRoute(builder: (context) => const AntiVirusSettingsPage())),
          ),
          ListTile(
            title: const Text('Site Settings', style: TextStyle(color: Colors.white)),
            subtitle: const Text('Manage permissions and cookies', style: TextStyle(color: Colors.grey)),
            onTap: () => Navigator.push(context, MaterialPageRoute(builder: (context) => const SiteSettingsPage())),
          ),
          _settingsHeader('Appearance'),
          ListTile(
            title: const Text('Theme', style: TextStyle(color: Colors.white)),
            subtitle: Text(model.currentTheme, style: const TextStyle(color: Colors.grey)),
            onTap: () => Navigator.push(context, MaterialPageRoute(builder: (context) => const ThemeSettingsPage())),
          ),
          _settingsHeader('General'),
          ListTile(
            title: const Text('Homepage', style: TextStyle(color: Colors.white)),
            subtitle: Text(model.homepageUrl, style: const TextStyle(color: Colors.grey)),
            onTap: () async {
              final controller = TextEditingController(text: model.homepageUrl);
              showDialog(
                context: context,
                builder: (context) => AlertDialog(
                  backgroundColor: const Color(0xFF282C37),
                  title: const Text('Set Homepage', style: TextStyle(color: Colors.white)),
                  content: TextField(controller: controller, style: const TextStyle(color: Colors.white)),
                  actions: [
                    TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
                    TextButton(onPressed: () { model.setHomepage(controller.text); Navigator.pop(context); }, child: const Text('Save')),
                  ],
                ),
              );
            },
          ),
          ListTile(
            title: const Text('Languages', style: TextStyle(color: Colors.white)),
            subtitle: Text(model.currentLanguage, style: const TextStyle(color: Colors.grey)),
            onTap: () => Navigator.push(context, MaterialPageRoute(builder: (context) => const LanguagesSettingsPage())),
          ),
          ListTile(
            title: const Text('Notifications', style: TextStyle(color: Colors.white)),
            subtitle: Text(model.notificationsEnabled ? 'On' : 'Off', style: const TextStyle(color: Colors.grey)),
            onTap: () => Navigator.push(context, MaterialPageRoute(builder: (context) => const NotificationsSettingsPage())),
          ),
          ListTile(
            title: const Text('Downloads', style: TextStyle(color: Colors.white)),
            onTap: () => Navigator.push(context, MaterialPageRoute(builder: (context) => const DownloadsPage())),
          ),
          _settingsHeader('Advanced'),
          ListTile(
            title: const Text('Clear All Browsing Data', style: TextStyle(color: Colors.redAccent)),
            onTap: () {
              model.deleteAllData();
              BledoNotification.show(context, 'All data cleared');
            },
          ),
          ListTile(
            title: const Text('About Bledo', style: TextStyle(color: Colors.white)),
            onTap: () {
              showDialog(
                context: context,
                builder: (context) => AlertDialog(
                  backgroundColor: const Color(0xFF1E222B),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                  content: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        width: 80,
                        height: 80,
                        decoration: const BoxDecoration(color: Colors.blueAccent, shape: BoxShape.circle),
                        child: const Icon(Icons.security, size: 50, color: Colors.white),
                      ),
                      const SizedBox(height: 16),
                      const Text('Bledo Browser', style: TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.bold)),
                      const Text('Version 1.0.0', style: TextStyle(color: Colors.grey, fontSize: 14)),
                      const SizedBox(height: 20),
                      const Text(
                        "A fast, secure, and privacy-focused browser.",
                        textAlign: TextAlign.center,
                        style: TextStyle(color: Colors.white70),
                      ),
                      const Divider(color: Colors.grey, height: 32),
                      const Text('CREATOR', style: TextStyle(color: Colors.blueAccent, fontSize: 12, fontWeight: FontWeight.bold, letterSpacing: 1.2)),
                      const SizedBox(height: 8),
                      const Text('Woopskidds', style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w500)),
                      const SizedBox(height: 12),
                      ElevatedButton.icon(
                        onPressed: () async {
                          final url = 'https://m.youtube.com/@Woopskidd';
                          final uri = Uri.parse(url);
                          if (!await launchUrl(uri, mode: LaunchMode.externalApplication)) {
                            BledoNotification.show(context, 'Could not launch $url');
                          }
                        },
                        icon: const Icon(Icons.play_circle_fill, color: Colors.white),
                        label: const Text('Visit YouTube Channel'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.redAccent,
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30)),
                        ),
                      ),
                    ],
                  ),
                  actions: [
                    TextButton(
                      onPressed: () => Navigator.pop(context),
                      child: const Text('CLOSE', style: TextStyle(color: Colors.blueAccent)),
                    ),
                  ],
                ),
              );
            },
          ),
        ],
      ),
    ),
  );
}

  Widget _settingsHeader(String title) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 24, 16, 8),
      child: Text(title.toUpperCase(), style: const TextStyle(color: Colors.blueAccent, fontWeight: FontWeight.bold, fontSize: 12)),
    );
  }
}

class DownloadsPage extends StatelessWidget {
  const DownloadsPage({super.key});

  @override
  Widget build(BuildContext context) {
    final model = Provider.of<BrowserModel>(context);
    return Scaffold(
      backgroundColor: const Color(0xFF111318),
      appBar: AppBar(
        title: const Text('Downloads'),
        backgroundColor: const Color(0xFF1E222B),
        actions: [
          IconButton(icon: const Icon(Icons.clear_all), onPressed: () => model.clearDownloads()),
        ],
      ),
      body: model.downloads.isEmpty
          ? const Center(child: Text('No downloads yet', style: TextStyle(color: Colors.grey)))
          : ListView.builder(
              itemCount: model.downloads.length,
              itemBuilder: (context, index) {
                final item = model.downloads[index];
                return ListTile(
                  leading: const Icon(Icons.file_present, color: Colors.blueAccent),
                  title: Text(item.name, style: const TextStyle(color: Colors.white), overflow: TextOverflow.ellipsis),
                  subtitle: item.isDownloading 
                    ? Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const SizedBox(height: 4),
                          LinearProgressIndicator(value: item.progress, backgroundColor: Colors.grey[800], valueColor: const AlwaysStoppedAnimation(Colors.blueAccent)),
                          const SizedBox(height: 4),
                          Text("${(item.progress * 100).toInt()}%", style: const TextStyle(color: Colors.grey, fontSize: 10)),
                        ],
                      )
                    : Text(item.url, style: const TextStyle(color: Colors.grey, fontSize: 10), maxLines: 1, overflow: TextOverflow.ellipsis),
                  trailing: item.isDownloading 
                    ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2))
                    : IconButton(
                        icon: const Icon(Icons.more_vert, color: Colors.white),
                        onPressed: () => _showDownloadMenu(context, model, index),
                      ),
                  onTap: () => item.isDownloading ? null : _handleFileClick(context, item),
                );
              },
            ),
    );
  }

  void _showDownloadMenu(BuildContext context, BrowserModel model, int index) {
    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF1E222B),
      builder: (context) {
        final renameController = TextEditingController(text: model.downloads[index].name);
        return Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.edit, color: Colors.blueAccent),
              title: const Text('Rename', style: TextStyle(color: Colors.white)),
              onTap: () {
                Navigator.pop(context);
                showDialog(
                  context: context,
                  builder: (context) => AlertDialog(
                    backgroundColor: const Color(0xFF282C37),
                    title: const Text('Rename File', style: TextStyle(color: Colors.white)),
                    content: TextField(controller: renameController, style: const TextStyle(color: Colors.white)),
                    actions: [
                      TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
                      TextButton(onPressed: () { model.renameDownload(index, renameController.text); Navigator.pop(context); }, child: const Text('Save')),
                    ],
                  ),
                );
              },
            ),
            ListTile(
              leading: const Icon(Icons.delete_outline, color: Colors.orangeAccent),
              title: const Text('Delete to Trash', style: TextStyle(color: Colors.white)),
              onTap: () {
                model.moveDownloadToTrash(index);
                Navigator.pop(context);
              },
            ),
            ListTile(
              leading: const Icon(Icons.delete_forever, color: Colors.redAccent),
              title: const Text('Delete Permanently', style: TextStyle(color: Colors.white)),
              onTap: () {
                model.deleteDownloadPermanently(index);
                Navigator.pop(context);
              },
            ),
          ],
        );
      },
    );
  }

  void _handleFileClick(BuildContext context, DownloadItem item) async {
    final path = item.path;
    final ext = item.name.split('.').last.toLowerCase();
    
    if (ext == 'txt' || ext == 'lua') {
      Navigator.push(context, MaterialPageRoute(builder: (context) => TextEditorPage(filePath: path, fileName: item.name)));
    } else if (ext == 'apk') {
      debugPrint("DEBUG: Attempting to install APK: $path");
      try {
        final platform = MethodChannel('com.Bledo.browser/security');
        await platform.invokeMethod('installApk', {'path': path});
      } catch (e) {
        debugPrint("DEBUG: Native Installation failed: $e");
        BledoNotification.show(context, 'Installation failed: $e');
      }
    } else {
      try {
        final result = await OpenFile.open(path);
        if (result.type != ResultType.done) {
          BledoNotification.show(context, 'Error: ${result.message}');
        }
      } catch (e) {
        BledoNotification.show(context, 'Failed to open file: $e');
      }
    }
  }
}

class TextEditorPage extends StatefulWidget {
  final String filePath;
  final String fileName;
  const TextEditorPage({super.key, required this.filePath, required this.fileName});

  @override
  State<TextEditorPage> createState() => _TextEditorPageState();
}

class _TextEditorPageState extends State<TextEditorPage> {
  final TextEditingController _controller = TextEditingController();
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadFile();
  }

  void _loadFile() async {
    try {
      final file = File(widget.filePath);
      if (await file.exists()) {
        final content = await file.readAsString();
        _controller.text = content;
      }
    } catch (e) {
      _controller.text = "Error loading file: $e";
    } finally {
      setState(() => _isLoading = false);
    }
  }

  void _saveFile() async {
    try {
      final file = File(widget.filePath);
      await file.writeAsString(_controller.text);
      BledoNotification.show(context, 'File saved successfully');
    } catch (e) {
      BledoNotification.show(context, 'Save error: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF111318),
      appBar: AppBar(
        title: Text(widget.fileName),
        backgroundColor: const Color(0xFF1E222B),
        actions: [
          IconButton(icon: const Icon(Icons.save), onPressed: _saveFile),
        ],
      ),
      body: _isLoading 
        ? const Center(child: CircularProgressIndicator()) 
        : Padding(
            padding: const EdgeInsets.all(16.0),
            child: TextField(
              controller: _controller,
              maxLines: null,
              style: const TextStyle(color: Colors.white, fontFamily: 'monospace'),
              decoration: const InputDecoration(border: InputBorder.none),
            ),
          ),
    );
  }
}

class VpnLocationSettingsPage extends StatelessWidget {
  const VpnLocationSettingsPage({super.key});

  @override
  Widget build(BuildContext context) {
    final model = Provider.of<BrowserModel>(context);
    return Scaffold(
      backgroundColor: const Color(0xFF111318),
      appBar: AppBar(
        title: const Text('VPN Location', style: TextStyle(color: Colors.white)), 
        backgroundColor: const Color(0xFF1E222B),
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: ListView(
        children: [
          RadioListTile<int>(
            title: const Text('Random', style: TextStyle(color: Colors.white)),
            subtitle: const Text('A random location will be picked for every tab', style: TextStyle(color: Colors.grey)),
            value: -1,
            groupValue: model.selectedVpnLocationIndex,
            onChanged: (val) => model.setVpnLocation(val!),
            activeColor: Colors.blueAccent,
          ),
          ListTile(
            leading: Radio<int>(
              value: -2,
              groupValue: model.selectedVpnLocationIndex,
              onChanged: (val) => Navigator.push(context, MaterialPageRoute(builder: (context) => const VpnMapPickerPage())),
              activeColor: Colors.blueAccent,
            ),
            title: const Text('Pick on Map', style: TextStyle(color: Colors.white)),
            subtitle: Text(
              model.selectedVpnLocationIndex == -2 
                ? 'Custom: ${model.customVpnLat.toStringAsFixed(4)}, ${model.customVpnLng.toStringAsFixed(4)}' 
                : 'Select any point on the world map',
              style: const TextStyle(color: Colors.grey)
            ),
            onTap: () => Navigator.push(context, MaterialPageRoute(builder: (context) => const VpnMapPickerPage())),
          ),
          const Divider(color: Colors.grey),
          ...model.vpnLocations.asMap().entries.map((entry) => RadioListTile<int>(
            title: Text(entry.value.name, style: const TextStyle(color: Colors.white)),
            value: entry.key,
            groupValue: model.selectedVpnLocationIndex,
            onChanged: (val) => model.setVpnLocation(val!),
            activeColor: Colors.blueAccent,
          )).toList(),
        ],
      ),
    );
  }
}

class VpnMapPickerPage extends StatefulWidget {
  const VpnMapPickerPage({super.key});

  @override
  State<VpnMapPickerPage> createState() => _VpnMapPickerPageState();
}

class _VpnMapPickerPageState extends State<VpnMapPickerPage> {
  LatLng? _selectedPoint;

  @override
  void initState() {
    super.initState();
    final model = Provider.of<BrowserModel>(context, listen: false);
    if (model.customVpnLat != 0.0 || model.customVpnLng != 0.0) {
      _selectedPoint = LatLng(model.customVpnLat, model.customVpnLng);
    } else {
      _selectedPoint = const LatLng(0.0, 0.0);
    }
  }

  @override
  Widget build(BuildContext context) {
    final model = Provider.of<BrowserModel>(context);
    
    return Scaffold(
      backgroundColor: const Color(0xFF111318),
      appBar: AppBar(
        title: const Text('Select Location on Map', style: TextStyle(color: Colors.white)),
        backgroundColor: const Color(0xFF1E222B),
        iconTheme: const IconThemeData(color: Colors.white),
        actions: [
          if (_selectedPoint != null)
            IconButton(
              icon: const Icon(Icons.check, color: Colors.greenAccent),
              onPressed: () {
                model.setCustomVpnLocation(_selectedPoint!.latitude, _selectedPoint!.longitude);
                Navigator.pop(context);
              },
            ),
        ],
      ),
      body: FlutterMap(
        options: MapOptions(
          initialCenter: _selectedPoint ?? const LatLng(0, 0),
          initialZoom: 2.0,
          onTap: (tapPosition, point) {
            setState(() {
              _selectedPoint = point;
            });
          },
        ),
        children: [
          TileLayer(
            urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
            userAgentPackageName: 'com.Bledo.browser',
          ),
          if (_selectedPoint != null)
            MarkerLayer(
              markers: [
                Marker(
                  point: _selectedPoint!,
                  width: 80,
                  height: 80,
                  child: const Icon(Icons.location_on, color: Colors.red, size: 40),
                ),
              ],
            ),
        ],
      ),
      floatingActionButton: _selectedPoint == null ? null : FloatingActionButton.extended(
        onPressed: () {
          model.setCustomVpnLocation(_selectedPoint!.latitude, _selectedPoint!.longitude);
          Navigator.pop(context);
        },
        backgroundColor: Colors.blueAccent,
        icon: const Icon(Icons.gps_fixed, color: Colors.white),
        label: const Text('Set as VPN Location', style: TextStyle(color: Colors.white)),
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.centerFloat,
    );
  }
}

class SiteSettingsPage extends StatelessWidget {
  const SiteSettingsPage({super.key});

  @override
  Widget build(BuildContext context) {
    final model = Provider.of<BrowserModel>(context);
    return Scaffold(
      backgroundColor: const Color(0xFF111318),
      appBar: AppBar(title: const Text('Site Settings'), backgroundColor: const Color(0xFF1E222B)),
      body: ListView(
        children: [
          _siteSettingToggle(Icons.location_on, 'Location', model.allowLocation, (v) => model.setAllowLocation(v)),
          _siteSettingToggle(Icons.camera_alt, 'Camera', model.allowCamera, (v) => model.setAllowCamera(v)),
          _siteSettingToggle(Icons.mic, 'Microphone', model.allowMic, (v) => model.setAllowMic(v)),
          _siteSettingToggle(Icons.javascript, 'JavaScript', model.allowJs, (v) => model.setAllowJs(v)),
          _siteSettingToggle(Icons.cookie, 'Cookies', model.allowCookies, (v) => model.setAllowCookies(v)),
        ],
      ),
    );
  }

  Widget _siteSettingToggle(IconData icon, String title, bool val, Function(bool) onChanged) {
    return SwitchListTile(
      secondary: Icon(icon, color: Colors.blueAccent),
      title: Text(title, style: const TextStyle(color: Colors.white)),
      value: val,
      onChanged: onChanged,
      activeColor: Colors.blueAccent,
    );
  }
}

class ThemeSettingsPage extends StatelessWidget {
  const ThemeSettingsPage({super.key});

  @override
  Widget build(BuildContext context) {
    final model = Provider.of<BrowserModel>(context);
    return Scaffold(
      backgroundColor: const Color(0xFF111318),
      appBar: AppBar(title: const Text('Appearance'), backgroundColor: const Color(0xFF1E222B)),
      body: ListView(
        children: ['Dark', 'Blue', 'Light', 'Green'].map((theme) => RadioListTile(
          title: Text(theme, style: const TextStyle(color: Colors.white)),
          value: theme,
          groupValue: model.currentTheme,
          onChanged: (val) => model.setTheme(val as String),
          activeColor: Colors.blueAccent,
        )).toList(),
      ),
    );
  }
}

class LanguagesSettingsPage extends StatelessWidget {
  const LanguagesSettingsPage({super.key});

  @override
  Widget build(BuildContext context) {
    final model = Provider.of<BrowserModel>(context);
    final langs = ['English', 'Spanish', 'French', 'German', 'Chinese', 'Japanese', 'Russian', 'Arabic', 'Hindi', 'Portuguese'];
    return Scaffold(
      backgroundColor: const Color(0xFF111318),
      appBar: AppBar(title: const Text('Languages'), backgroundColor: const Color(0xFF1E222B)),
      body: ListView(
        children: langs.map((lang) => RadioListTile(
          title: Text(lang, style: const TextStyle(color: Colors.white)),
          value: lang,
          groupValue: model.currentLanguage,
          onChanged: (val) => model.setLanguage(val as String),
          activeColor: Colors.blueAccent,
        )).toList(),
      ),
    );
  }
}

class NotificationsSettingsPage extends StatelessWidget {
  const NotificationsSettingsPage({super.key});

  @override
  Widget build(BuildContext context) {
    final model = Provider.of<BrowserModel>(context);
    return Scaffold(
      backgroundColor: const Color(0xFF111318),
      appBar: AppBar(title: const Text('Notifications'), backgroundColor: const Color(0xFF1E222B)),
      body: ListView(
        children: [
          SwitchListTile(
            title: const Text('Allow Notifications', style: TextStyle(color: Colors.white)),
            subtitle: const Text('Receive security alerts and download updates', style: TextStyle(color: Colors.grey)),
            value: model.notificationsEnabled,
            onChanged: (val) {
              model.setNotifications(val);
              if (val) {
                BledoNotification.show(context, 'Bledo notifications enabled');
              }
            },
            activeColor: Colors.blueAccent,
          ),
        ],
      ),
    );
  }
}

class AntiVirusSettingsPage extends StatelessWidget {
  const AntiVirusSettingsPage({super.key});

  @override
  Widget build(BuildContext context) {
    final model = Provider.of<BrowserModel>(context);
    return Scaffold(
      backgroundColor: const Color(0xFF111318),
      appBar: AppBar(title: const Text('Anti-Virus'), backgroundColor: const Color(0xFF1E222B)),
      body: ListView.builder(
        itemCount: model.avRules.length,
        itemBuilder: (context, index) {
          final rule = model.avRules[index];
          return SwitchListTile(
            title: Text(rule.name, style: const TextStyle(color: Colors.white)),
            subtitle: Text(rule.pattern, style: const TextStyle(color: Colors.grey)),
            value: rule.enabled,
            onChanged: (val) => model.toggleAVRule(index),
          );
        },
      ),
    );
  }
}

class HistoryPage extends StatelessWidget {
  const HistoryPage({super.key});

  @override
  Widget build(BuildContext context) {
    final model = Provider.of<BrowserModel>(context);
    return Scaffold(
      backgroundColor: const Color(0xFF111318),
      appBar: AppBar(
        title: const Text('History'),
        backgroundColor: const Color(0xFF1E222B),
        actions: [
          IconButton(icon: const Icon(Icons.delete_sweep), onPressed: () => model.clearHistory()),
        ],
      ),
      body: model.history.isEmpty
          ? const Center(child: Text('No history found', style: TextStyle(color: Colors.grey)))
          : ListView.builder(
              itemCount: model.history.length,
              itemBuilder: (context, index) {
                final item = model.history[index];
                return ListTile(
                  title: Text(item['title'] ?? 'No Title', style: const TextStyle(color: Colors.white)),
                  subtitle: Text(item['url'] ?? '', style: const TextStyle(color: Colors.grey)),
                  onTap: () {
                    model.currentTab.webViewController?.loadUrl(urlRequest: URLRequest(url: WebUri(item['url']!)));
                    Navigator.pop(context);
                  },
                );
              },
            ),
    );
  }
}

class TabSwitcherPage extends StatefulWidget {
  const TabSwitcherPage({super.key});

  @override
  State<TabSwitcherPage> createState() => _TabSwitcherPageState();
}

class _TabSwitcherPageState extends State<TabSwitcherPage> {
  bool showPrivate = false;

  @override
  Widget build(BuildContext context) {
    final model = Provider.of<BrowserModel>(context);
    final filteredTabs = model.tabs.asMap().entries.where((e) => e.value.isPrivate == showPrivate).toList();

    return Scaffold(
      backgroundColor: showPrivate ? const Color(0xFF1E1B4B) : const Color(0xFF111318),
      appBar: AppBar(
        title: Text(showPrivate ? 'Private Tabs' : 'Regular Tabs'),
        backgroundColor: showPrivate ? const Color(0xFF2E1065) : const Color(0xFF1E222B),
        actions: [
          IconButton(
            icon: Icon(showPrivate ? Icons.visibility_off : Icons.visibility), 
            onPressed: () => setState(() => showPrivate = !showPrivate)
          ),
          IconButton(icon: const Icon(Icons.add), onPressed: () { 
            if (showPrivate) {
               _BrowserScreenState.showPrivateTabDialog(context, model);
            } else {
              model.addTab(); 
              Navigator.pop(context);
            }
          }),
        ],
      ),
      body: filteredTabs.isEmpty
          ? Center(child: Text('No ${showPrivate ? "private" : "regular"} tabs open', style: const TextStyle(color: Colors.grey)))
          : GridView.builder(
              padding: const EdgeInsets.all(16),
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 2,
                childAspectRatio: 0.8,
                crossAxisSpacing: 16,
                mainAxisSpacing: 16,
              ),
              itemCount: filteredTabs.length,
              itemBuilder: (context, index) {
                final entry = filteredTabs[index];
                final tab = entry.value;
                final originalIndex = entry.key;
                final isCurrent = model.currentTabIndex == originalIndex;
                
                return GestureDetector(
                  onTap: () {
                    model.switchTab(originalIndex);
                    Navigator.pop(context);
                  },
                  child: Container(
                    decoration: BoxDecoration(
                      color: showPrivate ? const Color(0xFF4C1D95).withOpacity(0.3) : const Color(0xFF1E222B),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: isCurrent ? (showPrivate ? Colors.purpleAccent : Colors.blueAccent) : Colors.grey.withOpacity(0.3), 
                        width: 2
                      ),
                    ),
                    child: Column(
                      children: [
                        Padding(
                          padding: const EdgeInsets.all(8.0),
                          child: Row(
                            children: [
                              Expanded(child: Text(tab.title, style: const TextStyle(color: Colors.white, fontSize: 12), maxLines: 1, overflow: TextOverflow.ellipsis)),
                              IconButton(
                                padding: EdgeInsets.zero,
                                constraints: const BoxConstraints(),
                                icon: const Icon(Icons.close, color: Colors.white, size: 16),
                                onPressed: () {
                                  model.closeTab(originalIndex);
                                  setState(() {});
                                },
                              ),
                            ],
                          ),
                        ),
                        Expanded(
                          child: Container(
                            margin: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: showPrivate ? const Color(0xFF2E1065) : const Color(0xFF282C37), 
                              borderRadius: BorderRadius.circular(8)
                            ),
                            child: Center(
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(tab.isPrivate ? Icons.security : Icons.web, color: Colors.grey),
                                  if (tab.proxyType != null)
                                    Text(tab.proxyType!, style: const TextStyle(color: Colors.purpleAccent, fontSize: 10)),
                                  if (tab.isPrivate && (tab.password != null || tab.useBiometrics))
                                    const Icon(Icons.lock, color: Colors.purpleAccent, size: 12),
                                ],
                              )
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
      bottomNavigationBar: BottomNavigationBar(
        backgroundColor: showPrivate ? const Color(0xFF2E1065) : const Color(0xFF1E222B),
        selectedItemColor: showPrivate ? Colors.purpleAccent : Colors.blueAccent,
        unselectedItemColor: Colors.grey,
        currentIndex: showPrivate ? 1 : 0,
        onTap: (index) => setState(() => showPrivate = index == 1),
        items: const [
          BottomNavigationBarItem(icon: Icon(Icons.web), label: 'Regular'),
          BottomNavigationBarItem(icon: Icon(Icons.security), label: 'Private'),
        ],
      ),
    );
  }
}
