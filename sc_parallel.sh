#!/bin/bash
set -e  # Exit on error

UPSCAYL=/home/genai/Downloads/upscayl-bin-20240601-103425-linux/upscayl-bin
MODEL=RealESRGAN_General_WDN_x4_v3
# can use any model from upscayl-bin-20240601-103425-linux/models

# Number of parallel processes (adjust based on your GPU and system)
# For RTX 3090 24GB: 2-4 parallel processes work well
# Higher values may cause GPU memory issues
PARALLEL_JOBS=${2:-3}  # Default to 3 parallel jobs, can be overridden as second argument

INPUT=$1
if [ -z "$INPUT" ]; then
    echo "Usage: $0 <input_video_file> [parallel_jobs]"
    echo "  parallel_jobs: Number of parallel upscayl processes (default: 3, recommended: 2-4 for RTX 3090)"
    exit 1
fi

if [ ! -f "$INPUT" ]; then
    echo "Error: Input file '$INPUT' not found"
    exit 1
fi

BASE=$(basename "$INPUT" | cut -d. -f1)

# Get video information
echo "Analyzing video file..."
VIDEO_INFO=$(ffprobe -v error -select_streams v:0 -show_entries stream=width,height,r_frame_rate,duration -of default=noprint_wrappers=1:nokey=1 "$INPUT")
WIDTH=$(echo "$VIDEO_INFO" | head -n1)
HEIGHT=$(echo "$VIDEO_INFO" | head -n2 | tail -n1)
FR_RAW=$(echo "$VIDEO_INFO" | head -n3 | tail -n1)
DURATION=$(echo "$VIDEO_INFO" | tail -n1)

# Calculate frame rate
FR=$(echo "$FR_RAW" | awk -F'/' '{if ($2 != 0 && $2 != "") print $1/$2; else print 0}')
if [ -z "$FR" ] || [ "$FR" = "0" ] || [ "$(echo "$FR" | awk '{if ($1 < 1) print 1; else print 0}')" = "1" ]; then
    echo "Warning: Could not detect frame rate, using default 24 fps"
    FR=24
fi

# Round frame rate to 2 decimal places
FR=$(echo "$FR" | awk '{printf "%.2f", $1}')

# Calculate total frames
TOTAL_FRAMES=$(echo "$DURATION $FR" | awk '{printf "%.0f", $1 * $2}')

# Estimate processing time with parallel processing
# RTX 3090: ~0.2-0.4 seconds per frame (with parallel processing, divide by parallel jobs)
EST_SEC_PER_FRAME=0.3
EST_UPScale_TIME=$(echo "$TOTAL_FRAMES $EST_SEC_PER_FRAME $PARALLEL_JOBS" | awk '{printf "%.0f", ($1 * $2) / $3}')
EST_EXTRACT_TIME=30
EST_ENCODE_TIME=180
EST_TOTAL_TIME=$((EST_UPScale_TIME + EST_EXTRACT_TIME + EST_ENCODE_TIME))
EST_HOURS=$((EST_TOTAL_TIME / 3600))
EST_MINS=$(((EST_TOTAL_TIME % 3600) / 60))
EST_SECS=$((EST_TOTAL_TIME % 60))
EST_UPScale_MINS=$((EST_UPScale_TIME / 60))
EST_UPScale_SECS=$((EST_UPScale_TIME % 60))
EST_ENCODE_MINS=$((EST_ENCODE_TIME / 60))
EST_ENCODE_SECS=$((EST_ENCODE_TIME % 60))

echo "=========================================="
echo "Video Information:"
echo "  Resolution: ${WIDTH}x${HEIGHT}"
echo "  Frame Rate: ${FR} fps"
echo "  Duration: ${DURATION} seconds (~$(echo "$DURATION" | awk '{printf "%.1f", $1/60}') minutes)"
echo "  Total Frames: ${TOTAL_FRAMES}"
echo ""
echo "Parallel Processing Configuration:"
echo "  Parallel Jobs: ${PARALLEL_JOBS}"
echo "  Frames per batch: ~$((TOTAL_FRAMES / PARALLEL_JOBS))"
echo ""
echo "Estimated Processing Time (with parallel processing):"
if [ $EST_HOURS -gt 0 ]; then
    echo "  ~${EST_HOURS}h ${EST_MINS}m ${EST_SECS}s"
else
    echo "  ~${EST_MINS}m ${EST_SECS}s"
fi

echo "  (Frame extraction: ~${EST_EXTRACT_TIME}s)"
if [ $EST_UPScale_MINS -gt 0 ]; then
    echo "  (Upscaling: ~${EST_UPScale_MINS}m ${EST_UPScale_SECS}s - with ${PARALLEL_JOBS} parallel jobs)"
else
    echo "  (Upscaling: ~${EST_UPScale_SECS}s - with ${PARALLEL_JOBS} parallel jobs)"
fi
if [ $EST_ENCODE_MINS -gt 0 ]; then
    echo "  (Video encoding: ~${EST_ENCODE_MINS}m ${EST_ENCODE_SECS}s)"
