#include <openssl/crypto.h>
#include <openssl/err.h>
#include <openssl/evp.h>
#include <openssl/provider.h>
#include <openssl/rand.h>
#include <openssl/ssl.h>
#include <openssl/x509.h>
#include <openssl/x509_vfy.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#ifdef STATIC_OQS_PROVIDER
extern OSSL_provider_init_fn oqs_provider_init;
#endif
#define CHECK(expression) do { if (!(expression)) { fprintf(stderr, "Failed at line %d: %s\n", __LINE__, #expression); ERR_print_errors_fp(stderr); return 0; } } while (0)

static int certificate_check(OSSL_LIB_CTX *ctx) {
    EVP_PKEY *key = EVP_PKEY_Q_keygen(ctx, NULL, "EC", "prime256v1");
    X509 *cert = X509_new();
    CHECK(key && cert);
    CHECK(X509_set_version(cert, 2));
    CHECK(ASN1_INTEGER_set(X509_get_serialNumber(cert), 1));
    CHECK(X509_gmtime_adj(X509_getm_notBefore(cert), -60));
    CHECK(X509_gmtime_adj(X509_getm_notAfter(cert), 3600));
    X509_NAME *name = X509_NAME_new();
    CHECK(name);
    CHECK(X509_NAME_add_entry_by_txt(name, "CN", MBSTRING_ASC,
          (const unsigned char *)"Apothecary local test", -1, -1, 0));
    CHECK(X509_set_subject_name(cert, name));
    CHECK(X509_set_issuer_name(cert, name));
    X509_NAME_free(name);
    CHECK(X509_set_pubkey(cert, key));
    CHECK(X509_sign(cert, key, EVP_sha256()) > 0);
    CHECK(X509_verify(cert, key) == 1);
    X509_STORE *store = X509_STORE_new();
    X509_STORE_CTX *verify = X509_STORE_CTX_new_ex(ctx, NULL);
    CHECK(store && verify);
    CHECK(X509_STORE_set_flags(store, X509_V_FLAG_CHECK_SS_SIGNATURE));
    CHECK(X509_STORE_add_cert(store, cert));
    CHECK(X509_STORE_CTX_init(verify, store, cert, NULL));
    CHECK(X509_verify_cert(verify) == 1);
    X509_STORE_CTX_free(verify); X509_STORE_free(store);
    store = X509_STORE_new(); verify = X509_STORE_CTX_new_ex(ctx, NULL);
    CHECK(store && verify && X509_STORE_CTX_init(verify, store, cert, NULL));
    CHECK(X509_verify_cert(verify) != 1);
    ERR_clear_error();
    X509_STORE_CTX_free(verify); X509_STORE_free(store); X509_free(cert); EVP_PKEY_free(key);
    return 1;
}

static int kem_check(OSSL_LIB_CTX *ctx) {
    EVP_PKEY_CTX *generate = EVP_PKEY_CTX_new_from_name(ctx, "frodo640shake", "provider=oqsprovider");
    EVP_PKEY *key = NULL;
    CHECK(generate && EVP_PKEY_keygen_init(generate) > 0 && EVP_PKEY_generate(generate, &key) > 0);
    EVP_PKEY_CTX *operation = EVP_PKEY_CTX_new_from_pkey(ctx, key, "provider=oqsprovider");
    size_t ciphertext_length = 0, secret_length = 0, decoded_length;
    CHECK(operation && EVP_PKEY_encapsulate_init(operation, NULL) > 0);
    CHECK(EVP_PKEY_encapsulate(operation, NULL, &ciphertext_length, NULL, &secret_length) > 0);
    unsigned char *ciphertext = OPENSSL_malloc(ciphertext_length);
    unsigned char *secret = OPENSSL_malloc(secret_length), *decoded = OPENSSL_malloc(secret_length);
    CHECK(ciphertext && secret && decoded);
    CHECK(EVP_PKEY_encapsulate(operation, ciphertext, &ciphertext_length, secret, &secret_length) > 0);
    decoded_length = secret_length;
    CHECK(EVP_PKEY_decapsulate_init(operation, NULL) > 0);
    CHECK(EVP_PKEY_decapsulate(operation, decoded, &decoded_length, ciphertext, ciphertext_length) > 0);
    CHECK(decoded_length == secret_length && CRYPTO_memcmp(secret, decoded, secret_length) == 0);
    ciphertext[0] ^= 1;
    decoded_length = secret_length;
    int result = EVP_PKEY_decapsulate(operation, decoded, &decoded_length, ciphertext, ciphertext_length);
    CHECK(result <= 0 || decoded_length != secret_length || CRYPTO_memcmp(secret, decoded, secret_length) != 0);
    ERR_clear_error();
    OPENSSL_free(ciphertext); OPENSSL_clear_free(secret, secret_length); OPENSSL_clear_free(decoded, secret_length);
    EVP_PKEY_CTX_free(operation); EVP_PKEY_CTX_free(generate); EVP_PKEY_free(key);
    return 1;
}

