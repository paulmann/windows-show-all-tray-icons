# Design system — TrayIconGuard v8 “Aurora” (Fluent, 2026)

## Principles
Windows-11-native feel without WebView/WPF: calm surfaces, 4-px grid, 8-px card radius,
4-px control radius, motion only where it explains state (140–180 ms exponential ease).

## Color tokens (resolved by `ui/theme.cpp`)

| Token | Light | Dark |
|---|---|---|
| windowBg | `#F3F3F3` | `#202020` |
| cardBg | `#FBFBFB` | `#2B2B2B` |
| cardBorder | `#E5E5E5` | `#3A3A3A` |
| textPrimary | `#1B1B1B` | `#FFFFFF` |
| textSecondary | `#5D5D5D` | `#C5C5C5` |
| textDisabled | `#9E9E9E` | `#8A8A8A` |
| accent (default) | `#0F6CBD` | `#0F6CBD` (or system colorization) |
| accentHover / Pressed | ±10/20 % mix to black-white | same rule |
| success / soft | `#0F7B0F` / `#DFF0DF` | `#6CCB5F` / `#2A3B2A` |
| warning / soft | `#9D5D00` / `#FBEED8` | `#FCE100` / `#3E3A24` |
| danger / soft | `#C42B1C` / `#F9E2E0` | `#FF99A4` / `#442A2C` |
| hoverOverlay / pressOverlay | `#ECECEC` / `#E3E3E3` | `#2E2E2E` / `#353535` |
| scrollbar | `#C4C4C4` | `#5A5A5A` |
| statusBarBg | `#EBEBEB` | `#1B1B1B` |

Accent presets: `#0F6CBD` Windows blue · `#744DA9` violet · `#0E7070` teal · `#0F7B0F` green ·
`#98450C` rust · `#C239B3` orchid · `#9A0021` crimson · `#4C5B66` graphite.

## Typography
- Family: *Segoe UI Variable Text* → fallback *Segoe UI* (runtime probe via `GetTextFaceW`).
- Sizes @96 dpi: page title 26 SemiBold · card title 14 SemiBold · body 14 Medium/Regular ·
  secondary 11.5–12.5 · stat value 18 SemiBold · mono log *Cascadia Mono* → *Consolas* 11.5.
- Glyphs: *Segoe Fluent Icons* → *Segoe MDL2 Assets*: home E80F, apps E71D, lock E72E,
  color E771, save E74E, diagnostic E9D5, info E946, search E721, sync E72C, play E768,
  pause E769, close E711, warn E7BA, copy E8C8, delete E74D, add E710, chevron-up E70E,
  moon E708, sun E706, display E7F4, folder E838, link E71B, download E896, history E823.

## Geometry
- Nav rail: 244 px expanded / 64 px collapsed (<860 px window); item height 44; selected =
  card pill + 3×16 accent bar.
- Top bar 92 px (title 26 + subtitle); status bar 30 px.
- Content padding 28 px; card padding 16; card gap 12; row height 56 (40 compact).
- Toggle 40×20, knob 12→14 px; buttons h32 radius 4; segmented h32 radius 6 with sliding pill;
  search h36 radius 4 (focus = accent border 1.6 px).
- Scrollbars: 6-px overlay thumbs, radius 3, hot on hover/drag.

## Motion
Toggle knob+color 160 ms; segmented pill 180 ms; hover/press 90–140 ms; timer runs only while
animating; `animations=false` freezes all at target values.

## Icon language
Rounded-square Fluent tile, diagonal azure→deep-blue gradient, soft top-left highlight,
white shield with three knocked-out dots (promoted icons); solid shield ≤32 px for tray
legibility; state dot overlay on the live tray icon (green guarding / amber paused).
