#include <dirent.h>
#include <fcntl.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <X11/keysym.h>
#include <X11/XF86keysym.h>
#include <X11/Xlib.h>

enum State {
	StateNoInput,
	StateNoInputNoScreen,
	StateSuspend,
	StateDead
};

enum Color {
	Red,
	Blue,
	Purple,
	Off
};

static Display *dpy;
static enum State state = StateNoInput;
static int lastkeysym = NULL;
static int lastkeyn = 0;
static char oldbrightness[10] = "200";
static char * brightnessfile = "/sys/devices/platform/backlight/backlight/backlight/brightness";
static char * powerstatefile = "/sys/power/state";

void
writefile(char *filepath, char *str)
{
	int f;
	f = open(filepath, O_WRONLY);
	if (f != NULL) {
		write(f, str, strlen(str));
		close(f);
	} else {
		fprintf(stderr, "Couldn't open filepath <%s>\n", filepath);
	}
}

void
setpineled(enum Color c)
{
	if (c == Red) {
		writefile("/sys/class/leds/red:indicator/brightness", "1");
		writefile("/sys/class/leds/blue:indicator/brightness", "0");
	} else if (c == Blue) {
		writefile("/sys/class/leds/red:indicator/brightness", "0");
		writefile("/sys/class/leds/blue:indicator/brightness", "1");
	} else if (c == Purple) {
		writefile("/sys/class/leds/red:indicator/brightness", "1");
		writefile("/sys/class/leds/blue:indicator/brightness", "1");
	} else if (c == Off) {
		writefile("/sys/class/leds/red:indicator/brightness", "0");
		writefile("/sys/class/leds/blue:indicator/brightness", "0");
	}
}

void
syncstate()
{
	if (state == StateSuspend) {
		setpineled(Red);
		configuresuspendsettingsandwakeupsources();
		writefile(powerstatefile, "mem");
		state = StateNoInput;
		syncstate();
	} else if (state == StateNoInput) {
		setpineled(Blue);
		writefile(brightnessfile, oldbrightness);
	} else if (state == StateNoInputNoScreen) {
		setpineled(Purple);
		writefile(brightnessfile, "0");
	} else if (state == StateDead) {
		writefile(brightnessfile, oldbrightness);
		setpineled(Off);
	}
}

static void
die(const char *err, ...)
{
	fprintf(stderr, "Error: %s", err);
	state = StateDead;
	syncstate();
	exit(1);
}

// Loosely derived from suckless' slock's lockscreen binding logic but
// alot more coarse, intentionally so can be triggered while grab_key
// for dwm multikey path already holding..
void
lockscreen(Display *dpy, int screen)
{
	int i, ptgrab, kbgrab;
	Window root;
	root = RootWindow(dpy, screen);
	for (i = 0, ptgrab = kbgrab = -1; i < 9999999; i++) {
		if (ptgrab != GrabSuccess) {
			ptgrab = XGrabPointer(dpy, root, False,
				ButtonPressMask | ButtonReleaseMask |
				PointerMotionMask, GrabModeAsync,
				GrabModeAsync, None, None, CurrentTime);
		}
		if (kbgrab != GrabSuccess) {
			kbgrab = XGrabKeyboard(dpy, root, True,
				GrabModeAsync, GrabModeAsync, CurrentTime);
		}
		if (ptgrab == GrabSuccess && kbgrab == GrabSuccess) {
			XSelectInput(dpy, root, SubstructureNotifyMask);
			return;
		}
		usleep(100000);
	}
}

void
readinputloop(Display *dpy, int screen) {
	KeySym keysym;
	XEvent ev;
	char buf[32];

	while (state != StateDead && !XNextEvent(dpy, &ev)) {
		if (ev.type == KeyPress) {
			XLookupString(&ev.xkey, buf, sizeof(buf), &keysym, 0);
			if (lastkeysym == keysym) {
				lastkeyn++;
			} else {
				lastkeysym = keysym;
				lastkeyn = 1;
			}

			if (lastkeyn < 3)
				continue;

			lastkeyn = 0;
			lastkeysym = NULL;
			switch (keysym) {
				case XF86XK_AudioRaiseVolume:
					state = StateSuspend;
					break;
				case XF86XK_AudioLowerVolume:
					state = (state == StateNoInput ? StateNoInputNoScreen : StateNoInput);
					break;
				case XF86XK_PowerOff:
					state = StateDead;
					break;
			}
			syncstate();
		}
	}
}

int
getoldbrightness() {
	char * buffer = 0;
	long length;
	FILE * f = fopen(brightnessfile, "r");
	if (f) {
		fseek(f, 0, SEEK_END);
		length = ftell(f);
		fseek(f, 0, SEEK_SET);
		buffer = malloc(length);
		if (buffer) {
			fread(buffer, 1, length, f);
		}
		fclose(f);
	}
	if (buffer) {
		sprintf(oldbrightness, "%d", atoi(buffer));
	}
}

void
configuresuspendsettingsandwakeupsources()
{
	// Disable all wakeup sources
	struct dirent *wakeupsource;
	char wakeuppath[100];
	DIR *wakeupsources = opendir("/sys/class/wakeup");
	if (wakeupsources == NULL)
		die("Couldn't open directory /sys/class/wakeup\n");
	while ((wakeupsource = readdir(wakeupsources)) != NULL) {
		sprintf(
			wakeuppath, 
			"/sys/class/wakeup/%s/device/power/wakeup",
			wakeupsource->d_name
		);
		fprintf(stderr, "Disabling wakeup source: %s", wakeupsource->d_name);
		writefile(wakeuppath, "disabled");
		fprintf(stderr, ".. ok\n");
	}
	closedir(wakeupsources);

	// Enable powerbutton wakeup source
	fprintf(stderr, "Enable powerbutton wakeup source\n");
	writefile(
		"/sys/devices/platform/soc/1f03400.rsb/sunxi-rsb-3a3/axp221-pek/power/wakeup",
		"enabled"
	);

	// Temporary hack to disable USB driver that doesn't suspend
	fprintf(stderr, "Disabling buggy USB driver\n");
	writefile(
		"/sys/devices/platform/soc/1c19000.usb/driver/unbind",
		"1c19000.usb"
	);

	// Temporary hack to disable Bluetooth driver that crashes on suspend 1/5th the time
	fprintf(stderr, "Disabling buggy Bluetooth driver\n");
	writefile(
		"/sys/bus/serial/drivers/hci_uart_h5/unbind",
		"serial0-0"
	);

	// E.g. make sure we're using CRUST
	fprintf(stderr, "Flip mem_sleep setting to use crust\n");
	writefile("/sys/power/mem_sleep", "deep");
}

int
main(int argc, char **argv) {
	Screen *screen;

	if (setuid(0))
		die("setuid(0) failed\n");
	if (!(dpy = XOpenDisplay(NULL)))
		die("Cannot open display\n");

	screen = XDefaultScreen(dpy);
	XSync(dpy, 0);
	getoldbrightness();
	syncstate();
	lockscreen(dpy, screen);
	readinputloop(dpy, screen);
	return 0;
}
