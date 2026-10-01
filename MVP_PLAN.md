# twin_screen — MVP reja (ketma-ketlik)

> Yaratildi: 2026-09-25. Barcha qarorlar va arxitektura `CLAUDE.md`'da.
> Ish tartibi: har bosqichdan oldin kerak bo'lsa savol beriladi → yoziladi → tekshiriladi → keyingisiga o'tiladi.

## Holat

- [x] Savol-javob, qarorlar qabul qilindi
- [x] Plugin loyihasi yaratildi (`flutter create --template=plugin`, android/ios/web)
- [x] `CLAUDE.md` (spec) yozildi, `git init` qilindi
- [x] 0-bosqich: Xcode 27.0 + iOS 27.1 simulator runtime (iPhone Duo bor), Android foldable AVD'lar yaratildi
- [x] 1-bosqich: loyiha sozlamalari, shablon kod olib tashlandi
- [x] 2-bosqich: modellar va holat logikasi (resolver)
- [x] 3-bosqich: TwinScreenScope, platform ko'prigi, MediaQuery injection
- [x] 4-bosqich: TwinDebugOverlay + fold simulyatori
- [x] 5-bosqich: WindowClassBuilder, TwinPane, FoldAwareDialog
- [x] 6-bosqich: Android (Kotlin) — Pixel Fold, 7.6" Fold-in, 6.7" Flip emulatorlarida tekshirildi
- [x] 7-bosqich: iOS (Swift, runtime orqali) — iPhone Duo simulatorida cover holati, oddiy iPhone'da `standard`
  - [ ] Ochiq / yarim buklangan holatni iPhone Duo'da tekshirish (simulyatorda hinge'ni qo'lda ochish kerak)
- [x] 8-bosqich: web (Viewport Segments) va desktop
- [x] 9-bosqich: example app, README, CHANGELOG 0.1.0, testlar, `.pubignore`, `pub publish --dry-run` (0 warning)
- [ ] **10-bosqich: nashr** ← hozir shu yerda (sizning ruxsatingiz kerak)

---

## 0-bosqich — Tayyorgarlik (siz qilasiz)

**Xcode 27.1**
1. App Store yoki developer.apple.com'dan Xcode 27.1 o'rnating.
2. Terminalda:
   ```sh
   sudo xcode-select -s /Applications/Xcode.app
   sudo xcodebuild -runFirstLaunch
   ```
3. Tekshirish (natijani menga yuboring):
   ```sh
   xcodebuild -version                          # Xcode 27.1 bo'lishi kerak
   xcrun --sdk iphoneos --show-sdk-version      # 27.1
   swift --version                              # Swift guard uchun kerak
   xcrun simctl list devicetypes | grep -i duo  # iPhone Duo simulator bormi
   flutter doctor
   ```

**Android Studio emulatorlari** (Device Manager → Create Device):
- Pixel Fold
- 7.6" Fold-in with outer display (cover ekranni tekshirish uchun)
- Resizable (Experimental)
- Emulator'da Extended Controls → Virtual sensors → Hinge angle ishlashini tekshiring.

---

## 1-bosqich — Loyiha sozlamalari

- `pubspec.yaml`: min SDK'ni tushirish (Dart `^3.6.0`, Flutter `>=3.27.0`). Bu ko'proq loyihalarda ishlashi uchun.
- Desktop platformalarini qo'shish: `macos`, `windows`, `linux` → faqat `dartPluginClass`, native kod yo'q.
- Shablondagi `getPlatformVersion` kodini o'chirish.
- `analysis_options.yaml`: qat'iy lint'lar.
- Papka tuzilmasi:
  ```
  lib/
    twin_screen.dart            # public export
    src/models/                 # WindowClass, TwinHinge, TwinPosture, TwinScreenData ...
    src/core/                   # state resolver, breakpoints
    src/platform/               # platform interface, method/event channel, web, desktop
    src/widgets/                # TwinScreenScope, TwinPane, WindowClassBuilder, FoldAwareDialog
    src/debug/                  # TwinDebugOverlay, simulator, presets
  ```

**Tayyor mezoni:** `flutter analyze` toza, eski shablon kodi yo'q.

