#!/usr/bin/env python3
"""
Dragon-themed calendar popup.

Launched from the waybar clock's on-click. Appears as a small floating
window below the center of the bar via a Hyprland windowrule that
matches on the app-id/class `uy.bruno.calendar`.

Behavior:
- Escape → close
- Click outside (focus lost) → close
- Any action on the calendar is purely cosmetic
"""

import sys

import gi

gi.require_version("Gtk", "4.0")
from gi.repository import Gdk, Gio, GLib, Gtk  # noqa: E402


DRAGON_CSS = b"""
window.dragon-cal {
    background-color: rgba(18, 18, 26, 0.97);
    color: #e8dcc4;
    border: 1px solid rgba(212, 162, 76, 0.45);
    border-radius: 3px;
}

.dragon-cal calendar {
    background: transparent;
    color: #e8dcc4;
    font-family: "JetBrains Mono", "JetBrainsMono Nerd Font Mono", monospace;
    font-size: 13px;
    padding: 8px;
}

.dragon-cal calendar:selected,
.dragon-cal calendar.today {
    background: rgba(232, 184, 90, 0.18);
    color: #e8b85a;
    border-radius: 2px;
}

.dragon-cal calendar.today {
    color: #ff6b3d;
}

.dragon-cal calendar.header {
    color: #e8b85a;
    font-weight: 600;
}

.dragon-cal calendar.button {
    color: #e8b85a;
}

.dragon-cal calendar.day-name {
    color: #a88c5f;
}

.dragon-cal calendar.other-month {
    color: #6b5f4a;
}

.dragon-cal label.title {
    color: #e8b85a;
    font-weight: 600;
    font-size: 12px;
    padding: 4px 2px 0 2px;
}
"""


class CalendarApp(Gtk.Application):
    def __init__(self) -> None:
        super().__init__(
            application_id="uy.bruno.calendar",
            flags=Gio.ApplicationFlags.NON_UNIQUE,
        )

    def do_activate(self) -> None:  # noqa: D401 (GTK convention)
        css = Gtk.CssProvider()
        css.load_from_data(DRAGON_CSS)
        Gtk.StyleContext.add_provider_for_display(
            Gdk.Display.get_default(),
            css,
            Gtk.STYLE_PROVIDER_PRIORITY_APPLICATION,
        )

        win = Gtk.ApplicationWindow(application=self)
        win.set_title("Calendar")
        win.set_default_size(300, 280)
        win.set_decorated(False)
        win.set_resizable(False)
        win.add_css_class("dragon-cal")

        outer = Gtk.Box(orientation=Gtk.Orientation.VERTICAL, spacing=4)
        outer.set_margin_top(8)
        outer.set_margin_bottom(8)
        outer.set_margin_start(8)
        outer.set_margin_end(8)

        title = Gtk.Label()
        title.add_css_class("title")
        title.set_halign(Gtk.Align.CENTER)
        title.set_text(GLib.DateTime.new_now_local().format("%A, %d %B %Y"))
        outer.append(title)

        cal = Gtk.Calendar()
        outer.append(cal)

        win.set_child(outer)

        pending = {"id": 0}
        close_delay_ms = 200

        def cancel_pending():
            if pending["id"]:
                GLib.source_remove(pending["id"])
                pending["id"] = 0

        def do_close():
            pending["id"] = 0
            win.close()
            return GLib.SOURCE_REMOVE

        kc = Gtk.EventControllerKey()

        def on_escape(_ctrl, key, _keycode, _state):
            if key == Gdk.KEY_Escape:
                cancel_pending()
                win.close()
                return True
            return False

        kc.connect("key-pressed", on_escape)
        win.add_controller(kc)

        def on_active_change(w, _pspec):
            if w.is_active():
                cancel_pending()
            elif pending["id"] == 0:
                pending["id"] = GLib.timeout_add(close_delay_ms, do_close)

        win.connect("notify::is-active", on_active_change)

        win.present()


def main() -> int:
    app = CalendarApp()
    return app.run(sys.argv)


if __name__ == "__main__":
    sys.exit(main())
