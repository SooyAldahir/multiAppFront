#!/usr/bin/env python3
"""
Genera TODOS los íconos y pantallas de inicio (splash) de MultiApp a partir de una sola imagen.

Uso (desde multiAppFront):
    python3 scripts/generate_branding.py            # usa branding/icon_source.png
    python3 scripts/generate_branding.py otra.png   # con otra imagen cuadrada (fondo oscuro + logo al centro)

Requiere Pillow y numpy:  pip3 install pillow numpy

Qué genera:
  iOS
    - ios/Runner/Assets.xcassets/AppIcon.appiconset/*  (todas las medidas, sin transparencia, 1024 para la App Store)
    - ios/Runner/Assets.xcassets/LaunchImage.imageset/* + fondo oscuro en LaunchScreen.storyboard
  Android
    - mipmap-*/ic_launcher.png            (ícono clásico, Android 7 y anteriores)
    - mipmap-anydpi-v26/ic_launcher.xml   (ícono adaptativo: fondo + logo + versión monocromática de Android 13)
    - drawable-*/ic_notification.png      (ícono blanco para la barra de notificaciones)
    - drawable-*/splash_logo.png + launch_background.xml   (splash Android 11 y anteriores)
    - drawable-*/android12splash.png + values-v31/styles.xml (splash Android 12+)
  Tiendas
    - branding/store/app_store_icon_1024.png, play_store_icon_512.png, play_feature_graphic_1024x500.png
"""
import json
import os
import re
import sys

import numpy as np
from PIL import Image, ImageDraw, ImageFilter

ROOT = os.path.abspath(os.path.join(os.path.dirname(__file__), '..'))
SRC = sys.argv[1] if len(sys.argv) > 1 else os.path.join(ROOT, 'branding', 'icon_source.png')

BG = (21, 17, 38)          # fondo oscuro del ícono (#151126)
BG_HEX = '#151126'
GLOW = (121, 90, 231)      # brillo morado de la esquina

ANDROID_RES = os.path.join(ROOT, 'android', 'app', 'src', 'main', 'res')
IOS_ASSETS = os.path.join(ROOT, 'ios', 'Runner', 'Assets.xcassets')
DENSITIES = {'mdpi': 1, 'hdpi': 1.5, 'xhdpi': 2, 'xxhdpi': 3, 'xxxhdpi': 4}


def log(msg):
    print('✔', msg)


def save(img, path, **kw):
    os.makedirs(os.path.dirname(path), exist_ok=True)
    img.save(path, optimize=True, **kw)


def write(path, text):
    os.makedirs(os.path.dirname(path), exist_ok=True)
    with open(path, 'w', encoding='utf-8') as f:
        f.write(text)


# ---------------------------------------------------------------- análisis de la imagen

src = Image.open(SRC).convert('RGB')
arr = np.asarray(src).astype(np.float32)
H, W = arr.shape[:2]
maxc = arr.max(axis=2)

# Caja del logo: píxeles brillantes en la zona central (se ignora el brillo morado de la esquina).
cy0, cy1, cx0, cx1 = int(H * 0.2), int(H * 0.8), int(W * 0.2), int(W * 0.8)
ys, xs = np.where(maxc[cy0:cy1, cx0:cx1] > 170)
x0, x1 = xs.min() + cx0, xs.max() + cx0
y0, y1 = ys.min() + cy0, ys.max() + cy0
logo_size = max(x1 - x0, y1 - y0) + 1
cx, cy = (x0 + x1) / 2, (y0 + y1) / 2

