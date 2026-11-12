#ifdef TEST_LITE
#include "lite.pb.h"
using Message = apothecary::LiteMessage;
#else
#include "full.pb.h"
using Message = apothecary::FullMessage;
#endif
#include <string>

static_assert(PROTOBUF_VERSION == 7036002, "Unexpected Protobuf C++ runtime version");
int main() {
    Message source;
    source.set_text("Apothecary \xe2\x9c\x93");
    source.set_value(1234567890123LL);
    std::string bytes;
    if (!source.SerializeToString(&bytes)) return 1;
    Message decoded;
    if (!decoded.ParseFromString(bytes)) return 2;
    if (decoded.text() != source.text() || decoded.value() != source.value()) return 3;
#ifndef TEST_LITE
    if (!decoded.GetDescriptor()->FindFieldByName("text")) return 4;
#endif
    return 0;
}
