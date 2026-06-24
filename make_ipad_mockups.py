import os
from PIL import Image, ImageDraw

src_dir = os.path.expanduser("~/Downloads/SuperwizorScreenshots")
dst_dir = os.path.expanduser("~/Downloads/Superwizor_iPadScreenshots")
os.makedirs(dst_dir, exist_ok=True)

# iPad Pro 12.9/13" resolution
ipad_w, ipad_h = 2048, 2732
# App theme background color: #173e43 (Nocturne / Deep teal)
bg_color = (23, 62, 67) 

# Target height for the phone image on the iPad screen
target_h = 2300

print("Generating elegant iPad mockups...")
generated_count = 0

for filename in os.listdir(src_dir):
    if filename.upper().endswith(('.PNG', '.JPG', '.JPEG')) and not filename.startswith('.'):
        img_path = os.path.join(src_dir, filename)
        phone_img = Image.open(img_path)
        
        # Calculate new width to preserve aspect ratio
        phone_w, phone_h = phone_img.size
        aspect_ratio = phone_w / phone_h
        new_h = target_h
        new_w = int(new_h * aspect_ratio)
        
        # Resize phone screenshot
        phone_resized = phone_img.resize((new_w, new_h), Image.Resampling.LANCZOS)
        
        # Create a mask for rounded corners (iPhone style)
        radius = 60
        mask = Image.new('L', (new_w, new_h), 0)
        draw = ImageDraw.Draw(mask)
        draw.rounded_rectangle([0, 0, new_w, new_h], radius, fill=255)
        
        # Create the iPad background
        ipad_bg = Image.new('RGB', (ipad_w, ipad_h), bg_color)
        
        # Position to center the phone image
        paste_x = (ipad_w - new_w) // 2
        paste_y = (ipad_h - new_h) // 2
        
        # Paste resized screenshot onto background using the rounded corner mask
        ipad_bg.paste(phone_resized, (paste_x, paste_y), mask)
        
        # Save output
        out_path = os.path.join(dst_dir, filename)
        ipad_bg.save(out_path, "PNG")
        print(f"-> Generated elegant iPad mockup for {filename}")
        generated_count += 1

print(f"Done! Successfully generated {generated_count} iPad mockups.")
