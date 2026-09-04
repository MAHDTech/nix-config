// SPDX-License-Identifier: GPL-2.0
/*
 * aipu-uat — user acceptance test for the ArmChina Zhouyi NPU on Radxa Orion O6.
 *
 * WHY THIS EXISTS
 * ---------------
 * The CPU and GPU can be validated with off-the-shelf tools (stress-ng, glmark2,
 * vkmark). The NPU cannot: running an actual inference needs a model compiled by
 * ArmChina's Compass NN compiler into a Zhouyi TCB instruction stream, plus the
 * Compass userspace runtime. Neither is packaged in nixpkgs and neither is open
 * source, so "run a model and check the output" is not available here.
 *
 * What IS available is the driver's ioctl ABI on /dev/aipu, which is enough to
 * prove the hardware is real, powered, clocked, addressable and cycling. This
 * tool does exactly that and is explicit about the line it does not cross.
 *
 * WHAT EACH CHECK ACTUALLY PROVES
 * -------------------------------
 *   QUERY_CAP / QUERY_PARTITION_CAP
 *       The driver read the hardware's own identification and topology
 *       registers. version==6 (ZHOUYI_V3_1) and reg_base==0x14260000 coming
 *       back from silicon rather than from the DT is the NPU equivalent of
 *       panthor printing "Mali-G720-Immortalis id 0xc870".
 *
 *   REQ_IO reads of TSM_REVISION / TSM_BUILD_INFO
 *       Live MMIO. A powered-down or reset-held block reads back 0x00000000 or
 *       0xffffffff; anything else means the bus transaction reached the NPU and
 *       came back. This is the check that would have caught the GPU being held
 *       in reset immediately instead of via an SError.
 *
 *   REQ_BUF / FREE_BUF
 *       The memory manager allocated from the reserved carveout at 0xb0000000
 *       and handed back a physical address. Confirms the DT memory-region
 *       resolved and dma_alloc succeeded — the path that silently does nothing
 *       if the region node is misnamed.
 *
 *   ENABLE_TICK_COUNTER + repeated tick reads
 *       The strongest liveness signal short of inference. The tick counter is
 *       driven by the NPU's own clock, so a value that ADVANCES between reads
 *       proves the core is powered AND clocked AND running, not merely
 *       responding to register reads.
 *
 * WHAT IT DOES NOT PROVE
 * ----------------------
 *   Numerical correctness of inference, or sustained multi-core compute load.
 *   Those need the Compass SDK. Do not read a pass here as "the NPU computes
 *   correct results" — read it as "the NPU is alive, addressable and clocking".
 *   The stress mode below loads the driver, the memory manager and the register
 *   path continuously; it does not saturate the MAC arrays.
 *
 * Build:  cc -O2 -Wall -o aipu-uat aipu-uat.c
 * Usage:  aipu-uat [--stress SECONDS] [--quiet]
 * Exit:   0 all checks passed, 1 a check failed, 2 could not open /dev/aipu.
 */

#include <errno.h>
#include <fcntl.h>
#include <stdarg.h>
#include <stdint.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <sys/ioctl.h>
#include <time.h>
#include <unistd.h>

/*
 * ABI, copied verbatim from drivers/misc/armchina-npu/include/armchina_aipu.h.
 * Verbatim matters: any field reordering here silently corrupts every ioctl.
 */
#define AIPU_IOCTL_MAGIC 'A'

struct aipu_partition_cap {
	uint32_t id;
	uint32_t arch;
	uint32_t version;
	uint32_t config;
	struct aipu_debugger_info {
		uint64_t reg_base;
	} info;
	uint32_t cluster_cnt;
	struct aipu_cluster_cap {
		uint32_t core_cnt;
		uint32_t en_core_cnt;
		uint32_t tec_cnt;
	} clusters[8];
};

struct aipu_cap {
	uint32_t partition_cnt;
	uint32_t asid_cnt;
	uint64_t asid_base[32];
	uint32_t is_homogeneous;
	uint64_t dtcm_base;
	uint32_t dtcm_size;
	uint32_t gm0_size;
	uint32_t gm1_size;
	struct aipu_partition_cap partition_cap;
};

struct aipu_buf_desc {
	uint64_t pa;
	uint64_t dev_offset;
	uint64_t bytes;
	uint8_t region;
	uint8_t asid;
};