# Logo con transparencia (para splash y capas de Android).
pad = int(logo_size * 0.04)
bx0, by0 = int(cx - logo_size / 2 - pad), int(cy - logo_size / 2 - pad)
side = logo_size + 2 * pad
patch = arr[by0:by0 + side, bx0:bx0 + side]
pmax = patch.max(axis=2)
# Fondo local: se ajusta un plano (por canal) con los píxeles oscuros del recorte; así el brillo
# morado detrás del logo no deja un cuadro fantasma.
gy, gx = np.mgrid[0:side, 0:side].astype(np.float32)
dark = pmax < 100
A = np.column_stack([gx[dark], gy[dark], gx[dark] * gy[dark], np.ones(dark.sum())])
bg = np.empty_like(patch)
for ch in range(3):
    coef, *_ = np.linalg.lstsq(A, patch[..., ch][dark], rcond=None)
    bg[..., ch] = coef[0] * gx + coef[1] * gy + coef[2] * gx * gy + coef[3]
bgmax = bg.max(axis=2)
alpha = np.clip((pmax - bgmax - 14) / (150 - bgmax), 0, 1)
# Solo se conserva lo que está pegado a los cuadros (bordes suavizados), nada del fondo.
near = Image.fromarray(((pmax > 150) * 255).astype(np.uint8)).filter(ImageFilter.MaxFilter(9))
alpha *= np.asarray(near, dtype=np.float32) / 255
with np.errstate(divide='ignore', invalid='ignore'):
    rgb = (patch - (1 - alpha[..., None]) * bg) / np.maximum(alpha[..., None], 1e-3)
rgb = np.clip(rgb, 0, 255)
logo = Image.fromarray(np.dstack([rgb, alpha * 255]).astype(np.uint8), 'RGBA')

# Silueta blanca (notificaciones y ícono monocromático): los cuadros sin la estrella.
pmin = patch.min(axis=2)
star = (pmin > 200)  # la estrella es casi blanca
sil_alpha = alpha.copy()
sil_alpha[star] = 0
sil = Image.fromarray(np.dstack([np.full_like(alpha, 255)] * 3 + [sil_alpha * 255]).astype(np.uint8), 'RGBA')


def on_canvas(img, canvas, content):
    """Centra img (escalada a `content` px) en un lienzo transparente de `canvas` px."""
    out = Image.new('RGBA', (canvas, canvas), (0, 0, 0, 0))
    scaled = img.resize((content, content), Image.LANCZOS)
    off = (canvas - content) // 2
    out.alpha_composite(scaled, (off, off))
    return out


def background(size):
    """Fondo oscuro con el brillo morado arriba a la derecha (como la imagen original)."""
    yy, xx = np.mgrid[0:size, 0:size].astype(np.float32) / size
    d = np.sqrt((1 - xx) ** 2 + yy ** 2)
    t = np.clip(1 - d / 0.95, 0, 1) ** 2.2
    img = np.array(BG, np.float32) * (1 - t[..., None]) + np.array(GLOW, np.float32) * t[..., None]
    return Image.fromarray(img.astype(np.uint8), 'RGB')


# Ícono cuadrado: recorte de la imagen original con el logo ocupando ~62 %.
crop = int(round(logo_size / 0.62))
left = int(round(cx - crop / 2))
top = int(round(cy - crop / 2))
if left < 0 or top < 0 or left + crop > W or top + crop > H:
    # Si no cabe, se arma el logo sobre un fondo generado.
    icon_master = background(1024).convert('RGBA')
    icon_master.alpha_composite(on_canvas(logo, 1024, int(1024 * 0.62 * side / logo_size)))
else:
    icon_master = src.crop((left, top, left + crop, top + crop)).resize((1024, 1024), Image.LANCZOS)
icon_master = icon_master.convert('RGB')  # sin canal alfa (Apple lo rechaza)

# ---------------------------------------------------------------- iOS

appicon_dir = os.path.join(IOS_ASSETS, 'AppIcon.appiconset')
contents_path = os.path.join(appicon_dir, 'Contents.json')
if os.path.exists(contents_path):
    contents = json.load(open(contents_path))
    count = 0
    for item in contents['images']:
        if 'filename' not in item:
            continue
        pts = float(item['size'].split('x')[0])
        px = int(round(pts * float(item['scale'].rstrip('x'))))
        save(icon_master.resize((px, px), Image.LANCZOS), os.path.join(appicon_dir, item['filename']))
        count += 1
    log(f'iOS: {count} íconos en AppIcon.appiconset')

