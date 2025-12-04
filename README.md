# upscayl-video
Automated video upscaling using Real-ESRGAN AI models. Extract frames, upscale with AI, and reconstruct high-quality videos with preserved audio. Supports sequential and parallel processing.


# 🎬 AI Video Upscaling Scripts

> Automated video upscaling using Real-ESRGAN and AI models. Extract frames, upscale with AI, and reconstruct high-quality videos with preserved audio.

[![Bash](https://img.shields.io/badge/Bash-4.0+-blue.svg)](https://www.gnu.org/software/bash/)
[![FFmpeg](https://img.shields.io/badge/FFmpeg-Required-green.svg)](https://ffmpeg.org/)
[![License](https://img.shields.io/badge/License-See%20LICENSE-lightgrey.svg)](LICENSE)

**AI Video Upscaling Scripts** provides a complete automation solution for upscaling video files using AI-powered models. These bash scripts leverage `upscayl-bin` to process videos frame-by-frame, upscaling them with Real-ESRGAN and other AI models, then reassembling them into high-quality output videos with original audio preserved.

Perfect for enhancing old videos, upscaling low-resolution content, or improving video quality for archival purposes.

## Overview

These scripts provide an automated solution for upscaling video files using Real-ESRGAN and other AI models. They handle frame extraction, batch processing, parallel execution, and video reconstruction with audio preservation.

## Key Features

### 🎬 **Automated Video Processing Pipeline**
- **Frame Extraction**: Automatically extracts frames from input videos using FFmpeg
- **AI Upscaling**: Uses upscayl-bin with configurable AI models for frame enhancement
- **Video Reconstruction**: Reassembles upscaled frames into a new video file
- **Audio Preservation**: Automatically extracts and preserves original audio tracks

### ⚡ **Performance Optimizations**
- **Batch Processing**: Optimized thread configuration for efficient GPU utilization
- **Parallel Processing**: `sc_parallel.sh` supports multiple concurrent upscaling jobs
- **Smart Error Handling**: Robust error detection and recovery for corrupted video files
- **Time Estimation**: Provides accurate processing time estimates before starting

### 🛡️ **Robust Error Handling**
- Handles QuickTime/MOV files with codec compatibility issues
- Graceful error recovery for decoding issues
- Automatic frame rate detection with fallback defaults
- Comprehensive validation of input files and extracted frames

### 📊 **Detailed Progress Reporting**
- Real-time progress updates with timestamps
- Video information analysis (resolution, frame rate, duration)
- Processing time breakdown by stage
- Speedup metrics for parallel processing

## Prerequisites

### Required Software

1. **upscayl-bin**
   - Download the latest release from [upscayl GitHub repository](https://github.com/upscayl/upscayl-ncnn/releases)
   - Extract and place the `upscayl-bin` executable in the repository root directory
   - Ensure it has execute permissions: `chmod +x upscayl-bin`

2. **FFmpeg**
   - Required for video frame extraction and encoding
   - Install via package manager:
     ```bash
     # Ubuntu/Debian
     sudo apt-get install ffmpeg
     
     # Fedora/RHEL
     sudo dnf install ffmpeg
     
     # macOS (via Homebrew)
     brew install ffmpeg
     ```

3. **Bash** (version 4.0+)
   - Usually pre-installed on Linux/macOS systems
   - Verify with: `bash --version`

### Hardware Requirements

- **GPU**: NVIDIA GPU with CUDA support (recommended) or compatible Vulkan-capable GPU
  - RTX 3090 24GB: Recommended for parallel processing (2-4 parallel jobs)
  - Lower-end GPUs: Use sequential processing or reduce parallel jobs
- **RAM**: Minimum 8GB, 16GB+ recommended for large videos
- **Storage**: Sufficient space for:
  - Original video file
  - Extracted frames (temporary)
  - Upscaled frames (temporary)
  - Final output video (4x larger than input)

### AI Models

Models must be placed in the `models/` directory. Each model requires two files:
- `ModelName.bin` - Model weights
- `ModelName.param` - Model parameters

**Included Model:**
- `RealESRGAN_General_WDN_x4_v3` - General-purpose 4x upscaling model

**Download Additional Models:**
- Visit the [upscayl models repository](https://github.com/upscayl/models) or check the upscayl documentation
- Place model files in the `models/` directory
- Update the `MODEL` variable in the scripts to use different models

## Installation

1. **Clone or download this repository:**
   ```bash
   git clone <repository-url>
   cd upscayl-bin-20240601-103425-linux
   ```

2. **Download upscayl-bin:**
   - Visit [upscayl releases](https://github.com/upscayl/upscayl-ncnn/releases)
   - Download the appropriate binary for your system
   - Extract and place `upscayl-bin` in the repository root
   - Make it executable: `chmod +x upscayl-bin`

3. **Download AI models:**
   - Create `models/` directory if it doesn't exist: `mkdir -p models`
   - Download model files (`.bin` and `.param`) into `models/`
   - Ensure model names match the `MODEL` variable in scripts

4. **Install FFmpeg** (if not already installed):
   ```bash
   sudo apt-get install ffmpeg  # Ubuntu/Debian
   ```

5. **Make scripts executable:**
   ```bash
   chmod +x sc.sh sc_parallel.sh
   ```

6. **Configure script paths (if needed):**
   - Edit `UPSCAYL` variable in both scripts to match your `upscayl-bin` path
   - Edit `MODEL` variable to use a different model from `models/` directory

## Usage

### Sequential Processing (`sc.sh`)

Processes videos frame-by-frame sequentially. Best for:
- Systems with limited GPU memory
- Smaller videos
- When you need predictable resource usage

**Basic Usage:**
```bash
./sc.sh input_video.mp4
```

**Example:**
```bash
./sc.sh my_video.mov
# Output: my_video_upscaled.mkv
```

### Parallel Processing (`sc_parallel.sh`)

Processes multiple frame batches simultaneously. Best for:
- High-end GPUs (RTX 3090, RTX 4090, etc.)
- Large videos where speed is important
- Systems with sufficient GPU memory

**Basic Usage:**
```bash
./sc_parallel.sh input_video.mp4 [parallel_jobs]
```

**Examples:**
```bash
# Use default 3 parallel jobs
./sc_parallel.sh my_video.mp4

# Specify 4 parallel jobs (for RTX 3090 24GB)
./sc_parallel.sh my_video.mp4 4

# Use 2 parallel jobs (for lower-end GPUs)
./sc_parallel.sh my_video.mp4 2
```

**Parallel Jobs Recommendations:**
- **RTX 3090 24GB**: 2-4 parallel jobs
- **RTX 4090**: 3-5 parallel jobs
- **Lower-end GPUs (8-12GB)**: 1-2 parallel jobs
- **Very limited GPU memory**: Use `sc.sh` instead

### Custom Temp Directory

For `sc_parallel.sh`, you can specify a custom temporary directory if `/tmp` doesn't have enough space:

```bash
export UPSCAYL_TEMP=/path/to/large/disk
./sc_parallel.sh my_video.mp4
```

## Script Configuration

### Changing the Model

Edit the `MODEL` variable in either script:

```bash
# In sc.sh or sc_parallel.sh, change:
MODEL=RealESRGAN_General_WDN_x4_v3
# To:
MODEL=YourModelName
```

Ensure the model files (`YourModelName.bin` and `YourModelName.param`) exist in the `models/` directory.

### Adjusting Thread Configuration

Both scripts use optimized thread counts. You can modify these in the scripts:

```bash
# Format: -j load:proc:save
LOAD_THREADS=2    # Frames loading threads
PROC_THREADS=4    # Processing threads (GPU)
SAVE_THREADS=2    # Saving threads
THREAD_CONFIG="${LOAD_THREADS}:${PROC_THREADS}:${SAVE_THREADS}"
```

For parallel processing, lower thread counts per process are used to avoid GPU memory conflicts.

## Output

- **Output Format**: Matroska (`.mkv`) container with H.264 video codec
- **Output Naming**: `{input_filename}_upscaled.mkv`
- **Resolution**: 4x the input resolution (for 4x models like RealESRGAN_General_WDN_x4_v3)
- **Audio**: Preserved from original video (if present)
- **Frame Rate**: Maintains original frame rate

## Processing Workflow

Both scripts follow this workflow:

1. **Video Analysis**
   - Extracts video metadata (resolution, frame rate, duration)
   - Calculates total frames
   - Estimates processing time

2. **Frame Extraction**
   - Extracts all frames as PNG images
   - Handles codec compatibility issues
   - Validates successful extraction

3. **Upscaling** (Longest step)
   - Processes frames through AI model
   - Sequential: One batch at a time
   - Parallel: Multiple batches simultaneously

4. **Audio Extraction**
   - Extracts audio track from original video
   - Handles videos without audio gracefully

5. **Video Encoding**
   - Reassembles upscaled frames into video
   - Combines with original audio
   - Creates final output file

6. **Cleanup**
   - Automatically removes temporary files
   - Preserves only the final output

## Performance Notes

### Processing Speed
- **RTX 3090**: ~0.2-0.4 seconds per frame
- **Sequential**: Total time = frames × 0.3 seconds (estimated)
- **Parallel**: Total time ≈ (frames × 0.3) / parallel_jobs

### Example Processing Times
- **1-minute video @ 30fps** (1,800 frames):
  - Sequential: ~9 minutes
  - Parallel (3 jobs): ~3 minutes

- **10-minute video @ 24fps** (14,400 frames):
  - Sequential: ~72 minutes (1.2 hours)
  - Parallel (3 jobs): ~24 minutes

### Storage Requirements
- **Temporary files**: ~2-3x the original video size
- **Output file**: ~4x the original video size (for 4x upscaling)
- Ensure sufficient disk space before processing


## License

Please refer to the LICENSE file in this repository for license information.

## Contributing

Contributions are welcome! Please feel free to submit issues or pull requests.

## Acknowledgments

- **upscayl**: AI-powered image upscaling tool
- **Real-ESRGAN**: The AI models used for upscaling
- **FFmpeg**: Video processing framework

## Additional Resources

- [upscayl GitHub Repository](https://github.com/upscayl/upscayl-ncnn)
- [upscayl Models](https://github.com/upscayl/models)
- [FFmpeg Documentation](https://ffmpeg.org/documentation.html)
- [Real-ESRGAN Paper](https://github.com/xinntao/Real-ESRGAN)

