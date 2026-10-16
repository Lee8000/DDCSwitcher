@import Foundation;
@import IOKit;
#include "i2c.h"

static uint32_t capturedLength;
static UInt8 capturedBytes[DDC_BUFFER_SIZE];
static uint32_t capturedAddress;
IOReturn IOAVServiceWriteI2C(IOAVServiceRef service, uint32_t chipAddress, uint32_t address, void *buffer, uint32_t length) {
    (void)service; (void)chipAddress;
    capturedLength = length; capturedAddress = address;
    memcpy(capturedBytes, buffer, length);
    return kIOReturnSuccess;
}
IOReturn IOAVServiceReadI2C(IOAVServiceRef service, uint32_t chipAddress, uint32_t address, void *buffer, uint32_t length) {
    (void)service; (void)chipAddress; (void)address; (void)buffer; (void)length;
    return kIOReturnUnsupported;
}

int main(void) {
    struct { UInt8 code; UInt16 value; UInt8 checksum; } cases[] = {
        {INPUT, 17, 0xC9}, {INPUT, 216, 0}, {INPUT_ALT, 144, 0xDD}, {INPUT_ALT, 77, 0}
    };
    int failures = 0;
    for (unsigned i = 0; i < sizeof(cases) / sizeof(cases[0]); i++) {
        DDCPacket packet = createDDCPacket(cases[i].code);
        prepareDDCWrite(&packet, cases[i].value);
        performDDCWriteAtChipAddress(NULL, DDC_CHIP_ADDRESS_DEFAULT, &packet);
        if (capturedLength != 6 || capturedBytes[5] != cases[i].checksum || capturedAddress != packet.inputAddr) {
            fprintf(stderr, "FAIL: input %u/%u expected length 6/checksum %u, got %u/%u\n",
                cases[i].code, cases[i].value, cases[i].checksum, capturedLength, capturedBytes[5]);
            failures++;
        }
    }
    if (!failures) puts("PASS: 4 DDC packet cases, including zero checksum, mocked IOAV only.");
    return failures ? 1 : 0;
}
