#include <assert.h>
#include <stdint.h>
#include <stdio.h>
#include <cairo.h>
#include <cairo-svg.h>
#include <cairo-pdf.h>

static cairo_status_t count_bytes(void *closure, const unsigned char *data,
                                 unsigned int length)
{
    (void)data;
    *(size_t *)closure += length;
    return CAIRO_STATUS_SUCCESS;
}

int main(void)
{
    cairo_surface_t *image = cairo_image_surface_create(CAIRO_FORMAT_ARGB32, 16, 16);
    cairo_t *cr = cairo_create(image);
    cairo_set_source_rgb(cr, 1, 0, 0);
    cairo_paint(cr);
    assert(cairo_status(cr) == CAIRO_STATUS_SUCCESS);
    cairo_surface_flush(image);
    assert(*(uint32_t *)cairo_image_surface_get_data(image) == 0xffff0000u);

    size_t png_bytes = 0;
    assert(cairo_surface_write_to_png_stream(image, count_bytes, &png_bytes)
           == CAIRO_STATUS_SUCCESS);
    assert(png_bytes > 8);
    cairo_destroy(cr);
    cairo_surface_destroy(image);

    size_t svg_bytes = 0, pdf_bytes = 0;
    cairo_surface_t *outputs[] = {
        cairo_svg_surface_create_for_stream(count_bytes, &svg_bytes, 16, 16),
        cairo_pdf_surface_create_for_stream(count_bytes, &pdf_bytes, 16, 16)
    };
    for (unsigned int i = 0; i < 2; ++i) {
        cr = cairo_create(outputs[i]);
        cairo_rectangle(cr, 1, 1, 8, 8);
        cairo_fill(cr);
        assert(cairo_status(cr) == CAIRO_STATUS_SUCCESS);
        cairo_destroy(cr);
        cairo_surface_finish(outputs[i]);
        assert(cairo_surface_status(outputs[i]) == CAIRO_STATUS_SUCCESS);
        cairo_surface_destroy(outputs[i]);
    }
    assert(svg_bytes > 0 && pdf_bytes > 0);
    puts("Cairo WebAssembly image, PNG, SVG and PDF smoke test passed");
    return 0;
}
