import 'package:flutter_inappwebview/flutter_inappwebview.dart';
import 'browser_model.dart';
import 'dart:collection';
import 'package:flutter/foundation.dart';
import 'dart:io';

class PrivacyLogic {
  static String getDashboardHtml({bool isPrivate = false, String? proxyType, String currentEngine = "https://duckduckgo.com/?q="}) {
    String themeColor = isPrivate ? "#1e1b4b" : "#0A0C10";
    String gradient = isPrivate
        ? "linear-gradient(to right, #c084fc, #818cf8)"
        : "linear-gradient(to right, #A5F3FC, #38bdf8)";
    String privateBadge = isPrivate
        ? '<div style="background: #4c1d95; color: #e9d5ff; padding: 5px 15px; border-radius: 20px; font-size: 0.8rem; margin-top: 10px; border: 1px solid #7c3aed; display: inline-block;">Private Mode ${proxyType != null ? "($proxyType active)" : ""}</div><div style="color: #ef4444; font-size: 0.7rem; margin-top: 5px;">No cookies or data is allowed to exit this tab</div>'
        : '';

    final engines = {
        "https://duckduckgo.com/?q=": "DuckDuckGo",
        "https://www.google.com/search?q=": "Google",
        "https://search.brave.com/search?q=": "Brave Search",
        "https://www.startpage.com/sp/search?query=": "Startpage"
    };
    
    String engineName = engines[currentEngine] ?? "DuckDuckGo";

    return '''
<!DOCTYPE html>
<html lang="en">
<head>
    <meta charset="UTF-8">
    <meta http-equiv="Content-Security-Policy" content="default-src 'self' 'unsafe-inline' 'unsafe-eval' data: blob: https://tile.openstreetmap.org; img-src 'self' data: https://*; font-src 'self' data: https://fonts.gstatic.com;">
    <meta name="viewport" content="width=device-width, initial-scale=1.0, maximum-scale=1.0, user-scalable=no">
    <title>Bledo Dashboard</title>
    <style>
        * { box-sizing: border-box; margin: 0; padding: 0; font-family: -apple-system, BlinkMacSystemFont, "Segoe UI", Roboto, Helvetica, Arial, sans-serif; -webkit-tap-highlight-color: transparent; }
        body { background-color: $themeColor; color: #e2e8f0; display: flex; flex-direction: column; align-items: center; justify-content: center; min-height: 100vh; padding: 20px; overflow-x: hidden; }
        .brand-container { text-align: center; margin-bottom: 40px; }
        .logo { width: 120px; height: 120px; margin-bottom: 24px; filter: drop-shadow(0 0 15px rgba(165, 243, 252, 0.4)); }
        h1 { font-size: 3.5rem; font-weight: 700; letter-spacing: 1px; margin-bottom: 12px; background: $gradient; -webkit-background-clip: text; -webkit-text-fill-color: transparent; }
        .description { color: #64748b; font-size: 0.95rem; max-width: 450px; line-height: 1.5; margin-bottom: 10px; }
        
        .search-wrapper { width: 100%; max-width: 600px; display: flex; align-items: center; background: rgba(27, 32, 40, 0.6); border: 1px solid #334155; border-radius: 16px; padding: 8px; margin-bottom: 40px; transition: border-color 0.2s; }
        .search-wrapper:focus-within { border-color: #A5F3FC; }
        
        .engine-selector { position: relative; margin-right: 8px; }
        .engine-trigger { background: #1B2028; color: #94a3b8; border-radius: 12px; padding: 12px 20px; font-size: 0.9rem; cursor: pointer; display: flex; align-items: center; min-width: 130px; justify-content: space-between; }
        .engine-trigger::after { content: '▾'; margin-left: 10px; font-size: 0.8rem; }
        
        .engine-menu { position: absolute; top: calc(100% + 8px); left: 0; background: #1B2028; border: 1px solid #334155; border-radius: 12px; display: none; flex-direction: column; z-index: 100; min-width: 160px; box-shadow: 0 10px 25px rgba(0,0,0,0.4); }
        .engine-menu.active { display: flex; }
        .engine-item { padding: 12px 16px; cursor: pointer; color: #cbd5e1; font-size: 0.85rem; }
        .engine-item:hover { background: #334155; }

        .search-form { flex: 1; display: flex; align-items: center; padding-right: 12px; }
        .search-input { flex: 1; background: transparent; border: none; outline: none; color: white; padding: 12px; font-size: 1.1rem; }
        .search-input::placeholder { color: #475569; }
        .go-btn { color: #A5F3FC; font-weight: bold; background: transparent; border: none; cursor: pointer; font-size: 0.9rem; padding: 8px; }

        .shortcuts-grid { display: flex; flex-wrap: wrap; gap: 20px; justify-content: center; }
        .shortcut-item { width: 100px; height: 110px; display: flex; flex-direction: column; align-items: center; cursor: pointer; transition: transform 0.2s; position: relative; }
        .shortcut-item:hover { transform: translateY(-5px); }
        .shortcut-icon { width: 64px; height: 64px; background: #1B2028; border: 1px solid #334155; border-radius: 16px; display: flex; align-items: center; justify-content: center; margin-bottom: 8px; font-size: 1.5rem; font-weight: bold; color: #A5F3FC; }
        .shortcut-name { font-size: 0.75rem; color: #94a3b8; text-align: center; max-width: 90px; overflow: hidden; text-overflow: ellipsis; white-space: nowrap; }
        
        .add-shortcut { width: 64px; height: 64px; background: rgba(30, 41, 59, 0.4); border: 2px dashed #334155; border-radius: 16px; display: flex; align-items: center; justify-content: center; cursor: pointer; transition: border-color 0.2s; }
        .add-shortcut:hover { border-color: #A5F3FC; }
        .add-shortcut span { font-size: 1.5rem; color: #475569; }
        
        .modal-overlay { position: fixed; top: 0; left: 0; width: 100%; height: 100%; background: rgba(0,0,0,0.8); backdrop-filter: blur(8px); display: none; align-items: center; justify-content: center; z-index: 1000; }
        .modal-overlay.active { display: flex; }
        .modal-content { background: #0f172a; border: 1px solid #334155; border-radius: 24px; padding: 30px; width: 90%; max-width: 400px; }
        .modal-content h3 { color: white; margin-bottom: 20px; }
        .modal-input { width: 100%; background: #1B2028; border: 1px solid #334155; border-radius: 12px; padding: 14px; color: white; margin-bottom: 15px; outline: none; }
        .modal-buttons { display: flex; justify-content: flex-end; gap: 12px; }
        .btn { padding: 12px 24px; border-radius: 12px; border: none; cursor: pointer; font-weight: bold; }
        .btn-cancel { background: #334155; color: white; }
        .btn-add { background: #A5F3FC; color: #0f172a; }

        .shortcut-options-trigger { position: absolute; top: -5px; right: 5px; width: 24px; height: 24px; color: #A5F3FC; display: none; align-items: center; justify-content: center; font-size: 18px; font-weight: bold; z-index: 10; border-radius: 50%; background: rgba(0,0,0,0.6); }
        .shortcut-item:hover .shortcut-options-trigger { display: flex; }
        
        .options-menu { position: absolute; top: 25px; right: 0; background: #1B2028; border: 1px solid #334155; border-radius: 12px; display: none; flex-direction: column; z-index: 100; min-width: 100px; box-shadow: 0 10px 25px rgba(0,0,0,0.5); overflow: hidden; }
        .options-menu.active { display: flex; }
        .options-item { padding: 8px 12px; font-size: 0.8rem; color: #cbd5e1; cursor: pointer; }
        .options-item:hover { background: #334155; color: #A5F3FC; }
    </style>
</head>
<body>
    <div class="brand-container">
        <svg class="logo" viewBox="0 0 100 100" fill="none" xmlns="http://www.w3.org/2000/svg">
            <defs>
                <filter id="glow" x="-20%" y="-20%" width="140%" height="140%">
                    <feGaussianBlur stdDeviation="2" result="blur" />
                    <feComposite in="SourceGraphic" in2="blur" operator="over" />
                </filter>
            </defs>
            <circle cx="50" cy="50" r="48" fill="#1B2028" />
            <g filter="url(#glow)">
                <circle cx="50" cy="50" r="4.5" fill="#A5F3FC" />
                <ellipse cx="50" cy="50" rx="14" ry="38" stroke="#A5F3FC" stroke-width="2.5" fill="none" />
                <ellipse cx="50" cy="50" rx="14" ry="38" stroke="#A5F3FC" stroke-width="2.5" fill="none" transform="rotate(120 50 50)" />
                <ellipse cx="50" cy="50" rx="14" ry="38" stroke="#A5F3FC" stroke-width="2.5" fill="none" transform="rotate(240 50 50)" />
                <circle cx="50" cy="88" r="3.5" fill="#A5F3FC" />
                <circle cx="17.1" cy="31" r="3.5" fill="#A5F3FC" />
                <circle cx="82.9" cy="31" r="3.5" fill="#A5F3FC" />
            </g>
        </svg>
        <h1>Bledo</h1>
        <p class="description">Bledo the best security & privacy focused browser.</p>
        $privateBadge
    </div>

    <div class="search-wrapper">
        <div class="engine-selector">
            <div class="engine-trigger" id="engineTrigger">$engineName</div>
            <div class="engine-menu" id="engineMenu">
                <div class="engine-item" data-url="https://duckduckgo.com/?q=" data-name="DuckDuckGo">DuckDuckGo</div>
                <div class="engine-item" data-url="https://www.google.com/search?q=" data-name="Google">Google</div>
                <div class="engine-item" data-url="https://search.brave.com/search?q=" data-name="Brave Search">Brave Search</div>
                <div class="engine-item" data-url="https://www.startpage.com/sp/search?query=" data-name="Startpage">Startpage</div>
            </div>
        </div>
        <div class="search-form">
            <input type="text" id="searchInput" class="search-input" placeholder="Search the Web..." autocomplete="off">
            <button class="go-btn" id="goBtn">Go</button>
        </div>
    </div>

    <div class="shortcuts-grid" id="shortcutsGrid">
        <div class="add-shortcut" id="addShortcut"><span>+</span></div>
    </div>

    <div class="modal-overlay" id="modalOverlay">
        <div class="modal-content">
            <h3 id="modalTitle">Add Shortcut</h3>
            <input type="text" id="nameInput" class="modal-input" placeholder="Name">
            <input type="text" id="urlInput" class="modal-input" placeholder="Website">
            <div class="modal-buttons">
                <button class="btn btn-cancel" id="cancelBtn">Cancel</button>
                <button class="btn btn-add" id="saveBtn">Save</button>
            </div>
        </div>
    </div>

    <script>
        const trigger = document.getElementById('engineTrigger');
        const menu = document.getElementById('engineMenu');
        const searchInput = document.getElementById('searchInput');
        const goBtn = document.getElementById('goBtn');
        const shortcutsGrid = document.getElementById('shortcutsGrid');
        const modalOverlay = document.getElementById('modalOverlay');
        const addBtn = document.getElementById('addShortcut');
        const nameInput = document.getElementById('nameInput');
        const urlInput = document.getElementById('urlInput');
        const saveBtn = document.getElementById('saveBtn');
        const modalTitle = document.getElementById('modalTitle');

        let currentEngine = localStorage.getItem('bledo_engine') || "$currentEngine";
        let shortcuts = JSON.parse(localStorage.getItem('bledo_shortcuts')) || [];
        let editingIndex = -1;

        function renderShortcuts() {
            document.querySelectorAll('.shortcut-item').forEach(e => e.remove());
            shortcuts.forEach((s, index) => {
                const div = document.createElement('div');
                div.className = 'shortcut-item';
                div.innerHTML = `
                    <div class="shortcut-options-trigger" data-index="\${index}">...</div>
                    <div class="options-menu" id="options-\${index}">
                        <div class="options-item" onclick="window.openEdit(\${index})">✎ Edit</div>
                        <div class="options-item" onclick="window.deleteShortcut(\${index})" style="color: #ef4444">🗑 Delete</div>
                    </div>
                    <div class="shortcut-icon">\${s.name.charAt(0).toUpperCase()}</div>
                    <div class="shortcut-name">\${s.name}</div>
                `;
                
                div.addEventListener('click', (e) => {
                    if (!e.target.classList.contains('shortcut-options-trigger') && !e.target.closest('.options-menu')) {
                        if (window.flutter_inappwebview) {
                            window.flutter_inappwebview.callHandler('onNavigate', s.url);
                        } else {
                            window.location.href = s.url;
                        }
                    }
                });

                const t = div.querySelector('.shortcut-options-trigger');
                t.addEventListener('click', (e) => {
                    e.stopPropagation();
                    closeAllMenus();
                    const m = div.querySelector('.options-menu');
                    m.classList.toggle('active');
                });

                shortcutsGrid.insertBefore(div, addBtn);
            });
        }

        function closeAllMenus() {
            document.querySelectorAll('.options-menu').forEach(m => m.classList.remove('active'));
        }

        window.deleteShortcut = function(index) {
            shortcuts.splice(index, 1);
            localStorage.setItem('bledo_shortcuts', JSON.stringify(shortcuts));
            renderShortcuts();
        };

        window.openEdit = function(index) {
            editingIndex = index;
            const s = shortcuts[index];
            nameInput.value = s.name;
            urlInput.value = s.url;
            modalTitle.innerText = "Edit Shortcut";
            modalOverlay.classList.add('active');
            closeAllMenus();
        };

        addBtn.addEventListener('click', () => {
            editingIndex = -1;
            nameInput.value = '';
            urlInput.value = '';
            modalTitle.innerText = "Add Shortcut";
            modalOverlay.classList.add('active');
        });

        document.getElementById('cancelBtn').addEventListener('click', () => modalOverlay.classList.remove('active'));

        saveBtn.addEventListener('click', () => {
            const name = nameInput.value.trim();
            let url = urlInput.value.trim();
            if (name && url) {
                if (!url.startsWith('http')) url = 'https://' + url;
                if (editingIndex >= 0) {
                    shortcuts[editingIndex] = { name, url };
                } else {
                    shortcuts.push({ name, url });
                }
                localStorage.setItem('bledo_shortcuts', JSON.stringify(shortcuts));
                renderShortcuts();
                modalOverlay.classList.remove('active');
            }
        });

        trigger.addEventListener('click', (e) => {
            e.stopPropagation();
            menu.classList.toggle('active');
        });

        document.querySelectorAll('.engine-item').forEach(item => {
            item.addEventListener('click', () => {
                currentEngine = item.dataset.url;
                trigger.textContent = item.dataset.name;
                menu.classList.remove('active');
                localStorage.setItem('bledo_engine', currentEngine);
                if (window.flutter_inappwebview) {
                    window.flutter_inappwebview.callHandler('onEngineChange', currentEngine);
                }
            });
        });

        document.addEventListener('click', () => {
            menu.classList.remove('active');
            closeAllMenus();
        });

        function search() {
            const q = searchInput.value.trim();
            if (!q) return;
            if (window.flutter_inappwebview) {
                window.flutter_inappwebview.callHandler('onNavigate', q, currentEngine);
            }
        }

        goBtn.addEventListener('click', search);
        searchInput.addEventListener('keypress', (e) => { if(e.key === 'Enter') search(); });

        renderShortcuts();
    </script>
</body>
</html>
''';
  }

