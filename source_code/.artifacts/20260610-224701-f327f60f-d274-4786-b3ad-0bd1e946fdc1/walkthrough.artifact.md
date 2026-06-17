# Walkthrough - Enhanced Privacy Integration

I have added a new **Enhanced Privacy** feature to Bledo, which is enabled by default. This feature addresses several advanced tracking techniques that don't require deleting your persistent data.

## New Privacy Features

### 1. Referer Trimming
- **Mechanism**: Injected a `UserScript` that adds a `<meta name="referrer" content="same-origin">` tag to every page.
- **Benefit**: Prevents websites from seeing the exact page you came from when you click an external link, stopping history leakage to third parties.

### 2. Fingerprinting Jitter (Anti-Font Fingerprinting)
- **Mechanism**: Overrode `offsetWidth` and `offsetHeight` in the browser's DOM. When a site tries to measure text (a common way to detect your installed fonts), Bledo adds a tiny random "jitter" to the measurement.
- **Benefit**: Makes your font profile look unique and unstable to trackers, preventing them from using fonts to identify your device.

### 3. Screen & Viewport Masking
- **Mechanism**: Spoofed `window.screen` and related properties (`innerWidth`, `outerWidth`, etc.) to report a standardized 1080p resolution (1920x1080) regardless of your actual phone screen size.
- **Benefit**: Makes your device look like a standard desktop monitor to trackers, hiding your specific hardware model.

### 4. DNS CNAME Uncloaking
- **Mechanism**: Updated the [doh_proxy.dart](file:///C:/Users/Hello/AndroidStudioProjects/Bledo_full_project/Bledo/lib/doh_proxy.dart) to inspect the full chain of DNS records. If a domain (like `stats.example.com`) is found to be an alias (CNAME) for a known tracker (like `tracker.com`), the connection is blocked.
- **Benefit**: Stops advanced trackers that hide behind "first-party" subdomains to bypass traditional ad-blockers.

### 5. Aggressive Content Blocking
- **Mechanism**: Enhanced the `ContentBlocker` logic to automatically block any URL containing patterns like `telemetry`, `beacons`, or `metrics` when Enhanced Privacy is on.

## UI & Settings
- Added a new **Enhanced Privacy** toggle in the Bledo Settings page.
- The feature is **Enabled by Default** for all users.
