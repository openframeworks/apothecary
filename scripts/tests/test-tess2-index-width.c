#include <assert.h>
#include <stddef.h>
#include <stdio.h>
#include <math.h>
#include "tesselator.h"
#if defined(__ANDROID__) || defined(TARGET_ANDROID)
_Static_assert(sizeof(TESSindex) == 2, "Android tessellation indices must be 16-bit");
#else
_Static_assert(sizeof(TESSindex) == 4, "Desktop tessellation indices must remain 32-bit");
#endif
int main(void) {
    float star[12][2];
    for (int i = 0; i < 12; i++) {
        double angle = i * 3.141592653589793 / 6;
        double radius = (i & 1) ? 4 : 10;
        star[i][0] = (float)(radius * cos(angle));
        star[i][1] = (float)(radius * sin(angle));
    }
    TESStesselator *tess = tessNewTess(NULL);
    assert(tess);
    tessAddContour(tess, 2, star, sizeof(star[0]), 12);
    assert(tessTesselate(tess, TESS_WINDING_ODD, TESS_POLYGONS, 3, 2, NULL));
    int count = tessGetElementCount(tess);
    int vertices = tessGetVertexCount(tess);
    const TESSindex *elements = tessGetElements(tess);
    const float *points = tessGetVertices(tess);
    assert(count == 10);
    double area = 0;
    for (int t = 0; t < count; t++) {
        unsigned a = elements[t*3], b = elements[t*3+1], c = elements[t*3+2];
        assert(a < (unsigned)vertices && b < (unsigned)vertices && c < (unsigned)vertices);
        assert(a != b && b != c && a != c);
        double triangle = fabs((points[2*b]-points[2*a])*(points[2*c+1]-points[2*a+1]) - (points[2*c]-points[2*a])*(points[2*b+1]-points[2*a+1]))/2;
        assert(triangle > 0);
        area += triangle;
    }
    assert(fabs(area - 120) < 0.001);
    printf("index bytes=%zu; triangles=%d; filled area=%.3f\n", sizeof(TESSindex), count, area);
    tessDeleteTess(tess);
}