else
    echo "  (Video encoding: ~${EST_ENCODE_SECS}s)"
fi
echo "=========================================="
echo ""

# Optimize thread count for each parallel process
# Lower thread count per process since we're running multiple processes
CPU_CORES=$(nproc)
LOAD_THREADS=2
PROC_THREADS=2  # Reduced per process since multiple processes share GPU
SAVE_THREADS=2
THREAD_CONFIG="${LOAD_THREADS}:${PROC_THREADS}:${SAVE_THREADS}"

echo "Using parallel batch processing:"
echo "  ${PARALLEL_JOBS} parallel upscayl processes"
echo "  Thread config per process: ${THREAD_CONFIG}"
echo ""

# Use custom temp directory if specified, otherwise use /tmp
# Set UPSCAYL_TEMP environment variable to use a directory with more space
TEMP_BASE=${UPSCAYL_TEMP:-/tmp}
TD=$(mktemp -d ${TEMP_BASE}/upscayl_parallel_XXX)
trap "rm -rf $TD" EXIT  # Cleanup on exit

if [ "$TEMP_BASE" != "/tmp" ]; then
    echo "Using custom temp directory: $TEMP_BASE"
fi

mkdir -p $TD/frames
mkdir -p $TD/upscaled

# Create batch directories
for i in $(seq 1 $PARALLEL_JOBS); do
    mkdir -p "$TD/batch_${i}_frames"
    mkdir -p "$TD/batch_${i}_upscaled"
done

START_TIME=$(date +%s)
echo "[$(date +%H:%M:%S)] Extracting frames from $INPUT..."
# Handle QuickTime/MOV files that may have codec compatibility issues
# Strategy: Decode with error resilience, suppress noisy warnings but keep real errors
# -err_detect ignore_err: ignore decoding errors and continue
# -fflags +genpts+igndts: generate PTS if missing, ignore DTS issues  
# -vsync 0: disable frame synchronization to handle timing issues
# -c:v copy then decode: try direct decode first, fallback to re-encode if needed
ffmpeg -err_detect ignore_err -fflags +genpts+igndts+discardcorrupt -vsync 0 -i "$INPUT" -r $FR "$TD/frames/%08d.png" -y -hide_banner -loglevel warning 2>&1 | grep -vE "(error while decoding|Missing reference|top block unavailable|Reference.*>=|reference count overflow|decode_slice_header|no frame|mmco:|reference picture missing)" | grep -E "(Error|error|Failed|failed)" && {
    echo "Warning: Some decoding errors occurred, but continuing..."
} || true

