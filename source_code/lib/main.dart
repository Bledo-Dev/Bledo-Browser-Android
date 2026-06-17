import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:flutter/services.dart';
import 'package:app_links/app_links.dart';
import 'package:window_manager/window_manager.dart';
import 'dart:io';
import 'browser_model.dart';
import 'browser_screen.dart';
import 'ios_browser_screen.dart';
import 'windows_browser_screen.dart';
import 'mini_browser.dart';
import 'security_guard.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  if (Platform.isWindows || Platform.isLinux || Platform.isMacOS) {
    await windowManager.ensureInitialized();
    WindowOptions windowOptions = const WindowOptions(
      size: Size(1280, 800),
      center: true,
      backgroundColor: Colors.transparent,
      skipTaskbar: false,
      titleBarStyle: TitleBarStyle.hidden,
    );
    windowManager.waitUntilReadyToShow(windowOptions, () async {
      await windowManager.show();
      await windowManager.focus();
    });
  }

  final browserModel = BrowserModel();

  // Handle External Links (App Links / Intents)
  final appLinks = AppLinks();
  
  // 1. Initial Link (when app is opened via link)
  final initialLink = await appLinks.getInitialLink();
  if (initialLink != null) {
    browserModel.setExternalIntentUrl(initialLink.toString());
  }

  // 2. Incoming Links (when app is already running)
  appLinks.uriLinkStream.listen((uri) {
    browserModel.setExternalIntentUrl(uri.toString());
  });
  
  // Anti-Tampering Check
  SecurityLevel securityLevel = await SecurityGuard.performIntegrityCheck(browserModel);
  
  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider.value(value: browserModel),
      ],
      child: BledoApp(securityLevel: securityLevel),
    ),
  );
}

class BledoApp extends StatefulWidget {
  final SecurityLevel securityLevel;
  const BledoApp({super.key, required this.securityLevel});

  @override
  State<BledoApp> createState() => _BledoAppState();
}

class _BledoAppState extends State<BledoApp> {
  late bool _allowProceed;

  @override
  void initState() {
    super.initState();
    _allowProceed = widget.securityLevel == SecurityLevel.safe;
  }

  @override
  Widget build(BuildContext context) {
    final model = Provider.of<BrowserModel>(context);

    ThemeData themeData;
    switch (model.currentTheme) {
      case 'Blue':
        themeData = ThemeData(brightness: Brightness.dark, primaryColor: Colors.blue, scaffoldBackgroundColor: const Color(0xFF0F172A), useMaterial3: true);
        break;
      case 'Light':
        themeData = ThemeData(brightness: Brightness.light, primaryColor: Colors.blue, useMaterial3: true);
        break;
      case 'Green':
        themeData = ThemeData(brightness: Brightness.dark, primaryColor: Colors.green, scaffoldBackgroundColor: const Color(0xFF064E3B), useMaterial3: true);
        break;
      default:
        themeData = ThemeData(brightness: Brightness.dark, primaryColor: Colors.blue, scaffoldBackgroundColor: const Color(0xFF111318), useMaterial3: true);
    }

    bool isDesktop = Platform.isWindows || Platform.isMacOS || Platform.isLinux;
    bool isIos = Platform.isIOS;

    return MaterialApp(
      title: 'Bledo Browser',
      theme: themeData,
      home: model.externalIntentUrl != null 
        ? MiniBrowser(url: model.externalIntentUrl!)
        : (_allowProceed 
            ? (isIos ? const IosBrowserScreen() : (isDesktop ? const WindowsBrowserScreen() : Stack(
                children: [
                  const BrowserScreen(),
                  if (widget.securityLevel != SecurityLevel.safe) 
                    Positioned(
                      top: 0, left: 0, right: 0,
                      child: Material(
                        color: Colors.red.withOpacity(0.9),
                        child: SafeArea(
                          bottom: false,
                          child: Container(
                            padding: const EdgeInsets.symmetric(vertical: 4.0, horizontal: 8.0),
                            child: Text(
                              widget.securityLevel == SecurityLevel.critical 
                                ? "CRITICAL SECURITY BREACH: Integrity compromised." 
                                : "SECURITY WARNING: This environment may be compromised.", 
                              textAlign: TextAlign.center, 
                              style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold),
                            ),
                          ),
                        ),
                      ),
                    )
                ],
              )))
            : Scaffold(
                backgroundColor: const Color(0xFF111318),
                body: Center(
                  child: Padding(
                    padding: const EdgeInsets.all(32.0),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          widget.securityLevel == SecurityLevel.critical ? Icons.gpp_bad : Icons.security_update_warning, 
                          color: Colors.redAccent, 
                          size: 64
                        ),
                        const SizedBox(height: 24),
                        Text(
                          widget.securityLevel == SecurityLevel.critical ? "CRITICAL BREACH" : "SECURITY BREACH",
                          style: const TextStyle(color: Colors.redAccent, fontWeight: FontWeight.bold, fontSize: 24),
                        ),
                        const SizedBox(height: 16),
                        Text(
                          widget.securityLevel == SecurityLevel.critical 
                            ? "Application signature mismatch detected.\nAll sensitive data has been wiped for your protection." 
                            : "Application Integrity Compromised.\nYour environment does not meet the security requirements for this browser.",
                          textAlign: TextAlign.center,
                          style: const TextStyle(color: Colors.white70, fontSize: 16),
                        ),
                        const SizedBox(height: 48),
                        if (widget.securityLevel == SecurityLevel.warning)
                          ElevatedButton(
                            onPressed: () => setState(() => _allowProceed = true),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.redAccent,
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 12),
                            ),
                            child: const Text("PROCEED ANYWAY (Insecure)"),
                          ),
                        if (widget.securityLevel == SecurityLevel.critical)
                          const Text(
                            "This application has been permanently locked for security reasons. Please reinstall the official version.",
                            textAlign: TextAlign.center,
                            style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold),
                          ),
                        const SizedBox(height: 16),
                        TextButton(
                          onPressed: () => SystemNavigator.pop(),
                          child: const Text("CLOSE APP", style: TextStyle(color: Colors.white38)),
                        ),
                      ],
                    ),
                  ),
                ),
              )),
      debugShowCheckedModeBanner: false,
    );
  }
}
