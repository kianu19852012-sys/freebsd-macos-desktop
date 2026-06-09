#!/usr/bin/env python3
# ============================================================
#  FreeBSD macOS Desktop — First Boot Setup UI
#  Screen 1: Create Account
#  Screen 2: Timezone & Locale
#  Screen 3: Disk Selection & Partitioning
#  Screen 4: Installation Progress
#  Screen 5: Done + Reboot
# ============================================================

import tkinter as tk
from tkinter import ttk
import subprocess
import threading
import time
import sys
import os
import re
import queue

# ---- Install steps ----
STEPS = [
    ("Bootstrapping package manager",    "pkg bootstrap -y",                                                          3),
    ("Updating package index",           "pkg update -f",                                                             2),
    ("Partitioning & formatting disk",   "__PARTITION__",                                                             6),
    ("Installing Intel GPU driver",      "sh /usr/local/src/freebsd-macos/drivers/intel-gpu.sh",                     8),
    ("Installing Intel WiFi driver",     "sh /usr/local/src/freebsd-macos/drivers/intel-wifi.sh",                    5),
    ("Installing desktop packages",      "pkg install -y $(grep -v '^#' /usr/local/src/freebsd-macos/desktop/packages.txt | tr '\\n' ' ')", 30),
    ("Installing WhiteSur theme",        "sh /usr/local/src/freebsd-macos/desktop/whitesur/install.sh",              20),
    ("Deploying desktop configuration",  "sh /usr/local/src/freebsd-macos/firstboot/deploy-configs.sh",              5),
    ("Installing GRUB boot theme",       "sh /usr/local/src/freebsd-macos/grub/install-grub.sh auto",                5),
    ("Applying system settings",         "sh /usr/local/src/freebsd-macos/firstboot/apply-sysconfig.sh",             3),
    ("Finalizing installation",          "touch /var/db/.desktop-installed && sleep 2",                              2),
]
TOTAL_WEIGHT = sum(s[2] for s in STEPS)

# ---- Timezones ----
TIMEZONES = {
    "Africa": [
        ("Cairo (UTC+2)",          "Africa/Cairo"),
        ("Johannesburg (UTC+2)",   "Africa/Johannesburg"),
        ("Lagos (UTC+1)",          "Africa/Lagos"),
        ("Nairobi (UTC+3)",        "Africa/Nairobi"),
    ],
    "Americas": [
        ("Anchorage (UTC-9)",      "America/Anchorage"),
        ("Bogotá (UTC-5)",         "America/Bogota"),
        ("Buenos Aires (UTC-3)",   "America/Argentina/Buenos_Aires"),
        ("Chicago (UTC-6)",        "America/Chicago"),
        ("Denver (UTC-7)",         "America/Denver"),
        ("Los Angeles (UTC-8)",    "America/Los_Angeles"),
        ("Mexico City (UTC-6)",    "America/Mexico_City"),
        ("New York (UTC-5)",       "America/New_York"),
        ("Phoenix (UTC-7)",        "America/Phoenix"),
        ("Santiago (UTC-3)",       "America/Santiago"),
        ("São Paulo (UTC-3)",      "America/Sao_Paulo"),
        ("Toronto (UTC-5)",        "America/Toronto"),
        ("Vancouver (UTC-8)",      "America/Vancouver"),
    ],
    "Asia": [
        ("Bangkok (UTC+7)",        "Asia/Bangkok"),
        ("Beijing (UTC+8)",        "Asia/Shanghai"),
        ("Colombo (UTC+5:30)",     "Asia/Colombo"),
        ("Dubai (UTC+4)",          "Asia/Dubai"),
        ("Hong Kong (UTC+8)",      "Asia/Hong_Kong"),
        ("Jakarta (UTC+7)",        "Asia/Jakarta"),
        ("Jerusalem (UTC+3)",      "Asia/Jerusalem"),
        ("Karachi (UTC+5)",        "Asia/Karachi"),
        ("Kolkata (UTC+5:30)",     "Asia/Kolkata"),
        ("Kuala Lumpur (UTC+8)",   "Asia/Kuala_Lumpur"),
        ("Manila (UTC+8)",         "Asia/Manila"),
        ("Seoul (UTC+9)",          "Asia/Seoul"),
        ("Singapore (UTC+8)",      "Asia/Singapore"),
        ("Taipei (UTC+8)",         "Asia/Taipei"),
        ("Tehran (UTC+3:30)",      "Asia/Tehran"),
        ("Tokyo (UTC+9)",          "Asia/Tokyo"),
    ],
    "Australia & Pacific": [
        ("Adelaide (UTC+9:30)",    "Australia/Adelaide"),
        ("Auckland (UTC+12)",      "Pacific/Auckland"),
        ("Brisbane (UTC+10)",      "Australia/Brisbane"),
        ("Honolulu (UTC-10)",      "Pacific/Honolulu"),
        ("Melbourne (UTC+11)",     "Australia/Melbourne"),
        ("Perth (UTC+8)",          "Australia/Perth"),
        ("Sydney (UTC+11)",        "Australia/Sydney"),
    ],
    "Europe": [
        ("Amsterdam (UTC+2)",      "Europe/Amsterdam"),
        ("Athens (UTC+3)",         "Europe/Athens"),
        ("Berlin (UTC+2)",         "Europe/Berlin"),
        ("Dublin (UTC+1)",         "Europe/Dublin"),
        ("Helsinki (UTC+3)",       "Europe/Helsinki"),
        ("Istanbul (UTC+3)",       "Europe/Istanbul"),
        ("Lisbon (UTC+1)",         "Europe/Lisbon"),
        ("London (UTC+1)",         "Europe/London"),
        ("Madrid (UTC+2)",         "Europe/Madrid"),
        ("Moscow (UTC+3)",         "Europe/Moscow"),
        ("Paris (UTC+2)",          "Europe/Paris"),
        ("Rome (UTC+2)",           "Europe/Rome"),
        ("Stockholm (UTC+2)",      "Europe/Stockholm"),
        ("Warsaw (UTC+2)",         "Europe/Warsaw"),
        ("Zurich (UTC+2)",         "Europe/Zurich"),
    ],
    "UTC": [
        ("UTC (UTC+0)",            "UTC"),
    ],
}