struct aipu_buf_request {
	uint64_t bytes;
	uint32_t align_in_page;
	uint32_t data_type;
	uint8_t region;
	uint8_t asid;
	struct aipu_buf_desc desc;
};

struct aipu_io_req {
	uint32_t partition_id;
	uint32_t offset;
	enum aipu_rw_attr { AIPU_IO_READ, AIPU_IO_WRITE } rw;
	uint32_t value;
};

struct aipu_hw_status {
	enum { AIPU_STATUS_IDLE, AIPU_STATUS_BUSY, AIPU_STATUS_EXCEPTION } status;
};

#define AIPU_IOCTL_QUERY_CAP		_IOR(AIPU_IOCTL_MAGIC, 0, struct aipu_cap)
#define AIPU_IOCTL_QUERY_PARTITION_CAP	_IOR(AIPU_IOCTL_MAGIC, 1, struct aipu_partition_cap)
#define AIPU_IOCTL_REQ_BUF		_IOWR(AIPU_IOCTL_MAGIC, 2, struct aipu_buf_request)
#define AIPU_IOCTL_FREE_BUF		_IOW(AIPU_IOCTL_MAGIC, 3, struct aipu_buf_desc)
#define AIPU_IOCTL_REQ_IO		_IOWR(AIPU_IOCTL_MAGIC, 9, struct aipu_io_req)
#define AIPU_IOCTL_GET_HW_STATUS	_IOR(AIPU_IOCTL_MAGIC, 10, struct aipu_hw_status)
#define AIPU_IOCTL_ENABLE_TICK_COUNTER	_IO(AIPU_IOCTL_MAGIC, 13)
#define AIPU_IOCTL_DISABLE_TICK_COUNTER	_IO(AIPU_IOCTL_MAGIC, 12)

/* zhouyi/v3_1.h and zhouyi/v3.h */
#define TSM_BUILD_INFO_REG		0x14
#define TSM_STATUS_REG			0x18
#define TSM_REVISION_REG		0x50
#define TICK_COUNTER_LOW_REG		0x60
#define TICK_COUNTER_HIGH_REG		0x64

/*
 * This silicon reports 5 (V3), not 6 (V3_1) as the marketing generation would
 * suggest. Established at probe: with only the V3_1 handler compiled in the
 * driver rejected it with "unidentified hardware version number: 5". Accept
 * either and report which, rather than asserting the one we expected.
 */
#define ZHOUYI_V3			5
#define ZHOUYI_V3_1			6

static int failures;
static int quiet;

static void ok(const char *fmt, ...)
{
	va_list ap;

	if (quiet)
		return;
	fputs("  [ ok ] ", stdout);
	va_start(ap, fmt);
	vprintf(fmt, ap);
	va_end(ap);
	putchar('\n');
}

static void bad(const char *fmt, ...)
{
	va_list ap;

	failures++;
	fputs("  [FAIL] ", stdout);
	va_start(ap, fmt);
	vprintf(fmt, ap);
	va_end(ap);
	putchar('\n');
}

static uint32_t reg_read(int fd, uint32_t off, int *err)
{
	struct aipu_io_req io = { .partition_id = 0, .offset = off, .rw = AIPU_IO_READ };

	*err = ioctl(fd, AIPU_IOCTL_REQ_IO, &io);
	return io.value;
}

static uint64_t tick_read(int fd)
{
	int e1, e2;
	uint32_t lo = reg_read(fd, TICK_COUNTER_LOW_REG, &e1);
	uint32_t hi = reg_read(fd, TICK_COUNTER_HIGH_REG, &e2);

	if (e1 || e2)
		return 0;
	return ((uint64_t)hi << 32) | lo;
}

static double now_s(void)
{
	struct timespec ts;

	clock_gettime(CLOCK_MONOTONIC, &ts);
	return ts.tv_sec + ts.tv_nsec / 1e9;
}

