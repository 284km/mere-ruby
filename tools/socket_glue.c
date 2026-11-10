/* Async DNS and numeric nonblocking TCP connection primitives. Workers own
 * only libc data; they never enter Mere or access its regions. Releasing a
 * resolver detaches the caller immediately, even while getaddrinfo runs. */
#include <errno.h>
#include <fcntl.h>
#include <ifaddrs.h>
#include <limits.h>
#include <netdb.h>
#include <pthread.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <sys/socket.h>
#include <time.h>
#include <unistd.h>

struct resolver {
    int id, refs, cancelled, done, error, family, delay, injected_error;
    char *host, service[16];
    struct addrinfo *addresses;
    struct resolver *next;
};
static pthread_mutex_t lock = PTHREAD_MUTEX_INITIALIZER;
static pthread_cond_t changed = PTHREAD_COND_INITIALIZER;
static struct resolver *jobs;
static int next_id;
static pthread_once_t fork_hooks = PTHREAD_ONCE_INIT;
static void before_fork(void) { pthread_mutex_lock(&lock); }
static void after_fork(void) { pthread_mutex_unlock(&lock); }
static void child_after_fork(void) {
    /* The worker threads do not survive fork. Their inherited requests must
     * neither wait forever nor alias a new request in the child. The small
     * inherited libc allocations are left to process teardown. */
    jobs = NULL;
    pthread_mutex_unlock(&lock);
    changed = (pthread_cond_t)PTHREAD_COND_INITIALIZER;
}
static void install_fork_hooks(void) {
    pthread_atfork(before_fork, after_fork, child_after_fork);
}

static struct resolver *find_job(int id) {
    struct resolver *j;
    for (j = jobs; j && j->id != id; j = j->next) {}
    return j;
}
static void unref(struct resolver *j) {
    if (--j->refs) return;
    if (j->addresses) freeaddrinfo(j->addresses);
    free(j->host);
    free(j);
}
static void *resolve_worker(void *arg) {
    struct resolver *j = arg;
    pthread_mutex_lock(&lock);
    if (j->delay > 0) {
        struct timespec end;
        clock_gettime(CLOCK_REALTIME, &end);
        end.tv_sec += j->delay / 1000;
        end.tv_nsec += (j->delay % 1000) * 1000000L;
        if (end.tv_nsec >= 1000000000L) { end.tv_sec++; end.tv_nsec -= 1000000000L; }
        while (!j->cancelled && pthread_cond_timedwait(&changed, &lock, &end) != ETIMEDOUT) {}
    }
    if (j->cancelled) { unref(j); pthread_mutex_unlock(&lock); return NULL; }
    pthread_mutex_unlock(&lock);
    struct addrinfo hints = {0}, *addresses = NULL;
    hints.ai_family = j->family;
    hints.ai_socktype = SOCK_STREAM;
    hints.ai_flags = AI_NUMERICSERV;
    int error = j->injected_error ? j->injected_error :
        getaddrinfo(j->host[0] ? j->host : NULL, j->service, &hints, &addresses);
    pthread_mutex_lock(&lock);
    j->addresses = addresses;
    j->error = error;
    j->done = 1;
    unref(j);
    pthread_mutex_unlock(&lock);
    return NULL;
}
int mr_resolve_start(const char *host, int port, int family, int delay, int error) {
    pthread_once(&fork_hooks, install_fork_hooks);
    struct resolver *j = calloc(1, sizeof(*j));
    if (!j) return -ENOMEM;
    j->host = strdup(host);
    if (!j->host) { free(j); return -ENOMEM; }
    snprintf(j->service, sizeof(j->service), "%d", port);
    j->family = family == 6 ? AF_INET6 : AF_INET;
    j->delay = delay;
    j->injected_error = error;
    j->refs = 2;
    pthread_mutex_lock(&lock);
    do { next_id = next_id == INT_MAX ? 1 : next_id + 1; } while (find_job(next_id));
    j->id = next_id;
    j->next = jobs;
    jobs = j;
    pthread_t thread;
    int e = pthread_create(&thread, NULL, resolve_worker, j);
    if (e) { jobs = j->next; j->refs = 1; unref(j); pthread_mutex_unlock(&lock); return -e; }
    pthread_detach(thread);
    int id = j->id;
    pthread_mutex_unlock(&lock);
    return id;
}
int mr_resolve_done(int id) {
    pthread_mutex_lock(&lock);
    struct resolver *j = find_job(id);
    int done = j ? j->done : 1;
    pthread_mutex_unlock(&lock);
    return done;
}
int mr_resolve_error(int id) {
    pthread_mutex_lock(&lock);
    struct resolver *j = find_job(id);
    int error = j ? j->error : EAI_FAIL;
    pthread_mutex_unlock(&lock);
    return error;
}
const char *mr_resolve_address(int id, int index) {
    /* The FFI copies str results before the next call. */
    static char address[NI_MAXHOST];
    address[0] = 0;
    pthread_mutex_lock(&lock);
    struct resolver *j = find_job(id);
    struct addrinfo *a = j && j->done ? j->addresses : NULL;
    while (a && index-- > 0) a = a->ai_next;
    if (a && getnameinfo(a->ai_addr, a->ai_addrlen, address, sizeof(address), NULL, 0, NI_NUMERICHOST)) address[0] = 0;
    pthread_mutex_unlock(&lock);
    return address;
}
int mr_resolve_release(int id) {
    pthread_mutex_lock(&lock);
    struct resolver **p = &jobs;
    while (*p && (*p)->id != id) p = &(*p)->next;
    if (*p) {
        struct resolver *j = *p;
        *p = j->next;
        j->cancelled = 1;
        pthread_cond_broadcast(&changed);
        unref(j);
    }
    pthread_mutex_unlock(&lock);
    return 0;
}
int mr_connect_start(const char *host, int port, const char *local, int local_port) {
    struct addrinfo hints = {0}, *a = NULL, *bound = NULL;
    char service[16];
    snprintf(service, sizeof(service), "%d", port);
    hints.ai_family = AF_UNSPEC;
    hints.ai_socktype = SOCK_STREAM;
    hints.ai_flags = AI_NUMERICHOST | AI_NUMERICSERV;
    if (getaddrinfo(host, service, &hints, &a)) return -EINVAL;
    int fd = socket(a->ai_family, a->ai_socktype, a->ai_protocol), e = errno;
    if (fd >= 0) {
        if (fcntl(fd, F_SETFD, FD_CLOEXEC) < 0 || fcntl(fd, F_SETFL, O_NONBLOCK) < 0) e = errno;
        else if (local[0] || local_port) {
            snprintf(service, sizeof(service), "%d", local_port);
            hints.ai_family = a->ai_family;
            hints.ai_flags |= AI_PASSIVE;
            if (getaddrinfo(local[0] ? local : NULL, service, &hints, &bound)) e = EADDRNOTAVAIL;
            else e = bind(fd, bound->ai_addr, bound->ai_addrlen) < 0 ? errno : 0;
        } else e = 0;
        if (!e && connect(fd, a->ai_addr, a->ai_addrlen) < 0 && errno != EINPROGRESS && errno != EWOULDBLOCK) e = errno;
        if (e) { close(fd); fd = -1; }
    }
    if (bound) freeaddrinfo(bound);
    freeaddrinfo(a);
    return fd < 0 ? -e : fd;
}
/* Connect an already-bound UDP descriptor in the kernel. Recording just a
 * Ruby peer would neither filter incoming senders nor deliver ICMP errors. */
