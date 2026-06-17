import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';
import 'browser_model.dart';
import 'privacy_logic.dart';

class IosBrowserScreen extends StatefulWidget {
  const IosBrowserScreen({super.key});

  @override
  State<IosBrowserScreen> createState() => _IosBrowserScreenState();
}

class _IosBrowserScreenState extends State<IosBrowserScreen> {
  final TextEditingController _urlController = TextEditingController();

  @override
  Widget build(BuildContext context) {
    final model = Provider.of<BrowserModel>(context);
    final activeTab = model.tabs.isNotEmpty ? model.tabs[model.currentTabIndex] : null;

    return CupertinoPageScaffold(
      backgroundColor: CupertinoColors.systemBackground,
      navigationBar: CupertinoNavigationBar(
        backgroundColor: CupertinoColors.systemBackground.withOpacity(0.8),
        middle: _buildUrlBar(activeTab, model),
        trailing: CupertinoButton(
          padding: EdgeInsets.zero,
          child: const Icon(CupertinoIcons.ellipsis_circle, size: 24),
          onPressed: () => _showActionSheet(context, model),
        ),
      ),
      child: SafeArea(
        bottom: false,
        child: Column(
          children: [
            Expanded(
              child: Stack(
                children: model.tabs.asMap().entries.map((entry) {
                  return Offstage(
                    offstage: entry.key != model.currentTabIndex,
                    child: InAppWebView(
                      initialUrlRequest: URLRequest(url: WebUri(entry.value.url)),
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
            _buildBottomToolbar(activeTab, model),
          ],
        ),
      ),
    );
  }

  Widget _buildUrlBar(BrowserTab? activeTab, BrowserModel model) {
    return Container(
      height: 36,
      decoration: BoxDecoration(
        color: CupertinoColors.tertiarySystemFill,
        borderRadius: BorderRadius.circular(10),
      ),
      child: CupertinoTextField(
        controller: _urlController..text = activeTab?.url ?? "",
        placeholder: "Search or enter address",
        placeholderStyle: const TextStyle(color: CupertinoColors.placeholderText, fontSize: 14),
        style: const TextStyle(fontSize: 14),
        prefix: const Padding(
          padding: EdgeInsets.only(left: 8),
          child: Icon(CupertinoIcons.lock_fill, size: 14, color: CupertinoColors.systemGreen),
        ),
        decoration: null,
        onSubmitted: (value) {
          String formatted = PrivacyLogic.formatSearchUrl(value);
          activeTab?.webViewController?.loadUrl(urlRequest: URLRequest(url: WebUri(formatted)));
        },
      ),
    );
  }

  Widget _buildBottomToolbar(BrowserTab? activeTab, BrowserModel model) {
    return Container(
      height: 44,
      decoration: const BoxDecoration(
        border: Border(top: BorderSide(color: CupertinoColors.separator, width: 0.5)),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: [
          CupertinoButton(
            padding: EdgeInsets.zero,
            child: const Icon(CupertinoIcons.back, size: 24),
            onPressed: () => activeTab?.webViewController?.goBack(),
          ),
          CupertinoButton(
            padding: EdgeInsets.zero,
            child: const Icon(CupertinoIcons.forward, size: 24),
            onPressed: () => activeTab?.webViewController?.goForward(),
          ),
          CupertinoButton(
            padding: EdgeInsets.zero,
            child: const Icon(CupertinoIcons.share, size: 24),
            onPressed: () {}, // Share logic
          ),
          CupertinoButton(
            padding: EdgeInsets.zero,
            child: const Icon(CupertinoIcons.book, size: 24),
            onPressed: () {}, // Bookmarks logic
          ),
          CupertinoButton(
            padding: EdgeInsets.zero,
            child: Badge(
              label: Text("${model.tabs.length}"),
              child: const Icon(CupertinoIcons.square_on_square, size: 24),
            ),
            onPressed: () {}, // Tab switcher logic
          ),
        ],
      ),
    );
  }

  void _showActionSheet(BuildContext context, BrowserModel model) {
    showCupertinoModalPopup<void>(
      context: context,
      builder: (BuildContext context) => CupertinoActionSheet(
        title: const Text('Bledo Browser'),
        message: const Text('Secure Browsing Controls'),
        actions: <CupertinoActionSheetAction>[
          CupertinoActionSheetAction(
            child: const Text('New Private Tab'),
            onPressed: () {
              model.addTab(isPrivate: true);
              Navigator.pop(context);
            },
          ),
          CupertinoActionSheetAction(
            child: const Text('Reload Page'),
            onPressed: () {
              model.tabs[model.currentTabIndex].webViewController?.reload();
              Navigator.pop(context);
            },
          ),
          CupertinoActionSheetAction(
            child: const Text('Bledo Settings'),
            onPressed: () {
              Navigator.pop(context);
              // Navigate to settings
            },
          ),
        ],
        cancelButton: CupertinoActionSheetAction(
          isDefaultAction: true,
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
      ),
    );
  }
}
