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

              FONT_5X7: dict[str, tuple[int, int, int, int, int, int, int]] = {
                  " ": (0, 0, 0, 0, 0, 0, 0),
                  "A": (14, 17, 17, 31, 17, 17, 0),
                  "B": (30, 17, 30, 17, 17, 30, 0),
                  "C": (14, 17, 16, 16, 17, 14, 0),
                  "D": (30, 17, 17, 17, 17, 30, 0),
                  "E": (31, 16, 30, 16, 16, 31, 0),
                  "F": (31, 16, 30, 16, 16, 16, 0),
                  "G": (14, 17, 16, 23, 17, 15, 0),
                  "H": (17, 17, 31, 17, 17, 17, 0),
                  "I": (14, 4, 4, 4, 4, 14, 0),
                  "J": (7, 2, 2, 2, 18, 12, 0),
                  "K": (17, 18, 28, 18, 17, 17, 0),
                  "L": (16, 16, 16, 16, 16, 31, 0),
                  "M": (17, 27, 21, 17, 17, 17, 0),
                  "N": (17, 25, 21, 19, 17, 17, 0),
                  "O": (14, 17, 17, 17, 17, 14, 0),
                  "P": (30, 17, 17, 30, 16, 16, 0),
                  "Q": (14, 17, 17, 21, 18, 13, 0),
                  "R": (30, 17, 17, 30, 18, 17, 0),
                  "S": (15, 16, 14, 1, 1, 30, 0),
                  "T": (31, 4, 4, 4, 4, 4, 0),
                  "U": (17, 17, 17, 17, 17, 14, 0),
                  "V": (17, 17, 17, 17, 10, 4, 0),
                  "W": (17, 17, 17, 21, 27, 17, 0),
                  "X": (17, 10, 4, 4, 10, 17, 0),
                  "Y": (17, 10, 4, 4, 4, 4, 0),
                  "Z": (31, 1, 2, 4, 8, 31, 0),
                  "a": (0, 14, 1, 15, 17, 15, 0),
                  "b": (16, 16, 30, 17, 17, 30, 0),
                  "c": (0, 14, 17, 16, 17, 14, 0),
                  "d": (1, 1, 15, 17, 17, 15, 0),
                  "e": (0, 14, 17, 31, 16, 14, 0),
                  "f": (6, 8, 30, 8, 8, 8, 0),
                  "g": (0, 15, 17, 17, 15, 1, 14),
                  "h": (16, 16, 30, 17, 17, 17, 0),
                  "i": (4, 0, 12, 4, 4, 14, 0),
                  "j": (2, 0, 6, 2, 2, 18, 12),
                  "k": (16, 16, 18, 20, 28, 18, 0),
                  "l": (12, 4, 4, 4, 4, 14, 0),
                  "m": (0, 26, 21, 21, 17, 17, 0),
                  "n": (0, 30, 17, 17, 17, 17, 0),
                  "o": (0, 14, 17, 17, 17, 14, 0),
                  "p": (0, 30, 17, 17, 30, 16, 16),
                  "q": (0, 15, 17, 17, 15, 1, 1),
                  "r": (0, 22, 25, 16, 16, 16, 0),
                  "s": (0, 15, 16, 14, 1, 30, 0),
                  "t": (8, 8, 30, 8, 8, 6, 0),
                  "u": (0, 17, 17, 17, 17, 15, 0),
                  "v": (0, 17, 17, 17, 10, 4, 0),
                  "w": (0, 17, 17, 21, 21, 10, 0),
                  "x": (0, 17, 10, 4, 10, 17, 0),
                  "y": (0, 17, 17, 17, 15, 1, 14),
                  "z": (0, 31, 2, 4, 8, 31, 0),
                  "0": (14, 17, 19, 21, 25, 14, 0),
                  "1": (4, 12, 4, 4, 4, 14, 0),
                  "2": (14, 17, 1, 6, 8, 31, 0),
                  "3": (31, 2, 6, 1, 17, 14, 0),
                  "4": (2, 6, 10, 18, 31, 2, 0),
                  "5": (31, 16, 30, 1, 17, 14, 0),
                  "6": (6, 8, 30, 17, 17, 14, 0),
                  "7": (31, 1, 2, 4, 8, 8, 0),
                  "8": (14, 17, 14, 17, 17, 14, 0),
                  "9": (14, 17, 17, 15, 2, 12, 0),
                  "[": (14, 8, 8, 8, 8, 14, 0),
                  "]": (14, 2, 2, 2, 2, 14, 0),
                  ":": (0, 12, 12, 0, 12, 12, 0),
                  "%": (25, 26, 4, 4, 11, 19, 0),
                  '"': (10, 10, 0, 0, 0, 0, 0),
                  "'": (4, 4, 8, 0, 0, 0, 0),
                  "?": (14, 17, 2, 4, 0, 4, 0),
                  ".": (0, 0, 0, 0, 12, 12, 0),
                  ",": (0, 0, 0, 0, 12, 4, 8),
                  "/": (1, 2, 4, 4, 8, 16, 0),
                  "-": (0, 0, 0, 31, 0, 0, 0),
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
                  self.f_scale = max(1, min(3, width // 540, height // 320))
                  self.b_scale = 4 if self.f_scale >= 3 else (2 if self.f_scale == 2 else 1)
                  self.cell_w = 4 * self.b_scale
                  self.cell_h = 7 * self.b_scale
                  self.banner_w = len(self.WIDE_BANNER[0]) * self.cell_w
                  self.banner_h = len(self.WIDE_BANNER) * self.cell_h
                  self.char_adv = 6 * self.f_scale
                  self.quote_gap = 8 * self.f_scale
                  self.card_w = min(max(320, self.w - 16), max(self.banner_w, 82 * self.char_adv) + 12)
                  self.card_h = self.banner_h + self.quote_gap + 7 * self.f_scale + 3

                  self.x = random.randint(8, max(8, self.w - self.card_w - 8))
                  self.y = random.randint(8, max(8, self.h - self.card_h - 8))
                  self.dx = max(2, 2 * self.f_scale)
                  self.dy = max(2, 2 * self.f_scale - 1)
                  self.color_index = 0
                  self.quote_index = 0
                  self.corner_quote_index = 0
                  self.is_corner_hit = False
                  self.tick_count = 0

                  self.history: list[tuple[int, int]] = []
                  self.dirty_rects: list[tuple[int, int, int, int]] = []
                  self.prev_star_rects: list[tuple[int, int, int]] = []
                  self.prev_spark_rects: list[tuple[int, int]] = []
                  self.sparks: list[list[float]] = []

                  self.stars = [
                      [
                          ((i * 293 + 71) % max(1, self.w - 16)) + 8,
                          ((i * 163 + 43) % max(1, self.h - 16)) + 8,
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

                  banner_pad_left = max(0, (self.card_w - self.banner_w) // 2)
                  banner_pad_right = max(0, self.card_w - self.banner_w - banner_pad_left)
                  left_pad_bytes = bg * banner_pad_left
                  right_pad_bytes = bg * banner_pad_right

                  active_rows: list[tuple[int, bytes]] = []
                  trail1_rows: list[tuple[int, bytes]] = []
                  trail2_rows: list[tuple[int, bytes]] = []

                  bs = self.b_scale
                  cw = self.cell_w
                  for row_idx, line_str in enumerate(self.WIDE_BANNER):
                      for sub_y in range(7):
                          fg_chunks = [left_pad_bytes]
                          t1_chunks = [left_pad_bytes]
                          t2_chunks = [left_pad_bytes]

                          for ch in line_str:
                              if ch == " ":
                                  cell_bg = bg * cw
                                  fg_chunks.append(cell_bg)
                                  t1_chunks.append(cell_bg)
                                  t2_chunks.append(cell_bg)
                              elif ch == "█":
                                  px = spec_px if sub_y == 0 else face_px
                                  fg_chunks.append(px * cw)
                                  t1_chunks.append(t1_face * cw)
                                  t2_chunks.append(t2_face * cw)
                              else:
                                  mask = self.BEVEL_4X7.get(ch, (0, 0, 0, 0, 0, 0, 0))[sub_y]
                                  fg_chunks.append(
                                      b"".join((bevel_px if (mask & (1 << (3 - bit))) else bg) * bs for bit in range(4))
                                  )
                                  t1_chunks.append(
                                      b"".join((t1_bevel if (mask & (1 << (3 - bit))) else bg) * bs for bit in range(4))
                                  )
                                  t2_chunks.append(
                                      b"".join((t2_bevel if (mask & (1 << (3 - bit))) else bg) * bs for bit in range(4))
                                  )

                          fg_chunks.append(right_pad_bytes)
                          t1_chunks.append(right_pad_bytes)
                          t2_chunks.append(right_pad_bytes)

                          fg_row = b"".join(fg_chunks)[: self.card_w * 4]
                          t1_row = b"".join(t1_chunks)[: self.card_w * 4]
                          t2_row = b"".join(t2_chunks)[: self.card_w * 4]

                          base_ry = (row_idx * 7 + sub_y) * bs
                          for dy in range(bs):
                              ry = base_ry + dy
                              active_rows.append((ry, fg_row))
                              if ry % max(2, bs) == 0:
                                  trail1_rows.append((ry, t1_row))
                              if ry % max(3, bs + 2) == 0:
                                  trail2_rows.append((ry, t2_row))

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
                  fs = self.f_scale
                  adv = self.char_adv
                  text_px_w = len(full_str) * adv
                  q_pad_left = max(0, (self.card_w - text_px_w) // 2)

                  tag_px_s = self._pack_rgb(*tag_rgb) * fs
                  quote_px_s = self._pack_rgb(*quote_rgb) * fs
                  bg_s = bg * fs

                  for q_row in range(7):
                      row_chunks = [bg * q_pad_left]
                      for ch_idx, ch in enumerate(full_str):
                          if q_pad_left + (ch_idx + 1) * adv > self.card_w:
                              break
                          c_px_s = tag_px_s if ch_idx < len(tag_str) else quote_px_s
                          bits = self.FONT_5X7.get(ch, self.FONT_5X7[" "])[q_row]
                          row_chunks.append(
                              b"".join(c_px_s if (bits & (1 << (4 - bit))) else bg_s for bit in range(5)) + bg_s
                          )
                      row_bytes = b"".join(row_chunks)
                      if len(row_bytes) < self.card_w * 4:
                          row_bytes += bg * ((self.card_w * 4 - len(row_bytes)) // 4)
                      clipped_row = row_bytes[: self.card_w * 4]
                      base_qy = self.banner_h + self.quote_gap + q_row * fs
                      for dy in range(fs):
                          active_rows.append((base_qy + dy, clipped_row))

                  self.sprite_cache[key] = (active_rows, trail1_rows, trail2_rows)
                  self.active_rows = active_rows
                  self.trail1_rows = trail1_rows
                  self.trail2_rows = trail2_rows

              def _spawn_sparks(self, hit_x: bool, hit_y: bool, corner: bool) -> None:
                  count = 54 if corner else 26
                  r, g, b = self.SCREENSAVER_COLORS[self.color_index % len(self.SCREENSAVER_COLORS)]
                  cx = (4 if self.dx > 0 else self.w - 10) if hit_x else (self.x + self.card_w // 2)
                  cy = (4 if self.dy > 0 else self.h - 10) if hit_y else (self.y + self.banner_h // 2)

                  for i in range(count):
                      angle = random.uniform(0.0, math.pi * 2.0)
                      speed = random.uniform(6.0, 22.0 if corner else 15.0)
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
                  zero12 = b"\x00" * 12
                  zero20 = b"\x00" * 20

                  for rx, ry, rw, rh in self.dirty_rects:
                      z_row = b"\x00" * (rw * 4)
                      x_byte = rx * 4
                      row_len = rw * 4
                      for dy in range(rh):
                          pos = (ry + dy) * stride + x_byte
                          mm[pos : pos + row_len] = z_row
                  self.dirty_rects.clear()

                  for sx, sy, s_sz in self.prev_star_rects:
                      z_star = zero12 if s_sz == 3 else zero20
                      b_len = s_sz * 4
                      for dy in range(s_sz):
                          pos = (sy + dy) * stride + sx * 4
                          mm[pos : pos + b_len] = z_star
                  self.prev_star_rects.clear()

                  for px, py in self.prev_spark_rects:
                      for dy in range(4):
                          pos = (py + dy) * stride + px * 4
                          mm[pos : pos + 16] = b"\x00" * 16
                  self.prev_spark_rects.clear()

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
                  for st in self.stars:
                      if self.tick_count % 6 == 0:
                          st[2] = (st[2] + 1) % 5
                      spd = st[3]
                      st[0] += spd
                      if st[0] >= self.w - 10:
                          st[0] = 6
                          st[1] = (st[1] + 113) % (self.h - 16) + 8
                      sr, sg, sb = self.STAR_COLORS[(st[2] + st[3]) % len(self.STAR_COLORS)]
                      s_px = self._pack_rgb(sr, sg, sb)
                      sx, sy, phase = st[0], st[1], st[2]
                      if phase in (0, 1):
                          s_row = s_px * 3
                          for dy in range(3):
                              pos = (sy + dy) * stride + sx * 4
                              mm[pos : pos + 12] = s_row
                          self.prev_star_rects.append((sx, sy, 3))
                      else:
                          mid_row = s_px * 5
                          tip_row = b"\x00" * 8 + s_px + b"\x00" * 8
                          for dy in range(5):
                              pos = (sy + dy) * stride + sx * 4
                              mm[pos : pos + 20] = mid_row if dy == 2 else tip_row
                          self.prev_star_rects.append((sx, sy, 5))

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
                          if 0 <= px < self.w - 4 and 0 <= py < self.h - 4:
                              fade = min(1.0, sp[4] / 18.0)
                              p_row = self._pack_rgb(int(sp[5] * fade), int(sp[6] * fade), int(sp[7] * fade)) * 4
                              for dy in range(4):
                                  pos = (py + dy) * stride + px * 4
                                  mm[pos : pos + 16] = p_row
                              self.prev_spark_rects.append((px, py))
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

              glyphs = build_glyphs() if (not headless and style == "matrix") else []

              screens: dict[int, dict] = {}
              output_to_lsurf: dict[int, int] = {}

              def cleanup_screen_shm(sc: dict) -> None:
                  if sc.get("wl_buf_id"):
                      send_msg(sc["wl_buf_id"], 0)
                      sc["wl_buf_id"] = 0
                  if sc.get("pool_id"):
                      send_msg(sc["pool_id"], 1)
                      sc["pool_id"] = 0
                  if sc.get("mm") is not None:
                      try:
                          sc["mm"].close()
                      except Exception:
                          pass
                      sc["mm"] = None
                  if sc.get("fd", -1) >= 0:
                      try:
                          os.close(sc["fd"])
                      except Exception:
                          pass
                      sc["fd"] = -1

              def ensure_screen_buffer(sc: dict, target_w: int, target_h: int) -> None:
                  if headless:
                      bw, bh = 1, 1
                  elif style == "tars":
                      bw, bh = max(640, target_w), max(360, target_h)
                  else:
                      bw, bh = 480, 270

                  if sc.get("mm") is not None and sc.get("buf_w") == bw and sc.get("buf_h") == bh:
                      return

                  cleanup_screen_shm(sc)
                  stride = bw * 4
                  frame_bytes = stride * bh
                  fd = os.memfd_create("dont-sleep-shm", 0)
                  os.ftruncate(fd, frame_bytes)
                  mm = mmap.mmap(fd, frame_bytes, mmap.MAP_SHARED, mmap.PROT_READ | mmap.PROT_WRITE)
                  pool_id = alloc_id()
                  send_msg(shm_id, 0, struct.pack("<Ii", pool_id, frame_bytes), fds=[fd])
                  wl_buf_id = alloc_id()
                  shm_fmt = 0 if headless else 1
                  send_msg(pool_id, 0, struct.pack("<iiiiii", wl_buf_id, 0, bw, bh, stride, shm_fmt))

                  if headless:
                      anim = None
                  elif style == "tars":
                      anim = TarsAnimator(bw, bh)
                  elif style == "starfield":
                      anim = StarfieldAnimator(bw, bh)
                  elif style == "pipes":
                      anim = PipesAnimator(bw, bh)
                  else:
                      anim = MatrixAnimator(bw, bh, glyphs)

                  sc["fd"] = fd
                  sc["mm"] = mm
                  sc["pool_id"] = pool_id
                  sc["wl_buf_id"] = wl_buf_id
                  sc["buf_w"] = bw
                  sc["buf_h"] = bh
                  sc["anim"] = anim

              def add_output(out_name: int, out_ver: int) -> None:
                  if out_name in output_to_lsurf:
                      return
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
                  send_msg(surf_id, 6)  # initial commit to trigger configure

                  screens[lsurf_id] = {
                      "out_name": out_name,
                      "surf_id": surf_id,
                      "inhib_id": inhib_id,
                      "vp_id": vp_id,
                      "pool_id": 0,
                      "wl_buf_id": 0,
                      "fd": -1,
                      "mm": None,
                      "configured": False,
                      "width": 1920,
                      "height": 1080,
                      "buf_w": 0,
                      "buf_h": 0,
                      "anim": None,
                  }
                  output_to_lsurf[out_name] = lsurf_id

              def remove_screen(lsurf_id: int) -> None:
                  sc = screens.pop(lsurf_id, None)
                  if sc is None:
                      return
                  output_to_lsurf.pop(sc["out_name"], None)
                  cleanup_screen_shm(sc)
                  send_msg(sc["inhib_id"], 0)
                  send_msg(sc["vp_id"], 0)
                  send_msg(lsurf_id, 7)
                  send_msg(sc["surf_id"], 0)

              target_outputs = outputs[:1] if headless else outputs
              for out_name, out_ver in target_outputs:
                  add_output(out_name, out_ver)

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

                              if obj_id == reg_id and op == 0:  # wl_registry.global (hotplug)
                                  name, slen = struct.unpack_from("<II", payload, 0)
                                  iface = payload[8 : 8 + slen - 1].decode("utf-8", "replace")
                                  ver = struct.unpack_from("<I", payload, 8 + ((slen + 3) & ~3))[0]
                                  if iface == "wl_output" and (not headless or not screens):
                                      add_output(name, ver)
                              elif obj_id == reg_id and op == 1:  # wl_registry.global_remove (unplug)
                                  (name,) = struct.unpack_from("<I", payload, 0)
                                  if name in output_to_lsurf:
                                      remove_screen(output_to_lsurf[name])
                              elif obj_id in screens and op == 0:  # zwlr_layer_surface_v1.configure
                                  serial, w, h = struct.unpack_from("<III", payload, 0)
                                  sc = screens[obj_id]
                                  send_msg(obj_id, 6, struct.pack("<I", serial))
                                  if w > 0 and h > 0:
                                      sc["width"] = w
                                      sc["height"] = h
                                  ensure_screen_buffer(sc, sc["width"], sc["height"])
                                  send_msg(sc["vp_id"], 2, struct.pack("<ii", sc["width"], sc["height"]))
                                  sc["configured"] = True
                                  send_msg(sc["surf_id"], 1, struct.pack("<Iii", sc["wl_buf_id"], 0, 0))
                                  send_msg(sc["surf_id"], 2, struct.pack("<iiii", 0, 0, sc["width"], sc["height"]))
                                  send_msg(sc["surf_id"], 6)
                              elif obj_id in screens and op == 1:  # zwlr_layer_surface_v1.closed
                                  remove_screen(obj_id)
                                  if not screens and headless:
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
                              if sc["configured"] and sc["anim"] is not None and sc["mm"] is not None:
                                  sc["anim"].step(sc["mm"])
                                  send_msg(sc["surf_id"], 1, struct.pack("<Iii", sc["wl_buf_id"], 0, 0))
                                  send_msg(sc["surf_id"], 2, struct.pack("<iiii", 0, 0, sc["width"], sc["height"]))
                                  send_msg(sc["surf_id"], 6)
              finally:
                  for sc in list(screens.values()):
                      cleanup_screen_shm(sc)
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
