import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Built-in visual style (colors + gradient backdrop). Independent of wallpaper.
class UiStylePreset {
  const UiStylePreset({
    required this.id,
    required this.label,
    required this.description,
    required this.seed,
    required this.bgTop,
    required this.bgMid,
    required this.bgBottom,
    required this.accent,
    required this.surface,
    this.glow,
    this.brightness = Brightness.dark,
    this.dimDefault = 0.55,
  });

  final String id;
  final String label;
  final String description;
  final Color seed;
  final Color bgTop;
  final Color bgMid;
  final Color bgBottom;
  final Color accent;
  final Color surface;
  final Color? glow;
  final Brightness brightness;
  final double dimDefault;
}

/// Curated **color** packs only. Cat UI chrome (paws, badges, mascot) is fixed
/// product chrome and does not change with styleId — only recolors.
const uiStylePresets = <UiStylePreset>[
  /// Default Meowsic shell (UI previews 01 palette + 06 light brand panel).
  UiStylePreset(
    id: 'meowsic_cream',
    label: 'Meowsic 奶油',
    description: '默认：浅奶油面板 + 暖橘强调（01 色系 / 06 品牌壳）',
    seed: Color(0xFFE89B6C),
    bgTop: Color(0xFFF6E4D2),
    bgMid: Color(0xFFF0D5BC),
    bgBottom: Color(0xFFE5C0A0),
    accent: Color(0xFFE89B6C),
    surface: Color(0xFFFFF8F1),
    glow: Color(0xFFFFC4A8),
    brightness: Brightness.light,
    dimDefault: 0.32,
  ),
  /// 01 outer cocoa frame — darker warm companion to cream.
  UiStylePreset(
    id: 'meowsic_cocoa',
    label: 'Meowsic 可可',
    description: '深可可侧栏感 + 暖橘爪印，夜晚更护眼',
    seed: Color(0xFFE8A87C),
    bgTop: Color(0xFF3A2820),
    bgMid: Color(0xFF2A1C16),
    bgBottom: Color(0xFF1A120E),
    accent: Color(0xFFE8A87C),
    surface: Color(0xFF32241C),
    glow: Color(0xFFFFB4A2),
    dimDefault: 0.48,
  ),
  UiStylePreset(
    id: 'midnight',
    label: '午夜蓝',
    description: '深空蓝冷静配色（只换颜色）',
    seed: Color(0xFF6C9EFF),
    bgTop: Color(0xFF0B1020),
    bgMid: Color(0xFF0F1528),
    bgBottom: Color(0xFF0A0C12),
    accent: Color(0xFF6C9EFF),
    surface: Color(0xFF171A21),
  ),
  UiStylePreset(
    id: 'neon_cyber',
    label: '赛博霓虹',
    description: '青紫撞色，夜店 / 电子风',
    seed: Color(0xFF00F5D4),
    bgTop: Color(0xFF0A0618),
    bgMid: Color(0xFF12082A),
    bgBottom: Color(0xFF050510),
    accent: Color(0xFF00F5D4),
    surface: Color(0xFF141028),
    glow: Color(0xFFB14EFF),
  ),
  UiStylePreset(
    id: 'sunset',
    label: '暖阳落日',
    description: '橙粉渐变，温柔偏暖',
    seed: Color(0xFFFF8A5B),
    bgTop: Color(0xFF2A1220),
    bgMid: Color(0xFF1E1018),
    bgBottom: Color(0xFF120C10),
    accent: Color(0xFFFF8A5B),
    surface: Color(0xFF241820),
    glow: Color(0xFFFF5D8F),
  ),
  UiStylePreset(
    id: 'forest',
    label: '森野绿',
    description: '墨绿苔藓，安静专注',
    seed: Color(0xFF5DDBA0),
    bgTop: Color(0xFF0A1812),
    bgMid: Color(0xFF0C1610),
    bgBottom: Color(0xFF060C09),
    accent: Color(0xFF5DDBA0),
    surface: Color(0xFF121C16),
    glow: Color(0xFF2E8B57),
  ),
  UiStylePreset(
    id: 'sakura',
    label: '樱粉夜',
    description: '浅粉强调，偏日系氛围',
    seed: Color(0xFFFF8FB8),
    bgTop: Color(0xFF221820),
    bgMid: Color(0xFF1A1218),
    bgBottom: Color(0xFF100C12),
    accent: Color(0xFFFF8FB8),
    surface: Color(0xFF221820),
    glow: Color(0xFFE56B9A),
  ),
  UiStylePreset(
    id: 'ocean',
    label: '深海',
    description: '青绿海水，清爽通透',
    seed: Color(0xFF3ECFC7),
    bgTop: Color(0xFF061820),
    bgMid: Color(0xFF08141C),
    bgBottom: Color(0xFF040C10),
    accent: Color(0xFF3ECFC7),
    surface: Color(0xFF101C22),
    glow: Color(0xFF1B8A9C),
  ),
  UiStylePreset(
    id: 'lofi_purple',
    label: 'Lo-fi 紫',
    description: '雾紫灰调，适合松弛听感',
    seed: Color(0xFFB39DDB),
    bgTop: Color(0xFF161220),
    bgMid: Color(0xFF12101A),
    bgBottom: Color(0xFF0C0A12),
    accent: Color(0xFFB39DDB),
    surface: Color(0xFF1A1624),
    glow: Color(0xFF7E57C2),
  ),
  UiStylePreset(
    id: 'gold_noir',
    label: '黑金',
    description: '香槟金点缀，偏高级感',
    seed: Color(0xFFE0C07A),
    bgTop: Color(0xFF14120E),
    bgMid: Color(0xFF100E0A),
    bgBottom: Color(0xFF080706),
    accent: Color(0xFFE0C07A),
    surface: Color(0xFF1A1812),
    glow: Color(0xFF8B7355),
  ),
  UiStylePreset(
    id: 'oled_ink',
    label: 'OLED 墨黑',
    description: '极致黑底，省电、对比强',
    seed: Color(0xFFE8E8EC),
    bgTop: Color(0xFF000000),
    bgMid: Color(0xFF000000),
    bgBottom: Color(0xFF000000),
    accent: Color(0xFFE8E8EC),
    surface: Color(0xFF121212),
  ),
  UiStylePreset(
    id: 'crimson',
    label: '猩红现场',
    description: '红黑舞台感，摇滚向',
    seed: Color(0xFFFF4D6D),
    bgTop: Color(0xFF1A080C),
    bgMid: Color(0xFF12060A),
    bgBottom: Color(0xFF080406),
    accent: Color(0xFFFF4D6D),
    surface: Color(0xFF1C1014),
    glow: Color(0xFF9B1D3A),
  ),
  UiStylePreset(
    id: 'arctic',
    label: '极光',
    description: '冰蓝 + 青绿微光',
    seed: Color(0xFF7BDFF2),
    bgTop: Color(0xFF0A1420),
    bgMid: Color(0xFF0C1820),
    bgBottom: Color(0xFF060C12),
    accent: Color(0xFF7BDFF2),
    surface: Color(0xFF121C24),
    glow: Color(0xFF64DFDF),
  ),
  UiStylePreset(
    id: 'paper_light',
    label: '纸白日间',
    description: '浅色界面，白天室外更易读',
    seed: Color(0xFF3D6BF3),
    bgTop: Color(0xFFF4F6FA),
    bgMid: Color(0xFFECEFF5),
    bgBottom: Color(0xFFE2E6EF),
    accent: Color(0xFF3D6BF3),
    surface: Color(0xFFFFFFFF),
    brightness: Brightness.light,
    dimDefault: 0.35,
  ),
];

