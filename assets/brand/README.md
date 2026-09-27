# Brand sources

Vector sources for the launcher icon, the pre-12 start screen mark and the
Play Store icon (#97). They are committed so builds never depend on access to
the design project. These are not app assets: nothing here is bundled.

Provenance: claude.ai/design project `88279a49-c9f2-46fd-996c-c1fa9ca3a41e`,
file `Honest Solitaire.dc.html`, the brand sheet's APP ICON card (dark tile,
`#04213F`, radius 19 of 82). The spade path was copied from its inline SVG on
2026-09-26. The light tile on the same card is not shipped (owner, /n8-plan
M5 round one: "Dark icon").

| Source | Feeds | Notes |
|---|---|---|
| `icon-tile.svg` | `ArtSource/store/icon-512.png` | the APP ICON on a full-bleed `#04213F` square; Play applies its own mask |
| `icon-legacy.svg` | `mipmap-*/ic_launcher.png` (48–192 px) | the tile under the design's rounded corner (19 of 82 → 14.83 of 64), for Android 7 |
| `android-foreground.svg` | `mipmap-*/ic_launcher_foreground.png` (108–432 px), `drawable-*/launch_mark.png` (96–384 px) | the adaptive icon's foreground layer and the pre-12 start screen's mark; the icon background is `@color/ic_launcher_background` |
| `android-monochrome.svg` | `mipmap-*/ic_launcher_monochrome.png` (108–432 px) | Android 13 themed icon: corners and spade, white |
| `STUDIO-MARK.svg` | the launcher icon guard and `test/ui/mark_geometry_test.dart` | the studio's shared four-corner group (below) |

Render with `tools/render_icons.sh`; `tools/render_icons.sh --check` re-renders
into `build/icon-check/` and lists byte differences. It needs `rsvg-convert`
(Homebrew `librsvg`) and `python3`. The committed outputs were rendered on
2026-09-26 with rsvg-convert 2.62.2 and Python 3.12.3.

**Studio mark.** `STUDIO-MARK.svg` is the corner group copied from Honest Frog
Across's `ArtSource/brand/android-foreground-frog-mint.svg` (sha256
`bad1e3e00147db67a86bfc7d4d6e5fc18c3117b0892fb110bb8abe66b39136a6`, read from
GitHub 2026-09-26): corners `M 3 21 L 3 10 A 7 7 …` at stroke 6. The brand
sheet draws the same mark slightly heavier (`A 8.5`, stroke 7); the owner chose
Frog Across's geometry for every mark in the studio's apps (/n8-plan M5 round
two), so the in-app `HonestMarkPainter` uses it too.

**Inline mark.** The corners-and-spade group sits between `mark:begin` /
`mark:end` markers, identically in the three coloured sources; the guard holds
them to one copy and their corners to `STUDIO-MARK.svg`.

**Safe zone.** In the foreground, the mark's 64-unit box spans 184 of 432 px
(46 of 108 dp), centred. A corner's outer edge is an arc of radius 7 + 3
(half the stroke) about a point 10 units in from the box corner, so its
farthest point on the diagonal sits 10 − 10/√2 ≈ 2.93 units from the box
edge, (32 − 2.93) × √2 ≈ 41.1 units ≈ 0.642 of the box from the centre:
0.642 × 46 ≈ 29.5 dp, inside the 33-dp radius of the 66-dp safe zone that
circle masks keep. The guard recomputes this from the files.
