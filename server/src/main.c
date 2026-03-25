#include "mongoose.h"
#include <pcap.h>
#include <stdio.h>
#include <pthread.h>
#include <time.h>
#include <sys/socket.h>
#include <netinet/in.h>
#include <arpa/inet.h>
#include <unistd.h>
#include <netinet/if_ether.h>
#include <netinet/ip.h>
#include <netinet/ip6.h>
#include <netinet/tcp.h>
#include <netinet/udp.h>

// --- Global variables ---
#define HISTORY_SIZE 20
typedef struct {
    double timestamp;
    uint32_t len;
    char proto[16];
    char src_ip[64];
    char dst_ip[64];
    uint16_t src_port;
    uint16_t dst_port;
} PacketInfo;

PacketInfo packet_history[HISTORY_SIZE];
int history_index = 0;
int history_count = 0;
pthread_mutex_t history_mutex = PTHREAD_MUTEX_INITIALIZER;
struct mg_mgr mgr;
volatile bool new_packet_flag = false; // Flag to signal new packet

double get_now() {
    struct timespec ts;
    clock_gettime(CLOCK_MONOTONIC, &ts);
    return ts.tv_sec + (double)ts.tv_nsec / 1e9;
}

void send_history_to_client(struct mg_connection *c) {
    pthread_mutex_lock(&history_mutex);
    for (int i = history_count - 1; i >= 0; i--) {
        int idx = (history_index - 1 - i + HISTORY_SIZE) % HISTORY_SIZE;
        PacketInfo *p = &packet_history[idx];
        char json[512];
        snprintf(json, sizeof(json),
                 "{\"type\":\"packet\",\"ts\":%.3f,\"len\":%u,\"proto\":\"%s\",\"src\":\"%s:%u\",\"dst\":\"%s:%u\"}",
                 p->timestamp, p->len, p->proto, p->src_ip, p->src_port, p->dst_ip, p->dst_port);
        mg_ws_send(c, json, strlen(json), WEBSOCKET_OP_TEXT);
    }
    pthread_mutex_unlock(&history_mutex);
}

void broadcast_last_packet() {
    pthread_mutex_lock(&history_mutex);
    if (history_count == 0) {
        pthread_mutex_unlock(&history_mutex);
        return;
    }
    int last_idx = (history_index - 1 + HISTORY_SIZE) % HISTORY_SIZE;
    PacketInfo *p = &packet_history[last_idx];

    char json[512];
    snprintf(json, sizeof(json),
             "{\"type\":\"packet\",\"ts\":%.3f,\"len\":%u,\"proto\":\"%s\",\"src\":\"%s:%u\",\"dst\":\"%s:%u\"}",
             p->timestamp, p->len, p->proto, p->src_ip, p->src_port, p->dst_ip, p->dst_port);
    pthread_mutex_unlock(&history_mutex);

    for (struct mg_connection *c = mgr.conns; c != NULL; c = c->next) {
        if (c->is_websocket) {
            mg_ws_send(c, json, strlen(json), WEBSOCKET_OP_TEXT);
        }
    }
}

