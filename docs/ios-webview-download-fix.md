# iOS WebView File Download Fix

## Problem

File downloads (PDF, PNG, Excel, etc.) triggered from inside a Flutter `webview_flutter` WebView were silently failing on iOS. Android worked correctly. No error was shown to the user — the download simply never happened.

---

## Root Cause Analysis

### Bug 1 — Dead blob guard in `onNavigationRequest` (primary cause)

The navigation delegate had two separate checks for `blob:` URLs, but the first one returned early without doing anything useful:

```dart
// ❌ WRONG — blocks navigation but never triggers the download
if (request.url.startsWith('blob:')) {
  debugPrint('[Download] Blocked blob navigation: ${request.url}');
  return NavigationDecision.prevent;   // silently dropped!
}

// This second check NEVER ran because the first already returned
if (_isBlobUrl(request.url)) {
  unawaited(_requestBlobDownloadFromPage(request.url));
  return NavigationDecision.prevent;
}
```

On iOS, WKWebView fires a navigation request for blob URLs that the JS intercept misses (e.g. when the web page navigates directly via `window.location` or uses `<a download>`). The first guard blocked the navigation but never called `_requestBlobDownloadFromPage`, so the download was lost.

**Diagnostic log that revealed the bug:**
```
flutter: [Download] Blocked blob navigation: blob:https://yourdomain.com/138fd4c2-...
```
The URL appeared in logs but no download followed — confirming the block-without-action path was being hit.

### Bug 2 — Files saved to invisible app container (secondary cause)

On iOS, `getApplicationDocumentsDirectory()` saves files to the app's private sandbox:
```
/var/mobile/Containers/Data/Application/<UUID>/Documents/
```
Without the correct `Info.plist` keys, these files are **not visible** in the iOS Files app and `open_filex` (which uses `UIDocumentInteractionController`) may fail silently when trying to open them.

### Bug 3 — No iOS share sheet for opened files

`OpenFilex.open()` works well on Android but is unreliable on iOS for files in the app container. Users had no way to save files to Files, AirDrop them, or open in another app.

---

## Fix

### 1. Fix the blob navigation handler (`lib/main.dart`)

Remove the dead early-return guard. Merge into a single check that actually triggers the download:

```dart
// ✅ CORRECT
onNavigationRequest: (NavigationRequest request) {
  if (_isSpecialScheme(request.url)) {
    unawaited(_openExternally(request.url));
    return NavigationDecision.prevent;
  }
  if (_isBlobUrl(request.url)) {
    debugPrint('[Download] Blob navigation intercepted: ${request.url}');
    unawaited(_requestBlobDownloadFromPage(request.url));  // triggers JS → Dart download
    return NavigationDecision.prevent;
  }
  if (_shouldHandleAsDownload(request.url)) {
    unawaited(_downloadAndSaveFile(request.url));
    return NavigationDecision.prevent;
  }
  return NavigationDecision.navigate;
},
```

### 2. Expose the Documents folder to the Files app (`ios/Runner/Info.plist`)

Add these two keys:

```xml
<key>UIFileSharingEnabled</key>
<true/>
<key>LSSupportsOpeningDocumentsInPlace</key>
<true/>
```

`UIFileSharingEnabled` — exposes the app's Documents folder via iTunes and the Files app.
`LSSupportsOpeningDocumentsInPlace` — allows the Files app to open documents directly from the app container.

### 3. Use iOS share sheet to open downloaded files (`lib/main.dart`)

Add `share_plus` to `pubspec.yaml`:

```yaml
share_plus: ^10.1.4
```

In the open-file handler, use the native iOS share sheet instead of `open_filex`:

```dart
Future<void> _openDownloadedFile(String filePath) async {
  if (Platform.isIOS) {
    final box = context.findRenderObject() as RenderBox?;
    await Share.shareXFiles(
      [XFile(filePath)],
      sharePositionOrigin:
          box == null ? null : box.localToGlobal(Offset.zero) & box.size,
    );
    return;
  }

  // Android: use open_filex as before
  final result = await OpenFilex.open(filePath);
  ...
}
```

This gives the user Save to Files, AirDrop, Open In, and all standard iOS share options.

---

## How the Blob Download Flow Works (for reference)

```
User clicks download in WebView
        │
        ▼
JS intercept (injected on page load)
  patches window.open, URL.createObjectURL, anchor clicks
        │
        ├─ JS catches it → fetch(blobUrl) → FileReader → base64
        │                → DownloadChannel.postMessage(base64payload)
        │                       │
        │                       ▼
        │              Dart: _handleDownloadChannelMessage
        │                → base64Decode → _saveFileToDevice
        │
        └─ JS misses it → navigation reaches onNavigationRequest
                              │
                              ▼
                         _isBlobUrl check
                              │
                              ▼
                    _requestBlobDownloadFromPage
                       runs JS: window.__urbanEasyTriggerBlobDownload(url)
                              │
                              ▼
                       (same JS → Dart path as above)
```

---

## Checklist for Other Flutter WebView Apps

- [ ] Never have two separate checks for the same URL pattern in `onNavigationRequest` — the first one wins.
- [ ] Add `UIFileSharingEnabled` + `LSSupportsOpeningDocumentsInPlace` to `Info.plist` if saving files on iOS.
- [ ] Use `share_plus` (share sheet) on iOS instead of `open_filex` for post-download file opening.
- [ ] When a download is silently dropped, search logs for the URL — if it appears in a "blocked" log line with no follow-up download log, the handler is returning early without acting.
- [ ] `onNavigationRequest` only fires for **main-frame** navigations. Sub-resource loads (images, fonts) do not go through it.