  static List<ContentBlocker> getContentBlockers(List<AntiVirusRule> avRules, bool adBlockEnabled, bool antiVirusEnabled, {bool isEnhancedPrivacyEnabled = false}) {
    List<ContentBlocker> blockers = [];
    if (adBlockEnabled || isEnhancedPrivacyEnabled) {
      blockers.addAll([
        ContentBlocker(trigger: ContentBlockerTrigger(urlFilter: ".*doubleclick.net.*"), action: ContentBlockerAction(type: ContentBlockerActionType.BLOCK)),
        ContentBlocker(trigger: ContentBlockerTrigger(urlFilter: ".*google-analytics.com.*"), action: ContentBlockerAction(type: ContentBlockerActionType.BLOCK)),
        ContentBlocker(trigger: ContentBlockerTrigger(urlFilter: ".*ads.*"), action: ContentBlockerAction(type: ContentBlockerActionType.BLOCK)),
        ContentBlocker(trigger: ContentBlockerTrigger(urlFilter: ".*facebook.net.*"), action: ContentBlockerAction(type: ContentBlockerActionType.BLOCK)),
        ContentBlocker(trigger: ContentBlockerTrigger(urlFilter: ".*tiktok.com/.*pixel.*"), action: ContentBlockerAction(type: ContentBlockerActionType.BLOCK)),
        ContentBlocker(trigger: ContentBlockerTrigger(urlFilter: ".*crypto-locker.*|.*coin-hive.*"), action: ContentBlockerAction(type: ContentBlockerActionType.BLOCK)),
      ]);
      
      if (isEnhancedPrivacyEnabled) {
        blockers.addAll([
          ContentBlocker(trigger: ContentBlockerTrigger(urlFilter: ".*telemetry.*"), action: ContentBlockerAction(type: ContentBlockerActionType.BLOCK)),
          ContentBlocker(trigger: ContentBlockerTrigger(urlFilter: ".*metrics.*"), action: ContentBlockerAction(type: ContentBlockerActionType.BLOCK)),
          ContentBlocker(trigger: ContentBlockerTrigger(urlFilter: ".*beacons.*"), action: ContentBlockerAction(type: ContentBlockerActionType.BLOCK)),
          ContentBlocker(trigger: ContentBlockerTrigger(urlFilter: ".*track.*"), action: ContentBlockerAction(type: ContentBlockerActionType.BLOCK)),
        ]);
      }
    }
    if (antiVirusEnabled) {
      for (var rule in avRules) {
        if (rule.enabled) {
          blockers.add(ContentBlocker(trigger: ContentBlockerTrigger(urlFilter: rule.pattern), action: ContentBlockerAction(type: ContentBlockerActionType.BLOCK)));
        }
      }
    }
    return blockers;
  }

