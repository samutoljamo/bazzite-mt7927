/* SPDX-License-Identifier: GPL-2.0-only */
/* Compat stub for linux/soc/airoha/airoha_offload.h (introduced in Linux 6.19).
 * Needed when building mt76 from 6.19 source against older kernel headers.
 * CONFIG_NET_AIROHA and CONFIG_NET_AIROHA_NPU are unset on x86/Fedora,
 * so only the no-op stubs are compiled.
 */
#ifndef AIROHA_OFFLOAD_H
#define AIROHA_OFFLOAD_H

#include <linux/skbuff.h>
#include <linux/spinlock.h>
#include <linux/workqueue.h>

enum {
	PPE_CPU_REASON_HIT_UNBIND_RATE_REACHED = 0x0f,
};

struct airoha_ppe_dev {
	struct {
		int (*setup_tc_block_cb)(struct airoha_ppe_dev *dev,
					 void *type_data);
		void (*check_skb)(struct airoha_ppe_dev *dev,
				  struct sk_buff *skb, u16 hash,
				  bool rx_wlan);
	} ops;

	void *priv;
};

static inline struct airoha_ppe_dev *airoha_ppe_get_dev(struct device *dev)
{ return NULL; }
static inline void airoha_ppe_put_dev(struct airoha_ppe_dev *dev) {}
static inline int airoha_ppe_dev_setup_tc_block_cb(struct airoha_ppe_dev *dev,
						   void *type_data)
{ return -EOPNOTSUPP; }
static inline void airoha_ppe_dev_check_skb(struct airoha_ppe_dev *dev,
					    struct sk_buff *skb, u16 hash,
					    bool rx_wlan) {}

#define NPU_NUM_CORES		8
#define NPU_NUM_IRQ		6
#define NPU_RX0_DESC_NUM	512
#define NPU_RX1_DESC_NUM	512

/* CTRL */
#define NPU_RX_DMA_DESC_LAST_MASK	BIT(27)
#define NPU_RX_DMA_DESC_LEN_MASK	GENMASK(26, 14)
#define NPU_RX_DMA_DESC_CUR_LEN_MASK	GENMASK(13, 1)
#define NPU_RX_DMA_DESC_DONE_MASK	BIT(0)
/* INFO */
#define NPU_RX_DMA_PKT_COUNT_MASK	GENMASK(31, 29)
#define NPU_RX_DMA_PKT_ID_MASK		GENMASK(28, 26)
#define NPU_RX_DMA_SRC_PORT_MASK	GENMASK(25, 21)
#define NPU_RX_DMA_CRSN_MASK		GENMASK(20, 16)
#define NPU_RX_DMA_FOE_ID_MASK		GENMASK(15, 0)
/* DATA */
#define NPU_RX_DMA_SID_MASK		GENMASK(31, 16)
#define NPU_RX_DMA_FRAG_TYPE_MASK	GENMASK(15, 14)
#define NPU_RX_DMA_PRIORITY_MASK	GENMASK(13, 10)
#define NPU_RX_DMA_RADIO_ID_MASK	GENMASK(9, 6)
#define NPU_RX_DMA_VAP_ID_MASK		GENMASK(5, 2)
#define NPU_RX_DMA_FRAME_TYPE_MASK	GENMASK(1, 0)

struct airoha_npu_rx_dma_desc {
	u32 ctrl;
	u32 info;
	u32 data;
	u32 addr;
	u64 rsv;
} __packed;

/* CTRL */
#define NPU_TX_DMA_DESC_SCHED_MASK	BIT(31)
#define NPU_TX_DMA_DESC_LEN_MASK	GENMASK(30, 18)
#define NPU_TX_DMA_DESC_VEND_LEN_MASK	GENMASK(17, 1)
#define NPU_TX_DMA_DESC_DONE_MASK	BIT(0)

#define NPU_TXWI_LEN	192

struct airoha_npu_tx_dma_desc {
	u32 ctrl;
	u32 addr;
	u64 rsv;
	u8 txwi[NPU_TXWI_LEN];
} __packed;