/// Quick palette chips for one-tap accent picks.
const accentPalette = <Color>[
  // Meowsic cream / peach family first
  Color(0xFFE89B6C),
  Color(0xFFE8A87C),
  Color(0xFFFFB4A2),
  Color(0xFFC4784A),
  Color(0xFF8B5E45),
  Color(0xFFFF8A5B),
  Color(0xFF6C9EFF),
  Color(0xFF00F5D4),
  Color(0xFF5DDBA0),
  Color(0xFFFF8FB8),
  Color(0xFF3ECFC7),
  Color(0xFFB39DDB),
  Color(0xFFE0C07A),
  Color(0xFFFF4D6D),
  Color(0xFF7BDFF2),
  Color(0xFFFFD166),
  Color(0xFF9B5DE5),
  Color(0xFFFFFFFF),
  Color(0xFF90A4AE),
];

/// App UI: style preset + optional wallpaper + custom accent color.
class UiTheme extends ChangeNotifier {
  String? wallpaperPath;
  /// Cached gallery of imported wallpapers (absolute paths).
  List<String> wallpaperGallery = [];
  double dim = 0.55;
  BoxFit fit = BoxFit.cover;
  String styleId = 'meowsic_cream';

  /// When true, [customAccent] overrides preset accent/seed for controls & glow.
  bool useCustomAccent = false;
  Color customAccent = const Color(0xFF6C9EFF);

