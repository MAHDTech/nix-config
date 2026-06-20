# CloudKey Gen2 Plus Recovery & Flashing

This document outlines a massive breakthrough found during development: the UniFi CloudKey Gen2 Web
Recovery environment runs an unauthenticated `telnetd` instance as `root`, which can be used to
bypass all RSA signature checks and capture early kernel panics.

## Bypassing WebUI RSA Signatures

The WebUI firmware updater (`/api/fwupdate`) uses `ubnt-tools` to validate the RSA-2048 signature of uploaded `.bin` firmware against Ubiquiti's embedded CloudKey CA.

However, since `telnetd` gives us root access, we can push an unsigned raw `boot.img` over the
network and write it directly to the eMMC block device (`/dev/mmcblk0p42`), completely bypassing
the WebUI and signature checks.

### Flashing Procedure

1. **Boot into Recovery Mode:** Power off the CloudKey, hold the reset button with a paperclip, and power it on. Hold until the LED flashes white/blue.
2. **Start a Python Web Server on JONS:** To ensure the 30.5MB image doesn't get corrupted or truncated during transfer, we serve it over HTTP.
   In a terminal on JONS, run:
   ```bash
   cd /boot/nixos/nix-config
   python3 -m http.server 16000
   ```
   _(Ensure port 16000 is open in your JONS firewall!)_
3. **Pull the `boot.img` via Telnet:**
   Telnet into the CloudKey as root and download the image directly to `/tmp`:
   ```bash
   telnet <CLOUDKEY_IP>
   # Once logged in as root:
   cd /tmp
   wget http://<JONS_IP>:16000/result/boot.img
   dd if=boot.img of=/dev/mmcblk0p42 bs=4096
   ```
4. **Reboot:**
   Once the transfer completes, return to the Telnet shell and reboot:
   ```bash
   sync
   reboot -f
   ```

## Capturing RAMOOPS (Kernel Panics)

The Web Recovery Kernel is stripped down and does **not** have the `pstore` driver enabled. This means you cannot mount `/sys/fs/pstore` to read crash logs from a previous failed mainline boot.

However, the RAMOOPS data is preserved across warm reboots in a hardcoded physical memory block
(`0x92000000` to `0x92200000`). We can read this physical memory directly using `/dev/mem` in the
telnet shell, and send it back to JONS for decompression!

### Extraction Procedure

1. **Dump RAMOOPS to a file on the CloudKey:**

   ```bash
   dd if=/dev/mem of=/tmp/ramdump.bin bs=4096 count=512 skip=598016
   ```

   _(598016 blocks _ 4096 bytes = 0x92000000 offset).\*

2. **Start a Netcat listener on JONS:**

   ```bash
   nc -l 16000 > /tmp/ramdump.bin
   ```

3. **Send the dump from the CloudKey:**

   ```bash
   nc <JONS_IP> 16000 < /tmp/ramdump.bin
   ```

4. **Decompress the log on JONS:**
   The `pstore` logs are zlib/deflate compressed (indicated by the `====<timestamp>-C` header). Use a python script to extract and decompress them:

   ```python
   import zlib
   import re

   with open("/tmp/ramdump.bin", "rb") as f:
       data = f.read()

   pattern = re.compile(br'====(\d+\.\d+)-([A-Z])\n')
   matches = list(pattern.finditer(data))

   for i, match in enumerate(matches):
       start = match.end()
       end = matches[i+1].start() if i + 1 < len(matches) else len(data)
       record_data = data[start:end]

       if match.group(2).decode() == 'C':
           try:
               uncompressed = zlib.decompress(record_data, -15) # Raw deflate
               print(uncompressed.decode('utf-8', errors='replace'))
           except Exception:
               pass
   ```
