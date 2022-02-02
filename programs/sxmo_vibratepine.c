/* Based on: https://xnux.eu/devices/feature/vibrator.html#toc-example-program-to-control-the-vibration-motor */
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <stdarg.h>
#include <stdbool.h>
#include <errno.h>
#include <fcntl.h>
#include <poll.h>
#include <unistd.h>
#include <sys/ioctl.h>
#include <linux/input.h>


void syscall_error(int is_err, const char* fmt, ...)
{
	va_list ap;

	if (!is_err)
		return;

	printf("ERROR: ");
	va_start(ap, fmt);
	vprintf(fmt, ap);
	va_end(ap);
	printf(": %s\n", strerror(errno));

	exit(1);
}

void usage() {
	fprintf(stderr, "Usage: sxmo_vibratepine duration_ms\n");
	fprintf(stderr, "       sxmo_vibratepine duration_ms strength_number\n");
}

int main(int argc, char* argv[])
{
	int fd, ret, effects;

	int durationMs, strength;

	if (argc < 2) {
		usage();
		return 1;
	}
	argc--;

	if (argc > 1) {
		strength = atoi(argv[argc--]);
	} else {
		strength = 4000;
	}

	durationMs = atoi(argv[argc--]);

	fd = open("/dev/input/by-path/platform-vibrator-event", O_RDWR | O_CLOEXEC);
	syscall_error(fd < 0, "Can't open vibrator event device");
	ret = ioctl(fd, EVIOCGEFFECTS, &effects);
	syscall_error(ret < 0, "EVIOCGEFFECTS failed");

	struct ff_effect e = {
					.type = FF_RUMBLE,
					.id = -1,
					.u.rumble = { .strong_magnitude = strength },
	};

	ret = ioctl(fd, EVIOCSFF, &e);
	syscall_error(ret < 0, "EVIOCSFF failed");

	struct input_event play = { .type = EV_FF, .code = e.id, .value = 3 };
	ret = write(fd, &play, sizeof play);
	syscall_error(ret < 0, "write failed");

	usleep(durationMs * 1000);

	ret = ioctl(fd, EVIOCRMFF, e.id);
	syscall_error(ret < 0, "EVIOCRMFF failed");

	close(fd);
	return 0;
}
