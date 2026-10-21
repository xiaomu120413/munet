// NetTools native core.
//
// Exposes the probing primitives used by ping, port scanning and LAN sweeps:
// a non-blocking TCP connect raced against a timeout, a batch scanner with
// native thread-pool concurrency, interface enumeration via getifaddrs, and
// the port-expression parser. Keeping these in C++ lets ArkTS dispatch
// thousands of probes without one JS socket object per attempt.

#include <napi/native_api.h>

#include <algorithm>
#include <arpa/inet.h>
#include <atomic>
#include <cerrno>
#include <chrono>
#include <cstdio>
#include <cstdlib>
#include <cstring>
#include <fcntl.h>
#include <ifaddrs.h>
#include <net/if.h>
#include <netdb.h>
#include <netinet/in.h>
#include <poll.h>
#include <sstream>
#include <sys/socket.h>
#include <thread>
#include <unistd.h>
#include <vector>

#include <string>

namespace {

enum ProbeError {
    kOk = 0,
    kTimeout = 1,
    kRefused = 2,
    kDns = 3,
    kOther = 4,
};

struct ProbeOutcome {
    bool ok = false;
    int rttMs = 0;
    int error = kOther;
};

// ---------------------------------------------------------------------------
// Single TCP probe
// ---------------------------------------------------------------------------

ProbeOutcome ProbeAddress(const sockaddr_storage &base, int family, int port, int timeoutMs) {
    ProbeOutcome outcome;
    if (port <= 0 || port > 65535) {
        outcome.error = kOther;
        return outcome;
    }
    if (timeoutMs <= 0) {
        timeoutMs = 1;
    }

    sockaddr_storage target = base;
    if (family == AF_INET) {
        reinterpret_cast<sockaddr_in *>(&target)->sin_port = htons(static_cast<uint16_t>(port));
    } else if (family == AF_INET6) {
        reinterpret_cast<sockaddr_in6 *>(&target)->sin6_port = htons(static_cast<uint16_t>(port));
    } else {
        outcome.error = kOther;
        return outcome;
    }

    int fd = socket(family, SOCK_STREAM, 0);
    if (fd < 0) {
        outcome.error = kOther;
        return outcome;
    }

    int flags = fcntl(fd, F_GETFL, 0);
    if (flags >= 0) {
        fcntl(fd, F_SETFL, flags | O_NONBLOCK);
    }

    auto started = std::chrono::steady_clock::now();
    bool connected = (connect(fd, reinterpret_cast<const sockaddr *>(&target),
                              family == AF_INET ? sizeof(sockaddr_in) : sizeof(sockaddr_in6)) == 0);

    bool timedOut = false;
    bool refused = false;
    if (!connected && errno == EINPROGRESS) {
        pollfd pfd{};
        pfd.fd = fd;
        pfd.events = POLLOUT;
        int ready = poll(&pfd, 1, timeoutMs);
        if (ready == 0) {
            timedOut = true;
        } else if (ready > 0) {
            int socketError = 0;
            socklen_t len = sizeof(socketError);
            if (getsockopt(fd, SOL_SOCKET, SO_ERROR, &socketError, &len) == 0) {
                if (socketError == 0) {
                    connected = true;
                } else if (socketError == ECONNREFUSED) {
                    refused = true;
                }
            }
        }
    } else if (!connected && errno == ECONNREFUSED) {
        refused = true;
    }

    long elapsed = static_cast<long>(
        std::chrono::duration_cast<std::chrono::milliseconds>(
            std::chrono::steady_clock::now() - started)
            .count());
    close(fd);

    if (connected) {
        outcome.ok = true;
        outcome.rttMs = static_cast<int>(elapsed);
        outcome.error = kOk;
    } else {
        outcome.error = timedOut ? kTimeout : (refused ? kRefused : kOther);
    }
    return outcome;
}

ProbeOutcome ProbeTcp(const std::string &host, int port, int timeoutMs) {
    ProbeOutcome outcome;
    if (host.empty() || port <= 0 || port > 65535) {
        outcome.error = kOther;
        return outcome;
    }

    addrinfo hints{};
    hints.ai_family = AF_UNSPEC;
    hints.ai_socktype = SOCK_STREAM;

    char portText[8];
    snprintf(portText, sizeof(portText), "%d", port);

    addrinfo *resolved = nullptr;
    if (getaddrinfo(host.c_str(), portText, &hints, &resolved) != 0 || resolved == nullptr) {
        outcome.error = kDns;
        return outcome;
    }

    for (addrinfo *candidate = resolved; candidate != nullptr; candidate = candidate->ai_next) {
        sockaddr_storage base{};
        memcpy(&base, candidate->ai_addr, candidate->ai_addrlen);
        outcome = ProbeAddress(base, candidate->ai_family, port, timeoutMs);
        if (outcome.ok) {
            break;
        }
    }
    freeaddrinfo(resolved);
    return outcome;
}

const char *ErrorName(int error) {
    switch (error) {
        case kOk:
            return "";
        case kTimeout:
            return "timeout";
        case kRefused:
            return "refused";
        case kDns:
            return "dns";
        default:
            return "other";
    }
}

// ---------------------------------------------------------------------------
// Interface enumeration (getifaddrs)
// ---------------------------------------------------------------------------

struct IfaceEntry {
    std::string name;
    std::string address;
    int family = 0;     // AF_INET / AF_INET6
    int prefix = 0;
    bool loopback = false;
    bool up = false;
};

int PrefixLength(const sockaddr *mask, int family) {
    if (mask == nullptr) {
        return 0;
    }
    const uint8_t *bytes = nullptr;
    int length = 0;
    if (family == AF_INET) {
        bytes = reinterpret_cast<const uint8_t *>(
            &reinterpret_cast<const sockaddr_in *>(mask)->sin_addr);
        length = 4;
    } else {
        bytes = reinterpret_cast<const uint8_t *>(
            &reinterpret_cast<const sockaddr_in6 *>(mask)->sin6_addr);
        length = 16;
    }
    int bits = 0;
    for (int i = 0; i < length; ++i) {
        uint8_t byte = bytes[i];
        while ((byte & 0x80) != 0) {
            ++bits;
            byte = static_cast<uint8_t>(byte << 1);
        }
        if (byte != 0) {
            break;
        }
    }
    return bits;
}

std::vector<IfaceEntry> ListInterfaces() {
    std::vector<IfaceEntry> entries;
    ifaddrs *interfaces = nullptr;
    if (getifaddrs(&interfaces) != 0 || interfaces == nullptr) {
        return entries;
    }
    for (ifaddrs *it = interfaces; it != nullptr; it = it->ifa_next) {
        if (it->ifa_addr == nullptr || it->ifa_name == nullptr) {
            continue;
        }
        int family = it->ifa_addr->sa_family;
        if (family != AF_INET && family != AF_INET6) {
            continue;
        }
        char host[NI_MAXHOST] = {0};
        socklen_t addrLength = family == AF_INET ? sizeof(sockaddr_in) : sizeof(sockaddr_in6);
        if (getnameinfo(it->ifa_addr, addrLength, host, sizeof(host), nullptr, 0,
                        NI_NUMERICHOST) != 0) {
            continue;
        }
        IfaceEntry entry;
        entry.name = it->ifa_name;
        entry.address = host;
        entry.family = family;
        entry.prefix = PrefixLength(it->ifa_netmask, family);
        entry.loopback = (it->ifa_flags & IFF_LOOPBACK) != 0;
        entry.up = (it->ifa_flags & IFF_UP) != 0;
        entries.push_back(entry);
    }
    freeifaddrs(interfaces);
    return entries;
}

// ---------------------------------------------------------------------------
// Batch scanner (async NAPI work + native thread pool)
// ---------------------------------------------------------------------------

std::atomic<uint64_t> g_scanGeneration{1};

struct ProgressPayload {
    int64_t done;
    int64_t total;
};

struct ScanJob {
    napi_deferred deferred = nullptr;
    napi_async_work work = nullptr;
    napi_threadsafe_function progress = nullptr;

