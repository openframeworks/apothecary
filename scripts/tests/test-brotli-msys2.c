#include <brotli/decode.h>
#include <brotli/encode.h>
#include <stdio.h>
#include <string.h>

int main(void) {
    unsigned char input[2048], encoded[4096], decoded[2048];
    size_t encoded_size = sizeof(encoded), decoded_size = sizeof(decoded);
    size_t i;
    for (i = 0; i < sizeof(input); ++i) input[i] = (unsigned char)(i * 31);
    if (BrotliEncoderVersion() != 0x01002001 ||
        BrotliDecoderVersion() != 0x01002001) return 1;
    if (!BrotliEncoderCompress(6, BROTLI_DEFAULT_WINDOW, BROTLI_MODE_GENERIC,
            sizeof(input), input, &encoded_size, encoded)) return 2;
    if (BrotliDecoderDecompress(encoded_size, encoded, &decoded_size, decoded) !=
            BROTLI_DECODER_RESULT_SUCCESS) return 3;
    if (decoded_size != sizeof(input) || memcmp(input, decoded, sizeof(input))) return 4;
    decoded_size = sizeof(decoded);
    if (BrotliDecoderDecompress(encoded_size - 1, encoded, &decoded_size, decoded) !=
            BROTLI_DECODER_RESULT_ERROR) return 5;
    puts("Packaged Brotli 1.2.1: encoder, decoder, common and truncated-input rejection passed");
    return 0;
}
