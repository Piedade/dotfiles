/* See LICENSE file for copyright and license details. */

/* appearance */
#define ICONSIZE 14   /* icon size */
#define ICONSPACING 8 /* space between icon and title */
#define SHOWWINICON 1 /* 0 means no winicon */

static const unsigned int borderpx = 1;                 /* border pixel of windows */
static const unsigned int snap = 32;                    /* snap pixel */
static const unsigned int systraypinning = 0;           /* 0: sloppy systray follows selected monitor, >0: pin systray to monitor X */
static const unsigned int systrayonleft = 0;            /* 0: systray in the right corner, >0: systray on left of status text */
static const unsigned int systrayspacing = ICONSPACING; /* systray spacing */
static const int systraypinningfailfirst = 1;           /* 1: if pinning fails, display systray on the first monitor, False: display systray on the last monitor*/
static const int showsystray = 1;                       /* 0 means no systray */
static const int swallowfloating = 0;                   /* 1 means swallow floating windows by default */
static const int showbar = 1;                           /* 0 means no bar */
static const int topbar = 1;                            /* 0 means bottom bar */

static const char *fonts[] = {
    // "monospace:size=12",
    "FiraCode Nerd Font:size=11",
    "SF Mono:size=11",
    "MesloLGS Nerd Font Mono:size=11",
};
static const char dmenufont[] = "monospace:size=10";
// default colors
// static const char normbordercolor[]    = "#444444";
// static const char normbgcolor[]        = "#222222";
// static const char normfgcolor[]        = "#bbbbbb";
// static const char selbordercolor[]     = "#005577";
// static const char selbgcolor[]         = "#005577";
// static const char selfgcolor[]         = "#eeeeee";
static const char normbordercolor[] = "#444444";
static const char normbgcolor[] = "#000000";
static const char normfgcolor[] = "#eeeeee";
static const char selbordercolor[] = "#888888";
static const char selbgcolor[] = "#333333";
static const char selfgcolor[] = "#eeeeee";

static const char *colors[][3] = {
    /*               fg           bg           border   */
    [SchemeNorm] = {normfgcolor, normbgcolor, normbordercolor},
    [SchemeSel] = {selfgcolor, selbgcolor, selbordercolor},
};

static const char editor[] = "code";
static const char browser[] = "google-chrome";

static const char *const autostart[] = {
    // "xset", "s", "off", NULL,     // Disables the screensaver
    // "xset", "s", "noblank", NULL, // Prevent the screen from blanking (turning off)
    // "xset", "-dpms", NULL,        // Disables DPMS (Display Power Management Signaling)
    "xautolock", "-time", "20", "-locker", "systemctl suspend", NULL, // Lock the screen after 30 minutes of inactivity
    "dbus-update-activation-environment", "--systemd", "--all", NULL,
    "lxpolkit", NULL,
    "sh", "-c", "~/.screenlayout/default.sh", NULL,
    "dwmblocks", NULL,
    /* "picom", "-b", NULL, */
    "flameshot", NULL,
    "sh", "-c", "feh --randomize --bg-fill ~/.dotfiles/backgrounds/*", NULL,
    "dunst", NULL,
    /*
    editor, NULL,
    browser, "--profile-directory=Default", NULL,
    */
    "sh", "-c", "pactl set-source-mute $(pactl get-default-source) true", NULL,
    "sh", "-c", "sleep 1 && pkill -SIGUSR1 dwmblocks", NULL,
    "sh", "-c", "~/.config/startup.sh", NULL,
    NULL /* terminate */
};

/* tagging */
static const char *tags[] = {"1", "2", "3", "4", "5"};

static const Rule rules[] = {
    /* xprop(1):
     * WM_CLASS(STRING) = instance, class
     * WM_NAME(STRING) = title
     * WM_WINDOW_ROLE(STRING) = role
     */
    /* class role instance title tags mask isfloating isterminal noswallow monitor */
    {"St", NULL, NULL, NULL, 4, 0, 1, 0, 0},
    {"Lxpolkit", NULL, NULL, NULL, 0, 1, 0, 0, -1},
    {"pavucontrol", NULL, NULL, NULL, 0, 1, 0, 0, -1},
    {"Lxappearance", NULL, NULL, NULL, 0, 1, 0, 0, -1},
    {"Lightdm-settings", NULL, NULL, NULL, 0, 1, 0, 0, -1},
    {"Alacritty", NULL, NULL, NULL, 4, 0, 1, 0, 0},
    /* {"Code", NULL, NULL, NULL, 1, 0, 0, 1, 0}, */
    /* {"Google-chrome", NULL, NULL, NULL, 3, 0, 0, 0, 0}, */
    {"Google-chrome", "pop-up", NULL, NULL, 0, 1, 0, 0, -1},
    {"Thunar", NULL, NULL, NULL, 0, 1, 0, 0, -1},
    {"Xarchiver", NULL, NULL, NULL, 0, 1, 0, 0, -1},
    {NULL, NULL, NULL, "Event Tester", 0, 0, 0, 1, -1}, /* xev */
};