    std::string host;
    std::vector<int> ports;
    int concurrency = 64;
    int timeoutMs = 1500;
    uint64_t generation = 0;

    std::atomic<size_t> next{0};
    std::atomic<size_t> done{0};
    std::vector<ProbeOutcome> results;
};

void CallProgress(napi_env env, napi_value jsCallback, void * /*context*/, void *data) {
    auto *payload = static_cast<ProgressPayload *>(data);
    if (env == nullptr || jsCallback == nullptr) {
        delete payload;
        return;
    }
    napi_value argv[2];
    napi_create_int64(env, payload->done, &argv[0]);
    napi_create_int64(env, payload->total, &argv[1]);
    napi_value global;
    napi_get_global(env, &global);
    napi_call_function(env, global, jsCallback, 2, argv, nullptr);
    delete payload;
}

void ReportProgress(napi_threadsafe_function tsfn, size_t done, size_t total) {
    if (tsfn == nullptr) {
        return;
    }
    auto *payload = new ProgressPayload{static_cast<int64_t>(done), static_cast<int64_t>(total)};
    napi_call_threadsafe_function(tsfn, payload, napi_tsfn_nonblocking);
}

void ExecuteScan(napi_env /*env*/, void *data) {
    auto *job = static_cast<ScanJob *>(data);
    size_t total = job->ports.size();
    job->results.assign(total, ProbeOutcome{});
    if (total == 0) {
        return;
    }

    addrinfo hints{};
    hints.ai_family = AF_UNSPEC;
    hints.ai_socktype = SOCK_STREAM;

    addrinfo *resolved = nullptr;
    if (getaddrinfo(job->host.c_str(), nullptr, &hints, &resolved) != 0 || resolved == nullptr) {
        for (size_t i = 0; i < total; ++i) {
            job->results[i].error = kDns;
        }
        job->done = total;
        ReportProgress(job->progress, total, total);
        return;
    }

    sockaddr_storage base{};
    memcpy(&base, resolved->ai_addr, resolved->ai_addrlen);
    int family = resolved->ai_family;
    freeaddrinfo(resolved);

    auto worker = [job, &base, family, total]() {
        while (true) {
            if (job->generation != g_scanGeneration.load()) {
                return;
            }
            size_t index = job->next.fetch_add(1);
            if (index >= total) {
                return;
            }
            job->results[index] = ProbeAddress(base, family, job->ports[index], job->timeoutMs);
            size_t done = job->done.fetch_add(1) + 1;
            if (done % 8 == 0 || done == total) {
                ReportProgress(job->progress, done, total);
            }
        }
    };

    size_t workers = std::min<size_t>(static_cast<size_t>(std::max(1, job->concurrency)), total);
    std::vector<std::thread> threads;
    threads.reserve(workers);
    for (size_t i = 0; i < workers; ++i) {
        threads.emplace_back(worker);
    }
    for (auto &thread : threads) {
        thread.join();
    }
}

void CompleteScan(napi_env env, napi_status /*status*/, void *data) {
    auto *job = static_cast<ScanJob *>(data);

    napi_value result = nullptr;
    napi_create_array_with_length(env, job->ports.size(), &result);
    for (size_t i = 0; i < job->ports.size(); ++i) {
        napi_value item = nullptr;
        napi_create_object(env, &item);

        napi_value port = nullptr;
        napi_create_int32(env, job->ports[i], &port);
        napi_set_named_property(env, item, "port", port);

        napi_value open = nullptr;
        napi_get_boolean(env, job->results[i].ok, &open);
        napi_set_named_property(env, item, "open", open);

        napi_value rttMs = nullptr;
        napi_create_int32(env, job->results[i].rttMs, &rttMs);
        napi_set_named_property(env, item, "rttMs", rttMs);

        napi_value error = nullptr;
        napi_create_string_utf8(env, ErrorName(job->results[i].error), NAPI_AUTO_LENGTH, &error);
        napi_set_named_property(env, item, "error", error);

        napi_set_element(env, result, i, item);
    }

    napi_resolve_deferred(env, job->deferred, result);
    if (job->progress != nullptr) {
        napi_release_threadsafe_function(job->progress, napi_tsfn_release);
    }
    napi_delete_async_work(env, job->work);
    delete job;
}

napi_value Version(napi_env env, napi_callback_info /*info*/) {
    napi_value result = nullptr;
    napi_create_string_utf8(env, "0.3.0", NAPI_AUTO_LENGTH, &result);
    return result;
}

napi_value ProbeTcpNapi(napi_env env, napi_callback_info info) {
    size_t argc = 3;
    napi_value args[3] = {nullptr};
    napi_get_cb_info(env, info, &argc, args, nullptr, nullptr);

    char host[256] = {0};
    size_t hostLength = 0;
    int32_t port = 0;
    int32_t timeoutMs = 2000;

    if (argc > 0) {
        napi_get_value_string_utf8(env, args[0], host, sizeof(host), &hostLength);
    }
    if (argc > 1) {
        napi_get_value_int32(env, args[1], &port);
    }
    if (argc > 2) {
        napi_get_value_int32(env, args[2], &timeoutMs);
    }

    ProbeOutcome outcome = ProbeTcp(host, port, timeoutMs);

    napi_value result = nullptr;
    napi_create_object(env, &result);

    napi_value ok = nullptr;
    napi_get_boolean(env, outcome.ok, &ok);
    napi_set_named_property(env, result, "ok", ok);

    napi_value rttMs = nullptr;
    napi_create_int32(env, outcome.rttMs, &rttMs);
    napi_set_named_property(env, result, "rttMs", rttMs);

    napi_value error = nullptr;
    napi_create_string_utf8(env, ErrorName(outcome.error), NAPI_AUTO_LENGTH, &error);
    napi_set_named_property(env, result, "error", error);

    return result;
}

napi_value ListInterfacesNapi(napi_env env, napi_callback_info /*info*/) {
    std::vector<IfaceEntry> entries = ListInterfaces();

    napi_value result = nullptr;
    napi_create_array_with_length(env, entries.size(), &result);

    uint32_t index = 0;
    for (const IfaceEntry &entry : entries) {
        napi_value item = nullptr;
        napi_create_object(env, &item);

        napi_value name = nullptr;
        napi_create_string_utf8(env, entry.name.c_str(), NAPI_AUTO_LENGTH, &name);
        napi_set_named_property(env, item, "name", name);

        napi_value address = nullptr;
        napi_create_string_utf8(env, entry.address.c_str(), NAPI_AUTO_LENGTH, &address);
        napi_set_named_property(env, item, "address", address);

        napi_value family = nullptr;
        napi_create_string_utf8(env, entry.family == AF_INET ? "v4" : "v6", NAPI_AUTO_LENGTH,
                                &family);
        napi_set_named_property(env, item, "family", family);

        napi_value prefix = nullptr;
        napi_create_int32(env, entry.prefix, &prefix);
        napi_set_named_property(env, item, "prefixLength", prefix);

        napi_value loopback = nullptr;
        napi_get_boolean(env, entry.loopback, &loopback);
        napi_set_named_property(env, item, "loopback", loopback);

        napi_value up = nullptr;
        napi_get_boolean(env, entry.up, &up);
        napi_set_named_property(env, item, "up", up);

        napi_set_element(env, result, index++, item);
    }
    return result;
}

napi_value ParsePortExprNapi(napi_env env, napi_callback_info info) {
    size_t argc = 1;
    napi_value args[1] = {nullptr};
    napi_get_cb_info(env, info, &argc, args, nullptr, nullptr);

    char expr[4096] = {0};
    if (argc > 0) {
        napi_get_value_string_utf8(env, args[0], expr, sizeof(expr), nullptr);
    }

    std::vector<bool> seen(65536, false);
    std::string text(expr);
    size_t start = 0;
    while (start <= text.size()) {
        size_t comma = text.find(',', start);
        std::string token = text.substr(start, comma == std::string::npos ? std::string::npos
                                                                          : comma - start);
        // trim spaces
        size_t begin = token.find_first_not_of(" \t");
        size_t end = token.find_last_not_of(" \t");
        if (begin != std::string::npos) {
            token = token.substr(begin, end - begin + 1);
        } else {
            token.clear();
        }
        if (!token.empty()) {
            size_t dash = token.find('-');
            if (dash == std::string::npos) {
                char *tail = nullptr;
                long value = strtol(token.c_str(), &tail, 10);
                if (tail != token.c_str() && *tail == '\0' && value >= 1 && value <= 65535) {
                    seen[static_cast<size_t>(value)] = true;
                }
            } else {
                std::string left = token.substr(0, dash);
                std::string right = token.substr(dash + 1);
                char *tailLeft = nullptr;
                char *tailRight = nullptr;
                long low = strtol(left.c_str(), &tailLeft, 10);
                long high = strtol(right.c_str(), &tailRight, 10);
                if (tailLeft != left.c_str() && *tailLeft == '\0' &&
                    tailRight != right.c_str() && *tailRight == '\0' &&
                    low >= 1 && high <= 65535 && low <= high) {
                    for (long value = low; value <= high; ++value) {
                        seen[static_cast<size_t>(value)] = true;
                    }
                }
            }
        }
        if (comma == std::string::npos) {
            break;
        }
        start = comma + 1;
    }

    std::vector<int> ports;
    for (size_t port = 1; port < seen.size(); ++port) {
        if (seen[port]) {
            ports.push_back(static_cast<int>(port));
        }
    }

    napi_value result = nullptr;
    napi_create_array_with_length(env, ports.size(), &result);
    for (size_t i = 0; i < ports.size(); ++i) {
        napi_value item = nullptr;
        napi_create_int32(env, ports[i], &item);
        napi_set_element(env, result, static_cast<uint32_t>(i), item);
    }
    return result;
}

napi_value ScanPortsNapi(napi_env env, napi_callback_info info) {
    size_t argc = 5;
    napi_value args[5] = {nullptr};
    napi_get_cb_info(env, info, &argc, args, nullptr, nullptr);

    auto *job = new ScanJob();

    char host[256] = {0};
    if (argc > 0) {
        napi_get_value_string_utf8(env, args[0], host, sizeof(host), nullptr);
    }
    job->host = host;

    if (argc > 1) {
        uint32_t length = 0;
        napi_get_array_length(env, args[1], &length);
        job->ports.reserve(length);
        for (uint32_t i = 0; i < length; ++i) {
            napi_value element = nullptr;
            uint32_t value = 0;
            napi_get_element(env, args[1], i, &element);
            napi_get_value_uint32(env, element, &value);
            if (value >= 1 && value <= 65535) {
                job->ports.push_back(static_cast<int>(value));
            }
        }
    }

    int32_t concurrency = 64;
    int32_t timeoutMs = 1500;
    if (argc > 2) {
        napi_get_value_int32(env, args[2], &concurrency);
    }
    if (argc > 3) {
        napi_get_value_int32(env, args[3], &timeoutMs);
    }
    job->concurrency = std::max(1, std::min(512, concurrency));
    job->timeoutMs = std::max(100, std::min(60000, timeoutMs));

    napi_valuetype callbackType = napi_undefined;
    if (argc > 4) {
        napi_typeof(env, args[4], &callbackType);
    }
    if (callbackType == napi_function) {
        napi_value resourceName = nullptr;
        napi_create_string_utf8(env, "scanProgress", NAPI_AUTO_LENGTH, &resourceName);
        napi_create_threadsafe_function(env, args[4], nullptr, resourceName, 0, 1, nullptr,
                                        nullptr, nullptr, CallProgress, &job->progress);
    }

    job->generation = g_scanGeneration.load();

    napi_value promise = nullptr;
    napi_create_promise(env, &job->deferred, &promise);

    napi_value workName = nullptr;
    napi_create_string_utf8(env, "scanPorts", NAPI_AUTO_LENGTH, &workName);
    napi_create_async_work(env, nullptr, workName, ExecuteScan, CompleteScan, job, &job->work);
    napi_queue_async_work(env, job->work);

    return promise;
}

napi_value CancelScanNapi(napi_env env, napi_callback_info /*info*/) {
    g_scanGeneration.fetch_add(1);
    napi_value result = nullptr;
    napi_get_undefined(env, &result);
    return result;
}

// ---------------------------------------------------------------------------
// LAN sweep (IPv4 CIDR)
// ---------------------------------------------------------------------------

struct HostOutcome {
    std::string ip;
    bool online = false;
    std::vector<int> openPorts;
};

struct SweepJob {
    napi_deferred deferred = nullptr;
    napi_async_work work = nullptr;
    napi_threadsafe_function progress = nullptr;

