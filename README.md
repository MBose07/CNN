# MNIST Hardware CNN Accelerator

A complete hardware-software co-design implementation of a CNN accelerator for MNIST digit recognition. This project combines PyTorch model training with Verilog RTL simulation for fixed-point digit inference.

## Project Overview

This repository contains:
- **PyTorch Training Scripts**: Train and quantize a CNN model for MNIST
- **Verilog RTL**: Hardware implementation of convolution, pooling, dense layers, and argmax
- **Testbenches**: Verify hardware correctness against software predictions
- **Interactive Drawing Tool**: Real-time digit input for hardware testing

### Architecture

```
Input (28×28 MNIST Image)
    ↓
Convolution Layer (3×3 kernel, 1 stride)
    ↓
ReLU Activation
    ↓
Max Pooling (2×2, stride 2)
    ↓
Dense Layer (169 → 10)
    ↓
Argmax (10-way classification)
    ↓
Output (0-9 prediction)
```

### Fixed-Point Representation
- **Integer Width**: 16 bits (W)
- **Fractional Width**: 12 bits (Q)
- **Total Width**: 28 bits (W + Q)
- **Format**: Two's complement Q12 fixed-point

## Directory Structure

```
CNN/
├── py_scripts/                  # Python training and utility scripts
│   ├── script.py               # Full training pipeline
│   ├── train_hardware_mnist.py # Batch testing (100 images)
│   ├── draw_to_hex.py          # Interactive drawing tool
│   └── data/MNIST/             # Dataset (auto-downloaded)
├── rtl/                        # Verilog hardware implementation
│   ├── cnn_layer_top.v         # Top-level module
│   ├── components/             # Hardware building blocks
│   │   ├── convolver.v
│   │   ├── relu.v
│   │   ├── max_pool.v
│   │   ├── dense.v
│   │   ├── argmax.v
│   │   ├── mac.v              # Multiply-Accumulate
│   │   ├── shift_reg.v
│   │   └── comparator.v
│   └── mnist_hardware_waves.vcd # Simulation waveforms
├── tb/                         # Testbenches
│   ├── cnn_mnist_tb.v         # Single image testbench
│   └── tb_cnn_core.v          # Batch inference testbench
└── data/                       # Generated hex files
    ├── conv_weights.hex        # Quantized convolution weights
    ├── dense_weights.hex       # Quantized dense layer weights
    ├── image.hex               # Test image (28×28 = 784 pixels)
    ├── test_images.hex         # Batch test images (100×784 pixels)
    └── test_labels.hex         # Ground truth labels
```

## Setup & Usage

### Prerequisites

```bash
pip install torch torchvision numpy pillow
# For Verilog simulation:
# - Icarus Verilog (iverilog)
# - VVP simulator (included with iverilog)
```

### 1. Train Model & Generate Weights

```bash
cd py_scripts
python script.py
```

**Output Files:**
- `data/conv_weights.hex` - 9 convolution weights
- `data/dense_weights.hex` - 1690 dense layer weights
- `data/image.hex` - Single test image

### 2. Interactive Drawing Tool

```bash
python draw_to_hex.py
```

1. Draw a digit on the black canvas
2. Click **"Save to image.hex"** to convert to fixed-point hex
3. The image is downsampled (280px → 28px using Lanczos)
4. Output: `data/image.hex`

### 3. Single Image Hardware Verification

Run Verilog testbench with custom-drawn digit:

```bash
cd ../rtl
iverilog -o sim_core cnn_layer_top.v components/*.v ../tb/cnn_mnist_tb.v
vvp sim_core
```

**Output:**
- VCD waveform: `mnist_hardware_waves.vcd`
- Console prediction and comparison

### 4. Batch Testing (100 Images)

Generate test batch and run batch simulation:

```bash
cd ../py_scripts
python train_hardware_mnist.py    # Generates test_images.hex, test_labels.hex

cd ../rtl
iverilog -o sim_batch cnn_layer_top.v components/*.v ../tb/tb_cnn_core.v
vvp sim_batch
```

**Output:**
- Console accuracy metrics
- Per-image predictions vs ground truth

## Results

### Draw-to-Hex Testing (Interactive Drawing)

| Test Case | Input | Prediction | Expected | Status |
|-----------|-------|-----------|----------|--------|
| [PLACEHOLDER: Drawn Digit #1] | User-drawn 3 | 3 | 3 | ✅ Pass |
| [PLACEHOLDER: Drawn Digit #2] | User-drawn 2 | 2 | 2 | ✅ Pass |

**Live Testing Demo Video:**

[![MNIST Hardware CNN - Interactive Drawing Demo](https://img.shields.io/badge/Demo-Video-red?style=for-the-badge)](https://[PLACEHOLDER_VIDEO_URL])

> [PLACEHOLDER: Link to video demo showing real-time digit drawing and hardware prediction]
> 
> Video demonstrates:
> - Interactive canvas drawing
> - Real-time image conversion to Q12 fixed-point
> - Hardware prediction output
> - Waveform visualization in GTKWave

**Sample Waveforms:**
```
Clock Cycles: [START] → [CONV] → [RELU] → [POOL] → [DENSE] → [ARGMAX] → [DONE]
Expected delay: ~50-60 clock cycles per image
```

---

**Batch Test Results Screenshot:**

![MNIST Hardware CNN - Batch Test Results]([https://[PLACEHOLDER_SCREENSHOT_URL]](https://github.com/MBose07/CNN/blob/main/Screenshot%202026-06-16%20185639.png))

> [PLACEHOLDER: Screenshot showing console output from 100-image batch inference with accuracy metrics]

**Detailed Results:**
- **Software Accuracy** (PyTorch): [PLACEHOLDER: XX.X%]
- **Hardware Accuracy** (RTL): [PLACEHOLDER: XX.X%]
- **Mismatch Rate**: [PLACEHOLDER: 0.0%]
- **Average Inference Latency**: [PLACEHOLDER: ~500 ns @ 100MHz]

---

## Files Reference

### Python Scripts

| File | Purpose |
|------|---------|
| `script.py` | Complete training pipeline: load MNIST, train model, quantize weights |
| `train_hardware_mnist.py` | Load 100 test images, convert to fixed-point hex |
| `draw_to_hex.py` | Interactive GUI for digit drawing and conversion |

### Verilog Modules

| Module | Lines | Purpose |
|--------|-------|---------|
| `cnn_layer_top.v` | ~150 | Top-level orchestrator, pipeline control |
| `convolver.v` | ~200 | 3×3 convolution with streaming input |
| `relu.v` | ~20 | ReLU activation (combinational) |
| `max_pool.v` | ~150 | 2×2 max pooling with stride 2 |
| `dense.v` | ~120 | 10-output fully connected layer |
| `argmax.v` | ~50 | Find maximum score and output class |
| `mac.v` | ~80 | Multiply-Accumulate unit (core building block) |

### Test Benches

| File | Type | Scope |
|------|------|-------|
| `cnn_mnist_tb.v` | Single-image | 1 test image + waveform capture |
| `tb_cnn_core.v` | Batch | 100 images + accuracy reporting |


## References

- [MNIST Dataset](http://yann.lecun.com/exdb/mnist/)
- [PyTorch Documentation](https://pytorch.org/docs/stable/index.html)
- [Icarus Verilog](http://iverilog.icarus.com/)
- Fixed-point arithmetic: [Q-format](https://en.wikipedia.org/wiki/Q_(number_format))
- This Blog helped a LOTTTTTT (https://thedatabus.in/)

