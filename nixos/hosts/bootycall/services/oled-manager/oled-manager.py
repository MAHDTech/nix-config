import os
import time
import socket
from PIL import Image, ImageDraw, ImageFont

# Path to framebuffer
FB_PATH = "/dev/fb0"
WIDTH = 160
HEIGHT = 60

def get_ip_address():
    try:
        # Create a dummy socket to find local IP address
        s = socket.socket(socket.AF_INET, socket.SOCK_DGRAM)
        s.connect(("1.1.1.1", 80))
        ip = s.getsockname()[0]
        s.close()
        return ip
    except Exception:
        return "No IP"

def get_cpu_temp():
    try:
        # Check standard thermal zones
        for zone in ['thermal_zone0', 'thermal_zone1']:
            path = f"/sys/class/thermal/{zone}/temp"
            if os.path.exists(path):
                with open(path, "r") as f:
                    temp_milli = int(f.read().strip())
                    return f"{temp_milli / 1000.0:.1f}°C"
        return "N/A"
    except Exception:
        return "N/A"

def get_load():
    try:
        with open("/proc/loadavg", "r") as f:
            load = f.read().split()[0]
            return f"Load: {load}"
    except Exception:
        return "Load: N/A"

def get_uptime():
    try:
        with open("/proc/uptime", "r") as f:
            uptime_seconds = float(f.read().split()[0])
            hours = int(uptime_seconds // 3600)
            minutes = int((uptime_seconds % 3600) // 60)
            return f"Up: {hours}h {minutes}m"
    except Exception:
        return "Up: N/A"

def draw_screen():
    # Create a new image in RGB mode
    img = Image.new("RGB", (WIDTH, HEIGHT), "black")
    draw = ImageDraw.Draw(img)

    # Use default font or fallback font
    try:
        font = ImageFont.load_default()
    except Exception:
        font = None

    # Gather system info
    ip = get_ip_address()
    temp = get_cpu_temp()
    load = get_load()
    uptime = get_uptime()

    # Draw layout
    draw.text((5, 2), "NixOS BootyCall", fill="white", font=font)
    draw.line((5, 15, 155, 15), fill="white")
    draw.text((5, 18), f"IP: {ip}", fill="white", font=font)
    draw.text((5, 32), f"Temp: {temp}", fill="white", font=font)
    draw.text((95, 32), load, fill="white", font=font)
    draw.text((5, 46), uptime, fill="white", font=font)

    # Convert to RGB565 (Little Endian)
    pixels = img.getdata()
    out_bytes = bytearray()
    for r, g, b in pixels:
        # Pack to 16-bit: r (5 bits), g (6 bits), b (5 bits)
        val = ((r & 0xF8) << 8) | ((g & 0xFC) << 3) | (b >> 3)
        out_bytes.append(val & 0xFF)
        out_bytes.append((val >> 8) & 0xFF)

    # Write to framebuffer
    try:
        with open(FB_PATH, "wb") as f:
            f.write(out_bytes)
    except Exception as e:
        print(f"Failed to write to framebuffer: {e}")

def main():
    print("OLED Manager started.")
    while True:
        draw_screen()
        time.sleep(3)

if __name__ == "__main__":
    main()
