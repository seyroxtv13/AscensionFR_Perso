from PIL import Image
from pathlib import Path

assets = Path(r"C:\Users\Seyrox.DESKTOP-5NR0U8I\Desktop\AscensionFR_Perso\compagnon\assets")
assets.mkdir(parents=True, exist_ok=True)
img = Image.open(assets / "icon.png").convert("RGBA")
ico_path = assets / "icon.ico"
img.save(
    ico_path,
    format="ICO",
    sizes=[(16, 16), (32, 32), (48, 48), (64, 64), (128, 128), (256, 256)],
)
print("OK", ico_path, ico_path.stat().st_size)
