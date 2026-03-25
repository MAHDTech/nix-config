"""Terminal UI: Matrix logo, keyboard input, interactive menu."""

import fcntl
import logging
import os
import sys
import termios
import time
import tty

from core.log import console

MATRIX_LOGO = r"""[bold #00FF41]
████████╗ █████╗ ██████╗ ███████╗
╚══██╔══╝██╔══██╗██╔══██╗██╔════╝
   ██║   ███████║██████╔╝███████╗
   ██║   ██╔══██║██╔══██╗╚════██║
   ██║   ██║  ██║██║  ██║███████║
   ╚═╝   ╚═╝  ╚═╝╚═╝  ╚═╝╚══════╝
[/bold #00FF41]"""


def get_key():
    """Reads a single keypress from stdin, handling escape sequences for arrows."""
    fd = sys.stdin.fileno()
    old_settings = termios.tcgetattr(fd)
    try:
        tty.setraw(fd)
        ch = os.read(fd, 1).decode("utf-8", errors="ignore")
        if ch == "\x1b":  # Escape
            old_flags = fcntl.fcntl(fd, fcntl.F_GETFL)
            fcntl.fcntl(fd, fcntl.F_SETFL, old_flags | os.O_NONBLOCK)
            try:
                time.sleep(0.02)
                ch += os.read(fd, 1).decode("utf-8", errors="ignore")
                ch += os.read(fd, 1).decode("utf-8", errors="ignore")
            except OSError:
                pass
            finally:
                fcntl.fcntl(fd, fcntl.F_SETFL, old_flags)
    except Exception as e:
        logging.error(f"Error reading key: {e}")
        return ""
    finally:
        termios.tcsetattr(fd, termios.TCSADRAIN, old_settings)
    return ch


def select_from_menu(
    title: str, options: list, instruction: str, allow_back: bool = False
) -> int:
    selected_idx = 0
    while True:
        output = [MATRIX_LOGO]
        output.append(
            f"[bold #00FF41]>[/bold #00FF41] [bold white]{title}[/bold white]"
        )
        output.append(f"[bold #008F11]{instruction}[/bold #008F11]\n")

        for i, opt in enumerate(options):
            if i == selected_idx:
                output.append(
                    f"   [bold black on #00FF41]  ► {opt}  [/bold black on #00FF41]"
                )
            else:
                output.append(f"   [bold #008F11]    {opt}  [/bold #008F11]")

        footer = "\n[bold #008F11]  \\[↑/↓] Navigate   \\[ENTER] Select"
        if allow_back:
            footer += "   \\[ESC] Back"
        else:
            footer += "   \\[ESC] Exit"
        footer += "[/bold #008F11]"
        output.append(footer)

        console.clear()
        console.print("\n".join(output))

        key = get_key()
        logging.debug(f"Key pressed: {repr(key)}")

        if key in ("\x1b[A", "\x1bOA"):  # Up
            selected_idx = (selected_idx - 1) % len(options)
        elif key in ("\x1b[B", "\x1bOB"):  # Down
            selected_idx = (selected_idx + 1) % len(options)
        elif key in ("\r", "\n"):  # Enter
            return selected_idx
        elif key == "\x1b":  # Esc
            return -1
        elif key in ("q", "Q", "\x03"):  # q, Q, or Ctrl+C
            console.clear()
            sys.exit(0)


def interactive_menu(catalog: list) -> tuple[str, str]:
    """Renders the Rich terminal full-screen Matrix UI for model selection.
    Returns (selected_model: str, category_key: str).
    """
    ui_categories = [cat[1] for cat in catalog]

    while True:
        cat_idx = select_from_menu(
            "UPLINK ESTABLISHED", ui_categories, "SELECT NEURAL PATHWAY:", allow_back=False
        )
        if cat_idx == -1:
            console.clear()
            console.print("\n[bold #00FF41]DISCONNECTING...[/bold #00FF41]")
            sys.exit(0)

        selected_cat_tuple = catalog[cat_idx]
        short_key = selected_cat_tuple[0]
        ui_label = selected_cat_tuple[1]
        models = selected_cat_tuple[2]

        while True:
            mod_idx = select_from_menu(
                f"PATHWAY // {ui_label.upper()}",
                models,
                "SELECT CONSTRUCT MODEL:",
                allow_back=True,
            )
            if mod_idx == -1:
                break  # Go back to categories

            selected_model = models[mod_idx]
            console.clear()
            return selected_model, short_key
