#include <Imath/half.h>
#include <OpenEXR/ImfRgbaFile.h>
#include <OpenEXR/ImfHeader.h>
#include <tiffio.h>
#include <turbojpeg.h>
#include <cstdio>
#include <jpeglib.h>
#include <algorithm>
#include <cmath>
#include <iostream>
#include <stdexcept>
#include <vector>

static void require(bool ok, const char* message) {
    if (!ok) throw std::runtime_error(message);
}

static void exr_roundtrip(OPENEXR_IMF_NAMESPACE::Compression compression) {
    using namespace OPENEXR_IMF_NAMESPACE;
    const int width = 32, height = 32;
    std::vector<Rgba> source(width * height), result(width * height);
    for (int i = 0; i < width * height; ++i)
        source[i] = Rgba(float(i % 16) / 16, 0.25f, 0.5f, 1.0f);
    Header header(width, height);
    header.compression() = compression;
    {
        RgbaOutputFile output("roundtrip.exr", header, WRITE_RGBA);
        output.setFrameBuffer(source.data(), 1, width);
        output.writePixels(height);
    }
    {
        RgbaInputFile input("roundtrip.exr");
        input.setFrameBuffer(result.data(), 1, width);
        input.readPixels(0, height - 1);
    }
    for (int i = 0; i < width * height; ++i)
        require(source[i].r == result[i].r && source[i].g == result[i].g &&
                source[i].b == result[i].b && source[i].a == result[i].a,
                "EXR pixels did not round-trip");
    std::remove("roundtrip.exr");
}

static void tiff_roundtrip(uint16_t compression) {
    const uint32_t width = 32, height = 32;
    std::vector<unsigned char> row(width, 83), decoded(width);
    TIFF* file = TIFFOpen("roundtrip.tif", "w");
    require(file != nullptr, "TIFF write open failed");
    TIFFSetField(file, TIFFTAG_IMAGEWIDTH, width);
    TIFFSetField(file, TIFFTAG_IMAGELENGTH, height);
    TIFFSetField(file, TIFFTAG_SAMPLESPERPIXEL, 1);
    TIFFSetField(file, TIFFTAG_BITSPERSAMPLE, 8);
    TIFFSetField(file, TIFFTAG_PHOTOMETRIC, PHOTOMETRIC_MINISBLACK);
    TIFFSetField(file, TIFFTAG_PLANARCONFIG, PLANARCONFIG_CONTIG);
    TIFFSetField(file, TIFFTAG_ROWSPERSTRIP, height);
    require(TIFFSetField(file, TIFFTAG_COMPRESSION, compression) == 1,
            "TIFF compression not available");
    if (compression == COMPRESSION_JPEG) TIFFSetField(file, TIFFTAG_JPEGQUALITY, 100);
    for (uint32_t y = 0; y < height; ++y)
        require(TIFFWriteScanline(file, row.data(), y) == 1, "TIFF write failed");
    TIFFClose(file);
    file = TIFFOpen("roundtrip.tif", "r");
    require(file != nullptr, "TIFF read open failed");
    for (uint32_t y = 0; y < height; ++y) {
        require(TIFFReadScanline(file, decoded.data(), y) == 1, "TIFF read failed");
        for (auto value : decoded)
            require(std::abs(int(value) - 83) <= (compression == COMPRESSION_JPEG ? 1 : 0),
                    "TIFF pixels did not round-trip");
    }
    TIFFClose(file);
    std::remove("roundtrip.tif");
}

static void jpeg_roundtrip() {
    constexpr int width = 32, height = 32;
    std::vector<unsigned char> rgb(width * height * 3, 83);
    tjhandle compressor = tj3Init(TJINIT_COMPRESS);
    require(compressor != nullptr, "TurboJPEG initialization failed");
    require(tj3Set(compressor, TJPARAM_QUALITY, 100) == 0 &&
            tj3Set(compressor, TJPARAM_SUBSAMP, TJSAMP_444) == 0,
            "TurboJPEG configuration failed");
    unsigned char* compressed = nullptr;
    size_t size = 0;
    require(tj3Compress8(compressor, rgb.data(), width, 0, height, TJPF_RGB,
                        &compressed, &size) == 0, "TurboJPEG compression failed");
    tj3Destroy(compressor);
    // Decode using the separate classic libjpeg API archive.
    jpeg_decompress_struct decoder{};
    jpeg_error_mgr errors{};
    decoder.err = jpeg_std_error(&errors);
    jpeg_create_decompress(&decoder);
    jpeg_mem_src(&decoder, compressed, static_cast<unsigned long>(size));
    require(jpeg_read_header(&decoder, TRUE) == JPEG_HEADER_OK, "JPEG header failed");
    jpeg_start_decompress(&decoder);
    require(decoder.output_width == width && decoder.output_height == height &&
            decoder.output_components == 3, "JPEG dimensions changed");
    std::vector<unsigned char> row(width * 3);
    while (decoder.output_scanline < decoder.output_height) {
        JSAMPROW scanline = row.data();
        require(jpeg_read_scanlines(&decoder, &scanline, 1) == 1, "JPEG decode failed");
        for (auto value : row) require(std::abs(int(value) - 83) <= 1, "JPEG pixels changed");
    }
    jpeg_finish_decompress(&decoder);
    jpeg_destroy_decompress(&decoder);
    tj3Free(compressed);
}

int main() {
    try {
        require(float(IMATH_NAMESPACE::half(0.5f)) == 0.5f, "Imath half conversion failed");
        jpeg_roundtrip();
        tiff_roundtrip(COMPRESSION_ADOBE_DEFLATE);
        tiff_roundtrip(COMPRESSION_JPEG);
        exr_roundtrip(OPENEXR_IMF_NAMESPACE::ZIP_COMPRESSION);
        exr_roundtrip(OPENEXR_IMF_NAMESPACE::ZSTD_COMPRESSION);
        exr_roundtrip(OPENEXR_IMF_NAMESPACE::HTJ2K256_COMPRESSION);
        std::cout << "Imath, JPEG, TIFF Deflate/JPEG and EXR ZIP/ZSTD/HTJ2K passed\n";
        return 0;
    } catch (const std::exception& error) {
        std::cerr << error.what() << '\n';
        return 1;
    }
}