# ---- Locales ----
LOCALES = [
    ("English (US)",          "en_US.UTF-8", "us"),
    ("English (UK)",          "en_GB.UTF-8", "gb"),
    ("English (Australia)",   "en_AU.UTF-8", "us"),
    ("Deutsch (German)",      "de_DE.UTF-8", "de"),
    ("Español (Spanish)",     "es_ES.UTF-8", "es"),
    ("Français (French)",     "fr_FR.UTF-8", "fr"),
    ("Italiano (Italian)",    "it_IT.UTF-8", "it"),
    ("Nederlands (Dutch)",    "nl_NL.UTF-8", "nl"),
    ("Polski (Polish)",       "pl_PL.UTF-8", "pl"),
    ("Português (Brazil)",    "pt_BR.UTF-8", "br"),
    ("Português (Portugal)",  "pt_PT.UTF-8", "pt"),
    ("Русский (Russian)",     "ru_RU.UTF-8", "ru"),
    ("Svenska (Swedish)",     "sv_SE.UTF-8", "se"),
    ("Türkçe (Turkish)",      "tr_TR.UTF-8", "tr"),
    ("中文 (Simplified)",      "zh_CN.UTF-8", "us"),
    ("中文 (Traditional)",     "zh_TW.UTF-8", "us"),
    ("日本語 (Japanese)",       "ja_JP.UTF-8", "us"),
    ("한국어 (Korean)",          "ko_KR.UTF-8", "us"),
]

# ---- Partition schemes ----
PARTITION_SCHEMES = [
    {
        "id":    "erase_zfs",
        "label": "Erase & Install  (ZFS)",
        "icon":  "🗂",
        "desc":  "Erase the entire disk and install FreeBSD macOS Desktop on a ZFS pool.\n"
                 "Recommended for most users. Enables snapshots and data integrity checks.",
        "parts": [
            ("512 MB",  "EFI System Partition",  "FAT32",  "efi"),
            ("4 GB",    "FreeBSD Boot Pool",      "ZFS",    "freebsd-boot"),
            ("Rest",    "ZFS Root Pool  (zroot)", "ZFS",    "freebsd-zfs"),
        ],
    },
    {
        "id":    "erase_ufs",
        "label": "Erase & Install  (UFS)",
        "icon":  "💾",
        "desc":  "Erase the entire disk and install on UFS (Unix File System).\n"
                 "Simpler layout, slightly less overhead, no snapshot support.",
        "parts": [
            ("512 MB",  "EFI System Partition",  "FAT32",  "efi"),
            ("1 GB",    "Boot Partition",         "UFS",    "freebsd-ufs"),
            ("4 GB",    "Swap",                   "SWAP",   "freebsd-swap"),
            ("Rest",    "Root Partition  (/)",    "UFS",    "freebsd-ufs"),
        ],
    },
    {
        "id":    "alongside",
        "label": "Install Alongside Existing OS",
        "icon":  "➕",
        "desc":  "Shrink an existing partition and install FreeBSD in the freed space.\n"
                 "Keeps your current OS. You choose how much space to allocate.",
        "parts": [
            ("Existing", "Your current OS  (untouched)", "—",     "existing"),
            ("512 MB",   "EFI  (shared)",               "FAT32", "efi"),
            ("User",     "FreeBSD macOS Desktop",        "ZFS",   "freebsd-zfs"),
        ],
    },
    {
        "id":    "manual",
        "label": "Manual Partitioning",
        "icon":  "⚙️",
        "desc":  "Advanced: open gpart in a terminal and partition the disk yourself.\n"
                 "For experienced users only. The installer will drop to a shell.",
        "parts": [],
    },
]

# ---- palette ----
BG        = "#f5f5f7"
TEXT_DARK = "#1c1c1e"
TEXT_GRAY = "#6e6e73"
TEXT_MID  = "#3a3a3c"
BLUE      = "#0071e3"
BLUE_DARK = "#0051a2"
BLUE_LITE = "#e8f2fd"
GREEN     = "#34c759"
RED       = "#ff3b30"
ORANGE    = "#ff9f0a"
YELLOW    = "#ffd60a"
CARD_BG   = "#ffffff"
SEP       = "#e5e5ea"
WARN_BG   = "#fff3cd"
WARN_BD   = "#f5a623"

FONT_TITLE  = ("Inter", 26, "bold")
FONT_SUB    = ("Inter", 13)
FONT_LABEL  = ("Inter", 12)
FONT_INPUT  = ("Inter", 14)
FONT_SMALL  = ("Inter", 11)
FONT_HINT   = ("Inter", 10)
FONT_BTN    = ("Inter", 13, "bold")
FONT_LOGO   = ("SF Pro Display", 64)
FONT_STEP   = ("Inter", 13)
FONT_STEP_A = ("Inter", 13, "bold")
FONT_PCT    = ("Inter", 13, "bold")
FONT_LOG    = ("Monaco", 9)
FONT_DONE   = ("Inter", 72)
FONT_DONE_T = ("Inter", 30, "bold")
FONT_CD     = ("Inter", 44, "bold")
FONT_LIST   = ("Inter", 12)
FONT_SCHEME = ("Inter", 13, "bold")
FONT_SCHEME_D = ("Inter", 11)
FONT_DISK   = ("Inter", 12)
FONT_DISK_B = ("Inter", 12, "bold")
FONT_MONO   = ("Monaco", 11)