/* layout(s) */
static const float mfact = 0.6;      /* factor of master area size [0.05..0.95] */
static const int nmaster = 1;        /* number of clients in master area */
static const int resizehints = 1;    /* 1 means respect size hints in tiled resizals */
static const int lockfullscreen = 1; /* 1 will force focus on the fullscreen window */

static const Layout layouts[] = {
    /* symbol     arrange function */
    {"", tile}, /* first entry is default */
    {"", NULL}, /* no layout function means floating behavior */
    {"", monocle},
};

/* key definitions */
#define MODKEY Mod4Mask
#define TAGKEYS(KEY, TAG)                                                 \
    {MODKEY, KEY, view, {.ui = 1 << TAG}},                                \
        {MODKEY | ControlMask, KEY, toggletag, {.ui = 1 << TAG}},         \
        {MODKEY | ShiftMask, KEY, tag, {.ui = 1 << TAG}},                 \
        {MODKEY | ControlMask | ShiftMask, KEY, focusnthmon, {.i = TAG}}, \
        {MODKEY | ControlMask, KEY, tagnthmon, {.i = TAG}},

/* helper for spawning shell commands in the pre dwm-5.0 fashion */
#define SHCMD(cmd)                                           \
    {                                                        \
        .v = (const char *[]) { "/bin/sh", "-c", cmd, NULL } \
    }

#define STATUSBAR "dwmblocks"

/* commands */
static char dmenumon[2] = "0"; /* component of dmenucmd, manipulated in spawn() */
static const char *dmenucmd[] = {"dmenu_run", "-m", dmenumon, "-fn", dmenufont, "-nb", normbgcolor, "-nf", normfgcolor, "-sb", selbgcolor, "-sf", selfgcolor, NULL};
static const char *termcmd[] = {"alacritty", NULL};

static const char *launchercmd[] = {"rofi", "-modi", "drun", "-show", "drun", NULL};
static const char *launchereditor[] = {editor, NULL};
static const char *launcherbrowser[] = {browser, NULL};

#include "movestack.c"