  /// 0.85 / 1.0 / 1.15 / 1.3
  double textScale = 1.0;
  bool compactMode = false;

  /// Extract accent from current track cover art.
  bool coverThemeEnabled = false;

  UiStylePreset get style {
    return uiStylePresets.firstWhere(
      (s) => s.id == styleId,
      orElse: () => uiStylePresets.first,
    );
  }

  Color get solidBg => style.bgMid;

  Color get effectiveAccent => useCustomAccent ? customAccent : style.accent;
  Color get effectiveSeed => useCustomAccent ? customAccent : style.seed;
  Color get effectiveGlow =>
      useCustomAccent ? customAccent : (style.glow ?? style.accent);

  static int channel(Color c, String which) {
    final v = switch (which) {
      'r' => c.r,
      'g' => c.g,
      'b' => c.b,
      _ => c.r,
    };
    return (v * 255.0).round().clamp(0, 255);
  }

  String get accentHex => colorToHex(effectiveAccent);

  static String colorToHex(Color c) {
    final r = channel(c, 'r').toRadixString(16).padLeft(2, '0');
    final g = channel(c, 'g').toRadixString(16).padLeft(2, '0');
    final b = channel(c, 'b').toRadixString(16).padLeft(2, '0');
    return '#$r$g$b'.toUpperCase();
  }

  /// Parse `#RGB`, `#RRGGBB`, `#AARRGGBB`, or without `#`.
  static Color? tryParseHex(String raw) {
    var s = raw.trim();
    if (s.startsWith('#')) s = s.substring(1);
    if (s.startsWith('0x') || s.startsWith('0X')) s = s.substring(2);
    if (s.length == 3) {
      s = s.split('').map((ch) => '$ch$ch').join();
    }
    if (s.length == 6) s = 'FF$s';
    if (s.length != 8) return null;
    final v = int.tryParse(s, radix: 16);
    if (v == null) return null;
    return Color(v);
  }

