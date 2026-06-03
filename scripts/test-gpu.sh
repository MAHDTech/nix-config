#!/usr/bin/env bash
# GPU burn-in and acceleration test script for Zenbook and Orion

# Set default test duration (seconds)
DURATION=${1:-30}
# Set custom resolution (optional, e.g., 1920x1080)
USER_RES=${2}

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

echo "Launching nix-shell with glxgears (mesa-demos), vkmark, glmark2, and xrandr..."

nix-shell -p mesa-demos vkmark glmark2 xrandr --run "
  # Determine resolution to use
  if [ -n \"$USER_RES\" ]; then
      RESOLUTION=\"$USER_RES\"
      echo \"Using user-specified resolution: \$RESOLUTION\"
  else
      # Try to detect active monitor resolution
      RESOLUTION=\$(xrandr 2>/dev/null | grep -E ' connected' | grep -o -E '[0-9]+x[0-9]+' | head -n1)
      if [ -z \"\$RESOLUTION\" ]; then
          RESOLUTION=\"1920x1080\"
          echo \"Could not auto-detect resolution via xrandr. Falling back to default: \$RESOLUTION\"
      else
          echo \"Auto-detected screen resolution: \$RESOLUTION\"
      fi
  fi

  echo ''
  echo '------------------------------------------'
  echo '1. Testing OpenGL with glxgears (vblank off, fullscreen @ '\$RESOLUTION')...'
  echo '------------------------------------------'
  # Run in fullscreen; pass geometry as fallback
  vblank_mode=0 timeout ${DURATION}s glxgears -fullscreen -geometry \"\$RESOLUTION\"
  
  echo ''
  echo '------------------------------------------'
  echo '2. Testing Vulkan with vkmark (immediate present, fullscreen @ '\$RESOLUTION')...'
  echo '------------------------------------------'
  MESA_VK_WSI_PRESENT_MODE=immediate timeout ${DURATION}s vkmark --fullscreen --size \"\$RESOLUTION\"
  
  echo ''
  echo '------------------------------------------'
  echo '3. Testing OpenGL ES / WebGL with glmark2 (vblank off, fullscreen @ '\$RESOLUTION')...'
  echo '------------------------------------------'
  vblank_mode=0 timeout ${DURATION}s glmark2 --fullscreen --size \"\$RESOLUTION\"
"

echo "=========================================="
echo "GPU Benchmark Tests Completed."
echo "=========================================="