void packet_handler(u_char *args, const struct pcap_pkthdr *header, const u_char *packet) {
    // Determine link-layer header size and EtherType position.
    // DLT_LINUX_SLL (113) = "any" pseudo-interface, 16-byte cooked header,
    // protocol at offset 14. DLT_EN10MB (1) = Ethernet, 14-byte header,
    // ether_type at offset 12 (via struct ether_header).
    int linktype = args ? *(int *)args : DLT_EN10MB;
    int ll_len;
    uint16_t type;
    if (linktype == DLT_LINUX_SLL) {
        ll_len = 16;
        type = ntohs(*(uint16_t *)(packet + 14));
    } else {
        ll_len = 14;
        type = ntohs(((struct ether_header *)packet)->ether_type);
    }

    pthread_mutex_lock(&history_mutex);
    PacketInfo *info = &packet_history[history_index];
    info->timestamp = get_now();
    info->len = header->len;
    info->src_port = 0; info->dst_port = 0;
    strcpy(info->src_ip, "-"); strcpy(info->dst_ip, "-");
    strcpy(info->proto, "Other");

    if (type == 0x0800) {
        struct ip *ip4 = (struct ip *)(packet + ll_len);
        inet_ntop(AF_INET, &(ip4->ip_src), info->src_ip, sizeof(info->src_ip));
        inet_ntop(AF_INET, &(ip4->ip_dst), info->dst_ip, sizeof(info->dst_ip));
        if (ip4->ip_p == IPPROTO_TCP) {
            strcpy(info->proto, "TCP/IPv4");
            struct tcphdr *tcp = (struct tcphdr *)(packet + ll_len + (ip4->ip_hl << 2));
            info->src_port = ntohs(tcp->th_sport); info->dst_port = ntohs(tcp->th_dport);
        } else if (ip4->ip_p == IPPROTO_UDP) {
            strcpy(info->proto, "UDP/IPv4");
            struct udphdr *udp = (struct udphdr *)(packet + ll_len + (ip4->ip_hl << 2));
            info->src_port = ntohs(udp->uh_sport); info->dst_port = ntohs(udp->uh_dport);
        } else strcpy(info->proto, "IPv4");
    } else if (type == 0x86DD) {
        struct ip6_hdr *ip6 = (struct ip6_hdr *)(packet + ll_len);
        inet_ntop(AF_INET6, &(ip6->ip6_src), info->src_ip, sizeof(info->src_ip));
        inet_ntop(AF_INET6, &(ip6->ip6_dst), info->dst_ip, sizeof(info->dst_ip));
        if (ip6->ip6_nxt == IPPROTO_TCP) {
            strcpy(info->proto, "TCP/IPv6");
            struct tcphdr *tcp = (struct tcphdr *)(packet + ll_len + 40);
            info->src_port = ntohs(tcp->th_sport); info->dst_port = ntohs(tcp->th_dport);
        } else if (ip6->ip6_nxt == IPPROTO_UDP) {
            strcpy(info->proto, "UDP/IPv6");
            struct udphdr *udp = (struct udphdr *)(packet + ll_len + 40);
            info->src_port = ntohs(udp->uh_sport); info->dst_port = ntohs(udp->uh_dport);
        } else strcpy(info->proto, "IPv6");
    } else if (type == 0x0806) strcpy(info->proto, "ARP");

    history_index = (history_index + 1) % HISTORY_SIZE;
    if (history_count < HISTORY_SIZE) history_count++;
    
    new_packet_flag = true; // Set the flag
    
    pthread_mutex_unlock(&history_mutex);
}

// --- Handlers ---
#define CORS_HEADERS \
    "Access-Control-Allow-Origin: *\r\n" \
    "Access-Control-Allow-Methods: GET, POST, OPTIONS\r\n" \
    "Access-Control-Allow-Headers: Content-Type\r\n"

// Chunked download state — stored in c->fn_data during a /download response.
// Magic guards against treating other connections' fn_data as DownloadState.
#define DOWNLOAD_MAGIC 0xD04A1234u
#define DOWNLOAD_TOTAL_CHUNKS 10240   // 10 MB total (10240 × 1 KB)
#define DOWNLOAD_BATCH        128     // 128 KB flushed per MG_EV_WRITE

typedef struct {
    uint32_t magic;
    int chunks_sent;
    char buf[1024];
} DownloadState;

// Send up to DOWNLOAD_BATCH 1-KB chunks using chunked transfer encoding.
static void dl_send_batch(struct mg_connection *c, DownloadState *ds) {
    for (int i = 0; i < DOWNLOAD_BATCH && ds->chunks_sent < DOWNLOAD_TOTAL_CHUNKS; i++) {
        mg_printf(c, "%x\r\n", 1024);
        mg_send(c, ds->buf, 1024);
        mg_send(c, "\r\n", 2);
        ds->chunks_sent++;
    }
    if (ds->chunks_sent >= DOWNLOAD_TOTAL_CHUNKS) {
        mg_send(c, "0\r\n\r\n", 5); // chunked EOF
    }
}

static void ping_handler(struct mg_connection *c, int ev, void *ev_data) {
    if (ev == MG_EV_HTTP_MSG) {
        struct timespec s, e; clock_gettime(CLOCK_MONOTONIC, &s);
        int fd = socket(AF_INET, SOCK_STREAM, 0);
        struct sockaddr_in a; a.sin_family = AF_INET; a.sin_port = htons(53);
        inet_pton(AF_INET, "8.8.8.8", &a.sin_addr);
        if (connect(fd, (struct sockaddr *)&a, sizeof(a)) >= 0) {
            close(fd); clock_gettime(CLOCK_MONOTONIC, &e);
            long ns = (e.tv_sec - s.tv_sec) * 1000000000L + (e.tv_nsec - s.tv_nsec);
            mg_http_reply(c, 200, CORS_HEADERS, "%.2f ms\n", (double)ns / 1e6);
        } else { if (fd >= 0) close(fd); mg_http_reply(c, 500, CORS_HEADERS, "Error\n"); }
    }
}

static void upload_handler(struct mg_connection *c, int ev, void *ev_data) {
    if (ev == MG_EV_HTTP_MSG) mg_http_reply(c, 200, CORS_HEADERS, "Upload finished\n");
}

