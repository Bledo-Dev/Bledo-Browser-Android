import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';
import 'package:url_launcher/url_launcher.dart';
import 'dart:io';
import 'browser_model.dart';
import 'privacy_logic.dart';
import 'bledo_notification.dart';

class MiniBrowser extends StatefulWidget {
  final String url;
  const MiniBrowser({super.key, required this.url});

  @override
  State<MiniBrowser> createState() => _MiniBrowserState();
}

class _MiniBrowserState extends State<MiniBrowser> {
  InAppWebViewController? _controller;
  double _progress = 0;
  bool _isShowingDownloadFrame = false;
  String _currentUrl = "";
  String? _lastTriggeredDownloadUrl;

  @override
  void initState() {
    super.initState();
    _currentUrl = widget.url;
  }

  @override
  Widget build(BuildContext context) {
    final model = Provider.of<BrowserModel>(context);

    return Scaffold(
      backgroundColor: const Color(0xFF111318),
      appBar: AppBar(
        backgroundColor: const Color(0xFF1E222B),
        elevation: 2,
        leading: _logoIcon(),
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              _isShowingDownloadFrame ? 'Downloading...' : 'Running in Bledo', 
              style: const TextStyle(fontSize: 12, color: Colors.blueAccent, fontWeight: FontWeight.bold)
            ),
            if (!_isShowingDownloadFrame) ...[
              Text(
                _currentUrl,
                style: const TextStyle(fontSize: 10, color: Colors.white38),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ]
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.more_vert, color: Colors.white70),
            onPressed: () => _showMiniMenu(context, model),
          ),
        ],
      ),
      body: Stack(
        children: [
          Positioned.fill(
            child: _isShowingDownloadFrame 
              ? _buildDownloadFrame(context, model)
              : InAppWebView(
                  initialUrlRequest: URLRequest(url: WebUri(widget.url)),
                  initialSettings: PrivacyLogic.getWebViewSettings(
                    isPrivate: true,
                    isHardenedMode: model.isHardenedMode,
                  ),
                  onWebViewCreated: (controller) => _controller = controller,
                  onLoadStop: (controller, url) {
                    if (url != null) setState(() => _currentUrl = url.toString());
                  },
                  onProgressChanged: (controller, progress) {
                    setState(() => _progress = progress / 100);
                  },
                  onLoadResource: (controller, resource) {
                    if (_progress >= 1.0) {
                      setState(() => _progress = 1.0);
                    }
                  },
                  onDownloadStartRequest: (controller, downloadRequest) {
                    _handleDownload(downloadRequest.url.toString(), model);
                  },
                ),
          ),
          if (_progress < 1.0 && !_isShowingDownloadFrame)
            Positioned(
              top: 0, left: 0, right: 0,
              child: LinearProgressIndicator(
                value: _progress,
                backgroundColor: Colors.transparent,
                valueColor: const AlwaysStoppedAnimation<Color>(Colors.blueAccent),
                minHeight: 2,
              ),
            ),
        ],
      ),
    );
  }

  Widget _logoIcon() {
    return Container(
      width: 32,
      height: 32,
      decoration: const BoxDecoration(
        color: Color(0xFF1B2028),
        shape: BoxShape.circle,
      ),
      child: Center(
        child: Stack(
          alignment: Alignment.center,
          children: [
            _orbit(0),
            _orbit(120),
            _orbit(240),
            Container(width: 3.5, height: 3.5, decoration: const BoxDecoration(color: Color(0xFFA5F3FC), shape: BoxShape.circle)),
            _node(0, 12.5),
            _node(120, 12.5),
            _node(240, 12.5),
          ],
        ),
      ),
    );
  }

  Widget _orbit(double rotation) {
    return Transform.rotate(
      angle: rotation * 3.14159 / 180,
      child: Container(
        width: 10,
        height: 28,
        decoration: BoxDecoration(
          border: Border.all(color: const Color(0xFFA5F3FC), width: 0.8),
          borderRadius: const BorderRadius.all(Radius.elliptical(5, 14)),
        ),
      ),
    );
  }

  Widget _node(double rotation, double offset) {
    return Transform.rotate(
      angle: rotation * 3.14159 / 180,
      child: Transform.translate(
        offset: Offset(0, offset),
        child: Container(width: 2.5, height: 2.5, decoration: const BoxDecoration(color: Color(0xFFA5F3FC), shape: BoxShape.circle)),
      ),
    );
  }

  void _handleDownload(String url, BrowserModel model) {
    final fileName = url.split('/').last.split('?').first;
    if (fileName.isEmpty) return;

    setState(() {
      _isShowingDownloadFrame = true;
      _lastTriggeredDownloadUrl = url;
    });

    BledoNotification.show(
      context, 
      "Download starting: $fileName",
      actionLabel: "SHOW",
      onAction: () => setState(() => _isShowingDownloadFrame = true)
    );
  }

  Widget _buildDownloadFrame(BuildContext context, BrowserModel model) {
     final first = model.downloads.isNotEmpty ? model.downloads.first : null;
     bool isMatch = false;
     if (first != null && first.url == _lastTriggeredDownloadUrl) {
       isMatch = true;
     }

     return Container(
       color: Colors.black.withOpacity(0.9),
       child: Center(
         child: Container(
           margin: const EdgeInsets.all(24),
           padding: const EdgeInsets.all(24),
           decoration: BoxDecoration(
             color: const Color(0xFF1E222B),
             borderRadius: BorderRadius.circular(20),
             border: Border.all(color: Colors.blueAccent.withOpacity(0.5)),
           ),
           child: Column(
             mainAxisSize: MainAxisSize.min,
             children: [
               const Icon(Icons.download_for_offline, size: 64, color: Colors.blueAccent),
               const SizedBox(height: 16),
               const Text("Bledo Interactive Downloader", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 18)),
               const SizedBox(height: 8),
               Text(isMatch ? "File: ${first!.name}" : "Detecting stream...", style: const TextStyle(color: Colors.white70, fontSize: 14)),
               const SizedBox(height: 24),
               if (isMatch && first!.isDownloading)
                 Column(
                   children: [
                     LinearProgressIndicator(
                       value: first.progress,
                       backgroundColor: Colors.white10,
                       valueColor: const AlwaysStoppedAnimation(Colors.blueAccent),
                     ),
                     const SizedBox(height: 8),
                     Text("${(first.progress * 100).toInt()}%", style: const TextStyle(color: Colors.blueAccent, fontWeight: FontWeight.bold)),
                   ],
                 )
               else if (isMatch && !first!.isDownloading)
                  const Text("DOWNLOAD COMPLETE", style: TextStyle(color: Colors.greenAccent, fontWeight: FontWeight.bold))
               else 
                  const CircularProgressIndicator(),
               const SizedBox(height: 32),
               Row(
                 mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                 children: [
                   ElevatedButton(
                     onPressed: () => setState(() => _isShowingDownloadFrame = false),
                     style: ElevatedButton.styleFrom(backgroundColor: Colors.white10),
                     child: const Text("Return to Website"),
                   ),
                   if (isMatch && !first!.isDownloading)
                     ElevatedButton(
                       onPressed: () {
                          // Launch folder or open file
                          setState(() => _isShowingDownloadFrame = false);
                       },
                       style: ElevatedButton.styleFrom(backgroundColor: Colors.blueAccent),
                       child: const Text("Open File"),
                     ),
                 ],
               )
             ],
           ),
         ),
       ),
     );
  }

  void _showMiniMenu(BuildContext context, BrowserModel model) {
    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF111318),
      builder: (context) => Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          ListTile(
            leading: const Icon(Icons.open_in_browser, color: Colors.blueAccent),
            title: const Text("Open in Full Browser", style: TextStyle(color: Colors.white)),
            onTap: () {
              model.openInFullBrowser();
              Navigator.pop(context);
            },
          ),
          ListTile(
            leading: const Icon(Icons.close, color: Colors.redAccent),
            title: const Text("Terminate Session", style: TextStyle(color: Colors.white)),
            onTap: () => model.closeMiniBrowser(),
          ),
        ],
      ),
    );
  }
}
