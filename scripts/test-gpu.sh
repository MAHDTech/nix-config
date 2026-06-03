#!/usr/bin/env bash
# GPU burn-in and acceleration test script for Zenbook and Orion

# Set default test duration (seconds)
DURATION=${1:-30}

echo "=========================================="
echo "Starting GPU Acceleration & Benchmark Test"
echo "Target Duration per test: ${DURATION}s"
echo "=========================================="

# Check if we have a display available
if [ -z "$DISPLAY" ] && [ -z "$WAYLAND_DISPLAY" ]; then
    echo "WARNING: Neither DISPLAY nor WAYLAND_DISPLAY is set."
    echo "Please ensure you run this script inside a graphical session (X11 or Wayland)."
    exit 1
fi

echo "Launching nix-shell with glxgears (mesa-demos), vkmark, and glmark2..."

nix-shell -p mesa-demos vkmark glmark2 --run "
  echo ''
  echo '------------------------------------------'
  echo '1. Testing OpenGL with glxgears (vblank off)...'
  echo '------------------------------------------'
  vblank_mode=0 timeout ${DURATION}s glxgears
  
  echo ''
  echo '------------------------------------------'
  echo '2. Testing Vulkan with vkmark (immediate present)...'
  echo '------------------------------------------'
  MESA_VK_WSI_PRESENT_MODE=immediate timeout ${DURATION}s vkmark
  
  echo ''
  echo '------------------------------------------'
  echo '3. Testing OpenGL ES / WebGL with glmark2 (vblank off)...'
  echo '------------------------------------------'
  vblank_mode=0 timeout ${DURATION}s glmark2
"

echo "=========================================="
echo "GPU Benchmark Tests Completed."
echo "=========================================="
