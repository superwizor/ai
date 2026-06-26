import os
from PIL import Image, ImageOps

workspace_root = "/Users/maciekckoklormam91/Desktop/Inne/APP - Superwizor AI"
downloads_dir = os.path.expanduser("~/Downloads")

# 1. Create App Icon (512x512)
logo_path = os.path.join(workspace_root, "flutter-app/superwizor/assets/images/PNG/v02_supervisor_logo_gradient.png")
icon_out_path = os.path.join(downloads_dir, "app_icon_512.png")

if os.path.exists(logo_path):
    print(f"Generating App Icon from {logo_path}...")
    img = Image.open(logo_path)
    # Ensure it's 512x512 using lanczos resampling
    icon_img = img.resize((512, 512), Image.Resampling.LANCZOS)
    icon_img.save(icon_out_path, "PNG")
    print(f"✅ Saved App Icon to: {icon_out_path}")
else:
    print(f"❌ Error: Logo file not found at {logo_path}")

# 2. Create Feature Graphic (1024x500)
# We use the beautiful mockup "3 ekrany za nimi szyba troche glass morphizm .jpeg"
mockup_path = os.path.join(downloads_dir, "3 ekrany za nimi szyba troche glass morphizm .jpeg")
feature_out_path = os.path.join(downloads_dir, "feature_graphic_1024_500.png")

if os.path.exists(mockup_path):
    print(f"Generating Feature Graphic from {mockup_path}...")
    img = Image.open(mockup_path)
    # Crop and fit to cover 1024x500
    feature_img = ImageOps.fit(img, (1024, 500), method=Image.Resampling.LANCZOS)
    feature_img.save(feature_out_path, "PNG")
    print(f"✅ Saved Feature Graphic to: {feature_out_path}")
else:
    # Fallback to other mockups if this one doesn't exist
    alternative_mockups = [
        "5 mockupów troche rozrzucone.jpeg",
        "5 ekranow mockp mieciutki.jpeg",
        "3 ekrany mockupy aplikacja podstawowe funkcjonalnosci.jpeg"
    ]
    found = False
    for alt in alternative_mockups:
        alt_path = os.path.join(downloads_dir, alt)
        if os.path.exists(alt_path):
            print(f"Generating Feature Graphic from alternative: {alt_path}...")
            img = Image.open(alt_path)
            feature_img = ImageOps.fit(img, (1024, 500), method=Image.Resampling.LANCZOS)
            feature_img.save(feature_out_path, "PNG")
            print(f"✅ Saved Feature Graphic to: {feature_out_path}")
            found = True
            break
    if not found:
        print("❌ Error: No suitable mockup image found in Downloads to generate Feature Graphic.")
