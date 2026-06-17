import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';
import 'package:window_manager/window_manager.dart';
import 'dart:ui';
import 'browser_model.dart';

class WindowsBrowserScreen extends StatefulWidget {
  const WindowsBrowserScreen({super.key});

  @override
  State<WindowsBrowserScreen> createState() => _WindowsBrowserScreenState();
}

class _WindowsBrowserScreenState extends State<WindowsBrowserScreen> {
  final TextEditingController _urlController = TextEditingController();
  bool _isHudVisible = true;

  @override
  Widget build(BuildContext context) {
    final model = Provider.of<BrowserModel>(context);
    final activeTab = model.tabs.isNotEmpty ? model.tabs[model.currentTabIndex] : null;

    return Scaffold(
      backgroundColor: const Color(0xFF050505),
      body: Stack(
        children: [
          // 1. MAIN WEB CONTENT
          Padding(
            padding: const EdgeInsets.only(top: 100), // Space for floating header
            child: Stack(
              children: model.tabs.asMap().entries.map((entry) {
                return Offstage(
                  offstage: entry.key != model.currentTabIndex,
                  child: InAppWebView(
                    initialFile: "assets/index.html",
                    onWebViewCreated: (controller) => entry.value.webViewController = controller,
                    onLoadStart: (controller, url) => setState(() => entry.value.isLoading = true),
                    onLoadStop: (controller, url) {
                      setState(() => entry.value.isLoading = false);
                      if (url != null) model.updateTab(entry.key, url.toString());
                      controller.getTitle().then((title) {
                        if (title != null) model.updateTabTitle(entry.key, title);
                      });
                    },
                  ),
                );
              }).toList(),
            ),
          ),

          // 2. FLOATING CYBER-HEADER (Glassmorphism)
          Positioned(
            top: 0, left: 0, right: 0,
            child: ClipRRect(
              child: BackdropFilter(
                filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
                child: Container(
                  height: 100,
                  decoration: BoxDecoration(
                    color: Colors.black.withOpacity(0.7),
                    border: const Border(bottom: BorderSide(color: Colors.blueAccent, width: 0.5)),
                  ),
                  child: Column(
                    children: [
                      // Native Drag Area & Window Controls
                      const BledoBar(),
                      
                      // Floating Command Row
                      Expanded(
                        child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 20),
                          child: Row(
                            children: [
                              // Navigation Pod
                              Container(
                                decoration: BoxDecoration(
                                  color: Colors.white.withOpacity(0.05),
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: Row(
                                  children: [
                                    _IconButton(icon: Icons.chevron_left, onTap: () => activeTab?.webViewController?.goBack()),
                                    _IconButton(icon: Icons.chevron_right, onTap: () => activeTab?.webViewController?.goForward()),
                                    _IconButton(icon: Icons.refresh, onTap: () => activeTab?.webViewController?.reload()),
                                  ],
                                ),
                              ),
                              const SizedBox(width: 20),
                              
                              // TAB CHIPS
                              Expanded(
                                child: ListView.builder(
                                  scrollDirection: Axis.horizontal,
                                  itemCount: model.tabs.length + 1,
                                  itemBuilder: (context, index) {
                                    if (index == model.tabs.length) {
                                      return _AddTabButton(onTap: () => model.addTab(url: "https://www.google.com"));
                                    }
                                    final tab = model.tabs[index];
                                    final isSelected = index == model.currentTabIndex;
                                    return _TabChip(
                                      title: tab.title,
                                      isSelected: isSelected,
                                      isLoading: tab.isLoading,
                                      onTap: () => model.switchTab(index),
                                      onClose: () => model.closeTab(index),
                                    );
                                  },
                                ),
                              ),
                              
                              const SizedBox(width: 20),
                              // HUD Toggle
                              _IconButton(
                                icon: _isHudVisible ? Icons.visibility : Icons.visibility_off,
                                onTap: () => setState(() => _isHudVisible = !_isHudVisible),
                                color: Colors.cyanAccent,
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),

          // 3. FLOATING COMMAND INPUT (Centered Search)
          Positioned(
            top: 120, left: MediaQuery.of(context).size.width * 0.2, right: MediaQuery.of(context).size.width * 0.2,
            child: Container(
              height: 48,
              decoration: BoxDecoration(
                color: const Color(0xFF111111),
                borderRadius: BorderRadius.circular(24),
                border: Border.all(color: Colors.blueAccent.withOpacity(0.3)),
                boxShadow: [
                  BoxShadow(color: Colors.blueAccent.withOpacity(0.1), blurRadius: 20, spreadRadius: 2),
                ],
              ),
              child: Row(
                children: [
                  const Padding(padding: EdgeInsets.symmetric(horizontal: 16), child: Icon(Icons.security, size: 18, color: Colors.greenAccent)),
                  Expanded(
                    child: TextField(
                      controller: _urlController..text = activeTab?.url ?? "",
                      style: const TextStyle(color: Colors.white, fontSize: 14, fontFamily: 'monospace'),
                      decoration: const InputDecoration(
                        hintText: "EXECUTE COMMAND OR ENTER URL",
                        hintStyle: TextStyle(color: Colors.white24, fontSize: 12),
                        border: InputBorder.none,
                      ),
                      onSubmitted: (value) {
                        String url = value;
                        if (!url.startsWith("http")) url = "https://$url";
                        activeTab?.webViewController?.loadUrl(urlRequest: URLRequest(url: WebUri(url)));
                      },
                    ),
                  ),
                  _IconButton(icon: Icons.qr_code_scanner, onTap: () {}),
                ],
              ),
            ),
          ),

          // 4. FLOATING SECURITY HUD (Bottom Right)
          if (_isHudVisible)
            Positioned(
              bottom: 24, right: 24,
              child: _SecurityHud(),
            ),
        ],
      ),
    );
  }
}

class BledoBar extends StatelessWidget {
  const BledoBar({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 32,
      child: Stack(
        children: [
          const WindowCaption(
            brightness: Brightness.dark,
            backgroundColor: Colors.transparent,
          ),
          Positioned(
            left: 12, top: 0, bottom: 0,
            child: Center(
              child: Text(
                "BLEDO.CORE // DESKTOP_ENV",
                style: TextStyle(color: Colors.blueAccent.withOpacity(0.5), fontSize: 9, fontWeight: FontWeight.bold, letterSpacing: 3),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _TabChip extends StatelessWidget {
  final String title;
  final bool isSelected;
  final bool isLoading;
  final VoidCallback onTap;
  final VoidCallback onClose;

  const _TabChip({required this.title, required this.isSelected, required this.isLoading, required this.onTap, required this.onClose});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        margin: const EdgeInsets.only(right: 8, top: 8, bottom: 8),
        padding: const EdgeInsets.symmetric(horizontal: 16),
        decoration: BoxDecoration(
          color: isSelected ? Colors.blueAccent.withOpacity(0.15) : Colors.white.withOpacity(0.05),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: isSelected ? Colors.blueAccent : Colors.white10),
          boxShadow: isSelected ? [BoxShadow(color: Colors.blueAccent.withOpacity(0.2), blurRadius: 8)] : null,
        ),
        child: Row(
          children: [
            if (isLoading)
              const SizedBox(width: 12, height: 12, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.blueAccent))
            else
              Icon(Icons.circle, size: 8, color: isSelected ? Colors.blueAccent : Colors.white24),
            const SizedBox(width: 12),
            ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 120),
              child: Text(
                title.isEmpty ? "INIT..." : title.toUpperCase(),
                style: TextStyle(
                  color: isSelected ? Colors.white : Colors.white38,
                  fontSize: 10,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 1.2,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            const SizedBox(width: 8),
            IconButton(
              icon: const Icon(Icons.close, size: 14),
              onPressed: onClose,
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(),
              color: isSelected ? Colors.blueAccent : Colors.white24,
            ),
          ],
        ),
      ),
    );
  }
}

class _AddTabButton extends StatelessWidget {
  final VoidCallback onTap;
  const _AddTabButton({required this.onTap});

  @override
  Widget build(BuildContext context) {
    return IconButton(
      icon: const Icon(Icons.add_box_outlined, color: Colors.blueAccent, size: 20),
      onPressed: onTap,
    );
  }
}

class _IconButton extends StatelessWidget {
  final IconData icon;
  final VoidCallback? onTap;
  final Color color;

  const _IconButton({required this.icon, this.onTap, this.color = Colors.white60});

  @override
  Widget build(BuildContext context) {
    return IconButton(
      icon: Icon(icon, size: 18, color: color),
      onPressed: onTap,
      splashRadius: 20,
    );
  }
}

class _SecurityHud extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      width: 200,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.black.withOpacity(0.8),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.cyanAccent.withOpacity(0.2)),
        boxShadow: [BoxShadow(color: Colors.cyanAccent.withOpacity(0.05), blurRadius: 20)],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text("REAL-TIME SECURITY", style: TextStyle(color: Colors.cyanAccent, fontSize: 10, fontWeight: FontWeight.bold, letterSpacing: 1.5)),
          const SizedBox(height: 16),
          _HudMetric(label: "ENC_LAYER", value: "ACTIVE", color: Colors.greenAccent),
          _HudMetric(label: "TRAFFIC_TRK", value: "BLOCKED", color: Colors.orangeAccent),
          _HudMetric(label: "PRISM_EMU", value: "STABLE", color: Colors.blueAccent),
          const Divider(color: Colors.white10),
          const Text("SYSTEM COMPATIBILITY: X64_EMU", style: TextStyle(color: Colors.white24, fontSize: 8)),
        ],
      ),
    );
  }
}

class _HudMetric extends StatelessWidget {
  final String label;
  final String value;
  final Color color;

  const _HudMetric({required this.label, required this.value, required this.color});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: const TextStyle(color: Colors.white38, fontSize: 9)),
          Text(value, style: TextStyle(color: color, fontSize: 9, fontWeight: FontWeight.bold, fontFamily: 'monospace')),
        ],
      ),
    );
  }
}