  Future<void> load() async {
    final sp = await SharedPreferences.getInstance();
    wallpaperPath = sp.getString('ui_wallpaper');
    dim = sp.getDouble('ui_dim') ?? 0.55;
    final fitName = sp.getString('ui_fit') ?? 'cover';
    fit = BoxFit.values.firstWhere((e) => e.name == fitName, orElse: () => BoxFit.cover);
    styleId = sp.getString('ui_style') ?? 'meowsic_cream';
    if (!uiStylePresets.any((s) => s.id == styleId)) {
      styleId = 'meowsic_cream';
    }
    useCustomAccent = sp.getBool('ui_use_custom_accent') ?? false;
    final argb = sp.getInt('ui_custom_accent');
    if (argb != null) {
      customAccent = Color(argb);
    } else {
      customAccent = style.accent;
    }
    textScale = sp.getDouble('ui_text_scale') ?? 1.0;
    if (textScale < 0.8 || textScale > 1.4) textScale = 1.0;
    compactMode = sp.getBool('ui_compact') ?? false;
    coverThemeEnabled = sp.getBool('ui_cover_theme') ?? false;
    wallpaperGallery = sp.getStringList('ui_wallpaper_gallery') ?? [];
    // migrate legacy single wallpaper into gallery
    if (wallpaperPath != null && File(wallpaperPath!).existsSync()) {
      if (!wallpaperGallery.contains(wallpaperPath)) {
        wallpaperGallery = [...wallpaperGallery, wallpaperPath!];
        await sp.setStringList('ui_wallpaper_gallery', wallpaperGallery);
      }
    }
    wallpaperGallery = wallpaperGallery.where((p) => File(p).existsSync()).toList();
    if (wallpaperPath != null && !File(wallpaperPath!).existsSync()) {
      wallpaperPath = null;
    }
    notifyListeners();
  }

  Future<void> setTextScale(double v) async {
    textScale = v.clamp(0.85, 1.3);
    final sp = await SharedPreferences.getInstance();
    await sp.setDouble('ui_text_scale', textScale);
    notifyListeners();
  }

  Future<void> setCompactMode(bool v) async {
    compactMode = v;
    final sp = await SharedPreferences.getInstance();
    await sp.setBool('ui_compact', compactMode);
    notifyListeners();
  }

  Future<void> setCoverThemeEnabled(bool v) async {
    coverThemeEnabled = v;
    final sp = await SharedPreferences.getInstance();
    await sp.setBool('ui_cover_theme', coverThemeEnabled);
    if (!v && useCustomAccent) {
      // keep custom accent if user set manually; only clear when cover-driven
      // cover theme uses customAccent when applying
    }
    notifyListeners();
  }

  /// Apply dominant color extracted from album cover (cover theme mode).
  Future<void> applyCoverAccent(Color c) async {
    if (!coverThemeEnabled) return;
    await setCustomAccent(c, enable: true);
  }

  Future<void> setStyle(String id) async {
    if (!uiStylePresets.any((s) => s.id == id)) return;
    styleId = id;
    final sp = await SharedPreferences.getInstance();
    await sp.setString('ui_style', styleId);
    // Nudge dim toward style default when no wallpaper (cleaner first look).
    if (wallpaperPath == null) {
      dim = style.dimDefault;
      await sp.setDouble('ui_dim', dim);
    }
    // If not using custom accent, sync draft color to new style accent for picker.
    if (!useCustomAccent) {
      customAccent = style.accent;
    }
    notifyListeners();
  }

  Future<void> setCustomAccent(Color color, {bool enable = true}) async {
    customAccent = Color.fromARGB(
      255,
      channel(color, 'r'),
      channel(color, 'g'),
      channel(color, 'b'),
    );
    useCustomAccent = enable;
    final sp = await SharedPreferences.getInstance();
    await sp.setBool('ui_use_custom_accent', useCustomAccent);
    await sp.setInt(
      'ui_custom_accent',
      (0xFF << 24) |
          (channel(customAccent, 'r') << 16) |
          (channel(customAccent, 'g') << 8) |
          channel(customAccent, 'b'),
    );
    notifyListeners();
  }

  Future<void> setCustomAccentRgb(int r, int g, int b, {bool enable = true}) {
    return setCustomAccent(
      Color.fromARGB(255, r.clamp(0, 255), g.clamp(0, 255), b.clamp(0, 255)),
      enable: enable,
    );
  }

  Future<bool> setCustomAccentHex(String hex, {bool enable = true}) async {
    final c = tryParseHex(hex);
    if (c == null) return false;
    await setCustomAccent(c, enable: enable);
    return true;
  }

  Future<void> clearCustomAccent() async {
    useCustomAccent = false;
    customAccent = style.accent;
    final sp = await SharedPreferences.getInstance();
    await sp.setBool('ui_use_custom_accent', false);
    notifyListeners();
  }