int mr_udp_connect(int fd, const char *host, int port) {
    struct sockaddr_storage local;
    socklen_t length = sizeof(local);
    if (getsockname(fd, (struct sockaddr *)&local, &length)) return -errno;
    struct addrinfo hints = {0}, *address = NULL;
    char service[16];
    snprintf(service, sizeof(service), "%d", port);
    hints.ai_family = local.ss_family;
    hints.ai_socktype = SOCK_DGRAM;
    hints.ai_flags = AI_NUMERICHOST | AI_NUMERICSERV;
    if (getaddrinfo(host, service, &hints, &address)) return -EINVAL;
    int result;
    do { result = connect(fd, address->ai_addr, address->ai_addrlen); }
    while (result < 0 && errno == EINTR);
    int error = result < 0 ? errno : 0;
    freeaddrinfo(address);
    return -error;
}
int mr_connect_error(int fd) {
    int e = 0;
    socklen_t n = sizeof(e);
    if (getsockopt(fd, SOL_SOCKET, SO_ERROR, &e, &n)) return errno;
    return e;
}
const char *mr_ip_addresses(void) {
    static char *out;
    struct ifaddrs *addresses;
    free(out);
    out = NULL;
    if (getifaddrs(&addresses)) return "";
    size_t size = 1;
    out = calloc(size, 1);
    if (!out) { freeifaddrs(addresses); return ""; }
    for (struct ifaddrs *a = addresses; a; a = a->ifa_next) {
        if (!a->ifa_addr) continue;
        int family = a->ifa_addr->sa_family;
        if (family != AF_INET && family != AF_INET6) continue;
        /* Addrinfo's internal sockaddr representation is BSD layout on
         * every host. Preserve IPv6 scope IDs instead of reparsing names. */
        unsigned char raw[28] = {0};
        size_t bytes = family == AF_INET ? 16 : 28;
        raw[0] = (unsigned char)bytes;
        raw[1] = (unsigned char)family;
        if (family == AF_INET) {
            struct sockaddr_in *in = (struct sockaddr_in *)a->ifa_addr;
            memcpy(raw + 4, &in->sin_addr, 4);
        } else {
            struct sockaddr_in6 *in = (struct sockaddr_in6 *)a->ifa_addr;
            memcpy(raw + 8, &in->sin6_addr, 16);
            memcpy(raw + 24, &in->sin6_scope_id, 4);
        }
        char name[57];
        static const char hex[] = "0123456789abcdef";
        for (size_t i = 0; i < bytes; i++) {
            name[i * 2] = hex[raw[i] >> 4];
            name[i * 2 + 1] = hex[raw[i] & 15];
        }
        size_t length = bytes * 2;
        char *grown = realloc(out, size + length + 1);
        if (!grown) break;
        out = grown;
        memcpy(out + size - 1, name, length);
        out[size + length - 1] = '\n';
        out[size + length] = 0;
        size += length + 1;
    }
    freeifaddrs(addresses);
    return out;
}

/* Ruby passes MSG_CMSG_CLOEXEC to recvmsg when the host provides it. No
 * ancillary descriptors are accepted by this layer; mirror the result flag. */
int mr_recvmsg_flags(int unused) {
    (void)unused;
#ifdef MSG_CMSG_CLOEXEC
    return MSG_CMSG_CLOEXEC;
#else
    return 0;
#endif
}