enum airoha_npu_wlan_set_cmd {
	WLAN_FUNC_SET_WAIT_PCIE_ADDR,
	WLAN_FUNC_SET_WAIT_DESC,
	WLAN_FUNC_SET_WAIT_NPU_INIT_DONE,
	WLAN_FUNC_SET_WAIT_TRAN_TO_CPU,
	WLAN_FUNC_SET_WAIT_BA_WIN_SIZE,
	WLAN_FUNC_SET_WAIT_DRIVER_MODEL,
	WLAN_FUNC_SET_WAIT_DEL_STA,
	WLAN_FUNC_SET_WAIT_DRAM_BA_NODE_ADDR,
	WLAN_FUNC_SET_WAIT_PKT_BUF_ADDR,
	WLAN_FUNC_SET_WAIT_IS_TEST_NOBA,
	WLAN_FUNC_SET_WAIT_FLUSHONE_TIMEOUT,
	WLAN_FUNC_SET_WAIT_FLUSHALL_TIMEOUT,
	WLAN_FUNC_SET_WAIT_IS_FORCE_TO_CPU,
	WLAN_FUNC_SET_WAIT_PCIE_STATE,
	WLAN_FUNC_SET_WAIT_PCIE_PORT_TYPE,
	WLAN_FUNC_SET_WAIT_ERROR_RETRY_TIMES,
	WLAN_FUNC_SET_WAIT_BAR_INFO,
	WLAN_FUNC_SET_WAIT_FAST_FLAG,
	WLAN_FUNC_SET_WAIT_NPU_BAND0_ONCPU,
	WLAN_FUNC_SET_WAIT_TX_RING_PCIE_ADDR,
	WLAN_FUNC_SET_WAIT_TX_DESC_HW_BASE,
	WLAN_FUNC_SET_WAIT_TX_BUF_SPACE_HW_BASE,
	WLAN_FUNC_SET_WAIT_RX_RING_FOR_TXDONE_HW_BASE,
	WLAN_FUNC_SET_WAIT_TX_PKT_BUF_ADDR,
	WLAN_FUNC_SET_WAIT_INODE_TXRX_REG_ADDR,
	WLAN_FUNC_SET_WAIT_INODE_DEBUG_FLAG,
	WLAN_FUNC_SET_WAIT_INODE_HW_CFG_INFO,
	WLAN_FUNC_SET_WAIT_INODE_STOP_ACTION,
	WLAN_FUNC_SET_WAIT_INODE_PCIE_SWAP,
	WLAN_FUNC_SET_WAIT_RATELIMIT_CTRL,
	WLAN_FUNC_SET_WAIT_HWNAT_INIT,
	WLAN_FUNC_SET_WAIT_ARHT_CHIP_INFO,
	WLAN_FUNC_SET_WAIT_TX_BUF_CHECK_ADDR,
	WLAN_FUNC_SET_WAIT_TOKEN_ID_SIZE,
};

enum airoha_npu_wlan_get_cmd {
	WLAN_FUNC_GET_WAIT_NPU_INFO,
	WLAN_FUNC_GET_WAIT_LAST_RATE,
	WLAN_FUNC_GET_WAIT_COUNTER,
	WLAN_FUNC_GET_WAIT_DBG_COUNTER,
	WLAN_FUNC_GET_WAIT_RXDESC_BASE,
	WLAN_FUNC_GET_WAIT_WCID_DBG_COUNTER,
	WLAN_FUNC_GET_WAIT_DMA_ADDR,
	WLAN_FUNC_GET_WAIT_RING_SIZE,
	WLAN_FUNC_GET_WAIT_NPU_SUPPORT_MAP,
	WLAN_FUNC_GET_WAIT_MDC_LOCK_ADDRESS,
	WLAN_FUNC_GET_WAIT_NPU_VERSION,
};

struct airoha_npu {
	/* empty on non-Airoha kernels */
};

static inline struct airoha_npu *airoha_npu_get(struct device *dev)
{ return NULL; }
static inline void airoha_npu_put(struct airoha_npu *npu) {}
static inline int airoha_npu_wlan_init_reserved_memory(struct airoha_npu *npu)
{ return -EOPNOTSUPP; }
static inline int airoha_npu_wlan_send_msg(struct airoha_npu *npu,
					   int ifindex,
					   enum airoha_npu_wlan_set_cmd cmd,
					   void *data, int data_len, gfp_t gfp)
{ return -EOPNOTSUPP; }
static inline int airoha_npu_wlan_get_msg(struct airoha_npu *npu, int ifindex,
					  enum airoha_npu_wlan_get_cmd cmd,
					  void *data, int data_len, gfp_t gfp)
{ return -EOPNOTSUPP; }
static inline u32 airoha_npu_wlan_get_queue_addr(struct airoha_npu *npu,
						 int qid, bool xmit)
{ return 0; }
static inline void airoha_npu_wlan_set_irq_status(struct airoha_npu *npu,
						  u32 val) {}
static inline u32 airoha_npu_wlan_get_irq_status(struct airoha_npu *npu, int q)
{ return 0; }
static inline void airoha_npu_wlan_enable_irq(struct airoha_npu *npu, int q) {}
static inline void airoha_npu_wlan_disable_irq(struct airoha_npu *npu, int q) {}

#endif /* AIROHA_OFFLOAD_H */