launch_dir = os.path.join(IOS_ASSETS, 'LaunchImage.imageset')
if os.path.isdir(launch_dir):
    pts = 120  # tamaño del logo en la pantalla de inicio (puntos)
    for name, scale in (('LaunchImage.png', 1), ('LaunchImage@2x.png', 2), ('LaunchImage@3x.png', 3)):
        save(logo.resize((pts * scale, pts * scale), Image.LANCZOS), os.path.join(launch_dir, name))
    storyboard = os.path.join(ROOT, 'ios', 'Runner', 'Base.lproj', 'LaunchScreen.storyboard')
    if os.path.exists(storyboard):
        s = open(storyboard, encoding='utf-8').read()
        r, g, b = (c / 255 for c in BG)
        s = re.sub(r'<color key="backgroundColor"[^>]*/>',
                   f'<color key="backgroundColor" red="{r:.4f}" green="{g:.4f}" blue="{b:.4f}" alpha="1" '
                   'colorSpace="custom" customColorSpace="sRGB"/>', s, count=1)
        s = re.sub(r'<image name="LaunchImage" width="[\d.]+" height="[\d.]+"/>',
                   f'<image name="LaunchImage" width="{pts}" height="{pts}"/>', s)
        write(storyboard, s)
    log('iOS: pantalla de inicio (fondo oscuro + logo)')

# ---------------------------------------------------------------- Android

if os.path.isdir(ANDROID_RES):
    # Ícono clásico (cuadrado redondeado), 48 dp.
    rounded = icon_master.convert('RGBA')
    mask = Image.new('L', (1024, 1024), 0)
    ImageDraw.Draw(mask).rounded_rectangle((0, 0, 1023, 1023), radius=225, fill=255)
    rounded.putalpha(mask)
    for d, f in DENSITIES.items():
        px = int(48 * f)
        save(rounded.resize((px, px), Image.LANCZOS), os.path.join(ANDROID_RES, f'mipmap-{d}', 'ic_launcher.png'))

    # Ícono adaptativo (108 dp): fondo + logo dentro de la zona segura (66 dp) + monocromático.
    for d, f in DENSITIES.items():
        px = int(108 * f)
        content = int(px * 0.50 * side / logo_size)
        save(background(px), os.path.join(ANDROID_RES, f'mipmap-{d}', 'ic_launcher_background.png'))
        save(on_canvas(logo, px, content), os.path.join(ANDROID_RES, f'mipmap-{d}', 'ic_launcher_foreground.png'))
        save(on_canvas(sil, px, content), os.path.join(ANDROID_RES, f'mipmap-{d}', 'ic_launcher_monochrome.png'))
    write(os.path.join(ANDROID_RES, 'mipmap-anydpi-v26', 'ic_launcher.xml'), '''<?xml version="1.0" encoding="utf-8"?>
<adaptive-icon xmlns:android="http://schemas.android.com/apk/res/android">
    <background android:drawable="@mipmap/ic_launcher_background" />
    <foreground android:drawable="@mipmap/ic_launcher_foreground" />
    <monochrome android:drawable="@mipmap/ic_launcher_monochrome" />
</adaptive-icon>
''')
    log('Android: íconos clásico, adaptativo y monocromático')

    # Ícono de notificación (24 dp, blanco con transparencia).
    for d, f in DENSITIES.items():
        px = int(24 * f)
        save(on_canvas(sil, px, int(px * 0.92)), os.path.join(ANDROID_RES, f'drawable-{d}', 'ic_notification.png'))
    log('Android: ícono de notificaciones')

    # Splash Android ≤ 11: fondo de color + logo centrado (120 dp).
    for d, f in DENSITIES.items():
        px = int(120 * f)
        save(logo.resize((px, px), Image.LANCZOS), os.path.join(ANDROID_RES, f'drawable-{d}', 'splash_logo.png'))
        # Splash Android 12+: lienzo de 288 dp, el logo debe caber en un círculo de 192 dp.
        canvas = int(288 * f)
        save(on_canvas(logo, canvas, int(128 * f)), os.path.join(ANDROID_RES, f'drawable-{d}', 'android12splash.png'))

    write(os.path.join(ANDROID_RES, 'values', 'colors.xml'), f'''<?xml version="1.0" encoding="utf-8"?>
<resources>
    <color name="splash_background">{BG_HEX}</color>
    <color name="notification_color">#6B59DD</color>
</resources>
''')
    launch_xml = '''<?xml version="1.0" encoding="utf-8"?>
<!-- Pantalla de inicio: fondo oscuro con el logo al centro (generado por scripts/generate_branding.py) -->
<layer-list xmlns:android="http://schemas.android.com/apk/res/android">
    <item android:drawable="@color/splash_background" />
    <item>
        <bitmap android:gravity="center" android:src="@drawable/splash_logo" />
    </item>
</layer-list>
'''
    for folder in ('drawable', 'drawable-v21'):
        write(os.path.join(ANDROID_RES, folder, 'launch_background.xml'), launch_xml)

    styles_v31 = '''<?xml version="1.0" encoding="utf-8"?>
<!-- Android 12+: pantalla de inicio del sistema (generado por scripts/generate_branding.py) -->
<resources>
    <style name="LaunchTheme" parent="@android:style/Theme.Light.NoTitleBar">
        <item name="android:forceDarkAllowed">false</item>
        <item name="android:windowFullscreen">false</item>
        <item name="android:windowDrawsSystemBarBackgrounds">false</item>
        <item name="android:windowSplashScreenBackground">@color/splash_background</item>
        <item name="android:windowSplashScreenAnimatedIcon">@drawable/android12splash</item>
    </style>
    <style name="NormalTheme" parent="@android:style/Theme.Light.NoTitleBar">
        <item name="android:windowBackground">?android:colorBackground</item>
    </style>
</resources>
'''
    write(os.path.join(ANDROID_RES, 'values-v31', 'styles.xml'), styles_v31)
    write(os.path.join(ANDROID_RES, 'values-night-v31', 'styles.xml'), styles_v31.replace('Theme.Light.NoTitleBar', 'Theme.Black.NoTitleBar'))
    log('Android: pantallas de inicio (todas las versiones)')

