#include <assert.h>
#include <stdio.h>
#include <string.h>
#include "../../src/ui/native/unicode_text_codec.h"

int main(void) {
    size_t scalars = 0;
    for (uint32_t point = 0; point <= 0x10ffff; point++) {
        if (point >= 0xd800 && point <= 0xdfff) continue;
        uint16_t input[2], output[4];
        size_t units = 1;
        if (point < 0x10000) input[0] = (uint16_t)point;
        else { input[0] = 0xd800 | ((point - 0x10000) >> 10); input[1] = 0xdc00 | ((point - 0x10000) & 0x3ff); units = 2; }
        uint8_t bytes[6];
        size_t length = ap_utf16_to_utf8(input, units, bytes);
        assert(length == (point < 0x80 ? 1 : point < 0x800 ? 2 : point < 0x10000 ? 3 : 4));
        assert(ap_utf8_to_utf16(bytes, length, output) == units);
        assert(memcmp(input, output, units * sizeof(uint16_t)) == 0);
        scalars++;
    }
    const uint8_t mixed[] = {'A', 0, 0xe9, 0x9b, 0xaa, 0xf0, 0x9f, 0x98, 0x80, 'e', 0xcc, 0x81};
    uint16_t decoded[64]; uint8_t encoded[192];
    size_t units = ap_utf8_to_utf16(mixed, sizeof(mixed), decoded);
    assert(ap_utf16_to_utf8(decoded, units, encoded) == sizeof(mixed));
    assert(memcmp(mixed, encoded, sizeof(mixed)) == 0);
    const uint8_t bad[][5] = {{0xc0, 0x80}, {0xed, 0xa0, 0x80}, {0xf4, 0x90, 0x80, 0x80}, {0xf0, 0x80, 0x80, 0x80}, {0xf5, 0x80, 0x80, 0x80}, {0xe2, 'A', 0x80}, {0xe2, 0x82}};
    const size_t sizes[] = {2, 3, 4, 4, 4, 3, 2};
    for (size_t i = 0; i < sizeof(sizes) / sizeof(sizes[0]); i++) {
        assert(ap_utf8_to_utf16(bad[i], sizes[i], decoded) == sizes[i]);
        for (size_t j = 0; j < sizes[i]; j++) assert(decoded[j] == (bad[i][j] == 'A' ? 'A' : 0xfffd));
    }
    const uint16_t surrogates[] = {0xd800, 'A', 0xdc00, 0xdfff, 0xd800};
    const uint8_t replacements[] = {0xef,0xbf,0xbd,'A',0xef,0xbf,0xbd,0xef,0xbf,0xbd,0xef,0xbf,0xbd};
    assert(ap_utf16_to_utf8(surrogates, 5, encoded) == sizeof(replacements));
    assert(memcmp(encoded, replacements, sizeof(replacements)) == 0);
    assert(ap_utf8_to_utf16(NULL, 0, NULL) == 0);
    assert(ap_utf16_to_utf8(NULL, 0, NULL) == 0);
    printf("PASS: %zu Unicode scalars, embedded NUL, malformed UTF-8, unpaired surrogates and empty input\n", scalars);
    return 0;
}
