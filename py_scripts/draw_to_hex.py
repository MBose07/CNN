import tkinter as tk
from PIL import Image, ImageDraw
import numpy as np

class MNISTDrawingBoard:
    def __init__(self, root):
        self.root = root
        self.root.title("MNIST Input Canvas")
        
        # Exact matching hardware widths
        self.W = 16  
        self.Q = 12  
        
        self.canvas_size = 280
        self.canvas = tk.Canvas(root, width=self.canvas_size, height=self.canvas_size, bg="black")
        self.canvas.pack(pady=10)
        
        # Create clear offscreen black image
        self.image = Image.new("L", (self.canvas_size, self.canvas_size), "black")
        self.draw = ImageDraw.Draw(self.image)
        
        self.canvas.bind("<B1-Motion>", self.paint)
        
        self.btn_save = tk.Button(root, text="Save to image.hex", command=self.save_hex, bg="blue", fg="white")
        self.btn_save.pack(side=tk.LEFT, padx=20)
        
        self.btn_clear = tk.Button(root, text="Clear Canvas", command=self.clear_canvas, bg="red", fg="white")
        self.btn_clear.pack(side=tk.RIGHT, padx=20)

    def paint(self, event):
        # Thick white pen on black canvas
        r = 12
        x1, y1 = (event.x - r), (event.y - r)
        x2, y2 = (event.x + r), (event.y + r)
        self.canvas.create_oval(x1, y1, x2, y2, fill="white", outline="white")
        self.draw.ellipse([x1, y1, x2, y2], fill="white", outline="white")

    def clear_canvas(self):
        self.canvas.delete("all")
        self.image = Image.new("L", (self.canvas_size, self.canvas_size), "black")
        self.draw = ImageDraw.Draw(self.image)

    def float_to_fixed_hex(self, val):
        # Convert to strict Q12 fixed point
        scaled = int(val * (1 << self.Q))
        
        # 2's Complement masking for absolute 28-bit boundary representation
        if scaled < 0:
            scaled = (1 << (self.W + self.Q)) + scaled
            
        mask = (1 << (self.W + self.Q)) - 1
        scaled = scaled & mask
        
        # Pad to exactly 7 hex characters to form the precise 28-bit word
        return f"{scaled:07x}"

    def save_hex(self):
        # Lanczos filter ensures smoother downsampling so features don't drop out
        img_resized = self.image.resize((28, 28), Image.Resampling.LANCZOS)
        
        # Convert directly to normalized float array
        img_np = np.array(img_resized, dtype=np.float32) / 255.0
        flattened = img_np.flatten()
        
        with open("data/image.hex", "w") as f:
            for val in flattened:
                hex_str = self.float_to_fixed_hex(val)
                f.write(f"{hex_str}\n")
                
        print("image.hex successfully generated using old formatting format.")

if __name__ == "__main__":
    root = tk.Tk()
    app = MNISTDrawingBoard(root)
    root.mainloop()