  /// Slightly tint style backgrounds toward custom accent for cohesion.
  Color get bgTopTinted {
    if (!useCustomAccent) return style.bgTop;
    return Color.lerp(style.bgTop, customAccent, style.brightness == Brightness.light ? 0.12 : 0.18)!;
  }

  Color get bgMidTinted {
    if (!useCustomAccent) return style.bgMid;
    return Color.lerp(style.bgMid, customAccent, style.brightness == Brightness.light ? 0.08 : 0.12)!;
  }

  Color get bgBottomTinted {
    if (!useCustomAccent) return style.bgBottom;
    return Color.lerp(style.bgBottom, customAccent, style.brightness == Brightness.light ? 0.06 : 0.10)!;
  }

  Future<void> setDim(double v) async {
    dim = v.clamp(0.15, 0.85);
    final sp = await SharedPreferences.getInstance();
    await sp.setDouble('ui_dim', dim);
    notifyListeners();
  }

  Future<void> setFit(BoxFit f) async {
    fit = f;
    final sp = await SharedPreferences.getInstance();
    await sp.setString('ui_fit', f.name);
    notifyListeners();
  }

  Future<Directory> _galleryDir() async {
    final dir = await getApplicationDocumentsDirectory();
    final g = Directory(p.join(dir.path, 'wallpapers'));
    if (!await g.exists()) await g.create(recursive: true);
    return g;
  }

  Future<void> _persistGallery() async {
    final sp = await SharedPreferences.getInstance();
    await sp.setStringList('ui_wallpaper_gallery', wallpaperGallery);
    if (wallpaperPath != null) {
      await sp.setString('ui_wallpaper', wallpaperPath!);
    } else {
      await sp.remove('ui_wallpaper');
    }
  }

  Future<bool> pickWallpaper() async {
    if (kIsWeb) return false;
    final picker = ImagePicker();
    final file = await picker.pickImage(source: ImageSource.gallery, imageQuality: 90);
    if (file == null) return false;
    final g = await _galleryDir();
    final ext = p.extension(file.path).isEmpty ? '.jpg' : p.extension(file.path);
    final name = 'wp_${DateTime.now().millisecondsSinceEpoch}$ext';
    final dest = File(p.join(g.path, name));
    await File(file.path).copy(dest.path);
    wallpaperGallery = [...wallpaperGallery, dest.path];
    wallpaperPath = dest.path;
    await _persistGallery();
    notifyListeners();
    return true;
  }

  Future<void> useWallpaper(String path) async {
    if (!File(path).existsSync()) return;
    wallpaperPath = path;
    await _persistGallery();
    notifyListeners();
  }

  Future<void> deleteWallpaperFromGallery(String path) async {
    wallpaperGallery = wallpaperGallery.where((e) => e != path).toList();
    if (wallpaperPath == path) {
      wallpaperPath = wallpaperGallery.isNotEmpty ? wallpaperGallery.last : null;
    }
    try {
      final f = File(path);
      if (await f.exists()) await f.delete();
    } catch (_) {}
    await _persistGallery();
    notifyListeners();
  }

  Future<void> clearWallpaper() async {
    // Only clear active selection; keep gallery cache.
    wallpaperPath = null;
    final sp = await SharedPreferences.getInstance();
    await sp.remove('ui_wallpaper');
    notifyListeners();
  }

  String get fitLabel {
    switch (fit) {
      case BoxFit.cover:
        return '铺满裁切 (Cover)';
      case BoxFit.contain:
        return '完整显示 (Contain)';
      case BoxFit.fill:
        return '拉伸填满 (Fill)';
      case BoxFit.fitWidth:
        return '适应宽度';
      case BoxFit.fitHeight:
        return '适应高度';
      default:
        return fit.name;
    }
  }