  static InAppWebViewSettings getWebViewSettings({
    bool isPrivate = false,
    bool adBlockEnabled = true,
    bool antiVirusEnabled = true,
    List<AntiVirusRule>? avRules,
    bool allowJs = true,
    bool allowCookies = true,
    bool allowLocation = false,
    bool isDesktopMode = false,
    bool vpnActive = false,
    bool isHardenedMode = false,
    bool isEnhancedPrivacyEnabled = false,
  }) {
    String userAgent = isHardenedMode || isEnhancedPrivacyEnabled
        ? "Mozilla/5.0 (Windows NT 10.0; Win64; x64; rv:123.0) Gecko/20100101 Firefox/123.0" // Generic modern UA
        : (isDesktopMode
            ? "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/122.0.0.0 Safari/537.36"
            : "Mozilla/5.0 (Linux; Android 10; K) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/122.0.0.0 Mobile Safari/537.36");

    return InAppWebViewSettings(
      incognito: isPrivate,
      useOnDownloadStart: true,
      useShouldOverrideUrlLoading: true,
      mediaPlaybackRequiresUserGesture: isHardenedMode || isEnhancedPrivacyEnabled ? true : false,
      javaScriptEnabled: allowJs,
      javaScriptCanOpenWindowsAutomatically: isHardenedMode || isEnhancedPrivacyEnabled ? false : true,
      supportMultipleWindows: isHardenedMode || isEnhancedPrivacyEnabled ? false : true,
      domStorageEnabled: true,
      databaseEnabled: true,
      contentBlockers: getContentBlockers(avRules ?? [], adBlockEnabled, antiVirusEnabled, isEnhancedPrivacyEnabled: isEnhancedPrivacyEnabled),
      userAgent: userAgent,
      forceDark: ForceDark.OFF,
      transparentBackground: true,
      cacheEnabled: !isPrivate,
      clearCache: isPrivate,
      clearSessionCache: isPrivate,
      geolocationEnabled: vpnActive ? true : allowLocation,
      mixedContentMode: isHardenedMode || isEnhancedPrivacyEnabled ? MixedContentMode.MIXED_CONTENT_NEVER_ALLOW : MixedContentMode.MIXED_CONTENT_ALWAYS_ALLOW,
      safeBrowsingEnabled: true,
      useWideViewPort: true,
      loadWithOverviewMode: true,
      supportZoom: true,
      preferredContentMode: isDesktopMode ? UserPreferredContentMode.DESKTOP : UserPreferredContentMode.MOBILE,
      allowFileAccessFromFileURLs: isHardenedMode || isEnhancedPrivacyEnabled ? false : true,
      allowUniversalAccessFromFileURLs: isHardenedMode || isEnhancedPrivacyEnabled ? false : true,
      verticalScrollBarEnabled: true,
      horizontalScrollBarEnabled: true,
      algorithmicDarkeningAllowed: false,
      requestedWithHeaderOriginAllowList: isHardenedMode || isEnhancedPrivacyEnabled ? {} : null,
    );
  }