    uint32_t firstHost = 0;   // host byte order
    uint32_t hostCount = 0;
    std::vector<int> ports;
    int concurrency = 128;
    int timeoutMs = 1000;
    uint64_t generation = 0;

    std::atomic<size_t> next{0};
    std::atomic<size_t> done{0};
    std::vector<HostOutcome> results;
};

std::string IpToString(uint32_t hostOrderIp) {
    in_addr addr{};
    addr.s_addr = htonl(hostOrderIp);
    char buffer[INET_ADDRSTRLEN] = {0};
    inet_ntop(AF_INET, &addr, buffer, sizeof(buffer));
    return std::string(buffer);
}

// Large prefixes are rejected here; the UI asks for confirmation above 1024
// hosts and the hard cap below keeps memory bounded.
bool ParseCidr(const std::string &cidr, uint32_t &firstHost, uint32_t &hostCount) {
    size_t slash = cidr.find('/');
    if (slash == std::string::npos) {
        return false;
    }
    std::string ipPart = cidr.substr(0, slash);
    std::string prefixPart = cidr.substr(slash + 1);

    in_addr addr{};
    if (inet_pton(AF_INET, ipPart.c_str(), &addr) != 1) {
        return false;
    }
    char *tail = nullptr;
    long prefix = strtol(prefixPart.c_str(), &tail, 10);
    if (tail == prefixPart.c_str() || *tail != '\0' || prefix < 1 || prefix > 32) {
        return false;
    }

    uint32_t ip = ntohl(addr.s_addr);
    uint32_t mask = prefix == 32 ? 0xFFFFFFFFu : (0xFFFFFFFFu << (32 - prefix));
    uint32_t network = ip & mask;

    uint32_t count = 0;
    if (prefix == 32) {
        count = 1;
    } else if (prefix == 31) {
        count = 2;
    } else {
        count = (1u << (32 - prefix)) - 2;
    }
    if (count == 0 || count > 65536u) {
        return false;
    }
    firstHost = network + (prefix >= 31 ? 0 : 1);
    hostCount = count;
    return true;
}

void ExecuteSweep(napi_env /*env*/, void *data) {
    auto *job = static_cast<SweepJob *>(data);
    size_t total = job->hostCount;
    job->results.resize(total);
    if (total == 0) {
        return;
    }

    auto worker = [job, total]() {
        while (true) {
            if (job->generation != g_scanGeneration.load()) {
                return;
            }
            size_t index = job->next.fetch_add(1);
            if (index >= total) {
                return;
            }
            uint32_t hostIp = job->firstHost + static_cast<uint32_t>(index);

            sockaddr_storage base{};
            auto *addr = reinterpret_cast<sockaddr_in *>(&base);
            addr->sin_family = AF_INET;
            addr->sin_addr.s_addr = htonl(hostIp);

            HostOutcome &outcome = job->results[index];
            outcome.ip = IpToString(hostIp);
            for (int port : job->ports) {
                ProbeOutcome probe = ProbeAddress(base, AF_INET, port, job->timeoutMs);
                if (probe.ok) {
                    outcome.online = true;
                    outcome.openPorts.push_back(port);
                }
            }

            size_t done = job->done.fetch_add(1) + 1;
            if (done % 4 == 0 || done == total) {
                ReportProgress(job->progress, done, total);
            }
        }
    };

    size_t workers = std::min<size_t>(static_cast<size_t>(std::max(1, job->concurrency)), total);
    std::vector<std::thread> threads;
    threads.reserve(workers);
    for (size_t i = 0; i < workers; ++i) {
        threads.emplace_back(worker);
    }
    for (auto &thread : threads) {
        thread.join();
    }
}

void CompleteSweep(napi_env env, napi_status /*status*/, void *data) {
    auto *job = static_cast<SweepJob *>(data);

    napi_value result = nullptr;
    napi_create_array_with_length(env, job->results.size(), &result);
    for (size_t i = 0; i < job->results.size(); ++i) {
        napi_value item = nullptr;
        napi_create_object(env, &item);

        napi_value ip = nullptr;
        napi_create_string_utf8(env, job->results[i].ip.c_str(), NAPI_AUTO_LENGTH, &ip);
        napi_set_named_property(env, item, "ip", ip);

        napi_value online = nullptr;
        napi_get_boolean(env, job->results[i].online, &online);
        napi_set_named_property(env, item, "online", online);

        napi_value ports = nullptr;
        napi_create_array_with_length(env, job->results[i].openPorts.size(), &ports);
        for (size_t p = 0; p < job->results[i].openPorts.size(); ++p) {
            napi_value port = nullptr;
            napi_create_int32(env, job->results[i].openPorts[p], &port);
            napi_set_element(env, ports, static_cast<uint32_t>(p), port);
        }
        napi_set_named_property(env, item, "openPorts", ports);

        napi_set_element(env, result, static_cast<uint32_t>(i), item);
    }

    napi_resolve_deferred(env, job->deferred, result);
    if (job->progress != nullptr) {
        napi_release_threadsafe_function(job->progress, napi_tsfn_release);
    }
    napi_delete_async_work(env, job->work);
    delete job;
}

napi_value SweepCidrNapi(napi_env env, napi_callback_info info) {
    size_t argc = 5;
    napi_value args[5] = {nullptr};
    napi_get_cb_info(env, info, &argc, args, nullptr, nullptr);

    auto *job = new SweepJob();

    char cidr[64] = {0};
    if (argc > 0) {
        napi_get_value_string_utf8(env, args[0], cidr, sizeof(cidr), nullptr);
    }

    if (argc > 1) {
        uint32_t length = 0;
        napi_get_array_length(env, args[1], &length);
        job->ports.reserve(length);
        for (uint32_t i = 0; i < length; ++i) {
            napi_value element = nullptr;
            uint32_t value = 0;
            napi_get_element(env, args[1], i, &element);
            napi_get_value_uint32(env, element, &value);
            if (value >= 1 && value <= 65535) {
                job->ports.push_back(static_cast<int>(value));
            }
        }
    }

    int32_t concurrency = 128;
    int32_t timeoutMs = 1000;
    if (argc > 2) {
        napi_get_value_int32(env, args[2], &concurrency);
    }
    if (argc > 3) {
        napi_get_value_int32(env, args[3], &timeoutMs);
    }
    job->concurrency = std::max(1, std::min(512, concurrency));
    job->timeoutMs = std::max(100, std::min(60000, timeoutMs));

    napi_valuetype callbackType = napi_undefined;
    if (argc > 4) {
        napi_typeof(env, args[4], &callbackType);
    }
    if (callbackType == napi_function) {
        napi_value resourceName = nullptr;
        napi_create_string_utf8(env, "sweepProgress", NAPI_AUTO_LENGTH, &resourceName);
        napi_create_threadsafe_function(env, args[4], nullptr, resourceName, 0, 1, nullptr,
                                        nullptr, nullptr, CallProgress, &job->progress);
    }

    job->generation = g_scanGeneration.load();

    napi_value promise = nullptr;
    napi_create_promise(env, &job->deferred, &promise);

    if (!ParseCidr(cidr, job->firstHost, job->hostCount)) {
        // Resolve immediately with an empty result; the UI validates input.
        napi_value empty = nullptr;
        napi_create_array(env, &empty);
        napi_resolve_deferred(env, job->deferred, empty);
        if (job->progress != nullptr) {
            napi_release_threadsafe_function(job->progress, napi_tsfn_release);
        }
        delete job;
        return promise;
    }

    napi_value workName = nullptr;
    napi_create_string_utf8(env, "sweepCidr", NAPI_AUTO_LENGTH, &workName);
    napi_create_async_work(env, nullptr, workName, ExecuteSweep, CompleteSweep, job, &job->work);
    napi_queue_async_work(env, job->work);

    return promise;
}

// ---------------------------------------------------------------------------
// Local listening sockets (/proc/net/tcp[6], state 0A)
// ---------------------------------------------------------------------------

struct ListeningPort {
    int port = 0;
    std::string address;
    int family = AF_INET;
    uint32_t uid = 0;
};

bool DecodeProcAddress(const std::string &hex, int family, std::string &address) {
    char buffer[INET6_ADDRSTRLEN] = {0};
    if (family == AF_INET) {
        if (hex.size() != 8) {
            return false;
        }
        uint32_t value = static_cast<uint32_t>(strtoul(hex.c_str(), nullptr, 16));
        in_addr addr{};
        addr.s_addr = htonl(static_cast<uint32_t>(
            ((value & 0xFFu) << 24) | ((value & 0xFF00u) << 8) |
            ((value >> 8) & 0xFF00u) | ((value >> 24) & 0xFFu)));
        if (inet_ntop(AF_INET, &addr, buffer, sizeof(buffer)) == nullptr) {
            return false;
        }
        address = buffer;
        return true;
    }
    if (hex.size() != 32) {
        return false;
    }
    uint8_t bytes[16] = {0};
    for (int group = 0; group < 4; ++group) {
        std::string word = hex.substr(group * 8, 8);
        uint32_t value = static_cast<uint32_t>(strtoul(word.c_str(), nullptr, 16));
        bytes[group * 4 + 0] = static_cast<uint8_t>(value & 0xFFu);
        bytes[group * 4 + 1] = static_cast<uint8_t>((value >> 8) & 0xFFu);
        bytes[group * 4 + 2] = static_cast<uint8_t>((value >> 16) & 0xFFu);
        bytes[group * 4 + 3] = static_cast<uint8_t>((value >> 24) & 0xFFu);
    }
    if (inet_ntop(AF_INET6, bytes, buffer, sizeof(buffer)) == nullptr) {
        return false;
    }
    address = buffer;
    return true;
}

// Returns false when /proc/net/tcp* cannot be opened (sandbox restriction).
bool ReadListeningPorts(std::vector<ListeningPort> &out) {
    const char *paths[2] = {"/proc/net/tcp", "/proc/net/tcp6"};
    const int families[2] = {AF_INET, AF_INET6};
    bool readable = false;

    for (int fileIndex = 0; fileIndex < 2; ++fileIndex) {
        FILE *file = fopen(paths[fileIndex], "r");
        if (file == nullptr) {
            continue;
        }
        readable = true;
        char line[512];
        bool header = true;
        while (fgets(line, sizeof(line), file) != nullptr) {
            if (header) {
                header = false;
                continue;
            }
            std::istringstream stream(line);
            std::string sl;
            std::string local;
            std::string remote;
            std::string state;
            std::string txrx;
            std::string trtm;
            std::string retr;
            std::string uidText;
            if (!(stream >> sl >> local >> remote >> state >> txrx >> trtm >> retr >> uidText)) {
                continue;
            }
            if (state != "0A") {
                continue;
            }
            size_t colon = local.find(':');
            if (colon == std::string::npos) {
                continue;
            }
            std::string addressHex = local.substr(0, colon);
            std::string portHex = local.substr(colon + 1);
            ListeningPort entry;
            entry.family = families[fileIndex];
            entry.port = static_cast<int>(strtoul(portHex.c_str(), nullptr, 16));
            entry.uid = static_cast<uint32_t>(strtoul(uidText.c_str(), nullptr, 10));
            if (entry.port <= 0 || entry.port > 65535) {
                continue;
            }
            if (!DecodeProcAddress(addressHex, entry.family, entry.address)) {
                continue;
            }
            out.push_back(entry);
        }
        fclose(file);
    }
    return readable;
}

napi_value ListListeningPortsNapi(napi_env env, napi_callback_info /*info*/) {
    std::vector<ListeningPort> ports;
    if (!ReadListeningPorts(ports)) {
        napi_value nullValue = nullptr;
        napi_get_null(env, &nullValue);
        return nullValue;
    }

    napi_value result = nullptr;
    napi_create_array_with_length(env, ports.size(), &result);
    for (size_t i = 0; i < ports.size(); ++i) {
        napi_value item = nullptr;
        napi_create_object(env, &item);

        napi_value port = nullptr;
        napi_create_int32(env, ports[i].port, &port);
        napi_set_named_property(env, item, "port", port);

        napi_value address = nullptr;
        napi_create_string_utf8(env, ports[i].address.c_str(), NAPI_AUTO_LENGTH, &address);
        napi_set_named_property(env, item, "address", address);

        napi_value family = nullptr;
        napi_create_string_utf8(env, ports[i].family == AF_INET ? "v4" : "v6", NAPI_AUTO_LENGTH,
                                &family);
        napi_set_named_property(env, item, "family", family);

        napi_value uid = nullptr;
        napi_create_uint32(env, ports[i].uid, &uid);
        napi_set_named_property(env, item, "uid", uid);

        napi_set_element(env, result, static_cast<uint32_t>(i), item);
    }
    return result;
}

}  // namespace