static void traffic_handler(struct mg_connection *c, int ev, void *ev_data) {
    if (ev == MG_EV_HTTP_MSG) {
        pthread_mutex_lock(&history_mutex);
        char *j = malloc(16384); int o = snprintf(j, 16384, "[");
        for (int i = 0; i < history_count; i++) {
            int idx = (history_index - 1 - i + HISTORY_SIZE) % HISTORY_SIZE;
            PacketInfo *p = &packet_history[idx];
            o += snprintf(j + o, 16384 - o, "{\"ts\":%.3f,\"len\":%u,\"proto\":\"%s\",\"src\":\"%s:%u\",\"dst\":\"%s:%u\"}%s",
                          p->timestamp, p->len, p->proto, p->src_ip, p->src_port, p->dst_ip, p->dst_port,
                          (i == history_count - 1) ? "" : ",");
        }
        strcat(j, "]"); pthread_mutex_unlock(&history_mutex);
        mg_http_reply(c, 200, CORS_HEADERS "Content-Type: application/json\r\n", "%s\n", j);
        free(j);
    }
}

static void fn(struct mg_connection *c, int ev, void *ev_data) {
    // Continue streaming download on each write-complete event.
    if (ev == MG_EV_WRITE) {
        DownloadState *ds = c->fn_data;
        if (ds && ds->magic == DOWNLOAD_MAGIC) {
            if (ds->chunks_sent < DOWNLOAD_TOTAL_CHUNKS) {
                dl_send_batch(c, ds);
            } else {
                free(ds);
                c->fn_data = NULL;
            }
        }
        return;
    }

    // Free download state if client disconnects mid-transfer.
    if (ev == MG_EV_CLOSE) {
        DownloadState *ds = c->fn_data;
        if (ds && ds->magic == DOWNLOAD_MAGIC) {
            free(ds);
            c->fn_data = NULL;
        }
        return;
    }

    if (ev == MG_EV_HTTP_MSG) {
        struct mg_http_message *hm = (struct mg_http_message *) ev_data;
        if (mg_match(hm->method, mg_str("OPTIONS"), NULL)) {
            mg_http_reply(c, 204, CORS_HEADERS, "");
            return;
        }
        if (mg_match(hm->uri, mg_str("/ws"), NULL)) {
            mg_ws_upgrade(c, hm, NULL);
            send_history_to_client(c);
        } else if (mg_match(hm->uri, mg_str("/download"), NULL)) {
            // Set up chunked download state and send the first batch.
            DownloadState *ds = calloc(1, sizeof(DownloadState));
            ds->magic = DOWNLOAD_MAGIC;
            memset(ds->buf, 0x61, 1024); // 'a'
            c->fn_data = ds;
            mg_printf(c, "HTTP/1.1 200 OK\r\n"
                         CORS_HEADERS
                         "Content-Type: application/octet-stream\r\n"
                         "Transfer-Encoding: chunked\r\n\r\n");
            dl_send_batch(c, ds);
        } else if (mg_match(hm->uri, mg_str("/ping"), NULL)) ping_handler(c, ev, ev_data);
        else if (mg_match(hm->uri, mg_str("/upload"), NULL)) upload_handler(c, ev, ev_data);
        else if (mg_match(hm->uri, mg_str("/traffic"), NULL)) traffic_handler(c, ev, ev_data);
        else mg_http_reply(c, 200, CORS_HEADERS, "Arpahound Live Stream Server Running\n");
    }
}

static void *start_capture(void *param) {
    char err[PCAP_ERRBUF_SIZE];
    printf("Capturing on all interfaces\n"); fflush(stdout);
    pcap_t *h = pcap_open_live("any", BUFSIZ, 1, 10, err);
    if (h) {
        struct bpf_program fp;
        if (pcap_compile(h, &fp, "not port 8000 and not port 30800", 1, PCAP_NETMASK_UNKNOWN) == 0) {
            pcap_setfilter(h, &fp);
            pcap_freecode(&fp);
        }
        int linktype = pcap_datalink(h);
        printf("Live capture started (linktype=%d)\n", linktype); fflush(stdout);
        pcap_loop(h, -1, packet_handler, (u_char *)&linktype);
        pcap_close(h);
    } else {
        fprintf(stderr, "pcap_open_live failed: %s\n", err);
    }
    return NULL;
}

int main(void) {
    mg_mgr_init(&mgr);
    pthread_t tid;
    pthread_create(&tid, NULL, start_capture, NULL);
    pthread_detach(tid);
    mg_http_listen(&mgr, "http://0.0.0.0:8000", fn, NULL);

    for (;;) {
        mg_mgr_poll(&mgr, 10);
        if (new_packet_flag) {
            pthread_mutex_lock(&history_mutex);
            new_packet_flag = false;
            pthread_mutex_unlock(&history_mutex);
            broadcast_last_packet();
        }
    }
    return 0;
}