  /// Material theme derived from the active style preset (+ optional custom accent).
  /// Shape language follows Meowsic cream shell (soft 16–22px radii, peach selection).
  ThemeData buildTheme() {
    final s = style;
    final accent = effectiveAccent;
    final seed = effectiveSeed;
    final scheme = ColorScheme.fromSeed(
      seedColor: seed,
      brightness: s.brightness,
      primary: accent,
      surface: s.surface,
    );

    final isLight = s.brightness == Brightness.light;
    // Soft frosted bars like preview 06 cream window chrome.
    final barBg = Color.lerp(
      s.surface,
      isLight ? Colors.white : Colors.black,
      isLight ? 0.35 : 0.25,
    )!.withValues(alpha: isLight ? 0.82 : 0.55);
    final navBg = Color.lerp(
      s.surface,
      isLight ? Colors.white : Colors.black,
      isLight ? 0.45 : 0.3,
    )!.withValues(alpha: isLight ? 0.92 : 0.72);
    final cardBg = s.surface.withValues(alpha: isLight ? 0.92 : 0.62);
    final sheetBg = s.surface.withValues(alpha: 0.98);
    final onPrimary = isLight ? const Color(0xFF3D2418) : Colors.black;

    final shape22 = RoundedRectangleBorder(borderRadius: BorderRadius.circular(22));
    final shape16 = RoundedRectangleBorder(borderRadius: BorderRadius.circular(16));

    return ThemeData(
      useMaterial3: true,
      brightness: s.brightness,
      colorScheme: scheme.copyWith(
        primaryContainer: accent.withValues(alpha: isLight ? 0.28 : 0.35),
        onPrimaryContainer: isLight ? const Color(0xFF4A2C1C) : scheme.onSurface,
        secondaryContainer: accent.withValues(alpha: 0.18),
      ),
      scaffoldBackgroundColor: Colors.transparent,
      canvasColor: Colors.transparent,
      appBarTheme: AppBarTheme(
        backgroundColor: barBg,
        foregroundColor: scheme.onSurface,
        elevation: 0,
        centerTitle: false,
        scrolledUnderElevation: 0,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(bottom: Radius.circular(16)),
        ),
        systemOverlayStyle: isLight ? SystemUiOverlayStyle.dark : SystemUiOverlayStyle.light,
      ),
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: navBg,
        elevation: 0,
        height: 68,
        indicatorColor: accent.withValues(alpha: isLight ? 0.32 : 0.28),
        indicatorShape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        labelTextStyle: WidgetStateProperty.resolveWith((states) {
          final selected = states.contains(WidgetState.selected);
          return TextStyle(
            fontSize: 12,
            fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
            color: selected ? accent : scheme.onSurface.withValues(alpha: 0.72),
          );
        }),
        iconTheme: WidgetStateProperty.resolveWith((states) {
          final selected = states.contains(WidgetState.selected);
          return IconThemeData(
            size: 24,
            color: selected ? accent : scheme.onSurface.withValues(alpha: 0.7),
          );
        }),
      ),
      cardTheme: CardThemeData(
        color: cardBg,
        elevation: 0,
        shape: shape16,
        margin: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      ),
      bottomSheetTheme: BottomSheetThemeData(
        backgroundColor: sheetBg,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(22)),
        ),
      ),
      dialogTheme: DialogThemeData(backgroundColor: sheetBg, shape: shape22),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: s.surface.withValues(alpha: isLight ? 0.88 : 0.45),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(18),
          borderSide: BorderSide(color: accent.withValues(alpha: 0.18)),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(18),
          borderSide: BorderSide(color: scheme.onSurface.withValues(alpha: 0.08)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(18),
          borderSide: BorderSide(color: accent.withValues(alpha: 0.65), width: 1.4),
        ),
        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: accent,
          foregroundColor: onPrimary,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: scheme.onSurface,
          side: BorderSide(color: accent.withValues(alpha: 0.35)),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        ),
      ),
      sliderTheme: SliderThemeData(
        activeTrackColor: accent,
        thumbColor: accent,
        inactiveTrackColor: accent.withValues(alpha: 0.22),
        overlayColor: accent.withValues(alpha: 0.12),
      ),
      floatingActionButtonTheme: FloatingActionButtonThemeData(
        backgroundColor: accent,
        foregroundColor: onPrimary,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
      ),
      chipTheme: ChipThemeData(
        backgroundColor: s.surface.withValues(alpha: 0.75),
        selectedColor: accent.withValues(alpha: 0.35),
        labelStyle: TextStyle(color: scheme.onSurface),
        side: BorderSide(color: accent.withValues(alpha: 0.22)),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
      listTileTheme: ListTileThemeData(
        iconColor: accent.withValues(alpha: 0.9),
        selectedTileColor: accent.withValues(alpha: isLight ? 0.18 : 0.22),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      ),
      progressIndicatorTheme: ProgressIndicatorThemeData(
        color: accent,
        linearTrackColor: accent.withValues(alpha: 0.14),
      ),
      dividerColor: scheme.onSurface.withValues(alpha: 0.10),
      snackBarTheme: SnackBarThemeData(
        backgroundColor: s.surface.withValues(alpha: 0.96),
        contentTextStyle: TextStyle(color: scheme.onSurface),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }
}

