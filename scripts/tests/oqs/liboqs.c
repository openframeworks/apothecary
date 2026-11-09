#include <oqs/oqs.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>

static int check_kem(const char *algorithm) {
    OQS_KEM *kem = OQS_KEM_new(algorithm);
    if (!kem) return 0;
    unsigned char *pk = malloc(kem->length_public_key), *sk = malloc(kem->length_secret_key);
    unsigned char *ct = malloc(kem->length_ciphertext), *a = malloc(kem->length_shared_secret), *b = malloc(kem->length_shared_secret);
    if (!pk || !sk || !ct || !a || !b) return 0;
    if (OQS_KEM_keypair(kem, pk, sk) != OQS_SUCCESS ||
        OQS_KEM_encaps(kem, ct, a, pk) != OQS_SUCCESS ||
        OQS_KEM_decaps(kem, b, ct, sk) != OQS_SUCCESS ||
        memcmp(a, b, kem->length_shared_secret)) return 0;
    ct[0] ^= 1;
    if (OQS_KEM_decaps(kem, b, ct, sk) == OQS_SUCCESS &&
        !memcmp(a, b, kem->length_shared_secret)) return 0;
    free(pk); free(sk); free(ct); free(a); free(b); OQS_KEM_free(kem);
    return 1;
}

int main(void) {
    OQS_init();
    if (!check_kem(OQS_KEM_alg_ml_kem_768) ||
        !check_kem(OQS_KEM_alg_ntruprime_sntrup761)) return 1;
    OQS_SIG *sig = OQS_SIG_new(OQS_SIG_alg_ml_dsa_44);
    if (!sig) return 1;
    unsigned char *pk = malloc(sig->length_public_key), *sk = malloc(sig->length_secret_key);
    unsigned char *signature = malloc(sig->length_signature);
    size_t length = 0;
    const unsigned char message[] = "Apothecary OQS smoke test";
    if (!pk || !sk || !signature) return 1;
    if (OQS_SIG_keypair(sig, pk, sk) != OQS_SUCCESS ||
        OQS_SIG_sign(sig, signature, &length, message, sizeof(message), sk) != OQS_SUCCESS ||
        OQS_SIG_verify(sig, message, sizeof(message), signature, length, pk) != OQS_SUCCESS) return 1;
    signature[0] ^= 1;
    if (OQS_SIG_verify(sig, message, sizeof(message), signature, length, pk) == OQS_SUCCESS) return 1;
    free(pk); free(sk); free(signature); OQS_SIG_free(sig); OQS_destroy();
    puts("liboqs ML-KEM-768, SNTRUP761 and ML-DSA-44 passed, including negative controls");
    return 0;
}