EXTERN_C_START
static napi_value Init(napi_env env, napi_value exports) {
    napi_property_descriptor desc[] = {
        {"version", nullptr, Version, nullptr, nullptr, nullptr, napi_default, nullptr},
        {"probeTcp", nullptr, ProbeTcpNapi, nullptr, nullptr, nullptr, napi_default, nullptr},
        {"listInterfaces", nullptr, ListInterfacesNapi, nullptr, nullptr, nullptr, napi_default,
         nullptr},
        {"parsePortExpr", nullptr, ParsePortExprNapi, nullptr, nullptr, nullptr, napi_default,
         nullptr},
        {"scanPorts", nullptr, ScanPortsNapi, nullptr, nullptr, nullptr, napi_default, nullptr},
        {"sweepCidr", nullptr, SweepCidrNapi, nullptr, nullptr, nullptr, napi_default, nullptr},
        {"listListeningPorts", nullptr, ListListeningPortsNapi, nullptr, nullptr, nullptr,
         napi_default, nullptr},
        {"cancelScan", nullptr, CancelScanNapi, nullptr, nullptr, nullptr, napi_default, nullptr},
    };
    napi_define_properties(env, exports, sizeof(desc) / sizeof(desc[0]), desc);
    return exports;
}
EXTERN_C_END

static napi_module nettoolsModule = {
    .nm_version = 1,
    .nm_flags = 0,
    .nm_filename = nullptr,
    .nm_register_func = Init,
    .nm_modname = "nettools",
    .nm_priv = ((void *)0),
    .reserved = {0},
};

extern "C" __attribute__((constructor)) void RegisterNettoolsModule(void) {
    napi_module_register(&nettoolsModule);
}
