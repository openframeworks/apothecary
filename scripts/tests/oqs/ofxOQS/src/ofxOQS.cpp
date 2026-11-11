#include "ofxOQS.h"

#include <cstdint>
#include <cstring>
#include <vector>

bool ofxOQS::mlKemRoundTrip() {
	OQS_init();
	OQS_KEM *kem = OQS_KEM_new(OQS_KEM_alg_ml_kem_768);
	if (!kem) {
		OQS_destroy();
		return false;
	}
	std::vector<uint8_t> pk(kem->length_public_key), sk(kem->length_secret_key);
	std::vector<uint8_t> ct(kem->length_ciphertext), a(kem->length_shared_secret), b(kem->length_shared_secret);
	bool ok = OQS_KEM_keypair(kem, pk.data(), sk.data()) == OQS_SUCCESS &&
		OQS_KEM_encaps(kem, ct.data(), a.data(), pk.data()) == OQS_SUCCESS &&
		OQS_KEM_decaps(kem, b.data(), ct.data(), sk.data()) == OQS_SUCCESS &&
		std::memcmp(a.data(), b.data(), kem->length_shared_secret) == 0;
	ct[0] ^= 1;
	if (OQS_KEM_decaps(kem, b.data(), ct.data(), sk.data()) == OQS_SUCCESS &&
		std::memcmp(a.data(), b.data(), kem->length_shared_secret) == 0) {
		ok = false;
	}
	OQS_KEM_free(kem);
	OQS_destroy();
	return ok;
}

bool ofxOQS::mlDsaSignVerify() {
	OQS_init();
	OQS_SIG *sig = OQS_SIG_new(OQS_SIG_alg_ml_dsa_44);
	if (!sig) {
		OQS_destroy();
		return false;
	}
	std::vector<uint8_t> pk(sig->length_public_key), sk(sig->length_secret_key), signature(sig->length_signature);
	size_t length = 0;
	const unsigned char message[] = "ofxOQS";
	bool ok = OQS_SIG_keypair(sig, pk.data(), sk.data()) == OQS_SUCCESS &&
		OQS_SIG_sign(sig, signature.data(), &length, message, sizeof(message), sk.data()) == OQS_SUCCESS &&
		OQS_SIG_verify(sig, message, sizeof(message), signature.data(), length, pk.data()) == OQS_SUCCESS;
	signature[0] ^= 1;
	if (OQS_SIG_verify(sig, message, sizeof(message), signature.data(), length, pk.data()) == OQS_SUCCESS) {
		ok = false;
	}
	OQS_SIG_free(sig);
	OQS_destroy();
	return ok;
}

std::vector<std::string> ofxOQS::enabledKems() {
	OQS_init();
	std::vector<std::string> names;
	for (size_t i = 0; i < OQS_KEM_alg_count(); ++i) {
		const char *name = OQS_KEM_alg_identifier(i);
		if (name && OQS_KEM_alg_is_enabled(name)) {
			names.emplace_back(name);
		}
	}
	OQS_destroy();
	return names;
}

bool ofxOQS::runSmokeTests() {
	return mlKemRoundTrip() && mlDsaSignVerify();
}
