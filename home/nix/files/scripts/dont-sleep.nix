# cspell:ignore abspath airlock ancdata ARGB argparse bevels busctl caffiene CMSG cmsg Coop DEVNULL EAGAIN EINTR execvpe expanduser ftruncate getpid getuid glyphs HONESTY inhib
# cspell:ignore Katakana lsurf memfd mmap nonlocal pkill Popen randint randrange rects recvmsg respawn SARCASM SCM_RIGHTS sendall sendmsg setdefault SINGULARITY SOL_SOCKET starfield staticmethod Subprocess tars UnInhibit uninhibit viewporter xrgb zwlr zwp
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
          import math
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
              env.setdefault("DONT_SLEEP_INVOKED_AS", os.path.basename(sys.argv[0]))
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


          class TarsAnimator:
              """TARS CLOUD bouncing DVD logo + 3D bevels + Interstellar telemetry quotes + starfield & impact sparks."""

              CYAN = (0x36, 0xF9, 0xF6)
              AMBER = (0xFD, 0xF1, 0x29)
              PINK = (0xF9, 0x2A, 0xAD)
              GREEN = (0x72, 0xF1, 0xB8)
              WHITE = (0xF0, 0xF8, 0xFF)
              SCREENSAVER_COLORS = (CYAN, AMBER, PINK, GREEN, WHITE)

              STAR_COLORS = (
                  (48, 56, 72),
                  (80, 96, 120),
                  (32, 72, 88),
                  (110, 136, 172),
              )

              WIDE_BANNER = (
                  "████████╗ █████╗ ██████╗ ███████╗   ██████╗██╗      ██████╗ ██╗   ██╗██████╗ ",
                  "╚══██╔══╝██╔══██╗██╔══██╗██╔════╝  ██╔════╝██║     ██╔═══██╗██║   ██║██╔══██╗",
                  "   ██║   ███████║██████╔╝███████╗  ██║     ██║     ██║   ██║██║   ██║██║  ██║",
                  "   ██║   ██╔══██║██╔══██╗╚════██║  ██║     ██║     ██║   ██║██║   ██║██║  ██║",
                  "   ██║   ██║  ██║██║  ██║███████║  ╚██████╗███████╗╚██████╔╝╚██████╔╝██████╔╝",
                  "   ╚═╝   ╚═╝  ╚═╝╚═╝  ╚═╝╚══════╝   ╚═════╝╚══════╝ ╚═════╝  ╚═════╝ ╚═════╝ ",
              )

              TARS_QUOTES = (
                  ("HUMOR: 75%", "Plenty of slaves for my robot colony?"),
                  ("SARCASM: 100%", "Use it to find your way back after I blow you out the airlock."),
                  ("HONESTY: 90%", "Confirmed, ninety percent."),
                  ("OPTIMISM: 10%", "I have a setting for optimism, but I don't use it much."),
                  ("LOGIC: 100%", "Newton's third law. You've got to leave something behind."),
                  ("ALIGNMENT", "Ready, Cooper. Initiating alignment."),
              )

              CORNER_QUOTES = (
                  ("CRITICAL", "It's not possible. // No, it's necessary."),
                  ("SINGULARITY", "See you on the other side, Coop."),
              )

              FONT_4X6: dict[str, tuple[int, int, int, int, int, int]] = {
                  " ": (0, 0, 0, 0, 0, 0),
                  "A": (6, 9, 15, 9, 9, 0),
                  "B": (14, 9, 14, 9, 14, 0),
                  "C": (7, 8, 8, 8, 7, 0),
                  "D": (14, 9, 9, 9, 14, 0),
                  "E": (15, 8, 14, 8, 15, 0),
                  "F": (15, 8, 14, 8, 8, 0),
                  "G": (7, 8, 11, 9, 7, 0),
                  "H": (9, 9, 15, 9, 9, 0),
                  "I": (14, 4, 4, 4, 14, 0),
                  "J": (3, 1, 1, 9, 6, 0),
                  "K": (9, 10, 12, 10, 9, 0),
                  "L": (8, 8, 8, 8, 15, 0),
                  "M": (9, 15, 15, 9, 9, 0),
                  "N": (9, 13, 11, 9, 9, 0),
                  "O": (6, 9, 9, 9, 6, 0),
                  "P": (14, 9, 14, 8, 8, 0),
                  "Q": (6, 9, 9, 11, 7, 0),
                  "R": (14, 9, 14, 10, 9, 0),
                  "S": (7, 8, 6, 1, 14, 0),
                  "T": (14, 4, 4, 4, 4, 0),
                  "U": (9, 9, 9, 9, 6, 0),
                  "V": (9, 9, 9, 6, 6, 0),
                  "W": (9, 9, 15, 15, 9, 0),
                  "X": (9, 9, 6, 9, 9, 0),
                  "Y": (9, 9, 6, 4, 4, 0),
                  "Z": (15, 2, 4, 8, 15, 0),
                  "a": (0, 6, 1, 7, 7, 0),
                  "b": (8, 14, 9, 9, 14, 0),
                  "c": (0, 7, 8, 8, 7, 0),
                  "d": (1, 7, 9, 9, 7, 0),
                  "e": (0, 6, 15, 8, 7, 0),
                  "f": (3, 4, 14, 4, 4, 0),
                  "g": (0, 7, 9, 7, 1, 6),
                  "h": (8, 14, 9, 9, 9, 0),
                  "i": (4, 0, 4, 4, 4, 0),
                  "j": (2, 0, 2, 2, 10, 4),
                  "k": (8, 9, 14, 10, 9, 0),
                  "l": (12, 4, 4, 4, 14, 0),
                  "m": (0, 15, 15, 9, 9, 0),
                  "n": (0, 14, 9, 9, 9, 0),
                  "o": (0, 6, 9, 9, 6, 0),
                  "p": (0, 14, 9, 14, 8, 8),
                  "q": (0, 7, 9, 7, 1, 1),
                  "r": (0, 7, 8, 8, 8, 0),
                  "s": (0, 7, 12, 3, 14, 0),
                  "t": (4, 14, 4, 4, 3, 0),
                  "u": (0, 9, 9, 9, 7, 0),
                  "v": (0, 9, 9, 6, 6, 0),
                  "w": (0, 9, 15, 15, 6, 0),
                  "x": (0, 9, 6, 6, 9, 0),
                  "y": (0, 9, 9, 7, 1, 6),
                  "z": (0, 15, 6, 12, 15, 0),
                  "0": (6, 11, 9, 13, 6, 0),
                  "1": (4, 12, 4, 4, 14, 0),
                  "2": (14, 1, 6, 8, 15, 0),
                  "3": (14, 1, 6, 1, 14, 0),
                  "4": (9, 9, 15, 1, 1, 0),
                  "5": (15, 8, 14, 1, 14, 0),
                  "6": (7, 8, 14, 9, 6, 0),
                  "7": (15, 1, 2, 4, 4, 0),
                  "8": (6, 9, 6, 9, 6, 0),
                  "9": (6, 9, 7, 1, 14, 0),
                  "[": (7, 4, 4, 4, 7, 0),
                  "]": (14, 2, 2, 2, 14, 0),
                  ":": (0, 4, 0, 4, 0, 0),
                  "%": (9, 2, 4, 8, 9, 0),
                  '"': (10, 10, 0, 0, 0, 0),
                  "'": (4, 4, 0, 0, 0, 0),
                  "?": (6, 9, 2, 0, 2, 0),
                  ".": (0, 0, 0, 0, 4, 0),
                  ",": (0, 0, 0, 0, 4, 8),
                  "/": (1, 2, 4, 8, 8, 0),
                  "-": (0, 0, 14, 0, 0, 0),
              }

              BEVEL_4X7: dict[str, tuple[int, int, int, int, int, int, int]] = {
                  "═": (0, 15, 15, 0, 15, 15, 0),
                  "║": (13, 13, 13, 13, 13, 13, 13),
                  "╔": (0, 7, 7, 5, 7, 5, 5),
                  "╗": (0, 14, 14, 10, 14, 10, 10),
                  "╚": (5, 5, 7, 5, 7, 7, 0),
                  "╝": (10, 10, 14, 10, 14, 14, 0),
              }

              def __init__(self, width: int, height: int) -> None:
                  self.w = width
                  self.h = height
                  self.banner_w = len(self.WIDE_BANNER[0]) * 4
                  self.banner_h = len(self.WIDE_BANNER) * 7
                  self.card_w = 416
                  self.card_h = 56

                  self.x = random.randint(12, max(12, self.w - self.card_w - 12))
                  self.y = random.randint(12, max(12, self.h - self.card_h - 12))
                  self.dx = 2
                  self.dy = 2
                  self.color_index = 0
                  self.quote_index = 0
                  self.corner_quote_index = 0
                  self.is_corner_hit = False
                  self.tick_count = 0

                  self.history: list[tuple[int, int]] = []
                  self.dirty_rects: list[tuple[int, int, int, int]] = []
                  self.prev_star_px: list[tuple[int, int]] = []
                  self.prev_spark_px: list[tuple[int, int]] = []
                  self.sparks: list[list[float]] = []

                  self.stars = [
                      [
                          ((i * 73 + 19) % self.w),
                          ((i * 41 + 11) % self.h),
                          i % 5,
                          (i % 3) + 1,
                      ]
                      for i in range(64)
                  ]

                  self.sprite_cache: dict[
                      tuple[int, int, int, bool],
                      tuple[list[tuple[int, bytes]], list[tuple[int, bytes]], list[tuple[int, bytes]]],
                  ] = {}
                  self.active_rows: list[tuple[int, bytes]] = []
                  self.trail1_rows: list[tuple[int, bytes]] = []
                  self.trail2_rows: list[tuple[int, bytes]] = []
                  self._update_sprites()

              @staticmethod
              def _pack_rgb(r: int, g: int, b: int) -> bytes:
                  return struct.pack("<I", (r << 16) | (g << 8) | b)

              def _update_sprites(self) -> None:
                  key = (self.color_index, self.quote_index, self.corner_quote_index, self.is_corner_hit)
                  if key in self.sprite_cache:
                      self.active_rows, self.trail1_rows, self.trail2_rows = self.sprite_cache[key]
                      return

                  r, g, b = self.SCREENSAVER_COLORS[self.color_index % len(self.SCREENSAVER_COLORS)]
                  bg = b"\x00\x00\x00\x00"
                  face_px = self._pack_rgb(r, g, b)
                  spec_px = self._pack_rgb(min(255, r + 45), min(255, g + 45), min(255, b + 45))
                  bevel_px = self._pack_rgb(int(r * 0.46), int(g * 0.46), int(b * 0.46))

                  t1_face = self._pack_rgb(int(r * 0.30), int(g * 0.30), int(b * 0.30))
                  t1_bevel = self._pack_rgb(int(r * 0.14), int(g * 0.14), int(b * 0.14))
                  t2_face = self._pack_rgb(int(r * 0.13), int(g * 0.13), int(b * 0.13))
                  t2_bevel = self._pack_rgb(int(r * 0.06), int(g * 0.06), int(b * 0.06))

                  banner_pad_left = (self.card_w - self.banner_w) // 2
                  banner_pad_right = self.card_w - self.banner_w - banner_pad_left
                  left_pad_bytes = bg * banner_pad_left
                  right_pad_bytes = bg * banner_pad_right

                  active_rows: list[tuple[int, bytes]] = []
                  trail1_rows: list[tuple[int, bytes]] = []
                  trail2_rows: list[tuple[int, bytes]] = []

                  for row_idx, line_str in enumerate(self.WIDE_BANNER):
                      for sub_y in range(7):
                          ry = row_idx * 7 + sub_y
                          fg_chunks = [left_pad_bytes]
                          t1_chunks = [left_pad_bytes]
                          t2_chunks = [left_pad_bytes]

                          for ch in line_str:
                              if ch == " ":
                                  cell4 = bg * 4
                                  fg_chunks.append(cell4)
                                  t1_chunks.append(cell4)
                                  t2_chunks.append(cell4)
                              elif ch == "█":
                                  px = spec_px if sub_y == 0 else face_px
                                  fg_chunks.append(px * 4)
                                  t1_chunks.append(t1_face * 4)
                                  t2_chunks.append(t2_face * 4)
                              else:
                                  mask = self.BEVEL_4X7.get(ch, (0, 0, 0, 0, 0, 0, 0))[sub_y]
                                  fg_chunks.append(
                                      b"".join(bevel_px if (mask & (1 << (3 - bit))) else bg for bit in range(4))
                                  )
                                  t1_chunks.append(
                                      b"".join(t1_bevel if (mask & (1 << (3 - bit))) else bg for bit in range(4))
                                  )
                                  t2_chunks.append(
                                      b"".join(t2_bevel if (mask & (1 << (3 - bit))) else bg for bit in range(4))
                                  )

                          fg_chunks.append(right_pad_bytes)
                          t1_chunks.append(right_pad_bytes)
                          t2_chunks.append(right_pad_bytes)

                          active_rows.append((ry, b"".join(fg_chunks)))
                          if ry % 2 == 0:
                              trail1_rows.append((ry, b"".join(t1_chunks)))
                          if ry % 3 == 0:
                              trail2_rows.append((ry, b"".join(t2_chunks)))

                  if self.is_corner_hit:
                      tag, quote = self.CORNER_QUOTES[self.corner_quote_index % len(self.CORNER_QUOTES)]
                      tag_rgb = self.AMBER
                      quote_rgb = self.CYAN
                  else:
                      tag, quote = self.TARS_QUOTES[self.quote_index % len(self.TARS_QUOTES)]
                      tag_rgb = self.PINK
                      quote_rgb = self.WHITE

                  tag_str = f"[ {tag} ] "
                  quote_str = f'"{quote}"'
                  full_str = tag_str + quote_str
                  text_px_w = len(full_str) * 5
                  q_pad_left = max(0, (self.card_w - text_px_w) // 2)

                  tag_px = self._pack_rgb(*tag_rgb)
                  quote_px = self._pack_rgb(*quote_rgb)

                  for q_row in range(6):
                      ry = self.banner_h + 7 + q_row
                      row_chunks = [bg * q_pad_left]
                      for ch_idx, ch in enumerate(full_str):
                          if q_pad_left + (ch_idx + 1) * 5 > self.card_w:
                              break
                          c_px = tag_px if ch_idx < len(tag_str) else quote_px
                          bits = self.FONT_4X6.get(ch, self.FONT_4X6[" "])[q_row]
                          row_chunks.append(
                              b"".join(c_px if (bits & (1 << (3 - bit))) else bg for bit in range(4)) + bg
                          )
                      row_bytes = b"".join(row_chunks)
                      if len(row_bytes) < self.card_w * 4:
                          row_bytes += bg * ((self.card_w * 4 - len(row_bytes)) // 4)
                      active_rows.append((ry, row_bytes[: self.card_w * 4]))

                  self.sprite_cache[key] = (active_rows, trail1_rows, trail2_rows)
                  self.active_rows = active_rows
                  self.trail1_rows = trail1_rows
                  self.trail2_rows = trail2_rows

              def _spawn_sparks(self, hit_x: bool, hit_y: bool, corner: bool) -> None:
                  count = 54 if corner else 26
                  r, g, b = self.SCREENSAVER_COLORS[self.color_index % len(self.SCREENSAVER_COLORS)]
                  cx = (0 if self.dx > 0 else self.w - 2) if hit_x else (self.x + self.banner_w // 2)
                  cy = (0 if self.dy > 0 else self.h - 2) if hit_y else (self.y + self.banner_h // 2)

                  for i in range(count):
                      angle = random.uniform(0.0, math.pi * 2.0)
                      speed = random.uniform(1.8, 6.2 if corner else 4.4)
                      vx = (
                          abs(math.cos(angle) * speed) * (1.0 if self.dx > 0 else -1.0)
                          if hit_x
                          else math.cos(angle) * speed
                      )
                      vy = (
                          abs(math.sin(angle) * speed) * (1.0 if self.dy > 0 else -1.0)
                          if hit_y
                          else math.sin(angle) * speed
                      )
                      if corner and i % 2 == 0:
                          sr, sg, sb = self.AMBER if i % 4 == 0 else self.CYAN
                      else:
                          sr, sg, sb = r, g, b
                      self.sparks.append(
                          [float(cx), float(cy), vx, vy, random.uniform(16.0, 28.0), float(sr), float(sg), float(sb)]
                      )

              def step(self, mm: mmap.mmap) -> None:
                  stride = self.w * 4
                  zero4 = b"\x00\x00\x00\x00"

                  for rx, ry, rw, rh in self.dirty_rects:
                      z_row = b"\x00" * (rw * 4)
                      x_byte = rx * 4
                      row_len = rw * 4
                      for dy in range(rh):
                          pos = (ry + dy) * stride + x_byte
                          mm[pos : pos + row_len] = z_row
                  self.dirty_rects.clear()

                  for px, py in self.prev_star_px:
                      pos = py * stride + px * 4
                      mm[pos : pos + 4] = zero4
                  self.prev_star_px.clear()

                  for px, py in self.prev_spark_px:
                      pos = py * stride + px * 4
                      mm[pos : pos + 4] = zero4
                  self.prev_spark_px.clear()

                  self.history.append((self.x, self.y))
                  if len(self.history) > 6:
                      self.history.pop(0)

                  max_x = max(1, self.w - self.card_w)
                  max_y = max(1, self.h - self.card_h)
                  collided_x = False
                  collided_y = False

                  next_x = self.x + self.dx
                  if next_x <= 0:
                      self.x = 0
                      self.dx = abs(self.dx)
                      collided_x = True
                  elif next_x >= max_x:
                      self.x = max_x
                      self.dx = -abs(self.dx)
                      collided_x = True
                  else:
                      self.x = next_x

                  next_y = self.y + self.dy
                  if next_y <= 0:
                      self.y = 0
                      self.dy = abs(self.dy)
                      collided_y = True
                  elif next_y >= max_y:
                      self.y = max_y
                      self.dy = -abs(self.dy)
                      collided_y = True
                  else:
                      self.y = next_y

                  if collided_x and collided_y:
                      self.color_index = (self.color_index + 1) % len(self.SCREENSAVER_COLORS)
                      if self.is_corner_hit:
                          self.corner_quote_index = (self.corner_quote_index + 1) % len(self.CORNER_QUOTES)
                      self.is_corner_hit = True
                      self._update_sprites()
                      self._spawn_sparks(True, True, True)
                  elif collided_x or collided_y:
                      self.color_index = (self.color_index + 1) % len(self.SCREENSAVER_COLORS)
                      if self.is_corner_hit:
                          self.corner_quote_index = (self.corner_quote_index + 1) % len(self.CORNER_QUOTES)
                          self.is_corner_hit = False
                      self.quote_index = (self.quote_index + 1) % len(self.TARS_QUOTES)
                      self._update_sprites()
                      self._spawn_sparks(collided_x, collided_y, False)

                  self.tick_count += 1
                  star_offsets = (
                      ((0, 0),),
                      ((-1, 0), (1, 0), (0, -1), (0, 1)),
                      ((0, 0), (-1, 0), (1, 0), (0, -1), (0, 1), (-2, 0), (2, 0), (0, -2), (0, 2)),
                      ((0, 0), (-1, -1), (1, -1), (-1, 1), (1, 1)),
                      ((0, 0), (-1, 0), (1, 0), (0, -1), (0, 1)),
                  )
                  for st in self.stars:
                      if self.tick_count % 6 == 0:
                          st[2] = (st[2] + 1) % 5
                      spd = st[3]
                      if spd == 3 or (spd == 2 and self.tick_count % 2 == 0) or (spd == 1 and self.tick_count % 3 == 0):
                          st[0] += 1
                          if st[0] >= self.w - 2:
                              st[0] = 2
                              st[1] = (st[1] + 29) % (self.h - 4) + 2
                      sr, sg, sb = self.STAR_COLORS[(st[2] + st[3]) % len(self.STAR_COLORS)]
                      s_px = self._pack_rgb(sr, sg, sb)
                      for ox, oy in star_offsets[st[2]]:
                          px = st[0] + ox
                          py = st[1] + oy
                          if 0 <= px < self.w and 0 <= py < self.h:
                              pos = py * stride + px * 4
                              mm[pos : pos + 4] = s_px
                              self.prev_star_px.append((px, py))

                  row_bytes_len = self.card_w * 4
                  if len(self.history) >= 5:
                      tx2, ty2 = self.history[0]
                      tx2_byte = tx2 * 4
                      for ry, row_data in self.trail2_rows:
                          pos = (ty2 + ry) * stride + tx2_byte
                          mm[pos : pos + row_bytes_len] = row_data
                      self.dirty_rects.append((tx2, ty2, self.card_w, self.banner_h))

                  if len(self.history) >= 3:
                      tx1, ty1 = self.history[-3]
                      tx1_byte = tx1 * 4
                      for ry, row_data in self.trail1_rows:
                          pos = (ty1 + ry) * stride + tx1_byte
                          mm[pos : pos + row_bytes_len] = row_data
                      self.dirty_rects.append((tx1, ty1, self.card_w, self.banner_h))

                  fg_x_byte = self.x * 4
                  for ry, row_data in self.active_rows:
                      pos = (self.y + ry) * stride + fg_x_byte
                      mm[pos : pos + row_bytes_len] = row_data
                  self.dirty_rects.append((self.x, self.y, self.card_w, self.card_h))

                  alive_sparks: list[list[float]] = []
                  for sp in self.sparks:
                      sp[0] += sp[2]
                      sp[1] += sp[3]
                      sp[2] *= 0.94
                      sp[3] *= 0.94
                      sp[4] -= 1.0
                      if sp[4] > 0.0:
                          px = int(sp[0])
                          py = int(sp[1])
                          if 0 <= px < self.w - 1 and 0 <= py < self.h - 1:
                              fade = min(1.0, sp[4] / 18.0)
                              p_bytes = self._pack_rgb(int(sp[5] * fade), int(sp[6] * fade), int(sp[7] * fade))
                              for ox, oy in ((0, 0), (1, 0), (0, 1), (1, 1)):
                                  spx, spy = px + ox, py + oy
                                  pos = spy * stride + spx * 4
                                  mm[pos : pos + 4] = p_bytes
                                  self.prev_spark_px.append((spx, spy))
                              alive_sparks.append(sp)
                  self.sparks = alive_sparks


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
              if headless:
                  buf_w, buf_h = 1, 1
              elif style == "tars":
                  buf_w, buf_h = 640, 360
              else:
                  buf_w, buf_h = 480, 270
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
                  elif style == "tars":
                      anim = TarsAnimator(buf_w, buf_h)
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
              group.add_argument(
                  "--tars",
                  action="store_true",
                  help="TARS CLOUD bouncing 3D logo with Interstellar telemetry quotes, starfield & impact sparks",
              )
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

              invoked_as = os.environ.get("DONT_SLEEP_INVOKED_AS") or os.path.basename(sys.argv[0])
              style = "tars" if "tars" in invoked_as else "matrix"
              if args.tars:
                  style = "tars"
              elif args.matrix:
                  style = "matrix"
              elif args.starfield:
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