static const Key keys[] = {
    /* modifier                     key         function            argument */
    {MODKEY, XK_minus, spawn, {.v = termcmd}},
    {MODKEY, XK_p, spawn, {.v = launchercmd}},
    {MODKEY, XK_comma, spawn, {.v = launchereditor}},
    {MODKEY, XK_period, spawn, {.v = launcherbrowser}},
    {0, XK_Print, spawn, SHCMD("flameshot full")},
    {MODKEY, XK_Print, spawn, SHCMD("flameshot gui")},
    {MODKEY | ShiftMask, XK_Print, spawn, SHCMD("flameshot gui --clipboard")},
    {MODKEY, XK_e, spawn, SHCMD("open .")},
    {MODKEY | ShiftMask, XK_w, spawn, SHCMD("feh --randomize --bg-fill ~/.dotfiles/backgrounds/*")},
    {0, XF86XK_MonBrightnessUp, spawn, SHCMD("xbacklight -inc 10")},
    {0, XF86XK_MonBrightnessDown, spawn, SHCMD("xbacklight -dec 10")},
    {0, XF86XK_AudioLowerVolume, spawn, SHCMD("amixer sset Master 5%- unmute; pkill -RTMIN+4 dwmblocks")},
    {0, XF86XK_AudioMute, spawn, SHCMD("amixer sset Master $(amixer get Master | grep -q '\\[on\\]' && echo 'mute' || echo 'unmute'); pkill -RTMIN+4 dwmblocks")},
    {0, XF86XK_AudioRaiseVolume, spawn, SHCMD("amixer sset Master 5%+ unmute; pkill -RTMIN+4 dwmblocks")},
    {MODKEY, XK_b, togglebar, {0}},
    {MODKEY, XK_j, focusstack, {.i = -1}},
    {MODKEY, XK_k, focusstack, {.i = +1}},
    {MODKEY, XK_i, incnmaster, {.i = -1}},
    {MODKEY, XK_u, incnmaster, {.i = +1}},
    {MODKEY, XK_h, setmfact, {.f = -0.05}},
    {MODKEY, XK_l, setmfact, {.f = +0.05}},
    {MODKEY | ShiftMask, XK_h, setcfact, {.f = +0.25}},
    {MODKEY | ShiftMask, XK_l, setcfact, {.f = -0.25}},
    {MODKEY | ShiftMask, XK_o, setcfact, {.f = 0.00}},
    {MODKEY | ShiftMask, XK_j, movestack, {.i = +1}},
    {MODKEY | ShiftMask, XK_k, movestack, {.i = -1}},
    {MODKEY, XK_Return, zoom, {0}},
    {MODKEY, XK_Tab, view, {0}},
    {MODKEY, XK_q, killclient, {0}},
    {MODKEY, XK_t, setlayout, {.v = &layouts[0]}},
    {MODKEY, XK_f, setlayout, {.v = &layouts[1]}},
    {MODKEY, XK_m, setlayout, {.v = &layouts[2]}},
    {MODKEY, XK_space, setlayout, {0}},
    {MODKEY | ShiftMask, XK_space, togglefloating, {0}},
    {MODKEY, XK_0, view, {.ui = ~0}},
    {MODKEY | ShiftMask, XK_0, tag, {.ui = ~0}},
    {MODKEY, XK_Left, focusmon, {.i = -1}},
    {MODKEY, XK_Right, focusmon, {.i = +1}},
    {MODKEY | ControlMask, XK_Left, tagmon, {.i = -1}},
    {MODKEY | ControlMask, XK_Right, tagmon, {.i = +1}},
    TAGKEYS(XK_1, 0)
        TAGKEYS(XK_2, 1)
            TAGKEYS(XK_3, 2)
                TAGKEYS(XK_4, 3)
                    TAGKEYS(XK_5, 4)
                        TAGKEYS(XK_6, 5)
                            TAGKEYS(XK_7, 6)
                                TAGKEYS(XK_8, 7)
                                    TAGKEYS(XK_9, 8){MODKEY | ShiftMask, XK_q, quit, {0}},
    {MODKEY | ShiftMask, XK_Return, spawn, SHCMD("$HOME/.config/rofi/powermenu/powermenu.sh")},
    {MODKEY | ControlMask | ShiftMask, XK_r, spawn, SHCMD("systemctl reboot")},
    {MODKEY | ControlMask | ShiftMask, XK_s, spawn, SHCMD("systemctl suspend")},
};

/* button definitions */
/* click can be ClkTagBar, ClkLtSymbol, ClkStatusText, ClkWinTitle, ClkClientWin, or ClkRootWin */
static const Button buttons[] = {
    /* click                event mask      button          function        argument */
    {ClkLtSymbol, 0, Button1, setlayout, {0}},
    {ClkLtSymbol, 0, Button3, setlayout, {.v = &layouts[2]}},
    {ClkWinTitle, 0, Button2, zoom, {0}},
    // { ClkStatusText,        0,              Button2,        spawn,          {.v = termcmd } },
    {ClkStatusText, 0, Button1, sigstatusbar, {.i = 1}},
    {ClkStatusText, 0, Button2, sigstatusbar, {.i = 2}},
    {ClkStatusText, 0, Button3, sigstatusbar, {.i = 3}},
    /* placemouse options, choose which feels more natural:
     *    0 - tiled position is relative to mouse cursor
     *    1 - tiled postiion is relative to window center
     *    2 - mouse pointer warps to window center
     *
     * The moveorplace uses movemouse or placemouse depending on the floating state
     * of the selected client. Set up individual keybindings for the two if you want
     * to control these separately (i.e. to retain the feature to move a tiled window
     * into a floating position).
     */
    {ClkClientWin, MODKEY, Button1, moveorplace, {.i = 1}},
    {ClkClientWin, MODKEY, Button2, togglefloating, {0}},
    {ClkClientWin, MODKEY, Button3, resizemouse, {0}},
    {ClkTagBar, 0, Button1, view, {0}},
    {ClkTagBar, 0, Button3, toggleview, {0}},
    {ClkTagBar, MODKEY, Button1, tag, {0}},
    {ClkTagBar, MODKEY, Button3, toggletag, {0}},
};
