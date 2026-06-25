import os
import time
import socket
import json
import argparse
from PIL import Image, ImageDraw, ImageFont

FB_PATH = "/dev/fb0"
WIDTH = 160
HEIGHT = 60

def get_ip_address():
    try:
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

def draw_screen(config):
    # Create a new image in RGB mode
    img = Image.new("RGB", (WIDTH, HEIGHT), "black")
    draw = ImageDraw.Draw(img)

    try:
        font = ImageFont.load_default()
    except Exception:
        font = None

    enabled = config.get("enabled_metrics", ["hostname", "ip", "cpu_temp", "load", "uptime"])

    # Draw Title/Hostname
    if "hostname" in enabled:
        title = socket.gethostname().upper()
    else:
        title = "NIXOS"
    draw.text((5, 2), title, fill="white", font=font)
    draw.line((5, 15, 155, 15), fill="white")

    # Draw IP Address
    if "ip" in enabled:
        ip = get_ip_address()
        draw.text((5, 18), f"IP: {ip}", fill="white", font=font)

    # Draw Temp & Load
    temp_str = ""
    if "cpu_temp" in enabled:
        temp_str = f"Temp: {get_cpu_temp()}"
    draw.text((5, 32), temp_str, fill="white", font=font)

    load_str = ""
    if "load" in enabled:
        load_str = get_load()
    draw.text((95, 32), load_str, fill="white", font=font)

    # Draw Uptime
    if "uptime" in enabled:
        uptime = get_uptime()
        draw.text((5, 46), uptime, fill="white", font=font)

    # Convert to RGB565 (Little Endian)
    pixels = img.getdata()
    out_bytes = bytearray()
    for r, g, b in pixels:
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
    parser = argparse.ArgumentParser(description="CloudKey OLED Screen Manager")
    parser.add_argument("--config", type=str, help="Path to config JSON file")
    args = parser.parse_args()

    config = {}
    if args.config and os.path.exists(args.config):
        try:
            with open(args.config, "r") as f:
                config = json.load(f)
            print(f"Loaded configuration from {args.config}")
        except Exception as e:
            print(f"Failed to load configuration: {e}")

    poll_interval = config.get("poll_interval", 60) # default to 60s as requested
    print(f"OLED Manager started. Interval: {poll_interval}s")

    while True:
        draw_screen(config)
        time.sleep(poll_interval)

if __name__ == "__main__":
    main()
