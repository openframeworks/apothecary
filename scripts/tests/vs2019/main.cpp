#include <array>
#include <type_traits>
#include <iostream>
#include <cstring>
#include "assert-cxx17.h"
#ifdef TEST_PACKAGED_ZLIB
#include <zlib.h>
#endif
#ifdef TEST_PACKAGED_FMT
#include <fmt/format.h>
#endif

template <typename T, std::size_t N> constexpr T total(const std::array<T, N>& values) {
    static_assert(std::is_integral_v<T>, "Expected integral values");
    T sum{};
    for (auto value : values) sum += value;
    return sum;
}

int main() {
    const std::array<int, 3> values{1, 2, 3};
    std::cout << "VS2019: _MSC_VER=" << _MSC_VER << " _MSVC_LANG=" << _MSVC_LANG << '\n';
#ifdef TEST_PACKAGED_ZLIB
    const unsigned char input[] = "VS2019 packaged zlib roundtrip";
    unsigned char packed[256], unpacked[256];
    uLongf packed_size = sizeof(packed), unpacked_size = sizeof(unpacked);
    if (compress(packed, &packed_size, input, sizeof(input)) != Z_OK) return 2;
    if (uncompress(unpacked, &unpacked_size, packed, packed_size) != Z_OK) return 3;
    if (unpacked_size != sizeof(input) || std::memcmp(input, unpacked, sizeof(input))) return 4;
    std::cout << "Packaged zlib roundtrip passed\n";
#endif
#ifdef TEST_PACKAGED_FMT
    if (fmt::format("VS{} packaged {}", 2019, "fmt") != "VS2019 packaged fmt") return 5;
    std::cout << "Packaged fmt consumer passed\n";
#endif
    return total<int>(values) == 6 ? 0 : 1;
}
