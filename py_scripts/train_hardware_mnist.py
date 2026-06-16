import torch
from torchvision import datasets, transforms
from torch.utils.data import DataLoader

print("Loading MNIST dataset...")

# 1. Define how to process the images (convert to PyTorch tensors, 0.0 to 1.0)
transform = transforms.Compose([
    transforms.ToTensor()
])

# 2. Download/Load the testing dataset
test_dataset = datasets.MNIST(root='./data', train=False, download=True, transform=transform)

# 3. Create the test_loader to grab batches of 100 images
test_loader = DataLoader(test_dataset, batch_size=100, shuffle=False)

# 4. Define the Hardware Hex Converter
def float_to_fixed_hex(val, W=16, Q=12):
    """Converts a normalized float to a 28-bit Q12 fixed-point hex string."""
    scaled = int(val * (1 << Q))
    
    # 2's Complement masking for absolute 28-bit boundary representation
    if scaled < 0:
        scaled = (1 << (W + Q)) + scaled
        
    mask = (1 << (W + Q)) - 1
    scaled = scaled & mask
    
    # Pad to exactly 7 hex characters to form the precise 28-bit word
    return f"{scaled:07x}"

print("Extracting 100 images for batch verification...")
iterator = iter(test_loader) 

# Grab the first batch (100 images, 100 labels)
images, labels = next(iterator)

batch_images = []
batch_labels = []

# 5. Unpack the batch and process images one by one
for img, label in zip(images, labels):
    
    # Process the single image (28x28 = 784 pixels)
    flattened = img.flatten()
    for val in flattened:
        # Convert float to hex and append
        batch_images.append(float_to_fixed_hex(val.item())) 
        
    # Process the single label
    batch_labels.append(format(label.item(), '01x'))

# 6. Save the images to a hex file for the Verilog testbench
print("Saving pixel data to test_images.hex...")
with open("data/test_images.hex", "w") as f:
    for hex_val in batch_images:
        f.write(f"{hex_val}\n")

# 7. Save the labels to a hex file for verification
print("Saving ground-truth labels to test_labels.hex...")
with open("data/test_labels.hex", "w") as f:
    for hex_label in batch_labels:
        f.write(f"{hex_label}\n")

print("Success! Generated test_images.hex (78,400 lines) and test_labels.hex (100 lines).")