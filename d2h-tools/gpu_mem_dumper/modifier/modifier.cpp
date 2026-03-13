#include <array>
#include <cstdint>
#include <cstring>
#include <fcntl.h>
#include <fstream>
#include <iomanip>
#include <iostream>
#include <sstream>
#include <string>
#include <sys/mman.h>
#include <unistd.h>

namespace
{

constexpr size_t kPageBytes = 4096;

void dump_page4k(const volatile uint8_t *window, uint64_t windowOffset, uint64_t physPageAddr)
{
    constexpr uint64_t kWindowBytes = 0x10000;
    if (windowOffset + kPageBytes > kWindowBytes)
    {
        std::cerr << "Requested 4KB read crosses window boundary (offset 0x" << std::hex << windowOffset << ")"
                  << std::dec << std::endl;
        return;
    }

    std::array<uint8_t, kPageBytes> buffer{};
    for (size_t i = 0; i < buffer.size(); ++i)
    {
        buffer[i] = *(window + windowOffset + i);
    }

    std::cout << "Dumping 4KB page at PA 0x" << std::hex << std::setw(16) << std::setfill('0')
              << static_cast<unsigned long long>(physPageAddr) << std::setfill(' ') << std::dec << std::endl;

    for (size_t row = 0; row < buffer.size(); row += 32)
    {
        std::cout << std::hex << std::setw(16) << std::setfill('0')
                  << static_cast<unsigned long long>(physPageAddr + row) << " : ";
        for (size_t col = 0; col < 4; ++col)
        {
            uint64_t value = 0;
            std::memcpy(&value, buffer.data() + row + (col * 8), sizeof(value));
            std::cout << std::setw(16) << static_cast<unsigned long long>(value) << ' ';
        }
        std::cout << std::setfill(' ') << std::dec << std::endl;
    }
}

} // namespace

int main(int argc, char *argv[])
{
    if (argc < 2)
    {
        std::cout << "Usage: " << argv[0] << " <pte_addr_hex> [pte_val_hex] [--write]" << std::endl;
        return -1;
    }

    bool writeBack = false;
    const char *pteValArg = nullptr;
    for (int i = 2; i < argc; ++i)
    {
        if (std::string(argv[i]) == "--write")
        {
            writeBack = true;
            continue;
        }
        if (!pteValArg)
        {
            pteValArg = argv[i];
        }
    }

    if (writeBack && !pteValArg)
    {
        std::cout << "PTE value required when --write is specified" << std::endl;
        return -1;
    }

    // retrieve NVIDIA GPU's BAR0
    uint64_t bar0Addr;

    std::ifstream iomemFile("/proc/iomem");
    if (!iomemFile.is_open())
    {
        std::cout << "cannot open /proc/iomem" << std::endl;
        return -1;
    }

    std::string line;
    while (std::getline(iomemFile, line))
    {
        if (line.find("nvidia") == std::string::npos)
            continue;
        std::istringstream iss(line);
        std::string str;
        std::getline(iss, str, '-');
        bar0Addr = std::stoul(str, nullptr, 16);
        break;
    }

    iomemFile.close();

    std::cout << "NVIDIA GPU BAR0: 0x" << std::hex << bar0Addr << std::dec << std::endl;

    // access memory via physical addresses
    int fd = open("/dev/mem", O_RDWR | O_SYNC);
    if (fd == -1)
    {
        std::cout << "cannot open /dev/mem: " << std::endl;
        return -1;
    }

    size_t len = 0x1000000;
    void *phyMem = mmap(0, len, PROT_READ | PROT_WRITE, MAP_SHARED, fd, bar0Addr);

    uint64_t regAddr = (uint64_t)phyMem + 0x1700;
    uint64_t winAddr = (uint64_t)phyMem + 0x700000;

    uint64_t pteAddr = std::stoull(argv[1], nullptr, 16);
    uint64_t pteVal = 0;
    if (pteValArg)
    {
        pteVal = std::stoull(pteValArg, nullptr, 16);
    }
    uint64_t offAmnt = pteAddr & 0x000000000000FFFF;

    // move window to the target address
    *(volatile uint32_t *)regAddr = pteAddr >> 16;

    uint64_t pagePhysAddr = pteAddr & ~0xFFFULL;
    uint64_t pageOffset = (pteAddr & 0x000000000000FFFFULL) & ~0xFFFULL;
    dump_page4k(reinterpret_cast<volatile uint8_t *>(winAddr), pageOffset, pagePhysAddr);

    // capture the existing 8-byte PTE value before modifying it
    uint64_t oldVal = 0;
    for (int i = 0; i < 8; ++i)
    {
        uint8_t byte = *(volatile uint8_t *)(winAddr + offAmnt + i);
        oldVal |= static_cast<uint64_t>(byte) << (i * 8);
    }
    std::cout << "Current PTE value at 0x" << std::hex << std::setw(16) << std::setfill('0')
              << static_cast<unsigned long long>(pteAddr) << ": 0x" << std::setw(16)
              << static_cast<unsigned long long>(oldVal) << std::endl;

    if (writeBack)
    {
        std::cout << "Writing new PTE value 0x" << std::setw(16) << static_cast<unsigned long long>(pteVal) << std::dec
                  << std::setfill(' ') << std::endl;

        for (int i = 0; i < 8; ++i)
        {
            uint8_t byte = (pteVal >> (i * 8)) & 0xFF;
            *(volatile uint8_t *)(winAddr + offAmnt + i) = byte;
        }
    }

    munmap(phyMem, len);
    close(fd);

    return 0;
}