/// Gradient / glow backdrop + optional photo wallpaper.
class AppBackground extends StatelessWidget {
  const AppBackground({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    final ui = context.watch<UiTheme>();
    final s = ui.style;

    final meowsicShell = s.id == 'meowsic_cream' || s.id == 'meowsic_cocoa';

    return Stack(
      fit: StackFit.expand,
      children: [
        // Style gradient base (tinted when custom accent is on)
        DecoratedBox(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [ui.bgTopTinted, ui.bgMidTinted, ui.bgBottomTinted],
              stops: const [0.0, 0.45, 1.0],
            ),
          ),
        ),
        // Soft accent orbs for depth (skip pure OLED / flat paper)
        if (s.id != 'oled_ink' && s.id != 'paper_light')
          CustomPaint(
            painter: _GlowPainter(
              accent: ui.effectiveGlow,
              secondary: ui.effectiveAccent,
            ),
            size: Size.infinite,
          ),
        // Paw trail atmosphere (01 wallpaper feel) — recolors with accent
        if (meowsicShell || s.id.startsWith('meowsic'))
          CustomPaint(
            painter: _PawFieldPainter(
              color: ui.effectiveAccent.withValues(
                alpha: s.brightness == Brightness.light ? 0.07 : 0.09,
              ),
            ),
            size: Size.infinite,
          )
        else if (s.id != 'oled_ink')
          CustomPaint(
            painter: _PawFieldPainter(
              color: ui.effectiveAccent.withValues(alpha: 0.045),
              sparse: true,
            ),
            size: Size.infinite,
          ),
        // Optional user photo on top of style
        if (ui.wallpaperPath != null) ...[
          Image.file(
            File(ui.wallpaperPath!),
            fit: ui.fit,
            width: double.infinity,
            height: double.infinity,
            errorBuilder: (_, _, _) => const SizedBox.shrink(),
          ),
          ColoredBox(color: Colors.black.withValues(alpha: ui.dim)),
        ],
        child,
      ],
    );
  }
}

/// Soft scattered paw prints (vector, not interactive).
class _PawFieldPainter extends CustomPainter {
  _PawFieldPainter({required this.color, this.sparse = false});

  final Color color;
  final bool sparse;

