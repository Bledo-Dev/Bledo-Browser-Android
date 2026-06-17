# Tasks

- [x] Research existing implementations
    - [x] Search for "hardening mode"
    - [x] Search for "DoH" or "DNS over HTTPS"
    - [x] Identify DNS handling logic
    - [x] Understand "hardening mode" configuration
- [x] Design DoH with obfuscation
- [x] Implement DoH with obfuscation
    - [x] Create DohProxyServer with SOCKS5 support
    - [x] Implement DNS wire-format construction with padding
    - [x] Integrate with PrivacyLogic
- [x] Integrate with hardening mode
    - [x] Lifecycle management in BrowserModel
    - [x] Settings synchronization
- [x] Verify the implementation
    - [x] Manually verify padding logic
    - [x] Create unit test for padding
    - [x] Verify proxy priority (Tor vs DoH)