# ---------------------------------------------------------------- Tiendas

store = os.path.join(ROOT, 'branding', 'store')
save(icon_master, os.path.join(store, 'app_store_icon_1024.png'))
save(icon_master.resize((512, 512), Image.LANCZOS), os.path.join(store, 'play_store_icon_512.png'))

feature = background(1024).resize((1024, 500), Image.LANCZOS).convert('RGBA')
fl = logo.resize((300, 300), Image.LANCZOS)
feature.alpha_composite(fl, (130, 100))
draw = ImageDraw.Draw(feature)
font_path = None
for f in ('/System/Library/Fonts/SFNS.ttf', '/System/Library/Fonts/Helvetica.ttc',
          '/usr/share/fonts/truetype/dejavu/DejaVuSans-Bold.ttf', '/usr/share/fonts/dejavu/DejaVuSans-Bold.ttf'):
    if os.path.exists(f):
        font_path = f
        break
if font_path:
    from PIL import ImageFont

    def fit(text, size, max_w):
        while size > 12:
            fnt = ImageFont.truetype(font_path, size)
            if draw.textlength(text, font=fnt) <= max_w:
                return fnt
            size -= 2
        return ImageFont.truetype(font_path, size)

    max_w = 1024 - 480 - 50
    draw.text((480, 170), 'MultiApp', fill=(255, 255, 255), font=fit('MultiApp', 84, max_w))
    draw.text((484, 275), 'Tu día completo en una sola app', fill=(205, 198, 235),
              font=fit('Tu día completo en una sola app', 32, max_w))
save(feature.convert('RGB'), os.path.join(store, 'play_feature_graphic_1024x500.png'))
log('Tiendas: ícono App Store (1024), ícono Play (512) y gráfico destacado (1024×500)')
