#!/usr/bin/env python3
"""HMusic 各平台 App 图标生成器。

用法: python3 tool/generate_icons.py  (需要 brew install librsvg + pillow)

源: assets/icon/hmusic-glyph.svg (品牌音符，与 web favicon 同图形)
底色: #FCF8EF 暖纸 (取自 HMusic-Server web/assets/apple-touch-icon.png)

各平台形状规范不同, 不能一张方图缩放到底:
- iOS: 全出血方图, 系统裁圆角; App Store 禁 alpha 通道
- macOS: Apple 图标网格 —— 图形占画布 824/1024, 圆角 ≈ 22.5%, 四周留透明
  (全出血会显得比别家图标大一圈, 是移植 app 的典型破绽)
- Android 8+: 自适应图标 (前景字形 + 纯色背景层, 系统负责遮罩);
  前景安全区是中央 Ø66/108 圆, 字形按对角线内切算高度
- Android 7-: 传统 png, 自带圆角方形轮廓
- Windows: 多尺寸 .ico, 烘 10% 圆角
Linux 桌面图标由打包期 .desktop 处理, 不在此列。
"""

from __future__ import annotations

import io
import subprocess
from pathlib import Path

from PIL import Image, ImageDraw

ROOT = Path(__file__).resolve().parent.parent
SVG = ROOT / "assets/icon/hmusic-glyph.svg"
BG = (252, 248, 239, 255)  # #FCF8EF
TRANSPARENT = (0, 0, 0, 0)

# 字形占方形画布的高度比。0.72 对齐 web apple-touch-icon 的分量感。
GLYPH_FRAC = 0.72
# 自适应前景: 字形 (宽:高 ≈ 0.69) 对角线内切安全区圆 Ø66/108 → 高度上限 ≈ 0.50。
ADAPTIVE_FRAC = 0.50


def render_glyph(height: int = 1600) -> Image.Image:
    out = subprocess.run(
        ["rsvg-convert", "-h", str(height), str(SVG)],
        capture_output=True,
        check=True,
    )
    return Image.open(io.BytesIO(out.stdout)).convert("RGBA")


GLYPH = render_glyph()


def square(size: int, glyph_frac: float, bg: tuple = BG) -> Image.Image:
    """底色方图 + 居中字形。"""
    canvas = Image.new("RGBA", (size, size), bg)
    h = round(size * glyph_frac)
    w = round(GLYPH.width * h / GLYPH.height)
    glyph = GLYPH.resize((w, h), Image.LANCZOS)
    canvas.alpha_composite(glyph, ((size - w) // 2, (size - h) // 2))
    return canvas


def rounded(img: Image.Image, radius_frac: float) -> Image.Image:
    """烘圆角 (4x 超采样抗锯齿)。"""
    s = img.width
    ss = 4
    mask = Image.new("L", (s * ss, s * ss), 0)
    ImageDraw.Draw(mask).rounded_rectangle(
        [0, 0, s * ss - 1, s * ss - 1], radius=round(s * ss * radius_frac), fill=255
    )
    mask = mask.resize((s, s), Image.LANCZOS)
    out = Image.new("RGBA", (s, s), TRANSPARENT)
    out.paste(img, (0, 0), mask)
    return out


def macos_icon(size: int) -> Image.Image:
    """Apple 网格: 圆角砖占画布 824/1024, 四周透明留白。"""
    content = max(1, round(size * 824 / 1024))
    tile = rounded(square(content, GLYPH_FRAC), 185.4 / 824)
    canvas = Image.new("RGBA", (size, size), TRANSPARENT)
    offset = (size - content) // 2
    canvas.alpha_composite(tile, (offset, offset))
    return canvas


def save(img: Image.Image, path: Path) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    img.save(path)
    print(f"  {path.relative_to(ROOT)}")


def main() -> None:
    print("iOS (全出血, 无 alpha):")
    ios_dir = ROOT / "ios/Runner/Assets.xcassets/AppIcon.appiconset"
    ios_sizes = {
        "Icon-App-20x20@1x.png": 20,
        "Icon-App-20x20@2x.png": 40,
        "Icon-App-20x20@3x.png": 60,
        "Icon-App-29x29@1x.png": 29,
        "Icon-App-29x29@2x.png": 58,
        "Icon-App-29x29@3x.png": 87,
        "Icon-App-40x40@1x.png": 40,
        "Icon-App-40x40@2x.png": 80,
        "Icon-App-40x40@3x.png": 120,
        "Icon-App-60x60@2x.png": 120,
        "Icon-App-60x60@3x.png": 180,
        "Icon-App-76x76@1x.png": 76,
        "Icon-App-76x76@2x.png": 152,
        "Icon-App-83.5x83.5@2x.png": 167,
        "Icon-App-1024x1024@1x.png": 1024,
    }
    for name, px in ios_sizes.items():
        save(square(px, GLYPH_FRAC).convert("RGB"), ios_dir / name)

    print("macOS (Apple 网格圆角砖):")
    macos_dir = ROOT / "macos/Runner/Assets.xcassets/AppIcon.appiconset"
    for px in (16, 32, 64, 128, 256, 512, 1024):
        save(macos_icon(px), macos_dir / f"app_icon_{px}.png")

    print("Android 传统图标 (圆角方):")
    res = ROOT / "android/app/src/main/res"
    legacy = {"mdpi": 48, "hdpi": 72, "xhdpi": 96, "xxhdpi": 144, "xxxhdpi": 192}
    for density, px in legacy.items():
        save(
            rounded(square(px, GLYPH_FRAC), 1 / 6),
            res / f"mipmap-{density}/ic_launcher.png",
        )

    print("Android 自适应前景 (透明底字形):")
    adaptive = {"mdpi": 108, "hdpi": 162, "xhdpi": 216, "xxhdpi": 324, "xxxhdpi": 432}
    for density, px in adaptive.items():
        save(
            square(px, ADAPTIVE_FRAC, bg=TRANSPARENT),
            res / f"mipmap-{density}/ic_launcher_foreground.png",
        )

    print("Windows (.ico 多尺寸):")
    ico = rounded(square(256, GLYPH_FRAC), 0.10)
    ico_path = ROOT / "windows/runner/resources/app_icon.ico"
    ico.save(
        ico_path,
        format="ICO",
        sizes=[(16, 16), (24, 24), (32, 32), (48, 48), (64, 64), (128, 128), (256, 256)],
    )
    print(f"  {ico_path.relative_to(ROOT)}")


if __name__ == "__main__":
    main()