---

## 2-bosqich — Dart core: modellar va holat logikasi

- `WindowClass`: width + height klasslar (compact / medium / expanded), custom breakpoint'lar.
  - Width: compact < 600, medium 600–839, expanded ≥ 840
  - Height: compact < 480, medium 480–899, expanded ≥ 900
- `TwinDeviceType`: standard | foldable | flip | dualScreen | unknown
- `TwinPosture`: closed | halfOpened | flat | unknown
- `TwinHinge`: bounds, axis, isSeparating, occludesContent
- `TwinScreenData`: deviceType, posture, isSpanned, hinge, hingeAngle, segments, windowClass, mode
- **State resolver** — kirish ma'lumotlaridan `mode`'ni hisoblaydigan sof funksiya:

| Qurilma | Posture | App hinge'ni kesib o'tadimi | Hinge o'qi | → `mode` |
|---|---|---|---|---|
| standard | — | — | — | `standard` |
| foldable/flip/dualScreen | closed | yo'q | — | `cover` |
| foldable/flip/dualScreen | flat / halfOpened | yo'q | — | `singlePane` |
| foldable/flip/dualScreen | flat | ha | istalgan | `dualPane` |
| foldable/dualScreen | halfOpened | ha | vertikal | `book` |
| flip/foldable | halfOpened | ha | gorizontal | `tabletop` |
| foldable | unknown | yo'q | — | tor ekran (compact) → `cover`, aks holda → `singlePane` |

**Tayyor mezoni:** resolver uchun jadvaldagi har bir holatga unit test bor.

---

## 3-bosqich — TwinScreenScope va platform ko'prigi

