# cspell:ignore abspath ancdata ARGB argparse busctl caffiene CMSG cmsg DEVNULL EAGAIN EINTR execvpe expanduser ftruncate getpid getuid inhib Katakana lsurf memfd mmap nonlocal pkill Popen randint randrange recvmsg respawn SCM_RIGHTS sendall sendmsg SOL_SOCKET Subprocess UnInhibit uninhibit viewporter xrgb zwlr zwp
{
  config,
  pkgs,
  ...
}:
let
  scriptName = "dont-sleep";
  scriptPath = "${config.home.homeDirectory}/.local/bin/${scriptName}";
in
{
  home = {
    file = {
      ${scriptName} = {
        target = ".local/bin/${scriptName}";
        executable = true;

        text = ''
          #!${pkgs.python3}/bin/python3
          """
          dont-sleep: Burn-in-safe Wayland layer-shell screensaver & multi-layer idle inhibitor.

          Holds kernel-FD-scoped locks while active so AI agents can run uninterrupted
          without 1Password or the COSMIC session locking (and auto-releases even on SIGKILL):
            1. systemd-inhibit (idle:sleep:handle-lid-switch) -> blocks OS suspend/sleep
            2. zwp_idle_inhibitor_v1 (Wayland layer surface)  -> pauses cosmic-comp ext_idle_notifier_v1,
              blocking both cosmic-idle (lock-session + DPMS) and 1Password's 60m Wayland idle lock
          """

          import argparse
          import mmap
          import os
          import random
          import select
          import signal
          import socket
          import struct
          import subprocess
          import sys
          import time


          def run_status() -> int:
              print("=== systemd-inhibit locks ===")
              subprocess.run(["systemd-inhibit", "--list"], check=False)

              print("\n=== cosmic-idle process & config ===")
              subprocess.run(["pgrep", "-af", "cosmic-idle"], check=False)
              cfg_dir = os.path.expanduser("~/.config/cosmic/com.system76.CosmicIdle/v1")
              for key in ("screen_off_time", "suspend_on_ac_time", "suspend_on_battery_time"):
                  p = os.path.join(cfg_dir, key)
                  val = open(p).read().strip() if os.path.exists(p) else "<unset>"
                  print(f"  {key}: {val}")

              try:
                  out = subprocess.check_output(
                      [
                          "busctl",
                          "--user",
                          "call",
                          "org.freedesktop.ScreenSaver",
                          "/org/freedesktop/ScreenSaver",
                          "org.freedesktop.ScreenSaver",
                          "Inhibit",
                          "ss",
                          "dont-sleep-probe",
                          "status-check",
                      ],
                      text=True,
                  )
                  cookie = int(out.split()[1])
                  subprocess.run(
                      [
                          "busctl",
                          "--user",
                          "call",
                          "org.freedesktop.ScreenSaver",
                          "/org/freedesktop/ScreenSaver",
                          "org.freedesktop.ScreenSaver",
                          "UnInhibit",
                          "u",
                          str(cookie),
                      ],
                      check=False,
                      stdout=subprocess.DEVNULL,
                      stderr=subprocess.DEVNULL,
                  )
                  print(f"  ScreenSaver cookies issued since cosmic-idle start: {cookie - 1}")
              except Exception as exc:
                  print(f"  ScreenSaver D-Bus check failed: {exc}")

              return 0


          def run_reset_idle() -> int:
              print("Restarting cosmic-idle (cosmic-session will respawn it with clean inhibitor state)...")
              subprocess.run(["pkill", "-TERM", "-x", "cosmic-idle"], check=False)
              time.sleep(0.5)
              subprocess.run(["pgrep", "-af", "cosmic-idle"], check=False)
              return run_status()


          def ensure_systemd_inhibit() -> None:
              if os.environ.get("DONT_SLEEP_INHIBITED") == "1":
                  return
              env = os.environ.copy()
              env["DONT_SLEEP_INHIBITED"] = "1"
              cmd = [
                  "systemd-inhibit",
                  "--what=idle:sleep:handle-lid-switch",
                  "--mode=block",
                  "--who=dont-sleep",
                  "--why=Keeping session and 1Password unlocked for AI agents",
                  "--",
                  sys.executable,
                  os.path.abspath(__file__),
                  *sys.argv[1:],
              ]
              os.execvpe("systemd-inhibit", cmd, env)


          def build_glyphs() -> list[list[bytes]]:
              """Pre-render 64 8x10 bitmap glyphs across 6 green brightness levels."""
              palette = [
                  (0, 0, 0),
                  (0, 55, 15),
                  (0, 105, 30),
                  (0, 165, 45),
                  (0, 235, 65),
                  (210, 255, 220),
              ]
              rng = random.Random(1337)
              patterns = []
              for _ in range(64):
                  rows = [0]
                  for _r in range(8):
                      # Symmetric/katakana-like 6-bit inner pattern in an 8-px cell
                      bits = rng.randint(1, 62) << 1
                      rows.append(bits)
                  rows.append(0)
                  patterns.append(rows)

              # glyphs[level][glyph_idx] -> list of 10 row byte-slices (each 32 bytes for 8 XRGB8888 pixels)
              glyphs: list[list[list[bytes]]] = []
              for r, g, b in palette:
                  fg = struct.pack("<I", (r << 16) | (g << 8) | b)
                  bg = b"\x00\x00\x00\x00"
                  level_glyphs = []
                  for pat in patterns:
                      row_bytes = []
                      for bits in pat:
                          rb = b"".join(fg if (bits & (1 << (7 - bit))) else bg for bit in range(8))
                          row_bytes.append(rb)
                      level_glyphs.append(row_bytes)
                  glyphs.append(level_glyphs)
              return glyphs


          class MatrixAnimator:
              def __init__(self, width: int, height: int, glyphs: list[list[list[bytes]]]) -> None:
                  self.w = width
                  self.h = height
                  self.cols = width // 8
                  self.rows = height // 10
                  self.glyphs = glyphs
                  self.heads = [random.randint(-self.rows, 0) for _ in range(self.cols)]
                  self.Base_lengths = [random.randint(6, 16) for _ in range(self.cols)]
                  self.speeds = [random.choice((1, 1, 2)) for _ in range(self.cols)]
                  self.grid_glyph = [[random.randrange(64) for _ in range(self.rows)] for _ in range(self.cols)]
                  self.tick = 0

              def step(self, mm: mmap.mmap) -> None:
                  self.tick += 1
                  stride = self.w * 4
                  for c in range(self.cols):
                      if self.tick % self.speeds[c] != 0:
                          continue
                      head = self.heads[c] + 1
                      length = self.Base_lengths[c]
                      if head - length > self.rows:
                          head = random.randint(-10, -1)
                          self.Base_lengths[c] = random.randint(6, 16)
                          self.speeds[c] = random.choice((1, 1, 2))
                      self.heads[c] = head
                      if 0 <= head < self.rows:
                          self.grid_glyph[c][head] = random.randrange(64)

                      # Update head, trail steps, and tail clear
                      offsets = [
                          (head, 5),
                          (head - 1, 4),
                          (head - 2, 3),
                          (head - max(3, length // 2), 2),
                          (head - max(4, (length * 3) // 4), 1),
                          (head - length, 0),
                      ]
                      x_byte = c * 32
                      for r_idx, lvl in offsets:
                          if 0 <= r_idx < self.rows:
                              g_rows = self.glyphs[lvl][self.grid_glyph[c][r_idx]]
                              base_y = r_idx * 10
                              for dy in range(10):
                                  pos = (base_y + dy) * stride + x_byte
                                  mm[pos : pos + 32] = g_rows[dy]


          class StarfieldAnimator:
              def __init__(self, width: int, height: int) -> None:
                  self.w = width
                  self.h = height
                  self.stars = [self._new_star() for _ in range(260)]
                  self.prev_px: list[tuple[int, int]] = []

              def _new_star(self) -> list[float]:
                  return [
                      random.uniform(-self.w, self.w),
                      random.uniform(-self.h, self.h),
                      random.uniform(10.0, float(self.w)),
                  ]

              def step(self, mm: mmap.mmap) -> None:
                  stride = self.w * 4
                  zero = b"\x00\x00\x00\x00"
                  for px, py in self.prev_px:
                      pos = py * stride + px * 4
                      mm[pos : pos + 4] = zero
                      if px + 1 < self.w:
                          mm[pos + 4 : pos + 8] = zero
                  self.prev_px.clear()

                  cx, cy = self.w // 2, self.h // 2
                  for st in self.stars:
                      st[2] -= 6.0
                      if st[2] <= 2.0:
                          st[:] = self._new_star()
                          st[2] = float(self.w)
                      sx = int(cx + (st[0] * 120.0) / st[2])
                      sy = int(cy + (st[1] * 120.0) / st[2])
                      if 0 <= sx < self.w and 0 <= sy < self.h:
                          shade = max(40, min(255, int(255.0 * (1.0 - st[2] / float(self.w)))))
                          px_bytes = struct.pack("<I", (shade << 16) | (shade << 8) | min(255, shade + 20))
                          pos = sy * stride + sx * 4
                          mm[pos : pos + 4] = px_bytes
                          if st[2] < self.w * 0.4 and sx + 1 < self.w:
                              mm[pos + 4 : pos + 8] = px_bytes
                          self.prev_px.append((sx, sy))


          class PipesAnimator:
              COLORS = [
                  (0, 240, 255),
                  (255, 0, 170),
                  (0, 255, 85),
                  (255, 180, 0),
                  (130, 90, 255),
              ]

              def __init__(self, width: int, height: int) -> None:
                  self.w = width
                  self.h = height
                  self.gw = width // 8
                  self.gh = height // 8
                  self.pipes = [self._new_pipe() for _ in range(4)]
                  self.steps = 0

              def _new_pipe(self) -> list[int]:
                  return [
                      random.randrange(self.gw),
                      random.randrange(self.gh),
                      random.randrange(4),
                      random.randrange(len(self.COLORS)),
                  ]

              def step(self, mm: mmap.mmap) -> None:
                  self.steps += 1
                  stride = self.w * 4
                  if self.steps >= 550:
                      mm[:] = b"\x00" * (self.w * self.h * 4)
                      self.steps = 0
                      return

                  dirs = ((1, 0), (0, 1), (-1, 0), (0, -1))
                  for p in self.pipes:
                      if random.random() < 0.25:
                          p[2] = (p[2] + random.choice((-1, 1))) % 4
                      dx, dy = dirs[p[2]]
                      nx, ny = p[0] + dx, p[1] + dy
                      if not (0 <= nx < self.gw and 0 <= ny < self.gh):
                          p[:] = self._new_pipe()
                          continue
                      p[0], p[1] = nx, ny
                      r, g, b = self.COLORS[p[3]]
                      core = struct.pack("<I", (r << 16) | (g << 8) | b)
                      edge = struct.pack("<I", ((r // 2) << 16) | ((g // 2) << 8) | (b // 2))
                      row_slice = edge + core * 4 + edge
                      bx = nx * 8 + 1
                      by = ny * 8 + 1
                      for ry in range(6):
                          pos = (by + ry) * stride + bx * 4
                          mm[pos : pos + 24] = row_slice


          def run_wayland_screensaver(style: str, headless: bool, grace: float) -> int:
              runtime_dir = os.environ.get("XDG_RUNTIME_DIR", f"/run/user/{os.getuid()}")
              wl_display = os.environ.get("WAYLAND_DISPLAY", "wayland-1")
              sock_path = os.path.join(runtime_dir, wl_display)

              s = socket.socket(socket.AF_UNIX, socket.SOCK_STREAM)
              s.connect(sock_path)

              def send_msg(obj_id: int, opcode: int, payload: bytes = b"", fds: list[int] | None = None) -> None:
                  size = 8 + len(payload)
                  msg = struct.pack("<II", obj_id, (size << 16) | opcode) + payload
                  if fds:
                      s.sendmsg([msg], [(socket.SOL_SOCKET, socket.SCM_RIGHTS, struct.pack(f"<{len(fds)}i", *fds))])
                  else:
                      s.sendall(msg)

              def pack_str(st: str) -> bytes:
                  b = st.encode("utf-8") + b"\x00"
                  pad = (4 - (len(b) % 4)) % 4
                  return struct.pack("<I", len(b)) + b + (b"\x00" * pad)

              next_id = 2

              def alloc_id() -> int:
                  nonlocal next_id
                  i = next_id
                  next_id += 1
                  return i

              def drain_ancillary(ancdata: list[tuple[int, int, bytes]]) -> None:
                  for cmsg_level, cmsg_type, cmsg_data in ancdata:
                      if cmsg_level == socket.SOL_SOCKET and cmsg_type == socket.SCM_RIGHTS:
                          count = len(cmsg_data) // 4
                          for fd in struct.unpack(f"<{count}i", cmsg_data[: count * 4]):
                              try:
                                  os.close(fd)
                              except OSError:
                                  pass

              reg_id = alloc_id()
              sync_id = alloc_id()
              send_msg(1, 1, struct.pack("<I", reg_id))
              send_msg(1, 0, struct.pack("<I", sync_id))

              buf = b""
              globals_found: dict[str, tuple[int, int]] = {}
              outputs: list[tuple[int, int]] = []
              sync_done = False

              while not sync_done:
                  r, _, _ = select.select([s], [], [], 2.0)
                  if not r:
                      break
                  data, anc, _, _ = s.recvmsg(4096, 64)
                  drain_ancillary(anc)
                  if not data:
                      break
                  buf += data
                  while len(buf) >= 8:
                      obj_id, size_op = struct.unpack_from("<II", buf, 0)
                      size = size_op >> 16
                      op = size_op & 0xFFFF
                      if len(buf) < size:
                          break
                      payload = buf[8:size]
                      buf = buf[size:]
                      if obj_id == reg_id and op == 0:
                          name, slen = struct.unpack_from("<II", payload, 0)
                          iface = payload[8 : 8 + slen - 1].decode("utf-8", "replace")
                          ver = struct.unpack_from("<I", payload, 8 + ((slen + 3) & ~3))[0]
                          if iface == "wl_output":
                              outputs.append((name, ver))
                          else:
                              globals_found[iface] = (name, ver)
                      elif obj_id == sync_id and op == 0:
                          sync_done = True

              def bind(iface: str, max_ver: int) -> int:
                  name, ver = globals_found[iface]
                  oid = alloc_id()
                  send_msg(
                      reg_id,
                      0,
                      struct.pack("<I", name) + pack_str(iface) + struct.pack("<II", min(ver, max_ver), oid),
                  )
                  return oid

              comp_id = bind("wl_compositor", 4)
              shm_id = bind("wl_shm", 1)
              seat_id = bind("wl_seat", 1)
              viewporter_id = bind("wp_viewporter", 1)
              layer_shell_id = bind("zwlr_layer_shell_v1", 4)
              inhibit_mgr_id = bind("zwp_idle_inhibit_manager_v1", 1)

              pointer_id = 0
              keyboard_id = 0
              if not headless:
                  pointer_id = alloc_id()
                  send_msg(seat_id, 0, struct.pack("<I", pointer_id))
                  keyboard_id = alloc_id()
                  send_msg(seat_id, 1, struct.pack("<I", keyboard_id))

              # Render resolution scaled to each monitor via wp_viewport
              buf_w = 1 if headless else 480
              buf_h = 1 if headless else 270
              stride = buf_w * 4
              frame_bytes = stride * buf_h

              glyphs = build_glyphs() if (not headless and style == "matrix") else []

              screens: dict[int, dict] = {}
              target_outputs = outputs[:1] if headless else outputs
              for out_name, out_ver in target_outputs:
                  out_id = alloc_id()
                  send_msg(
                      reg_id,
                      0,
                      struct.pack("<I", out_name)
                      + pack_str("wl_output")
                      + struct.pack("<II", min(out_ver, 2), out_id),
                  )
                  surf_id = alloc_id()
                  send_msg(comp_id, 0, struct.pack("<I", surf_id))
                  inhib_id = alloc_id()
                  send_msg(inhibit_mgr_id, 1, struct.pack("<II", inhib_id, surf_id))
                  vp_id = alloc_id()
                  send_msg(viewporter_id, 1, struct.pack("<II", vp_id, surf_id))
                  lsurf_id = alloc_id()
                  send_msg(
                      layer_shell_id,
                      0,
                      struct.pack("<IIII", lsurf_id, surf_id, out_id, 3) + pack_str("dont-sleep"),
                  )
                  if headless:
                      send_msg(lsurf_id, 0, struct.pack("<II", 1, 1))
                      send_msg(lsurf_id, 1, struct.pack("<I", 1))
                      send_msg(lsurf_id, 2, struct.pack("<i", 0))
                      send_msg(lsurf_id, 4, struct.pack("<I", 0))
                  else:
                      send_msg(lsurf_id, 0, struct.pack("<II", 0, 0))
                      send_msg(lsurf_id, 1, struct.pack("<I", 15))  # top|bottom|left|right
                      send_msg(lsurf_id, 2, struct.pack("<i", -1))  # cover panel & dock
                      send_msg(lsurf_id, 4, struct.pack("<I", 1))  # exclusive keyboard
                  send_msg(surf_id, 6)  # commit

                  fd = os.memfd_create("dont-sleep-shm", 0)
                  os.ftruncate(fd, frame_bytes)
                  mm = mmap.mmap(fd, frame_bytes, mmap.MAP_SHARED, mmap.PROT_READ | mmap.PROT_WRITE)
                  pool_id = alloc_id()
                  send_msg(shm_id, 0, struct.pack("<Ii", pool_id, frame_bytes), fds=[fd])
                  wl_buf_id = alloc_id()
                  # Format 0 = ARGB8888 (transparent for headless), 1 = XRGB8888 (opaque black for screensaver)
                  shm_fmt = 0 if headless else 1
                  send_msg(pool_id, 0, struct.pack("<iiiiii", wl_buf_id, 0, buf_w, buf_h, stride, shm_fmt))

                  if headless:
                      anim = None
                  elif style == "starfield":
                      anim = StarfieldAnimator(buf_w, buf_h)
                  elif style == "pipes":
                      anim = PipesAnimator(buf_w, buf_h)
                  else:
                      anim = MatrixAnimator(buf_w, buf_h, glyphs)

                  screens[lsurf_id] = {
                      "surf_id": surf_id,
                      "vp_id": vp_id,
                      "wl_buf_id": wl_buf_id,
                      "fd": fd,
                      "mm": mm,
                      "configured": False,
                      "width": buf_w,
                      "height": buf_h,
                      "anim": anim,
                  }

              running = True

              def handle_sig(_signum: int, _frame: object) -> None:
                  nonlocal running
                  running = False

              signal.signal(signal.SIGINT, handle_sig)
              signal.signal(signal.SIGTERM, handle_sig)

              start_time = time.monotonic()
              anchor_mouse: tuple[int, int] | None = None

              mode_desc = "headless inhibitor" if headless else f"{style} screensaver"
              print(
                  f"[dont-sleep] Active ({mode_desc} across {len(screens)} output(s)). "
                  + ("Press Ctrl-C to stop." if headless else "Press any key or move mouse to unlock.")
              )

              try:
                  while running:
                      timeout = 1.0 if headless else 0.033
                      r, _, _ = select.select([s], [], [], timeout)
                      if r:
                          data, anc, _, _ = s.recvmsg(4096, 64)
                          drain_ancillary(anc)
                          if not data:
                              break
                          buf += data
                          while len(buf) >= 8:
                              obj_id, size_op = struct.unpack_from("<II", buf, 0)
                              size = size_op >> 16
                              op = size_op & 0xFFFF
                              if len(buf) < size:
                                  break
                              payload = buf[8:size]
                              buf = buf[size:]

                              if obj_id in screens and op == 0:  # zwlr_layer_surface_v1.configure
                                  serial, w, h = struct.unpack_from("<III", payload, 0)
                                  sc = screens[obj_id]
                                  send_msg(obj_id, 6, struct.pack("<I", serial))
                                  if w > 0 and h > 0:
                                      sc["width"] = w
                                      sc["height"] = h
                                      send_msg(sc["vp_id"], 2, struct.pack("<ii", w, h))
                                  sc["configured"] = True
                                  send_msg(sc["surf_id"], 1, struct.pack("<Iii", sc["wl_buf_id"], 0, 0))
                                  send_msg(sc["surf_id"], 2, struct.pack("<iiii", 0, 0, sc["width"], sc["height"]))
                                  send_msg(sc["surf_id"], 6)
                              elif obj_id in screens and op == 1:  # closed
                                  running = False
                              elif not headless and obj_id == pointer_id:
                                  if op == 0:  # enter(serial, surface, x, y)
                                      serial = struct.unpack_from("<I", payload, 0)[0]
                                      send_msg(pointer_id, 0, struct.pack("<IIii", serial, 0, 0, 0))
                                  elif op == 2:  # motion(time, sx, sy)
                                      if time.monotonic() - start_time >= grace:
                                          _, sx, sy = struct.unpack_from("<Iii", payload, 0)
                                          if anchor_mouse is None:
                                              anchor_mouse = (sx, sy)
                                          elif abs(sx - anchor_mouse[0]) + abs(sy - anchor_mouse[1]) > (12 * 256):
                                              running = False
                                  elif op == 3:  # button
                                      if time.monotonic() - start_time >= grace:
                                          running = False
                              elif not headless and obj_id == keyboard_id:
                                  if op == 3:  # key(serial, time, key, state)
                                      _, _, _, state = struct.unpack_from("<IIII", payload, 0)
                                      if state == 1 and (time.monotonic() - start_time >= grace):
                                          running = False

                      if not headless and running:
                          for sc in screens.values():
                              if sc["configured"] and sc["anim"] is not None:
                                  sc["anim"].step(sc["mm"])
                                  send_msg(sc["surf_id"], 1, struct.pack("<Iii", sc["wl_buf_id"], 0, 0))
                                  send_msg(sc["surf_id"], 2, struct.pack("<iiii", 0, 0, sc["width"], sc["height"]))
                                  send_msg(sc["surf_id"], 6)
              finally:
                  for sc in screens.values():
                      try:
                          sc["mm"].close()
                      except Exception:
                          pass
                      try:
                          os.close(sc["fd"])
                      except Exception:
                          pass
                  s.close()
                  print("[dont-sleep] Released all inhibitors.")

              return 0


          def main() -> int:
              parser = argparse.ArgumentParser(
                  prog="dont-sleep",
                  description="Burn-in-safe Wayland layer-shell screensaver & multi-layer idle inhibitor.",
              )
              group = parser.add_mutually_exclusive_group()
              group.add_argument("--matrix", action="store_true", help="Matrix digital rain animation (default)")
              group.add_argument("--starfield", action="store_true", help="3D warp starfield animation")
              group.add_argument("--pipes", action="store_true", help="2D neon pipes animation")
              group.add_argument(
                  "--headless",
                  "--no-screensaver",
                  action="store_true",
                  help="Inhibit sleep/lock/1Password in terminal without showing fullscreen screensaver",
              )
              group.add_argument("--status", action="store_true", help="Show active inhibitors and cosmic-idle status")
              group.add_argument(
                  "--reset-idle",
                  action="store_true",
                  help="Restart cosmic-idle to clear stuck browser ScreenSaver inhibitors",
              )
              parser.add_argument(
                  "-g",
                  "--grace",
                  type=float,
                  default=2.0,
                  help="Grace period in seconds before input dismisses the screensaver (default: 2.0)",
              )
              args = parser.parse_args()

              if args.status:
                  return run_status()
              if args.reset_idle:
                  return run_reset_idle()

              ensure_systemd_inhibit()

              style = "matrix"
              if args.starfield:
                  style = "starfield"
              elif args.pipes:
                  style = "pipes"

              return run_wayland_screensaver(style=style, headless=args.headless, grace=args.grace)


          if __name__ == "__main__":
              sys.exit(main())
        '';
      };
    };

    sessionVariables = {
      DONT_SLEEP = scriptPath;
    };
  };
}
