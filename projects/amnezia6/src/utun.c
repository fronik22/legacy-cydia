/*
 * UTUN control interface for iOS.
 *
 * The kernel control connection sequence follows Senko's awg_utun.c
 * (GPLv2), adapted for Amnezia6.
 */

#include "utun.h"

#include <errno.h>
#include <string.h>
#include <sys/ioctl.h>
#include <sys/socket.h>
#include <unistd.h>

#ifndef AF_SYSTEM
#define AF_SYSTEM 32
#endif
#ifndef PF_SYSTEM
#define PF_SYSTEM AF_SYSTEM
#endif
#ifndef SYSPROTO_CONTROL
#define SYSPROTO_CONTROL 2
#endif
#ifndef AF_SYS_CONTROL
#define AF_SYS_CONTROL 2
#endif
#ifndef UTUN_OPT_IFNAME
#define UTUN_OPT_IFNAME 2
#endif

struct a6_ctl_info {
    unsigned int ctl_id;
    char ctl_name[96];
};

struct a6_sockaddr_ctl {
    unsigned char sc_len;
    unsigned char sc_family;
    unsigned short ss_sysaddr;
    unsigned int sc_id;
    unsigned int sc_unit;
    unsigned int sc_reserved[5];
};

#define A6_CTLIOCGINFO _IOWR('N', 3, struct a6_ctl_info)

int a6_utun_open(char *ifname, size_t cap) {
    struct a6_ctl_info info;
    struct a6_sockaddr_ctl addr;
    socklen_t got;
    int fd;

    if (!ifname || cap < 2) {
        errno = EINVAL;
        return -1;
    }
    memset(&info, 0, sizeof info);
    strncpy(info.ctl_name, "com.apple.net.utun_control", sizeof info.ctl_name - 1);
    fd = socket(PF_SYSTEM, SOCK_DGRAM, SYSPROTO_CONTROL);
    if (fd < 0) return -1;
    if (ioctl(fd, A6_CTLIOCGINFO, &info) != 0) {
        close(fd);
        return -1;
    }
    memset(&addr, 0, sizeof addr);
    addr.sc_len = sizeof addr;
    addr.sc_family = AF_SYSTEM;
    addr.ss_sysaddr = AF_SYS_CONTROL;
    addr.sc_id = info.ctl_id;
    addr.sc_unit = 0;
    if (connect(fd, (struct sockaddr *)&addr, sizeof addr) != 0) {
        close(fd);
        return -1;
    }
    got = (socklen_t)cap;
    if (getsockopt(fd, SYSPROTO_CONTROL, UTUN_OPT_IFNAME, ifname, &got) != 0 ||
        !ifname[0]) {
        close(fd);
        return -1;
    }
    ifname[cap - 1] = 0;
    return fd;
}