int main(int argc, char **argv)
{
	int fd, ret, err;
	long stress_secs = 0;
	struct aipu_cap cap;
	struct aipu_partition_cap pcap;
	struct aipu_hw_status hw;

	for (int i = 1; i < argc; i++) {
		if (!strcmp(argv[i], "--stress") && i + 1 < argc)
			stress_secs = strtol(argv[++i], NULL, 10);
		else if (!strcmp(argv[i], "--quiet"))
			quiet = 1;
	}

	fd = open("/dev/aipu", O_RDWR);
	if (fd < 0) {
		fprintf(stderr, "cannot open /dev/aipu: %s\n", strerror(errno));
		fprintf(stderr, "the driver is a module and blacklisted on first boot;\n");
		fprintf(stderr, "load it with: sudo modprobe armchina_npu\n");
		return 2;
	}

	printf("== identification ==\n");
	memset(&cap, 0, sizeof(cap));
	ret = ioctl(fd, AIPU_IOCTL_QUERY_CAP, &cap);
	if (ret) {
		bad("QUERY_CAP failed: %s", strerror(errno));
	} else {
		ok("partitions=%u asid_cnt=%u homogeneous=%u",
		   cap.partition_cnt, cap.asid_cnt, cap.is_homogeneous);
		ok("global memory gm0=%u KiB gm1=%u KiB dtcm=%u KiB",
		   cap.gm0_size / 1024, cap.gm1_size / 1024, cap.dtcm_size / 1024);
	}

	memset(&pcap, 0, sizeof(pcap));
	ret = ioctl(fd, AIPU_IOCTL_QUERY_PARTITION_CAP, &pcap);
	if (ret) {
		bad("QUERY_PARTITION_CAP failed: %s", strerror(errno));
	} else {
		unsigned total_cores = 0, enabled_cores = 0;

		if (pcap.version == ZHOUYI_V3)
			ok("ISA version %u = Zhouyi V3 (what this silicon reports)",
			   pcap.version);
		else if (pcap.version == ZHOUYI_V3_1)
			ok("ISA version %u = Zhouyi V3_1", pcap.version);
		else
			bad("ISA version %u, expected %u (V3) or %u (V3_1)",
			    pcap.version, ZHOUYI_V3, ZHOUYI_V3_1);

		if (pcap.info.reg_base == 0x14260000ULL)
			ok("register base 0x%llx matches the DT node",
			   (unsigned long long)pcap.info.reg_base);
		else
			bad("register base 0x%llx, expected 0x14260000",
			    (unsigned long long)pcap.info.reg_base);

		for (unsigned c = 0; c < pcap.cluster_cnt && c < 8; c++) {
			total_cores += pcap.clusters[c].core_cnt;
			enabled_cores += pcap.clusters[c].en_core_cnt;
			ok("cluster %u: %u cores (%u enabled), %u TECs", c,
			   pcap.clusters[c].core_cnt, pcap.clusters[c].en_core_cnt,
			   pcap.clusters[c].tec_cnt);
		}
		if (enabled_cores)
			ok("%u of %u cores enabled across %u cluster(s)",
			   enabled_cores, total_cores, pcap.cluster_cnt);
		else
			bad("no NPU cores reported as enabled");
	}

	printf("== live register access ==\n");
	{
		uint32_t rev = reg_read(fd, TSM_REVISION_REG, &err);

		if (err)
			bad("REQ_IO read of TSM_REVISION failed: %s", strerror(errno));
		else if (rev == 0x0 || rev == 0xffffffff)
			bad("TSM_REVISION reads 0x%08x — block unpowered or held in reset", rev);
		else
			ok("TSM_REVISION = 0x%08x (live MMIO)", rev);

		uint32_t bi = reg_read(fd, TSM_BUILD_INFO_REG, &err);

		if (!err && bi != 0x0 && bi != 0xffffffff)
			ok("TSM_BUILD_INFO = 0x%08x", bi);
		else if (!err)
			bad("TSM_BUILD_INFO reads 0x%08x", bi);

		uint32_t st = reg_read(fd, TSM_STATUS_REG, &err);

		if (!err)
			ok("TSM_STATUS = 0x%08x", st);
	}

	memset(&hw, 0, sizeof(hw));
	if (!ioctl(fd, AIPU_IOCTL_GET_HW_STATUS, &hw)) {
		if (hw.status == AIPU_STATUS_EXCEPTION)
			bad("hardware reports EXCEPTION state");
		else
			ok("hardware status = %s",
			   hw.status == AIPU_STATUS_IDLE ? "IDLE" : "BUSY");
	}

	printf("== memory manager (carveout at 0xb0000000) ==\n");
	{
		struct aipu_buf_request req;

		memset(&req, 0, sizeof(req));
		req.bytes = 1 << 20;
		req.align_in_page = 1;
		req.data_type = 0;
		if (ioctl(fd, AIPU_IOCTL_REQ_BUF, &req)) {
			bad("REQ_BUF 1 MiB failed: %s", strerror(errno));
		} else {
			ok("allocated 1 MiB at pa=0x%llx (region %u)",
			   (unsigned long long)req.desc.pa, req.desc.region);
			if (req.desc.pa >= 0xb0000000ULL && req.desc.pa < 0xd0000000ULL)
				ok("allocation lies inside the reserved carveout");
			else
				printf("  [note] pa outside 0xb0000000-0xcfffffff; "
				       "driver fell back to system CMA\n");
			if (ioctl(fd, AIPU_IOCTL_FREE_BUF, &req.desc))
				bad("FREE_BUF failed: %s", strerror(errno));
			else
				ok("freed");
		}
	}

	printf("== clock liveness (tick counter) ==\n");
	{
		uint64_t t0, t1;

		if (ioctl(fd, AIPU_IOCTL_ENABLE_TICK_COUNTER)) {
			bad("ENABLE_TICK_COUNTER failed: %s", strerror(errno));
		} else {
			t0 = tick_read(fd);
			usleep(200000);
			t1 = tick_read(fd);
			if (t1 > t0)
				ok("tick counter advanced %llu in 200 ms — core is clocked",
				   (unsigned long long)(t1 - t0));
			else
				bad("tick counter did not advance (%llu -> %llu): "
				    "core powered but not clocking",
				    (unsigned long long)t0, (unsigned long long)t1);
			ioctl(fd, AIPU_IOCTL_DISABLE_TICK_COUNTER);
		}
	}

	if (stress_secs > 0) {
		double t_end = now_s() + stress_secs;
		unsigned long iters = 0, alloc_fail = 0, io_fail = 0;
		uint64_t tick_start, tick_end;

		printf("== stress: %ld s of allocation churn and register I/O ==\n", stress_secs);
		printf("   (exercises driver, memory manager and MMIO path; does NOT\n");
		printf("    saturate the MAC arrays — that needs the Compass SDK)\n");
		ioctl(fd, AIPU_IOCTL_ENABLE_TICK_COUNTER);
		tick_start = tick_read(fd);

		while (now_s() < t_end) {
			struct aipu_buf_request req;

			memset(&req, 0, sizeof(req));
			req.bytes = (1 << 20) * (1 + (iters % 8));
			req.align_in_page = 1;
			if (ioctl(fd, AIPU_IOCTL_REQ_BUF, &req))
				alloc_fail++;
			else
				ioctl(fd, AIPU_IOCTL_FREE_BUF, &req.desc);

			reg_read(fd, TSM_REVISION_REG, &err);
			if (err)
				io_fail++;
			reg_read(fd, TSM_STATUS_REG, &err);
			if (err)
				io_fail++;

			if (++iters % 2000 == 0 && !quiet) {
				printf("   %lus left, %lu iterations, %lu alloc fail, %lu io fail\n",
				       (unsigned long)(t_end - now_s()), iters, alloc_fail, io_fail);
				fflush(stdout);
			}
		}

		tick_end = tick_read(fd);
		ioctl(fd, AIPU_IOCTL_DISABLE_TICK_COUNTER);

		printf("== stress result ==\n");
		if (alloc_fail)
			bad("%lu allocation failures over %lu iterations", alloc_fail, iters);
		else
			ok("%lu alloc/free cycles, zero failures", iters);
		if (io_fail)
			bad("%lu register I/O failures", io_fail);
		else
			ok("register I/O clean throughout");
		if (tick_end > tick_start)
			ok("tick counter advanced %llu over the run",
			   (unsigned long long)(tick_end - tick_start));
		else
			bad("tick counter stalled during the run");

		memset(&hw, 0, sizeof(hw));
		if (!ioctl(fd, AIPU_IOCTL_GET_HW_STATUS, &hw) &&
		    hw.status == AIPU_STATUS_EXCEPTION)
			bad("hardware entered EXCEPTION state during stress");
		else
			ok("no hardware exception after stress");
	}

	close(fd);
	printf("\n%s (%d failure%s)\n", failures ? "FAILED" : "PASSED",
	       failures, failures == 1 ? "" : "s");
	return failures ? 1 : 0;
}