# Check if frames were actually extracted
FRAME_COUNT=$(ls -1 "$TD/frames"/*.png 2>/dev/null | wc -l)
if [ $FRAME_COUNT -eq 0 ]; then
    echo "Error: No frames were extracted. The video may be too corrupted or incompatible."
    exit 1
fi
EXTRACT_TIME=$(($(date +%s) - START_TIME))
# FRAME_COUNT already calculated above, reuse it
echo "[$(date +%H:%M:%S)] Extracted ${FRAME_COUNT} frames in ${EXTRACT_TIME}s"

# Split frames into batches
echo "[$(date +%H:%M:%S)] Splitting ${FRAME_COUNT} frames into ${PARALLEL_JOBS} batches..."
FRAMES_PER_BATCH=$((FRAME_COUNT / PARALLEL_JOBS))
REMAINING_FRAMES=$((FRAME_COUNT % PARALLEL_JOBS))

FRAME_INDEX=1
for i in $(seq 1 $PARALLEL_JOBS); do
    # Calculate batch size (distribute remaining frames across first batches)
    BATCH_SIZE=$FRAMES_PER_BATCH
    if [ $i -le $REMAINING_FRAMES ]; then
        BATCH_SIZE=$((BATCH_SIZE + 1))
    fi
    
    BATCH_DIR="$TD/batch_${i}_frames"
    COUNT=0
    
    # Copy frames to batch directory with sequential numbering
    while [ $COUNT -lt $BATCH_SIZE ] && [ $FRAME_INDEX -le $FRAME_COUNT ]; do
        FRAME_FILE=$(printf "$TD/frames/%08d.png" $FRAME_INDEX)
        if [ -f "$FRAME_FILE" ]; then
            cp "$FRAME_FILE" "$BATCH_DIR/$(printf "%08d.png" $((COUNT + 1)))"
            COUNT=$((COUNT + 1))
        fi
        FRAME_INDEX=$((FRAME_INDEX + 1))
    done
    
    echo "  Batch $i: $COUNT frames"
done

# Process all batches in parallel
echo "[$(date +%H:%M:%S)] Starting parallel upscaling with ${PARALLEL_JOBS} processes..."
UPSCALE_START=$(date +%s)

# Run batches in parallel using background jobs
PIDS=()
for i in $(seq 1 $PARALLEL_JOBS); do
    BATCH_FRAMES_DIR="$TD/batch_${i}_frames"
    BATCH_OUTPUT_DIR="$TD/batch_${i}_upscaled"
    
    (
        echo "[$(date +%H:%M:%S)] Starting batch $i..."
        $UPSCAYL -i "$BATCH_FRAMES_DIR" -o "$BATCH_OUTPUT_DIR" -n "$MODEL" -j "$THREAD_CONFIG" -v || {
            echo "Error: Failed to upscale batch $i"
            exit 1
        }
        echo "[$(date +%H:%M:%S)] Completed batch $i"
    ) &
    PIDS+=($!)
done

# Wait for all background jobs to complete
FAILED=0
for i in "${!PIDS[@]}"; do
    PID=${PIDS[$i]}
    BATCH_NUM=$((i + 1))
    if ! wait $PID; then
        FAILED=1
        echo "Error: Batch $BATCH_NUM failed"
    fi
done

if [ $FAILED -eq 1 ]; then
    echo "Error: Parallel processing failed"
    exit 1
fi

UPSCALE_TIME=$(($(date +%s) - UPSCALE_START))
echo "[$(date +%H:%M:%S)] All batches completed in ${UPSCALE_TIME}s"

# Create hard links instead of symlinks (avoids filesystem issues, uses same inode = no extra space)
echo "[$(date +%H:%M:%S)] Creating hard links to upscaled frames in correct order..."
FRAME_INDEX=1
for i in $(seq 1 $PARALLEL_JOBS); do
    BATCH_DIR="$TD/batch_${i}_upscaled"
    BATCH_FRAME_COUNT=$(ls -1 "$BATCH_DIR"/*.png 2>/dev/null | wc -l)
    
    for j in $(seq 1 $BATCH_FRAME_COUNT); do
        SOURCE_FILE=$(printf "$BATCH_DIR/%08d.png" $j)
        if [ -f "$SOURCE_FILE" ]; then
            DEST_FILE=$(printf "$TD/upscaled/%08d.png" $FRAME_INDEX)
            # Use hard link instead of symlink - same inode, no extra space, more reliable
            ln "$SOURCE_FILE" "$DEST_FILE" 2>/dev/null || {
                # Fallback: if hard link fails (different filesystem), try copy
                echo "Warning: Hard link failed, using copy instead"
                cp "$SOURCE_FILE" "$DEST_FILE"
            }
            FRAME_INDEX=$((FRAME_INDEX + 1))
        fi
    done
done

UPScaled_COUNT=$(ls -1 "$TD/upscaled"/*.png 2>/dev/null | wc -l)
echo "[$(date +%H:%M:%S)] Linked ${UPScaled_COUNT} upscaled frames"

echo "[$(date +%H:%M:%S)] Extracting audio from original video..."
ffmpeg -i "$INPUT" -vn -acodec copy "$TD/audio.aac" -y -hide_banner -loglevel error 2>/dev/null || {
    echo "  (No audio track found or could not extract audio)"
    HAS_AUDIO=0
}
HAS_AUDIO=${HAS_AUDIO:-1}

echo "[$(date +%H:%M:%S)] Creating output video ${BASE}_upscaled.mkv..."
ENCODE_START=$(date +%s)
if [ $HAS_AUDIO -eq 1 ] && [ -f "$TD/audio.aac" ]; then
    # Create video with audio
    ffmpeg -framerate $FR -i "$TD/upscaled/%08d.png" -i "$TD/audio.aac" -r $FR -vf format=yuv420p -c:v libx264 -c:a aac -shortest "${BASE}_upscaled.mkv" -y -hide_banner -loglevel error || {
        echo "Error: Failed to create output video with audio"
        exit 1
    }
    echo "  (Audio preserved)"
else
    # Create video without audio
    ffmpeg -framerate $FR -i "$TD/upscaled/%08d.png" -r $FR -vf format=yuv420p -c:v libx264 "${BASE}_upscaled.mkv" -y -hide_banner -loglevel error || {
        echo "Error: Failed to create output video"
        exit 1
    }
    echo "  (No audio in original video)"
fi
ENCODE_TIME=$(($(date +%s) - ENCODE_START))
TOTAL_TIME=$(($(date +%s) - START_TIME))

echo ""
echo "=========================================="
echo "Processing Complete!"
echo "  Total time: ${TOTAL_TIME}s (~$((TOTAL_TIME / 60))m $((TOTAL_TIME % 60))s)"
echo "  Frame extraction: ${EXTRACT_TIME}s"
echo "  Upscaling (${PARALLEL_JOBS} parallel jobs): ${UPSCALE_TIME}s"
echo "  Video encoding: ${ENCODE_TIME}s"
echo "  Output: ${BASE}_upscaled.mkv"
echo ""
if [ $UPSCALE_TIME -gt 0 ]; then
    ESTIMATED_SEQUENTIAL=$((TOTAL_FRAMES * 3 / 10))  # 0.3 seconds per frame
    SPEEDUP=$((ESTIMATED_SEQUENTIAL / UPSCALE_TIME))
    if [ $SPEEDUP -gt 0 ]; then
        echo "  Estimated speedup: ~${SPEEDUP}x faster than sequential processing"
    fi
fi
echo "=========================================="

