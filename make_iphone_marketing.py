import os
from PIL import Image, ImageOps

files = [
    "/Users/maciekckoklormam91/Desktop/Inne/APP - Superwizor AI/flutter-app/superwizor/assets/images/Zdjęcia APP/3 ekrany za nimi szyba troche glass morphizm .jpeg",
    "/Users/maciekckoklormam91/Desktop/Inne/APP - Superwizor AI/flutter-app/superwizor/assets/images/Zdjęcia APP/Place_this_image_onto_the_202606032112 (1).jpeg",
    "/Users/maciekckoklormam91/Desktop/Inne/APP - Superwizor AI/flutter-app/superwizor/assets/images/Zdjęcia APP/Place_this_image_onto_the_202606032112.jpeg",
    "/Users/maciekckoklormam91/Desktop/Inne/APP - Superwizor AI/flutter-app/superwizor/assets/images/Zdjęcia APP/wklej_to_zdjecie_jako_ekran_kwadrat.jpg"
]

dst_dir = os.path.expanduser("~/Downloads/Superwizor_iPhoneScreenshots")
os.makedirs(dst_dir, exist_ok=True)

# Clear old files in the directory
print("Cleaning old iPhone screenshots...")
for filename in os.listdir(dst_dir):
    file_path = os.path.join(dst_dir, filename)
    try:
        if os.path.isfile(file_path):
            os.unlink(file_path)
    except Exception as e:
        print(f"Could not delete {file_path}: {e}")

# Target iPhone 6.5" resolution
iphone_w, iphone_h = 1284, 2778

print("Processing marketing images for iPhone (1284 x 2778)...")
for i, filepath in enumerate(files):
    if not os.path.exists(filepath):
        print(f"Error: File does not exist: {filepath}")
        continue
    
    img = Image.open(filepath)
    
    # Crop and fit to cover full iPhone screen (center-cropped)
    final_img = ImageOps.fit(img, (iphone_w, iphone_h), method=Image.Resampling.LANCZOS)
    
    out_path = os.path.join(dst_dir, f"marketing_iphone_{i+1}.png")
    final_img.save(out_path, "PNG")
    print(f"-> Saved: {out_path}")

print("Successfully processed all marketing screenshots for iPhone!")
