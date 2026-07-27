import 'dart:io' show Platform;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:provider/provider.dart';

import 'audio/hub_audio_handler.dart';
import 'screens/home_shell.dart';
import 'state/hub_state.dart';
import 'state/ui_theme.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  SystemChrome.setSystemUIOverlayStyle(const SystemUiOverlayStyle(
    statusBarColor: Colors.transparent,
  ));

  // Android 13+: without this, media notification may not appear at all.
  if (!kIsWeb && Platform.isAndroid) {
    try {
      final status = await Permission.notification.status;
      if (!status.isGranted) {
        await Permission.notification.request();
      }
    } catch (_) {}
  }

  HubAudioHandler? handler;
  try {
    handler = await initHubAudioHandler();
  } catch (e, st) {
    debugPrint('audio_service init failed: $e\n$st');
    // Windows/web may not support audio_service fully; fall back to plain player.
    handler = null;
  }

  final uiTheme = UiTheme();
  await uiTheme.load();

  runApp(MusicHubApp(audioHandler: handler, uiTheme: uiTheme));
}

class MusicHubApp extends StatefulWidget {
  const MusicHubApp({super.key, this.audioHandler, required this.uiTheme});

  final HubAudioHandler? audioHandler;
  final UiTheme uiTheme;

  @override
  State<MusicHubApp> createState() => _MusicHubAppState();
}

class _MusicHubAppState extends State<MusicHubApp> with WidgetsBindingObserver {
  late final HubState _hub = HubState(audioHandler: widget.audioHandler)
    ..uiTheme = widget.uiTheme;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    // Consume any pending home-widget action from cold start.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _hub.consumeWidgetAction();
    });
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    // Session online cache (memory + temp) must not survive process death.
    // ignore: discarded_futures
    _hub.purgeOnlineSessionCache();
    // ignore: discarded_futures
    _hub.exitKaraokeMode(purgeCache: true);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      // Soft ping on resume — fixes “切后台后断链” without full reconnect wipe.
      _hub.onAppResumed();
    } else if (state == AppLifecycleState.paused) {
      // Best-effort progress flush before freeze.
      // ignore: discarded_futures
      _hub.flushProgressNow();
      // K 歌会话缓存：进后台即清（流水线伴奏为临时文件）
      // ignore: discarded_futures
      _hub.exitKaraokeMode(purgeCache: true);
    } else if (state == AppLifecycleState.detached) {
      // App closing — delete online search session cache + karaoke stems.
      // ignore: discarded_futures
      _hub.purgeOnlineSessionCache();
      // ignore: discarded_futures
      _hub.exitKaraokeMode(purgeCache: true);
    }
  }

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider.value(value: _hub),
        ChangeNotifierProvider.value(value: widget.uiTheme),
      ],
      child: Consumer<UiTheme>(
        builder: (context, ui, _) {
          return MaterialApp(
            title: 'meowsic',
            debugShowCheckedModeBanner: false,
            theme: ui.buildTheme(),
            builder: (context, child) {
              final mq = MediaQuery.of(context);
              return MediaQuery(
                data: mq.copyWith(
                  textScaler: TextScaler.linear(ui.textScale),
                ),
                child: AppBackground(child: child ?? const SizedBox.shrink()),
              );
            },
            home: const HomeShell(),
          );
        },
      ),
    );
  }
}
