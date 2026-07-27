import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:mobile_scanner/mobile_scanner.dart';

import '../util/hub_url.dart';
import '../widgets/cat_decor.dart';

/// Scan a QR that encodes Music Hub LAN URL (from PC web 「扫码连手机」).
class QrScanScreen extends StatefulWidget {
  const QrScanScreen({super.key});

  @override
  State<QrScanScreen> createState() => _QrScanScreenState();
}

class _QrScanScreenState extends State<QrScanScreen> {
  final MobileScannerController _controller = MobileScannerController(
    detectionSpeed: DetectionSpeed.normal,
    facing: CameraFacing.back,
    formats: const [BarcodeFormat.qrCode],
  );
  bool _handled = false;
  String? _lastError;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _onDetect(BarcodeCapture capture) {
    if (_handled) return;
    for (final b in capture.barcodes) {
      final raw = b.rawValue;
      if (raw == null || raw.isEmpty) continue;
      final url = extractHubUrl(raw);
      if (url == null) {
        setState(() => _lastError = '识别到内容但不是有效地址：\n$raw');
        continue;
      }
      _handled = true;
      // keep system haptic for scan success
      HapticFeedback.mediumImpact();
      Navigator.of(context).pop(url);
      return;
    }
  }

  Future<void> _pasteFromClipboard() async {
    final data = await Clipboard.getData(Clipboard.kTextPlain);
    final text = data?.text;
    if (text == null || text.trim().isEmpty) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('剪贴板为空')),
      );
      return;
    }
    final url = extractHubUrl(text);
    if (url == null) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('剪贴板不是有效地址：$text')),
      );
      return;
    }
    if (!mounted) return;
    Navigator.of(context).pop(url);
  }

  @override
  Widget build(BuildContext context) {
    // Desktop without reliable camera: still show paste fallback + scanner if available
    final isDesktop = !kIsWeb &&
        (defaultTargetPlatform == TargetPlatform.windows ||
            defaultTargetPlatform == TargetPlatform.linux ||
            defaultTargetPlatform == TargetPlatform.macOS);

    return Scaffold(
      appBar: AppBar(
        title: const Text('扫描服务器二维码'),
        actions: [
          IconButton(
            tooltip: '从剪贴板粘贴',
            onPressed: _pasteFromClipboard,
            icon: const Icon(Icons.content_paste),
          ),
          IconButton(
            tooltip: '切换闪光灯',
            onPressed: () => _controller.toggleTorch(),
            icon: const Icon(Icons.flash_on),
          ),
        ],
      ),
      body: Column(
        children: [
          Expanded(
            child: Stack(
              fit: StackFit.expand,
              children: [
                MobileScanner(
                  controller: _controller,
                  onDetect: _onDetect,
                  errorBuilder: (context, error) {
                    return Center(
                      child: Padding(
                        padding: const EdgeInsets.all(24),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(Icons.videocam_off, size: 48, color: Colors.white54),
                            const SizedBox(height: 12),
                            Text(
                              isDesktop
                                  ? '当前设备摄像头不可用或未授权。\n可在电脑 Web 复制链接，点下方粘贴。'
                                  : '无法打开摄像头：${error.errorCode}\n请授予相机权限后重试。',
                              textAlign: TextAlign.center,
                              style: const TextStyle(color: Colors.white70),
                            ),
                            const SizedBox(height: 16),
                            FilledButton.icon(
                              onPressed: _pasteFromClipboard,
                              icon: const Icon(Icons.content_paste),
                              label: const Text('从剪贴板粘贴地址'),
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
                // Viewfinder: paw corners (cat chrome; theme only recolors claws)
                const IgnorePointer(
                  child: Center(
                    child: QrPawViewfinder(size: 248),
                  ),
                ),
                Positioned(
                  left: 16,
                  right: 16,
                  bottom: 24,
                  child: Text(
                    isDesktop
                        ? '用摄像头对准电脑上的二维码，或粘贴链接'
                        : '对准电脑 Music Hub 页面上的二维码',
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      color: Colors.white,
                      shadows: [Shadow(blurRadius: 8, color: Colors.black)],
                    ),
                  ),
                ),
              ],
            ),
          ),
          if (_lastError != null)
            Material(
              color: Colors.orange.shade900,
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Text(_lastError!, style: const TextStyle(fontSize: 12)),
              ),
            ),
          SafeArea(
            top: false,
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: _pasteFromClipboard,
                      icon: const Icon(Icons.content_paste),
                      label: const Text('粘贴链接'),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: FilledButton.tonal(
                      onPressed: () => Navigator.pop(context),
                      child: const Text('取消'),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
