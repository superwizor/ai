import os
from PIL import Image, ImageOps

files = [
    "/Users/maciekckoklormam91/Desktop/Inne/APP - Superwizor AI/flutter-app/superwizor/assets/images/Zdjęcia APP/3 ekrany za nimi szyba troche glass morphizm .jpeg",
    "/Users/maciekckoklormam91/Desktop/Inne/APP - Superwizor AI/flutter-app/superwizor/assets/images/Zdjęcia APP/Place_this_image_onto_the_202606032112 (1).jpeg",
    "/Users/maciekckoklormam91/Desktop/Inne/APP - Superwizor AI/flutter-app/superwizor/assets/images/Zdjęcia APP/Place_this_image_onto_the_202606032112.jpeg",
    "/Users/maciekckoklormam91/Desktop/Inne/APP - Superwizor AI/flutter-app/superwizor/assets/images/Zdjęcia APP/wklej_to_zdjecie_jako_ekran_kwadrat.jpg"
]

dst_dir = os.path.expanduser("~/Downloads/Superwizor_iPadScreenshots")
os.makedirs(dst_dir, exist_ok=True)

# Clear old files in the directory
print("Cleaning old screenshots...")
for filename in os.listdir(dst_dir):
    file_path = os.path.join(dst_dir, filename)
    try:
        if os.path.isfile(file_path):
            os.unlink(file_path)
    except Exception as e:
        print(f"Could not delete {file_path}: {e}")

ipad_w, ipad_h = 2048, 2732

print("Processing marketing images to fully cover iPad screen...")
for i, filepath in enumerate(files):
    if not os.path.exists(filepath):
        print(f"Error: File does not exist: {filepath}")
        continue
    
    img = Image.open(filepath)
    
    # Crop and fit to fully cover the iPad screen (taking the center part)
    final_img = ImageOps.fit(img, (ipad_w, ipad_h), method=Image.Resampling.LANCZOS)
    print(f"-> Image {i+1} cropped and fitted to cover full screen (center-cropped).")
        
    out_path = os.path.join(dst_dir, f"marketing_ipad_{i+1}.png")
    final_img.save(out_path, "PNG")
    print(f"Saved: {out_path}")

print("Successfully processed all marketing screenshots to full-screen cover!")