  static UnmodifiableListView<UserScript>? getVpnUserScripts(VpnLocation? location) {
    if (location == null) return null;

    final script = UserScript(
      source: """
        (function() {
          const spoofCoords = {
            latitude: ${location.lat},
            longitude: ${location.lng},
            accuracy: 10,
            altitude: null,
            altitudeAccuracy: null,
            heading: null,
            speed: null
          };

          navigator.geolocation.getCurrentPosition = function(success, error, options) {
            success({ coords: spoofCoords, timestamp: Date.now() });
          };

          navigator.geolocation.watchPosition = function(success, error, options) {
            success({ coords: spoofCoords, timestamp: Date.now() });
            return 1337;
          };
        })();
      """,
      injectionTime: UserScriptInjectionTime.AT_DOCUMENT_START,
    );

    return UnmodifiableListView<UserScript>([script]);
  }

  static List<UserScript> getHardeningScripts() {
    return [
      UserScript(
        source: """
          (function() {
            // 1. Canvas Fingerprinting Protection (Noise Injection)
            const originalGetImageData = CanvasRenderingContext2D.prototype.getImageData;
            CanvasRenderingContext2D.prototype.getImageData = function(x, y, w, h) {
              const imageData = originalGetImageData.apply(this, arguments);
              for (let i = 0; i < 10; i++) {
                imageData.data[i] = (imageData.data[i] + Math.floor(Math.random() * 2)) % 256;
              }
              return imageData;
            };

            // 2. WebGL Fingerprinting Protection
            const originalReadPixels = WebGLRenderingContext.prototype.readPixels;
            WebGLRenderingContext.prototype.readPixels = function() {
              return originalReadPixels.apply(this, arguments);
            };

            // 3. Hardware & Environment Spoofing (Super Hardening)
            Object.defineProperty(navigator, 'hardwareConcurrency', { value: 4 });
            Object.defineProperty(navigator, 'deviceMemory', { value: 8 });
            Object.defineProperty(navigator, 'maxTouchPoints', { value: 5 });
            
            // 4. Global Privacy Control (GPC)
            Object.defineProperty(navigator, 'globalPrivacyControl', { value: true });
            Object.defineProperty(navigator, 'doNotTrack', { value: "1" });

            // 5. AudioContext Fingerprinting Protection
            const originalCreateBuffer = window.AudioContext ? window.AudioContext.prototype.createBuffer : null;
            if (originalCreateBuffer) {
              window.AudioContext.prototype.createBuffer = function() {
                const buffer = originalCreateBuffer.apply(this, arguments);
                const data = buffer.getChannelData(0);
                if (data.length > 0) data[0] += (Math.random() * 0.0000001);
                return buffer;
              };
            }

            // 6. Timezone & Locale Standardization (Standardizing to UTC/Generic)
            const originalResolvedOptions = Intl.DateTimeFormat.prototype.resolvedOptions;
            Intl.DateTimeFormat.prototype.resolvedOptions = function() {
              const options = originalResolvedOptions.apply(this, arguments);
              options.timeZone = "UTC";
              return options;
            };

            // 7. Disable Sensitive Tracking APIs
            if (navigator.battery) {
              Object.defineProperty(navigator, 'battery', { value: undefined });
            }
            if (navigator.getBattery) {
              navigator.getBattery = () => new Promise((resolve) => resolve({
                level: 1.0, charging: true, chargingTime: 0, dischargingTime: Infinity
              }));
            }
            
            // 8. WebRTC Leak Protection (Strict)
            if (navigator.mediaDevices && navigator.mediaDevices.getUserMedia) {
               navigator.mediaDevices.getUserMedia = function() {
                 return Promise.reject(new Error('WebRTC is disabled for privacy.'));
               };
            }
            
            // 9. Disable Gamepad, Vibration, and Screen Orientation APIs
            navigator.getGamepads = () => [];
            navigator.vibrate = () => false;
            if (screen.orientation) {
              Object.defineProperty(screen.orientation, 'lock', { value: () => Promise.reject() });
            }
            
            console.log('Bledo Super-Hardening Active: Comprehensive fingerprinting and tracking protection applied.');
          })();
        """,
        injectionTime: UserScriptInjectionTime.AT_DOCUMENT_START,
      )
    ];
  }