- `TwinScreenScope` (root widget) + `TwinScreen.of(context)`. InheritedModel aspect'lari ishlatiladi: widget faqat o'zi o'qigan qism o'zgarganda rebuild bo'ladi.
- Platform interface: `MethodChannel` (hardware ma'lumoti) + `EventChannel` (hinge angle/posture stream).
- **MediaQuery injection:** iOS/web/simulyatordan kelgan hinge `MediaQuery.displayFeatures`'ga yoziladi. Platforma o'zi bergan bo'lsa (Android), dublikat qilinmaydi.
- Plugin bo'lmagan platformada (`MissingPluginException`) jim fallback → `standard`.

**Tayyor mezoni:** Flutter'ning `showDialog(anchorPoint:)` va `DisplayFeatureSubScreen` injection qilingan feature'larni ko'rishini widget test isbotlaydi.

---

## 4-bosqich — Debug overlay + simulyator (erta, chunki asosiy test vositasi)

- **Simulyator:** app'ni preset'ning logical o'lchamida chizadi va MediaQuery'ni (size, padding, displayFeatures) soxtalashtiradi.
  - Presetlar: iPhone Duo (cover 466pt / ichki 626×890pt), Galaxy Z Fold, Galaxy Z Flip, Pixel Fold, Surface Duo, Xiaomi Mix Flip.
  - Boshqaruv: posture (closed / halfOpened / flat), orientatsiya, hinge kengligi, hinge angle slider.
- **Chizish:** segmentlar (rangli fon), hinge (qizil chiziqli), reserved region'lar (kamera).
- **Info panel:** sudrab joyini o'zgartirsa bo'ladi, yig'iladi. Ko'rsatadi: mode, posture, angle, window class, dp o'lcham, platforma, manba (native / flutter / simulated).
- Release build'da avtomatik o'chadi (`kReleaseMode`), lekin qo'lda yoqish mumkin.

**Tayyor mezoni:** oddiy iOS simulator, Chrome yoki macOS'da har bir preset va posture'ni ko'rish mumkin.

---

## 5-bosqich — Widgetlar

- `WindowClassBuilder(compact:, medium:, expanded:)`
- `TwinPane(start:, end:, fallback:)`:
  1. Hinge ajratib tursa (separating) → aynan hinge bo'yicha bo'linadi, hinge ostiga kontent tushmaydi.
  2. Tekis, ajratmaydigan fold + window class ≥ medium → bo'linish fold chizig'iga tekislanadi.
  3. Fold yo'q → window class fallback: compact → faqat `start`; medium/expanded → yonma-yon.
  4. RTL: start o'ngda. Gorizontal hinge: start tepada.
- `showFoldAwareDialog(...)` + `FoldAwareDialog`: `anchorPoint` qaysi yarimda bo'lsa o'sha yarimda chiqadi. Anchor bo'lmasa → `preferredSide`. `allowSpanning` bilan ikkala yarimni egallashi mumkin.

**Tayyor mezoni:** har bir widget uchun simulyator presetlarida widget testlar.

---

## 6-bosqich — Android (Kotlin)

- Hardware tekshiruvi: `PackageManager.FEATURE_SENSOR_HINGE_ANGLE`, `Sensor.TYPE_HINGE_ANGLE` (API 30+).
- Hinge angle stream → `closed` holatini aniqlash (cover ekranda Flutter fold feature bermaydi).
- Flip yoki book: fold o'qi qurilmaning tabiiy orientatsiyasiga nisbatan olinadi.
- Fold va bounds uchun Flutter'ning o'z `displayFeatures`'i ishlatiladi, qayta yozilmaydi.

**Tayyor mezoni:** 3 ta emulatorda (Pixel Fold, 7.6" Fold-in with outer display, Resizable) hamma `mode`'lar to'g'ri.

---

## 7-bosqich — iOS (Swift, Xcode 27.1 kerak)

- `UIHingeInteraction(updateHandler:)` → `hinge.status` + `hinge.angle` (radian → gradus). `hinge == nil` bo'lsa hinge yo'q.
- `view.reservedRegions(kind: .division, options: .includeInactive)` → fold rect; `.occlusion` → kamera.
- Koordinatalarni FlutterView koordinatalariga o'tkazish (point = logical pixel).
- Guard: kod eski Xcode'da ham compile bo'lishi kerak. Aniq `#if` sharti 0-bosqichdagi `swift --version` natijasiga qarab tanlanadi.
- flutter/flutter#193025 merge bo'lib Flutter o'zi `displayFeatures` bersa, dublikat qilinmaydi.

**Tayyor mezoni:** iPhone Duo simulatorida cover / ochiq / yarim buklangan holatlar to'g'ri, oddiy iPhone'da esa `standard`.

---

## 8-bosqich — Web va desktop

- Web: `window.viewport.segments` (Viewport Segments API) + `navigator.devicePosture.type` (`continuous` / `folded`), `package:web` orqali. Hamma narsa feature-detect qilinadi.
- Desktop va iPad: `standard`, window class va fallback ishlaydi.

**Tayyor mezoni:** `flutter build web` va `flutter build macos` o'tadi. Chrome DevTools'dagi foldable emulyatsiyada segmentlar ko'rinadi.

---

## 9-bosqich — Example app, hujjatlar, testlar

- Example app: har bir feature uchun demo ekran (holat info, TwinPane, dialog, window class), overlay yoqilgan.
- README (inglizcha): o'rnatish, qisqa misollar, platformalar jadvali, `foldable` paketidan farqi. GIF'lar keyinroq qo'shiladi.
- CHANGELOG `0.1.0`, `version: 0.1.0`.
- `.pubignore` (CLAUDE.md, MVP_PLAN.md nashrga chiqmasin; `.gitignore` qoidalari ham ko'chiriladi).
- Tekshiruvlar: `flutter analyze`, `flutter test`, `flutter build apk --debug`, `flutter build ios --no-codesign`, `flutter build web`, `dart pub publish --dry-run`, `pana` (pub.dev ball).

---

## 10-bosqich — Nashr (sizning ruxsatingiz bilan)

1. GitHub: `muhammadrasul-dev/twin_screen` public repo, MIT.
2. Birinchi commit + push.
3. `dart pub publish` → pub.dev'da `0.1.0`.

---

## Keyinroq (MVP'dan keyin)

- large / extraLarge window class'lar
- Android rear display / dual display rejimlari (`WindowAreaController`)
- Fold-aware bottom sheet, navigation, list-detail widgetlari
- Hinge angle'ga bog'langan animatsiyalar
- Qurilma modellari allowlist'i
- Simulyator uchun klaviatura shortcut'lari