static int signature_check(OSSL_LIB_CTX *ctx) {
    EVP_PKEY_CTX *generate = EVP_PKEY_CTX_new_from_name(ctx, "falcon512", "provider=oqsprovider");
    EVP_PKEY *key = NULL;
    CHECK(generate && EVP_PKEY_keygen_init(generate) > 0 && EVP_PKEY_generate(generate, &key) > 0);
    EVP_MD_CTX *sign = EVP_MD_CTX_new(), *verify = EVP_MD_CTX_new();
    const unsigned char message[] = "Apothecary provider smoke test";
    size_t signature_length = 0;
    CHECK(sign && verify);
    CHECK(EVP_DigestSignInit_ex(sign, NULL, NULL, ctx, "provider=oqsprovider", key, NULL) > 0);
    CHECK(EVP_DigestSign(sign, NULL, &signature_length, message, sizeof(message)) > 0);
    unsigned char *signature = OPENSSL_malloc(signature_length);
    CHECK(signature && EVP_DigestSign(sign, signature, &signature_length, message, sizeof(message)) > 0);
    CHECK(EVP_DigestVerifyInit_ex(verify, NULL, NULL, ctx, "provider=oqsprovider", key, NULL) > 0);
    CHECK(EVP_DigestVerify(verify, signature, signature_length, message, sizeof(message)) == 1);
    signature[0] ^= 1;
    CHECK(EVP_DigestVerify(verify, signature, signature_length, message, sizeof(message)) != 1);
    ERR_clear_error();
    OPENSSL_free(signature); EVP_MD_CTX_free(sign); EVP_MD_CTX_free(verify);
    EVP_PKEY_CTX_free(generate); EVP_PKEY_free(key);
    return 1;
}

static int run(const char *module_path) {
    CHECK(OpenSSL_version_num() == OPENSSL_VERSION_NUMBER);
    OSSL_LIB_CTX *ctx = OSSL_LIB_CTX_new();
    CHECK(ctx);
    OSSL_PROVIDER *defaults = OSSL_PROVIDER_load(ctx, "default");
    CHECK(defaults);
#ifdef STATIC_OQS_PROVIDER
    (void)module_path;
    CHECK(OSSL_PROVIDER_add_builtin(ctx, "oqsprovider", oqs_provider_init));
#else
    CHECK(module_path && OSSL_PROVIDER_set_default_search_path(ctx, module_path));
#endif
    OSSL_PROVIDER *provider = OSSL_PROVIDER_load(ctx, "oqsprovider");
    CHECK(provider && OSSL_PROVIDER_self_test(provider));
    unsigned char random[32], second_random[32];
    CHECK(RAND_bytes_ex(ctx, random, sizeof(random), 0));
    CHECK(RAND_bytes_ex(ctx, second_random, sizeof(second_random), 0));
    CHECK(CRYPTO_memcmp(random, second_random, sizeof(random)) != 0);
    SSL_CTX *tls = SSL_CTX_new_ex(ctx, NULL, TLS_method());
    CHECK(tls && SSL_CTX_set_min_proto_version(tls, TLS1_3_VERSION));
    CHECK(certificate_check(ctx) && kem_check(ctx) && signature_check(ctx));
    SSL_CTX_free(tls); OSSL_PROVIDER_unload(provider); OSSL_PROVIDER_unload(defaults); OSSL_LIB_CTX_free(ctx);
    puts("OpenSSL RNG/TLS/certificate checks and oqsprovider FrodoKEM/Falcon passed");
    return 1;
}
int main(int argc, char **argv) { return run(argc > 1 ? argv[1] : NULL) ? 0 : 1; }