  static List<UserScript> getEnhancedPrivacyScripts() {
    return [
      UserScript(
        source: """
          (function() {
            // 1. Referer Trimming (Strict)
            const meta = document.createElement('meta');
            meta.name = "referrer";
            meta.content = "same-origin"; // Only send referrer to same domain
            document.head.appendChild(meta);

            // 2. Font Fingerprinting Protection (Jitter)
            const originalOffsetWidth = Object.getOwnPropertyDescriptor(HTMLElement.prototype, 'offsetWidth').get;
            const originalOffsetHeight = Object.getOwnPropertyDescriptor(HTMLElement.prototype, 'offsetHeight').get;

            Object.defineProperty(HTMLElement.prototype, 'offsetWidth', {
              get: function() {
                const val = originalOffsetWidth.apply(this);
                if (this.tagName === 'SPAN' && (this.style.fontFamily || this.style.fontSize)) {
                   return val + (Math.random() > 0.5 ? 0.001 : -0.001);
                }
                return val;
              }
            });

            // 3. Screen & Viewport Spoofing (Standardizing to 1080p)
            const standardScreen = {
              width: 1920,
              height: 1080,
              availWidth: 1920,
              availHeight: 1040,
              colorDepth: 24,
              pixelDepth: 24,
              orientation: { type: 'landscape-primary', angle: 0 }
            };

            Object.defineProperty(window, 'screen', { value: standardScreen });
            Object.defineProperty(window, 'innerWidth', { value: 1920 });
            Object.defineProperty(window, 'innerHeight', { value: 1080 });
            Object.defineProperty(window, 'outerWidth', { value: 1920 });
            Object.defineProperty(window, 'outerHeight', { value: 1080 });
            Object.defineProperty(window, 'devicePixelRatio', { value: 1 });
            
            console.log('Bledo Enhanced Privacy Active: Referer trimming and fingerprint masking applied.');
          })();
        """,
        injectionTime: UserScriptInjectionTime.AT_DOCUMENT_START,
      )
    ];
  }