  @override
  void paint(Canvas canvas, Size size) {
    final p = Paint()..color = color;
    final spots = sparse
        ? const [
            Offset(0.12, 0.18),
            Offset(0.82, 0.22),
            Offset(0.22, 0.72),
            Offset(0.78, 0.68),
          ]
        : const [
            Offset(0.08, 0.12),
            Offset(0.22, 0.28),
            Offset(0.88, 0.16),
            Offset(0.72, 0.08),
            Offset(0.14, 0.55),
            Offset(0.90, 0.48),
            Offset(0.08, 0.82),
            Offset(0.78, 0.78),
            Offset(0.42, 0.92),
            Offset(0.55, 0.18),
          ];
    for (var i = 0; i < spots.length; i++) {
      final o = spots[i];
      final cx = size.width * o.dx;
      final cy = size.height * o.dy;
      final sc = (sparse ? 14.0 : 16.0) + (i % 3) * 3.0;
      _drawPaw(canvas, Offset(cx, cy), sc, p, rotate: (i.isEven ? -1 : 1) * 0.28);
    }
  }

  void _drawPaw(Canvas canvas, Offset c, double s, Paint p, {double rotate = 0}) {
    canvas.save();
    canvas.translate(c.dx, c.dy);
    canvas.rotate(rotate);
    canvas.drawOval(Rect.fromCenter(center: Offset(0, s * 0.12), width: s * 0.55, height: s * 0.42), p);
    for (final t in [
      Offset(-s * 0.28, -s * 0.18),
      Offset(-s * 0.10, -s * 0.32),
      Offset(s * 0.10, -s * 0.32),
      Offset(s * 0.28, -s * 0.18),
    ]) {
      canvas.drawOval(Rect.fromCenter(center: t, width: s * 0.22, height: s * 0.26), p);
    }
    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant _PawFieldPainter old) =>
      old.color != color || old.sparse != sparse;
}

class _GlowPainter extends CustomPainter {
  _GlowPainter({required this.accent, required this.secondary});

  final Color accent;
  final Color secondary;

  @override
  void paint(Canvas canvas, Size size) {
    final a = Paint()
      ..color = accent.withValues(alpha: 0.14)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 80);
    final b = Paint()
      ..color = secondary.withValues(alpha: 0.10)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 70);

    canvas.drawCircle(Offset(size.width * 0.85, size.height * 0.12), size.width * 0.42, a);
    canvas.drawCircle(Offset(size.width * 0.1, size.height * 0.55), size.width * 0.38, b);
    canvas.drawCircle(Offset(size.width * 0.6, size.height * 0.9), size.width * 0.35, a);
  }

  @override
  bool shouldRepaint(covariant _GlowPainter oldDelegate) =>
      oldDelegate.accent != accent || oldDelegate.secondary != secondary;
}

/// Small preview swatch used in settings picker.
class StylePreviewChip extends StatelessWidget {
  const StylePreviewChip({
    super.key,
    required this.preset,
    required this.selected,
    required this.onTap,
  });

  final UiStylePreset preset;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 132,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(14),
          onTap: onTap,
          child: Ink(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(14),
              border: Border.all(
                color: selected
                    ? preset.accent
                    : (preset.brightness == Brightness.light
                        ? Colors.black26
                        : Colors.white24),
                width: selected ? 2 : 1,
              ),
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [preset.bgTop, preset.bgMid, preset.bgBottom],
              ),
            ),
            child: Padding(
              padding: const EdgeInsets.all(10),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      _dot(preset.accent),
                      const SizedBox(width: 4),
                      _dot(preset.glow ?? preset.bgTop),
                      const SizedBox(width: 4),
                      _dot(preset.surface),
                      const Spacer(),
                      if (selected)
                        Icon(Icons.check_circle, size: 16, color: preset.accent),
                    ],
                  ),
                  const Spacer(),
                  Text(
                    preset.label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontWeight: FontWeight.w700,
                      fontSize: 13,
                      color: preset.brightness == Brightness.light
                          ? Colors.black87
                          : Colors.white,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    preset.description,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 10,
                      height: 1.2,
                      color: preset.brightness == Brightness.light
                          ? Colors.black54
                          : Colors.white60,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _dot(Color c) => Container(
        width: 10,
        height: 10,
        decoration: BoxDecoration(
          color: c,
          shape: BoxShape.circle,
          border: Border.all(color: Colors.white24, width: 0.5),
        ),
      );
}

