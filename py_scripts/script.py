import torch
import torch.nn as nn
import torch.optim as optim
import torchvision
import torchvision.transforms as transforms
import os

# ==========================================
# 1. Hardware-Aligned PyTorch Model
# ==========================================
class HardwareCNN(nn.Module):
    def __init__(self):
        super(HardwareCNN, self).__init__()
        # Convolution: 1 input channel, 1 output channel, 3x3 kernel, Stride 1, NO BIAS
        self.conv1 = nn.Conv2d(in_channels=1, out_channels=1, kernel_size=3, stride=1, bias=False)
        self.relu = nn.ReLU()
        # Pooling: 2x2 window, Stride 2
        self.pool = nn.MaxPool2d(kernel_size=2, stride=2)
        # Dense: 13x13 = 169 input features, 10 output classes, NO BIAS
        self.fc = nn.Linear(in_features=169, out_features=10, bias=False)

    def forward(self, x):
        x = self.conv1(x)
        x = self.relu(x)
        x = self.pool(x)
        x = torch.flatten(x, 1)
        x = self.fc(x)
        return x

# ==========================================
# 2. Hyperparameters & Data Loading
# ==========================================
EPOCHS = 3
LEARNING_RATE = 0.001
BATCH_SIZE = 64
Q_FRAC = 12       # 12 fractional bits
TOTAL_BITS = 28   # N + Q = 16 + 12 = 28 bits

# Transform: Convert to tensor and normalize between 0 and 1
transform = transforms.Compose([transforms.ToTensor()])

print("Downloading/Loading MNIST dataset...")
train_dataset = torchvision.datasets.MNIST(root='./data', train=True, transform=transform, download=True)
test_dataset = torchvision.datasets.MNIST(root='./data', train=False, transform=transform, download=True)

train_loader = torch.utils.data.DataLoader(dataset=train_dataset, batch_size=BATCH_SIZE, shuffle=True)
test_loader = torch.utils.data.DataLoader(dataset=test_dataset, batch_size=1, shuffle=False)

# ==========================================
# 3. Training Loop
# ==========================================
model = HardwareCNN()
criterion = nn.CrossEntropyLoss()
optimizer = optim.Adam(model.parameters(), lr=LEARNING_RATE)

print("\nStarting Training...")
model.train()
for epoch in range(EPOCHS):
    total_loss = 0
    for images, labels in train_loader:
        optimizer.zero_grad()
        outputs = model(images)
        loss = criterion(outputs, labels)
        loss.backward()
        optimizer.step()
        total_loss += loss.item()
    print(f"Epoch [{epoch+1}/{EPOCHS}], Loss: {total_loss/len(train_loader):.4f}")

# ==========================================
# 4. Extracting and Quantizing for Verilog
# ==========================================
print("\nTraining Complete. Quantizing weights to Q12 format...")

def float_to_fixed_hex(val, frac_bits=Q_FRAC, total_bits=TOTAL_BITS):
    """Converts a float to a two's complement hex string for Verilog."""
    scaled = int(round(val * (2 ** frac_bits)))
    
    # Check boundaries for 28-bit integer
    max_val = (1 << (total_bits - 1)) - 1
    min_val = -(1 << (total_bits - 1))
    
    # Saturation (just in case, though unlikely for these weights)
    if scaled > max_val: scaled = max_val
    if scaled < min_val: scaled = min_val
        
    # Two's complement conversion for negative numbers
    if scaled < 0:
        scaled = (1 << total_bits) + scaled
        
    # Format as zero-padded hex (28 bits = 7 hex characters)
    return format(scaled, f'07x')

def write_hex_file(filename, data_tensor):
    flat_data = data_tensor.detach().numpy().flatten()
    with open(filename, 'w') as f:
        for val in flat_data:
            f.write(f"{float_to_fixed_hex(val)}\n")
    print(f"Generated {filename} ({len(flat_data)} values)")

# Extract Weights
write_hex_file("data/conv_weights.hex", model.conv1.weight)
write_hex_file("data/dense_weights.hex", model.fc.weight)

# ==========================================
# 5. Extracting a Test Image
# ==========================================
model.eval()
print("\nExtracting test image for simulation...")

# Grab the very first image in the test set
test_image, true_label = next(iter(test_loader))

# Let PyTorch predict it so we know what the hardware SHOULD output
with torch.no_grad():
    software_output = model(test_image)
    predicted_label = torch.argmax(software_output, dim=1).item()

print(f"Software Prediction: {predicted_label}")
print(f"Actual Truth Label: {true_label.item()}")

# Flatten and export the 28x28 image to hex
write_hex_file("data/image.hex", test_image)

print("\nSuccess! You can now run your Verilog testbench.")