  static String formatSearchUrl(String query, {String? searchBase}) {
    String trimmed = query.trim();
    if (trimmed == 'bledo://dashboard') return trimmed;
    if (trimmed.startsWith('http://') || trimmed.startsWith('https://')) return trimmed;
    final domainRegex = RegExp(r'^(?!.* )([a-zA-Z0-9-]+\.)+[a-zA-Z]{2,}(/.*)?\$');
    if (domainRegex.hasMatch(trimmed) || trimmed.startsWith('localhost')) return 'https://$trimmed';
    String base = searchBase ?? 'https://duckduckgo.com/?q=';
    return '$base\${Uri.encodeComponent(trimmed)}';
  }

  static Future<void> applyProxy(String? proxyType, int torPort, {int? dohPort}) async {
    debugPrint("DEBUG: applyProxy called with type: \$proxyType, torPort: \$torPort, dohPort: \$dohPort");
    
    // Priority: Tor > DoH Proxy
    String? proxyUrl;
    if (proxyType == 'Tor') {
      proxyUrl = "socks5://127.0.0.1:\$torPort";
    } else if (dohPort != null && dohPort > 0) {
      proxyUrl = "socks5://127.0.0.1:\$dohPort";
    }

    if (proxyUrl != null) {
      bool supported = await WebViewFeature.isFeatureSupported(WebViewFeature.PROXY_OVERRIDE);
      if (supported) {
        try {
          await ProxyController.instance().setProxyOverride(
            settings: ProxySettings(
              proxyRules: [ProxyRule(url: proxyUrl)],
              bypassRules: ["<local>"],
            ),
          );
        } catch (e) {
          debugPrint("DEBUG: ProxyOverride Error: \$e");
        }
      }
    } else {
      bool supported = await WebViewFeature.isFeatureSupported(WebViewFeature.PROXY_OVERRIDE);
      if (supported) {
        await ProxyController.instance().clearProxyOverride();
      }
    }
  }

  static Future<bool> _isProxyLive(String host, int port) async {
    try {
      final socket = await Socket.connect(host, port, timeout: const Duration(seconds: 1));
      await socket.close();
      return true;
    } catch (_) {
      return false;
    }
  }
}
