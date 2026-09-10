#ifndef AP_UNICODE_TEXT_CODEC_H
#define AP_UNICODE_TEXT_CODEC_H
#include <stddef.h>
#include <stdint.h>

/* Standard Unicode text, not JNI modified UTF-8. No normalization or NUL
 * termination is applied to content. Malformed UTF-8 bytes and unpaired
 * UTF-16 surrogates become U+FFFD; valid neighbouring characters are retained.
 * Caller capacities: UTF-16 <= input bytes; UTF-8 <= 3 * input UTF-16 units. */
static inline size_t ap_utf8_to_utf16(const uint8_t *bytes, size_t length, uint16_t *units) {
    size_t written = 0;
    for (size_t i = 0; i < length;) {
        uint32_t point = 0xfffd;
        size_t count = 1;
        uint8_t first = bytes[i];
        if (first < 0x80) {
            point = first;
        } else {
            size_t needed = first >= 0xc2 && first <= 0xdf ? 2 :
                first >= 0xe0 && first <= 0xef ? 3 :
                first >= 0xf0 && first <= 0xf4 ? 4 : 0;
            if (needed && needed <= length - i) {
                uint32_t candidate = first & (needed == 2 ? 0x1f : needed == 3 ? 0x0f : 0x07);
                int valid = 1;
                for (size_t j = 1; j < needed; j++) {
                    if ((bytes[i + j] & 0xc0) != 0x80) { valid = 0; break; }
                    candidate = (candidate << 6) | (bytes[i + j] & 0x3f);
                }
                uint32_t minimum = needed == 2 ? 0x80 : needed == 3 ? 0x800 : 0x10000;
                if (valid && candidate >= minimum && candidate <= 0x10ffff &&
                    !(candidate >= 0xd800 && candidate <= 0xdfff)) {
                    point = candidate;
                    count = needed;
                }
            }
        }
        i += count;
        if (point <= 0xffff) {
            units[written++] = (uint16_t)point;
        } else {
            point -= 0x10000;
            units[written++] = (uint16_t)(0xd800 | (point >> 10));
            units[written++] = (uint16_t)(0xdc00 | (point & 0x3ff));
        }
    }
    return written;
}

static inline size_t ap_utf16_to_utf8(const uint16_t *units, size_t length, uint8_t *bytes) {
    size_t written = 0;
    for (size_t i = 0; i < length; i++) {
        uint32_t point = units[i];
        if (point >= 0xd800 && point <= 0xdbff) {
            if (i + 1 < length && units[i + 1] >= 0xdc00 && units[i + 1] <= 0xdfff) {
                point = 0x10000 + ((point - 0xd800) << 10) + (units[++i] - 0xdc00);
            } else point = 0xfffd;
        } else if (point >= 0xdc00 && point <= 0xdfff) point = 0xfffd;
        if (point < 0x80) bytes[written++] = (uint8_t)point;
        else if (point < 0x800) {
            bytes[written++] = (uint8_t)(0xc0 | (point >> 6));
            bytes[written++] = (uint8_t)(0x80 | (point & 0x3f));
        } else if (point < 0x10000) {
            bytes[written++] = (uint8_t)(0xe0 | (point >> 12));
            bytes[written++] = (uint8_t)(0x80 | ((point >> 6) & 0x3f));
            bytes[written++] = (uint8_t)(0x80 | (point & 0x3f));
        } else {
            bytes[written++] = (uint8_t)(0xf0 | (point >> 18));
            bytes[written++] = (uint8_t)(0x80 | ((point >> 12) & 0x3f));
            bytes[written++] = (uint8_t)(0x80 | ((point >> 6) & 0x3f));
            bytes[written++] = (uint8_t)(0x80 | (point & 0x3f));
        }
    }
    return written;
}
#endif