class SetupApp:
    def __init__(self, root):
        self.root = root
        self.root.title("FreeBSD macOS Desktop — Setup")
        self.root.configure(bg=BG)
        self.root.attributes("-fullscreen", True)
        self.root.resizable(False, False)
        self.root.protocol("WM_DELETE_WINDOW", lambda: None)

        self.W = self.root.winfo_screenwidth()
        self.H = self.root.winfo_screenheight()

        self.user_info   = {}
        self.locale_info = {"timezone": "UTC", "locale": "en_US.UTF-8", "keymap": "us"}
        self.disk_info   = {"disk": "", "scheme": "erase_zfs", "swap_gb": 4,
                            "alongside_gb": 40, "confirm": False}
        self.log_queue   = queue.Queue()
        self._clock_job  = None

        self._show_user_creation()

    # ================================================================
    #  Shared helpers
    # ================================================================
    def _clear(self):
        if self._clock_job:
            try: self.root.after_cancel(self._clock_job)
            except: pass
            self._clock_job = None
        for w in self.root.winfo_children():
            w.destroy()

    def _footer(self):
        tk.Label(self.root,
                 text="FreeBSD macOS Desktop  •  First Boot Setup",
                 font=FONT_HINT, bg=BG, fg=TEXT_GRAY
                 ).place(relx=0.5, rely=0.975, anchor="center")

    def _nav_buttons(self, back_cmd=None, next_label="Continue →", next_cmd=None,
                     next_color=BLUE, rely=0.905):
        frame = tk.Frame(self.root, bg=BG)
        frame.place(relx=0.5, rely=rely, anchor="center")

        if back_cmd:
            b = tk.Button(frame, text="← Back", font=FONT_BTN,
                          bg=SEP, fg=TEXT_MID,
                          activebackground="#d1d1d6", activeforeground=TEXT_DARK,
                          bd=0, relief="flat", padx=22, pady=11,
                          cursor="hand2", command=back_cmd)
            b.pack(side="left", padx=(0, 12))
            b.bind("<Enter>", lambda e: b.config(bg="#d1d1d6"))
            b.bind("<Leave>", lambda e: b.config(bg=SEP))

        btn = tk.Button(frame, text=next_label, font=FONT_BTN,
                        bg=next_color, fg="white",
                        activebackground=BLUE_DARK, activeforeground="white",
                        bd=0, relief="flat", padx=28, pady=12,
                        cursor="hand2", command=next_cmd)
        btn.pack(side="left")
        btn.bind("<Enter>", lambda e: btn.config(bg=BLUE_DARK))
        btn.bind("<Leave>", lambda e: btn.config(bg=next_color))
        return btn

    def _progress_dots(self, active, total=4):
        frame = tk.Frame(self.root, bg=BG)
        frame.place(relx=0.5, rely=0.948, anchor="center")
        for i in range(1, total + 1):
            size  = 10 if i == active else 7
            color = BLUE if i == active else "#d1d1d6"
            c = tk.Canvas(frame, width=size, height=size, bg=BG, highlightthickness=0)
            c.pack(side="left", padx=4)
            c.create_oval(0, 0, size, size, fill=color, outline="")

    def _section_title(self, parent, text, rely=None):
        lbl = tk.Label(parent if rely is None else self.root,
                       text=text, font=("Inter", 13, "bold"),
                       bg=BG, fg=TEXT_DARK)
        if rely is not None:
            lbl.place(relx=0.5, rely=rely, anchor="center")
        else:
            lbl.pack(anchor="w", pady=(0, 6))
        return lbl

    # ================================================================
    #  SCREEN 1 — Create Account
    # ================================================================
    def _show_user_creation(self):
        self._clear()

        frame = tk.Frame(self.root, bg=BG)
        frame.place(relx=0.5, rely=0.45, anchor="center")

        tk.Label(frame, text="🐡", font=FONT_LOGO, bg=BG).pack(pady=(0, 4))
        tk.Label(frame, text="Create Your Account",
                 font=FONT_TITLE, bg=BG, fg=TEXT_DARK).pack()
        tk.Label(frame, text="This will be the main user on your FreeBSD macOS Desktop.",
                 font=FONT_SUB, bg=BG, fg=TEXT_GRAY).pack(pady=(4, 18))

        card = tk.Frame(frame, bg=CARD_BG, highlightthickness=1, highlightbackground=SEP)
        card.pack(ipadx=28, ipady=16)

        def field(parent, label, var, show="", hint=""):
            row = tk.Frame(parent, bg=CARD_BG); row.pack(fill="x", pady=6)
            tk.Label(row, text=label, font=FONT_LABEL, bg=CARD_BG, fg=TEXT_MID, anchor="w").pack(fill="x")
            e = tk.Entry(row, textvariable=var, show=show,
                         font=FONT_INPUT, bg=CARD_BG, fg=TEXT_DARK,
                         bd=0, highlightthickness=2,
                         highlightbackground=SEP, highlightcolor=BLUE,
                         insertbackground=BLUE, relief="flat", width=30)
            e.pack(fill="x", ipady=7, pady=(3, 0))
            if hint:
                tk.Label(row, text=hint, font=FONT_HINT, bg=CARD_BG, fg=TEXT_GRAY, anchor="w").pack(fill="x", pady=(2,0))
            return e

        self._v_fn = tk.StringVar(); self._v_un = tk.StringVar()
        self._v_pw = tk.StringVar(); self._v_cf = tk.StringVar()

        def on_name(*_):
            parts = self._v_fn.get().strip().lower().split()
            self._v_un.set(re.sub(r'[^a-z0-9]', '', parts[0])[:16] if parts else '')

        self._v_fn.trace_add("write", on_name)

        e_full = field(card, "Full Name",        self._v_fn, hint="e.g. John Appleseed")
        field(card, "Username",         self._v_un, hint="Lowercase letters and numbers, max 16 chars")
        field(card, "Password",         self._v_pw, show="•")
        field(card, "Confirm Password", self._v_cf, show="•")

        # Strength
        sb = tk.Frame(card, bg=CARD_BG); sb.pack(fill="x", pady=(2,0))
        tk.Label(sb, text="Strength:", font=FONT_HINT, bg=CARD_BG, fg=TEXT_GRAY).pack(side="left")
        track = tk.Frame(sb, bg=SEP, width=120, height=4); track.pack(side="left", padx=6, pady=4)
        track.pack_propagate(False)
        self._sf = tk.Frame(track, bg=SEP, width=0, height=4); self._sf.place(x=0, y=0)
        self._sl = tk.Label(sb, text="", font=FONT_HINT, bg=CARD_BG, fg=TEXT_GRAY); self._sl.pack(side="left")

        def on_pw(*_):
            pw = self._v_pw.get()
            score = sum([len(pw)>=8, len(pw)>=12, bool(re.search(r'[A-Z]',pw)),
                         bool(re.search(r'[0-9]',pw)), bool(re.search(r'[^a-zA-Z0-9]',pw))])
            colors = ["", RED, ORANGE, ORANGE, GREEN, GREEN]
            labels = ["", "Weak", "Fair", "Fair", "Good", "Strong"]
            w = int(120 * score / 5)
            self._sf.place(x=0, y=0, width=w, height=4)
            self._sf.config(bg=colors[score] if score else SEP)
            self._sl.config(text=labels[score], fg=colors[score] if score else TEXT_GRAY)
        self._v_pw.trace_add("write", on_pw)

        self._err1 = tk.Label(card, text="", font=FONT_SMALL, bg=CARD_BG, fg=RED)
        self._err1.pack(pady=(4,0))

        def proceed():
            fn=self._v_fn.get().strip(); un=self._v_un.get().strip().lower()
            pw=self._v_pw.get();         cf=self._v_cf.get()
            if not fn: return self._err1.config(text="⚠  Please enter your full name.")
            if not un or not re.match(r'^[a-z][a-z0-9]{0,15}$', un):
                return self._err1.config(text="⚠  Username must start with a letter, lowercase/numbers only.")
            if len(pw) < 6: return self._err1.config(text="⚠  Password must be at least 6 characters.")
            if pw != cf:    return self._err1.config(text="⚠  Passwords do not match.")
            self._err1.config(text="")
            self.user_info = {"fullname": fn, "username": un, "password": pw}
            self.root.unbind("<Return>")
            self._show_timezone_locale()

        self.root.bind("<Return>", lambda e: proceed())
        self._nav_buttons(next_cmd=proceed)
        self._progress_dots(active=1)
        self._footer()
        e_full.focus_set()

    # ================================================================
    #  SCREEN 2 — Timezone & Locale
    # ================================================================
    def _show_timezone_locale(self):
        self._clear()

        tk.Label(self.root, text="Time Zone & Language",
                 font=FONT_TITLE, bg=BG, fg=TEXT_DARK).place(relx=0.5, rely=0.09, anchor="center")
        tk.Label(self.root, text="Choose your region and preferred language.",
                 font=FONT_SUB, bg=BG, fg=TEXT_GRAY).place(relx=0.5, rely=0.15, anchor="center")

        cols = tk.Frame(self.root, bg=BG)
        cols.place(relx=0.5, rely=0.53, anchor="center")

        # ---- LEFT: Timezone ----
        tz_f = tk.Frame(cols, bg=BG); tz_f.pack(side="left", padx=(0,20), anchor="n")
        tk.Label(tz_f, text="Time Zone", font=("Inter",13,"bold"), bg=BG, fg=TEXT_DARK).pack(anchor="w", pady=(0,6))

        rr = tk.Frame(tz_f, bg=BG); rr.pack(fill="x", pady=(0,8))
        tk.Label(rr, text="Region", font=FONT_LABEL, bg=BG, fg=TEXT_GRAY).pack(anchor="w")
        self._v_region = tk.StringVar(value="Americas")
        reg_menu = ttk.Combobox(rr, textvariable=self._v_region,
                                values=sorted(TIMEZONES.keys()),
                                state="readonly", font=FONT_LIST, width=24)
        reg_menu.pack(fill="x", pady=(3,0))

        tk.Label(tz_f, text="City", font=FONT_LABEL, bg=BG, fg=TEXT_GRAY).pack(anchor="w", pady=(4,2))
        tz_lf = tk.Frame(tz_f, bg=CARD_BG, highlightthickness=1, highlightbackground=SEP)
        tz_lf.pack()
        tz_sc = tk.Scrollbar(tz_lf, orient="vertical")
        self._tz_lb = tk.Listbox(tz_lf, font=FONT_LIST, bg=CARD_BG, fg=TEXT_DARK,
                                  selectbackground=BLUE, selectforeground="white",
                                  activestyle="none", relief="flat", bd=0,
                                  width=28, height=10, yscrollcommand=tz_sc.set)
        tz_sc.config(command=self._tz_lb.yview)
        self._tz_lb.pack(side="left"); tz_sc.pack(side="right", fill="y")
        self._tz_sel_lbl = tk.Label(tz_f, text="", font=("Inter",11), bg=BG, fg=BLUE, anchor="w")
        self._tz_sel_lbl.pack(anchor="w", pady=(5,0))

        def pop_cities(*_):
            region = self._v_region.get()
            self._tz_lb.delete(0,"end")
            for d,_ in TIMEZONES.get(region,[]):
                self._tz_lb.insert("end", f"  {d}")
            self._tz_lb.selection_set(0); on_tz()

        def on_tz(*_):
            region=self._v_region.get(); sel=self._tz_lb.curselection()
            if not sel: return
            _,zone = TIMEZONES[region][sel[0]]
            self.locale_info["timezone"]=zone
            self._tz_sel_lbl.config(text=f"✓  {zone}")

        self._v_region.trace_add("write", pop_cities)
        self._tz_lb.bind("<<ListboxSelect>>", on_tz)
        pop_cities()

        # ---- RIGHT: Locale ----
        lc_f = tk.Frame(cols, bg=BG); lc_f.pack(side="left", anchor="n")
        tk.Label(lc_f, text="Language & Keyboard", font=("Inter",13,"bold"), bg=BG, fg=TEXT_DARK).pack(anchor="w", pady=(0,6))
        tk.Label(lc_f, text="Language / Locale", font=FONT_LABEL, bg=BG, fg=TEXT_GRAY).pack(anchor="w", pady=(4,2))

        lc_lf = tk.Frame(lc_f, bg=CARD_BG, highlightthickness=1, highlightbackground=SEP); lc_lf.pack()
        lc_sc = tk.Scrollbar(lc_lf, orient="vertical")
        self._lc_lb = tk.Listbox(lc_lf, font=FONT_LIST, bg=CARD_BG, fg=TEXT_DARK,
                                  selectbackground=BLUE, selectforeground="white",
                                  activestyle="none", relief="flat", bd=0,
                                  width=26, height=10, yscrollcommand=lc_sc.set)
        lc_sc.config(command=self._lc_lb.yview)
        self._lc_lb.pack(side="left"); lc_sc.pack(side="right", fill="y")

        for d,_,_ in LOCALES: self._lc_lb.insert("end", f"  {d}")
        self._lc_lb.selection_set(0)

        self._lc_sel_lbl = tk.Label(lc_f, text="", font=("Inter",11), bg=BG, fg=BLUE, anchor="w")
        self._lc_sel_lbl.pack(anchor="w", pady=(5,0))

        tk.Label(lc_f, text="Keyboard Layout", font=FONT_LABEL, bg=BG, fg=TEXT_GRAY).pack(anchor="w", pady=(12,2))
        self._km_lbl = tk.Label(lc_f, text="us", font=FONT_MONO, bg=CARD_BG, fg=TEXT_DARK,
                                 highlightthickness=1, highlightbackground=SEP, padx=12, pady=8)
        self._km_lbl.pack(anchor="w")
        tk.Label(lc_f, text="Auto-set from language.", font=FONT_HINT, bg=BG, fg=TEXT_GRAY).pack(anchor="w", pady=(3,0))

        def on_lc(*_):
            sel=self._lc_lb.curselection()
            if not sel: return
            _,lc,km = LOCALES[sel[0]]
            self.locale_info["locale"]=lc; self.locale_info["keymap"]=km
            self._lc_sel_lbl.config(text=f"✓  {lc}"); self._km_lbl.config(text=km)
        self._lc_lb.bind("<<ListboxSelect>>", on_lc); on_lc()

        # Clock
        clk_f = tk.Frame(self.root, bg=BG)
        clk_f.place(relx=0.5, rely=0.875, anchor="center")
        self._clk_lbl = tk.Label(clk_f, text="", font=("Inter",14), bg=BG, fg=TEXT_GRAY)
        self._clk_lbl.pack()
        self._tick_clock()

        def go_back():
            if self._clock_job: self.root.after_cancel(self._clock_job)
            self._show_user_creation()
        def go_next():
            if self._clock_job: self.root.after_cancel(self._clock_job)
            self._show_disk_picker()

        self._nav_buttons(back_cmd=go_back, next_cmd=go_next)
        self._progress_dots(active=2)
        self._footer()

    def _tick_clock(self):
        import datetime
        now = datetime.datetime.now().strftime("%A, %B %-d  •  %H:%M:%S")
        tz  = self.locale_info.get("timezone","UTC")
        self._clk_lbl.config(text=f"🕐  {now}  ({tz})")
        self._clock_job = self.root.after(1000, self._tick_clock)

    # ================================================================
    #  SCREEN 3 — Disk Selection & Partitioning
    # ================================================================
    def _show_disk_picker(self):
        self._clear()

        tk.Label(self.root, text="Installation Disk",
                 font=FONT_TITLE, bg=BG, fg=TEXT_DARK).place(relx=0.5, rely=0.07, anchor="center")
        tk.Label(self.root, text="Choose where to install FreeBSD macOS Desktop.",
                 font=FONT_SUB, bg=BG, fg=TEXT_GRAY).place(relx=0.5, rely=0.125, anchor="center")

        # ---- Two-column layout ----
        cols = tk.Frame(self.root, bg=BG)
        cols.place(relx=0.5, rely=0.52, anchor="center")

        # ==============================
        # LEFT — Disk list
        # ==============================
        left = tk.Frame(cols, bg=BG); left.pack(side="left", padx=(0,20), anchor="n")
        tk.Label(left, text="Available Disks", font=("Inter",13,"bold"),
                 bg=BG, fg=TEXT_DARK).pack(anchor="w", pady=(0,8))

        disk_list_f = tk.Frame(left, bg=CARD_BG, highlightthickness=1, highlightbackground=SEP)
        disk_list_f.pack()

        disk_scroll = tk.Scrollbar(disk_list_f, orient="vertical")
        self._disk_lb = tk.Listbox(
            disk_list_f, font=FONT_DISK, bg=CARD_BG, fg=TEXT_DARK,
            selectbackground=BLUE, selectforeground="white",
            activestyle="none", relief="flat", bd=0,
            width=30, height=8, yscrollcommand=disk_scroll.set
        )
        disk_scroll.config(command=self._disk_lb.yview)
        self._disk_lb.pack(side="left", fill="both"); disk_scroll.pack(side="right", fill="y")

        # Disk info label below the list
        self._disk_info_lbl = tk.Label(
            left, text="Select a disk to see details.",
            font=FONT_HINT, bg=BG, fg=TEXT_GRAY,
            anchor="w", justify="left", wraplength=260
        )
        self._disk_info_lbl.pack(anchor="w", pady=(6,0))

        # Disk visual bar
        self._disk_bar_canvas = tk.Canvas(left, height=28, width=260,
                                           bg=BG, highlightthickness=0)
        self._disk_bar_canvas.pack(anchor="w", pady=(4,0))

        # Refresh button
        ref_btn = tk.Button(left, text="⟳  Refresh Disks", font=FONT_HINT,
                            bg=SEP, fg=TEXT_MID, bd=0, relief="flat",
                            padx=10, pady=5, cursor="hand2",
                            command=self._refresh_disks)
        ref_btn.pack(anchor="w", pady=(8,0))

        # ==============================
        # RIGHT — Partition scheme
        # ==============================
        right = tk.Frame(cols, bg=BG); right.pack(side="left", anchor="n")
        tk.Label(right, text="Partition Scheme", font=("Inter",13,"bold"),
                 bg=BG, fg=TEXT_DARK).pack(anchor="w", pady=(0,8))

        self._scheme_var = tk.StringVar(value="erase_zfs")
        self._scheme_frames = {}

        for scheme in PARTITION_SCHEMES:
            sf = tk.Frame(right, bg=CARD_BG, highlightthickness=2,
                          highlightbackground=SEP, cursor="hand2")
            sf.pack(fill="x", pady=4, ipadx=10, ipady=8)
            self._scheme_frames[scheme["id"]] = sf

            top = tk.Frame(sf, bg=CARD_BG); top.pack(fill="x")
            rb = tk.Radiobutton(top, variable=self._scheme_var, value=scheme["id"],
                                bg=CARD_BG, activebackground=CARD_BG,
                                command=lambda sid=scheme["id"]: self._select_scheme(sid))
            rb.pack(side="left")
            tk.Label(top, text=f"{scheme['icon']}  {scheme['label']}",
                     font=FONT_SCHEME, bg=CARD_BG, fg=TEXT_DARK).pack(side="left")

            tk.Label(sf, text=scheme["desc"],
                     font=FONT_SCHEME_D, bg=CARD_BG, fg=TEXT_GRAY,
                     anchor="w", justify="left", wraplength=280).pack(anchor="w", padx=24, pady=(2,0))

            sf.bind("<Button-1>", lambda e, sid=scheme["id"]: self._select_scheme(sid))

        # Scheme detail / partition table
        tk.Label(right, text="Partition Layout", font=("Inter",12,"bold"),
                 bg=BG, fg=TEXT_DARK).pack(anchor="w", pady=(12,4))
        self._part_frame = tk.Frame(right, bg=BG); self._part_frame.pack(anchor="w")

        # Options (swap size / alongside size)
        self._opts_frame = tk.Frame(right, bg=BG); self._opts_frame.pack(anchor="w", pady=(8,0))

        # Initialise
        self._disks = []
        self._refresh_disks()
        self._select_scheme("erase_zfs")

        # ==============================
        # Warning banner (shown when erase selected)
        # ==============================
        self._warn_frame = tk.Frame(self.root, bg=WARN_BG,
                                     highlightthickness=1, highlightbackground=WARN_BD)
        self._warn_lbl = tk.Label(self._warn_frame,
                                   text="⚠️  This will ERASE ALL DATA on the selected disk. Make sure you have a backup.",
                                   font=("Inter", 11, "bold"), bg=WARN_BG, fg="#7d4e00",
                                   padx=14, pady=8)
        self._warn_lbl.pack()
        self._warn_frame.place(relx=0.5, rely=0.895, anchor="center")

        def on_disk_select(*_):
            sel = self._disk_lb.curselection()
            if not sel or not self._disks: return
            disk = self._disks[sel[0]]
            self.disk_info["disk"] = disk["dev"]
            info = (f"{disk['dev']}  —  {disk['size']}  "
                    f"({disk.get('model','Unknown model')})")
            self._disk_info_lbl.config(text=info)
            self._draw_disk_bar(disk)

        self._disk_lb.bind("<<ListboxSelect>>", on_disk_select)

        def go_back(): self._show_timezone_locale()
        def go_next():
            if not self.disk_info.get("disk"):
                self._warn_lbl.config(text="⚠️  Please select a disk first.", fg=RED,
                                       bg=WARN_BG)
                return
            self._show_install_progress()

        self._nav_buttons(back_cmd=go_back, next_cmd=go_next,
                          next_label="Erase & Install →",
                          next_color=RED if "erase" in self._scheme_var.get() else BLUE,
                          rely=0.935)
        self._progress_dots(active=3)
        self._footer()

    def _refresh_disks(self):
        """Probe real disks via geom / lsblk fallback."""
        self._disks = []
        self._disk_lb.delete(0, "end")

        try:
            # Try FreeBSD geom
            out = subprocess.check_output(
                ["geom", "disk", "list"], text=True, stderr=subprocess.DEVNULL
            )
            current = {}
            for line in out.splitlines():
                line = line.strip()
                if line.startswith("Geom name:"):
                    if current: self._disks.append(current)
                    current = {"dev": "/dev/" + line.split(":")[-1].strip()}
                elif "Mediasize:" in line:
                    size_b = int(re.search(r'\d+', line).group())
                    current["size"] = self._fmt_size(size_b)
                    current["size_b"] = size_b
                elif "descr:" in line.lower():
                    current["model"] = line.split(":",1)[-1].strip()
            if current: self._disks.append(current)
        except Exception:
            pass

        # Fallback — lsblk (Linux / Docker test env)
        if not self._disks:
            try:
                out = subprocess.check_output(
                    ["lsblk", "-d", "-o", "NAME,SIZE,MODEL", "--bytes", "--noheadings"],
                    text=True, stderr=subprocess.DEVNULL
                )
                for line in out.splitlines():
                    parts = line.split(None, 2)
                    if not parts: continue
                    name = parts[0]
                    if name in ("loop", "sr") or name.startswith("loop"): continue
                    size_b = int(parts[1]) if len(parts) > 1 else 0
                    model  = parts[2].strip() if len(parts) > 2 else "Unknown"
                    self._disks.append({
                        "dev": f"/dev/{name}",
                        "size": self._fmt_size(size_b),
                        "size_b": size_b,
                        "model": model,
                    })
            except Exception:
                pass

        # Demo fallback (no real disks found — ISO/VM without disks visible)
        if not self._disks:
            self._disks = [
                {"dev": "/dev/ada0", "size": "256 GB", "size_b": 256*10**9, "model": "Demo Disk (no real disk detected)"},
                {"dev": "/dev/ada1", "size": "512 GB", "size_b": 512*10**9, "model": "Demo Disk 2"},
            ]

        for d in self._disks:
            self._disk_lb.insert("end",
                f"  {d['dev']}   {d['size']:>8}   {d.get('model','')[:22]}")

        # Auto-select first
        if self._disks:
            self._disk_lb.selection_set(0)
            self.disk_info["disk"] = self._disks[0]["dev"]
            self._disk_info_lbl.config(
                text=f"{self._disks[0]['dev']}  —  {self._disks[0]['size']}  "
                     f"({self._disks[0].get('model','Unknown')})"
            )
            self._draw_disk_bar(self._disks[0])

    def _fmt_size(self, b):
        for unit in ["B","KB","MB","GB","TB"]:
            if b < 1000: return f"{b:.0f} {unit}"
            b /= 1000
        return f"{b:.1f} PB"

    def _draw_disk_bar(self, disk):
        """Draw a visual partition bar for the selected disk + scheme."""
        c = self._disk_bar_canvas; c.delete("all")
        W = 260; H = 28; r = 5
        scheme_id = self._scheme_var.get()
        scheme    = next(s for s in PARTITION_SCHEMES if s["id"] == scheme_id)

        if not scheme["parts"]:
            c.create_text(W//2, H//2, text="Manual — no auto layout", fill=TEXT_GRAY, font=FONT_HINT)
            return

        COLORS = ["#0071e3","#34c759","#ff9f0a","#ff3b30","#af52de","#5ac8fa","#ffcc00"]
        total_parts = len(scheme["parts"])
        seg_w = W // total_parts
        x = 0
        for i, (size, label, fs, _) in enumerate(scheme["parts"]):
            color = COLORS[i % len(COLORS)]
            is_last = (i == total_parts - 1)
            w = W - x if is_last else seg_w
            # Rounded ends on first/last
            c.create_rectangle(x, 2, x+w, H-2, fill=color, outline="")
            short = label.split("(")[0].strip()[:12]
            if w > 40:
                c.create_text(x + w//2, H//2, text=short, fill="white",
                               font=("Inter",8,"bold"), anchor="center")
            x += w

    def _select_scheme(self, sid):
        self._scheme_var.set(sid)
        # Highlight selected card
        for k, f in self._scheme_frames.items():
            f.config(highlightbackground=BLUE if k == sid else SEP,
                     highlightthickness=2 if k == sid else 1,
                     bg=BLUE_LITE if k == sid else CARD_BG)
            for child in f.winfo_children():
                child.config(bg=BLUE_LITE if k == sid else CARD_BG)
                for grandchild in child.winfo_children():
                    try: grandchild.config(bg=BLUE_LITE if k == sid else CARD_BG)
                    except: pass

        # Update partition table
        for w in self._part_frame.winfo_children(): w.destroy()
        for w in self._opts_frame.winfo_children(): w.destroy()

        scheme = next(s for s in PARTITION_SCHEMES if s["id"] == sid)

        if scheme["parts"]:
            # Header
            hdr = tk.Frame(self._part_frame, bg=BG); hdr.pack(fill="x")
            for col, width in [("Size",7),("Partition",20),("Format",8)]:
                tk.Label(hdr, text=col, font=("Inter",10,"bold"),
                         bg=BG, fg=TEXT_GRAY, width=width, anchor="w").pack(side="left")

            for size, label, fs, _ in scheme["parts"]:
                row = tk.Frame(self._part_frame, bg=BG); row.pack(fill="x", pady=1)
                tk.Label(row, text=size,  font=FONT_MONO,  bg=BG, fg=TEXT_DARK, width=7,  anchor="w").pack(side="left")
                tk.Label(row, text=label, font=FONT_LABEL, bg=BG, fg=TEXT_DARK, width=20, anchor="w").pack(side="left")
                tk.Label(row, text=fs,    font=FONT_MONO,  bg=BG, fg=BLUE,      width=8,  anchor="w").pack(side="left")
        else:
            tk.Label(self._part_frame,
                     text="A shell will open for manual partitioning.",
                     font=FONT_HINT, bg=BG, fg=TEXT_GRAY).pack(anchor="w")

        # Extra options
        if sid == "erase_zfs" or sid == "erase_ufs":
            r = tk.Frame(self._opts_frame, bg=BG); r.pack(fill="x", pady=(4,0))
            tk.Label(r, text="Swap size (GB):", font=FONT_LABEL, bg=BG, fg=TEXT_GRAY).pack(side="left")
            self._v_swap = tk.IntVar(value=self.disk_info.get("swap_gb", 4))
            sb = tk.Spinbox(r, from_=0, to=32, increment=1, textvariable=self._v_swap,
                            font=FONT_LABEL, width=4, bd=0, relief="flat",
                            bg=CARD_BG, fg=TEXT_DARK, highlightthickness=1,
                            highlightbackground=SEP)
            sb.pack(side="left", padx=8)
            tk.Label(r, text="(0 = none)", font=FONT_HINT, bg=BG, fg=TEXT_GRAY).pack(side="left")
            self._v_swap.trace_add("write", lambda *_: self.disk_info.update({"swap_gb": self._v_swap.get()}))

        elif sid == "alongside":
            r = tk.Frame(self._opts_frame, bg=BG); r.pack(fill="x", pady=(4,0))
            tk.Label(r, text="FreeBSD partition size (GB):", font=FONT_LABEL, bg=BG, fg=TEXT_GRAY).pack(side="left")
            self._v_aside = tk.IntVar(value=self.disk_info.get("alongside_gb", 40))
            sb = tk.Spinbox(r, from_=20, to=500, increment=10, textvariable=self._v_aside,
                            font=FONT_LABEL, width=5, bd=0, relief="flat",
                            bg=CARD_BG, fg=TEXT_DARK, highlightthickness=1,
                            highlightbackground=SEP)
            sb.pack(side="left", padx=8)
            tk.Label(r, text="GB minimum 20 GB", font=FONT_HINT, bg=BG, fg=TEXT_GRAY).pack(side="left")
            self._v_aside.trace_add("write", lambda *_: self.disk_info.update({"alongside_gb": self._v_aside.get()}))

        self.disk_info["scheme"] = sid

        # Redraw bar
        sel = self._disk_lb.curselection()
        if sel and self._disks:
            self._draw_disk_bar(self._disks[sel[0]])

        # Update warning banner
        if hasattr(self, '_warn_lbl'):
            if "erase" in sid:
                self._warn_lbl.config(
                    text="⚠️  This will ERASE ALL DATA on the selected disk. Make sure you have a backup.",
                    fg="#7d4e00", bg=WARN_BG)
                self._warn_frame.config(bg=WARN_BG)
            elif sid == "alongside":
                self._warn_lbl.config(
                    text="ℹ️  Your existing OS will be kept. Ensure you have at least 40 GB free.",
                    fg="#1c4a7d", bg="#d6eaf8")
                self._warn_frame.config(bg="#d6eaf8")
            else:
                self._warn_lbl.config(
                    text="ℹ️  Manual partitioning — use gpart to set up your disk layout.",
                    fg=TEXT_GRAY, bg=BG)
                self._warn_frame.config(bg=BG)

    # ================================================================
    #  SCREEN 4 — Install Progress
    # ================================================================
    def _show_install_progress(self):
        self._clear()

        tk.Label(self.root, text="🐡", font=FONT_LOGO, bg=BG).place(relx=0.5, rely=0.17, anchor="center")
        tk.Label(self.root, text="Setting Up Your System",
                 font=FONT_TITLE, bg=BG, fg=TEXT_DARK).place(relx=0.5, rely=0.29, anchor="center")

        first = self.user_info.get("fullname","").split()[0]
        disk  = self.disk_info.get("disk","?")
        tz    = self.locale_info.get("timezone","UTC")
        tk.Label(self.root,
                 text=f"Welcome, {first}!  Installing to {disk}  •  {tz}",
                 font=FONT_SUB, bg=BG, fg=TEXT_GRAY).place(relx=0.5, rely=0.36, anchor="center")

        bar_w = min(480, int(self.W * 0.42))
        tk.Frame(self.root, bg=SEP, height=6, width=bar_w).place(relx=0.5, rely=0.47, anchor="center")
        self._bar_fill = tk.Frame(self.root, bg=BLUE, height=6, width=0)
        self._bar_fill.place(relx=0.5, rely=0.47, x=-(bar_w//2), anchor="w", width=0, height=6)
        self._bar_w = bar_w

        self._pct_lbl = tk.Label(self.root, text="0%", font=FONT_PCT, bg=BG, fg=BLUE)
        self._pct_lbl.place(relx=0.5, rely=0.52, anchor="center")
        self._step_lbl = tk.Label(self.root, text="Starting…", font=FONT_STEP, bg=BG, fg=TEXT_GRAY)
        self._step_lbl.place(relx=0.5, rely=0.57, anchor="center")

        card_w = min(520, int(self.W * 0.46))
        card = tk.Frame(self.root, bg=CARD_BG, highlightthickness=1, highlightbackground=SEP)
        card.place(relx=0.5, rely=0.755, anchor="center", width=card_w)
        self._step_rows = []
        for name,_,_ in STEPS:
            row = tk.Frame(card, bg=CARD_BG); row.pack(fill="x", padx=18, pady=2)
            icon = tk.Label(row, text="○", font=FONT_STEP, bg=CARD_BG, fg="#c7c7cc", width=2); icon.pack(side="left")
            lbl  = tk.Label(row, text=name, font=FONT_STEP, bg=CARD_BG, fg="#8e8e93", anchor="w"); lbl.pack(side="left", fill="x", expand=True)
            self._step_rows.append((icon, lbl))

        log_f = tk.Frame(self.root, bg="#1c1c1e")
        log_f.place(relx=0.5, rely=0.965, anchor="center", width=self.W*0.9, height=48)
        self._log_text = tk.Text(log_f, bg="#1c1c1e", fg="#8e8e93", font=FONT_LOG,
                                  bd=0, highlightthickness=0, wrap="word", state="disabled")
        self._log_text.pack(fill="both", expand=True, padx=10, pady=5)

        self._poll_log()
        threading.Thread(target=self._run_install, daemon=True).start()

    def _update_bar(self, dw):
        pct=min(100,int(dw/TOTAL_WEIGHT*100)); fw=max(0,int(self._bar_w*pct/100))
        self._bar_fill.place(relx=0.5,rely=0.47,x=-(self._bar_w//2),anchor="w",width=fw,height=6)
        self._pct_lbl.config(text=f"{pct}%")

    def _set_step(self, idx, state):
        icon, lbl = self._step_rows[idx]
        if   state=="pending": icon.config(text="○",fg="#c7c7cc"); lbl.config(fg="#8e8e93",font=FONT_STEP)
        elif state=="active":  icon.config(text="◉",fg=BLUE);      lbl.config(fg=TEXT_DARK,font=FONT_STEP_A)
        elif state=="done":    icon.config(text="✓",fg=GREEN);     lbl.config(fg=TEXT_GRAY,font=FONT_STEP)
        elif state=="error":   icon.config(text="✗",fg=RED);       lbl.config(fg=RED,font=FONT_STEP)

    def _log(self, line):
        self._log_text.config(state="normal")
        self._log_text.insert("end", line+"\n"); self._log_text.see("end")
        self._log_text.config(state="disabled")

    def _poll_log(self):
        try:
            while True:
                msg=self.log_queue.get_nowait(); t=msg[0]
                if   t=="log":        self._log(msg[1])
                elif t=="step_start": self._set_step(msg[1],"active"); self._step_lbl.config(text=STEPS[msg[1]][0]+"…")
                elif t=="step_done":  self._set_step(msg[1],"done" if msg[2] else "error")
                elif t=="progress":   self._update_bar(msg[1])
                elif t=="complete":   self._show_done(); return
        except queue.Empty: pass
        self.root.after(80, self._poll_log)

    def _run_install(self):
        info=self.user_info; lc=self.locale_info; di=self.disk_info
        q=self.log_queue

        # 1. Create user
        q.put(("log",f"Creating user: {info['username']} ({info['fullname']})"))
        for cmd in [
            f"pw useradd -n {info['username']} -c \"{info['fullname']}\" -m -s /usr/local/bin/bash -G wheel",
            f"printf '%s\\n%s\\n' '{info['password']}' '{info['password']}' | pw usermod {info['username']} -h 0",
        ]: subprocess.run(cmd,shell=True,check=False,capture_output=True)
        q.put(("log",f"User '{info['username']}' created."))

        # 2. Timezone
        q.put(("log",f"Setting timezone: {lc['timezone']}"))
        subprocess.run(f"ln -sf /usr/share/zoneinfo/{lc['timezone']} /etc/localtime",shell=True,check=False)
        with open("/etc/timezone","w") as f: f.write(lc["timezone"]+"\n")

        # 3. Locale
        q.put(("log",f"Setting locale: {lc['locale']} / keymap: {lc['keymap']}"))
        os.makedirs("/etc/profile.d",exist_ok=True)
        with open("/etc/profile.d/locale.sh","w") as f:
            f.write(f"export LANG={lc['locale']}\nexport LC_ALL={lc['locale']}\n")
        os.makedirs("/etc/X11/xorg.conf.d",exist_ok=True)
        with open("/etc/X11/xorg.conf.d/00-keyboard.conf","w") as f:
            f.write(f'Section "InputClass"\n    Identifier "keyboard"\n    MatchIsKeyboard "on"\n    Option "XkbLayout" "{lc["keymap"]}"\nEndSection\n')

        # 4. Run install steps (partition step is special)
        dw=0
        for i,(name,cmd,weight) in enumerate(STEPS):
            q.put(("step_start",i))
            ok=True
            if cmd=="__PARTITION__":
                q.put(("log",f"Partitioning {di['disk']} using scheme: {di['scheme']}"))
                ok=self._do_partition(di)
            else:
                q.put(("log",f"$ {cmd[:90]}"))
                try:
                    proc=subprocess.Popen(cmd,shell=True,stdout=subprocess.PIPE,
                                          stderr=subprocess.STDOUT,text=True,bufsize=1)
                    for line in proc.stdout:
                        line=line.rstrip()
                        if line: q.put(("log",line[-120:]))
                    proc.wait()
                    if proc.returncode!=0:
                        ok=False; q.put(("log",f"[warn] exited {proc.returncode}"))
                except Exception as e:
                    ok=False; q.put(("log",f"[error] {e}"))
            dw+=weight
            q.put(("step_done",i,ok))
            q.put(("progress",dw))
        q.put(("complete",None))

    def _do_partition(self, di):
        """Run the appropriate gpart commands for the chosen scheme."""
        disk   = di["disk"]
        scheme = di["scheme"]
        swap   = di.get("swap_gb",4)
        q      = self.log_queue

        cmds = []

        if scheme == "erase_zfs":
            cmds = [
                f"gpart destroy -F {disk} 2>/dev/null || true",
                f"gpart create -s gpt {disk}",
                f"gpart add -t efi      -s 512M  -l efi      {disk}",
                f"gpart add -t freebsd-zfs -l zroot {disk}",
                f"newfs_msdos -F 32 -b 8192 {disk}p1",
                f"zpool create -f -o ashift=12 -O compression=lz4 -O atime=off "
                f"-O mountpoint=none zroot {disk}p2",
                f"zfs create -o mountpoint=/ zroot/ROOT",
                f"zfs create -o mountpoint=/ROOT/default zroot/ROOT/default",
                f"zfs create -o mountpoint=/home zroot/home",
                f"zfs create -o mountpoint=/var  zroot/var",
                f"zfs create -o mountpoint=/tmp  zroot/tmp",
                f"zpool set bootfs=zroot/ROOT/default zroot",
            ]
            if swap > 0:
                cmds.append(f"zfs create -V {swap}G -o org.freebsd:swap=on zroot/swap")

        elif scheme == "erase_ufs":
            cmds = [
                f"gpart destroy -F {disk} 2>/dev/null || true",
                f"gpart create -s gpt {disk}",
                f"gpart add -t efi         -s 512M   -l efi    {disk}",
                f"gpart add -t freebsd-ufs -s 1G     -l boot   {disk}",
            ]
            if swap > 0:
                cmds.append(f"gpart add -t freebsd-swap -s {swap}G -l swap {disk}")
            cmds += [
                f"gpart add -t freebsd-ufs -l root {disk}",
                f"newfs_msdos -F 32 -b 8192 {disk}p1",
                f"newfs -U {disk}p2",
                f"newfs -U {disk}p{'4' if swap > 0 else '3'}",
            ]

        elif scheme == "alongside":
            aside = di.get("alongside_gb", 40)
            cmds = [
                f"gpart add -t freebsd-zfs -s {aside}G -l freebsd {disk}",
                f"zpool create -f -o ashift=12 -O compression=lz4 "
                f"-O atime=off -O mountpoint=/ zroot {disk}p$(gpart show {disk} | grep freebsd | tail -1 | awk '{{print $3}}')",
            ]

        elif scheme == "manual":
            q.put(("log", "Manual partitioning requested — dropping to shell."))
            subprocess.run("xterm -e gpart show; gpart -h", shell=True)
            return True

        for cmd in cmds:
            q.put(("log", f"$ {cmd[:100]}"))
            result = subprocess.run(cmd, shell=True, capture_output=True, text=True)
            if result.stdout: q.put(("log", result.stdout.strip()[-100:]))
            if result.stderr: q.put(("log", result.stderr.strip()[-100:]))
            if result.returncode != 0:
                q.put(("log", f"[warn] partition step exited {result.returncode} — continuing"))
        return True

    # ================================================================
    #  SCREEN 5 — Done + Reboot
    # ================================================================
    def _show_done(self):
        self._clear()
        frame=tk.Frame(self.root,bg=BG); frame.place(relx=0.5,rely=0.5,anchor="center")
        tk.Label(frame,text="✓",font=FONT_DONE,bg=BG,fg=GREEN).pack()
        tk.Label(frame,text="You're All Set!",font=FONT_DONE_T,bg=BG,fg=TEXT_DARK).pack(pady=(6,0))

        first = self.user_info.get("fullname","").split()[0]
        uname = self.user_info.get("username","")
        tz    = self.locale_info.get("timezone","UTC")
        lc    = self.locale_info.get("locale","en_US.UTF-8")
        disk  = self.disk_info.get("disk","")
        scheme = self.disk_info.get("scheme","")

        tk.Label(frame,
                 text=(f"Welcome, {first}.  Log in as  {uname}  when the desktop starts.\n"
                       f"Disk: {disk}  ({scheme})   •   {tz}   •   {lc}"),
                 font=FONT_SUB,bg=BG,fg=TEXT_GRAY,justify="center").pack(pady=(10,28))

        cd_f=tk.Frame(frame,bg=BG); cd_f.pack()
        tk.Label(cd_f,text="Rebooting in",font=("Inter",14),bg=BG,fg=TEXT_GRAY).pack()
        self._cd=tk.Label(cd_f,text="10",font=FONT_CD,bg=BG,fg=BLUE); self._cd.pack()
        tk.Label(cd_f,text="seconds",font=("Inter",14),bg=BG,fg=TEXT_GRAY).pack()
        self._countdown=10; self._tick_reboot()
        self._footer()

    def _tick_reboot(self):
        self._countdown-=1; self._cd.config(text=str(self._countdown))
        if self._countdown<=0: os.system("shutdown -r now")
        else: self.root.after(1000,self._tick_reboot)


def main():
    root=tk.Tk()
    SetupApp(root)
    root.mainloop()

if __name__=="__main__":
    main()
