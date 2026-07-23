# -*- mode: python ; coding: utf-8 -*-
# PyInstaller : python -m PyInstaller AscensionFR_Perso_Compagnon.spec
import os

block_cipher = None
SPEC_DIR = os.path.dirname(os.path.abspath(SPEC))
ICON = os.path.join(SPEC_DIR, "assets", "icon.ico")
VERSION = os.path.join(SPEC_DIR, "version_info.txt")

a = Analysis(
    ["compagnon.py"],
    pathex=[SPEC_DIR],
    binaries=[],
    datas=[
        (os.path.join(SPEC_DIR, "assets", "icon.ico"), "assets"),
        (os.path.join(SPEC_DIR, "assets", "icon.png"), "assets"),
        (os.path.join(SPEC_DIR, "assets", "crest.png"), "assets"),
        (os.path.join(SPEC_DIR, "assets", "ui"), "assets/ui"),
    ],
    hiddenimports=[],
    hookspath=[],
    hooksconfig={},
    runtime_hooks=[],
    excludes=[],
    win_no_prefer_redirects=False,
    win_private_assemblies=False,
    cipher=block_cipher,
    noarchive=False,
)
pyz = PYZ(a.pure, a.zipped_data, cipher=block_cipher)

exe = EXE(
    pyz,
    a.scripts,
    a.binaries,
    a.zipfiles,
    a.datas,
    [],
    name="AscensionFR_Perso",
    debug=False,
    bootloader_ignore_signals=False,
    strip=False,
    upx=False,
    upx_exclude=[],
    runtime_tmpdir=None,
    console=False,
    disable_windowed_traceback=False,
    argv_emulation=False,
    target_arch=None,
    codesign_identity=None,
    entitlements_file=None,
    icon=ICON,
    version=VERSION,
)
