/* Include this wrapper when linking Apothecary's precompiled RGFW library.
 * Do not define RGFW_IMPLEMENTATION in an application linking librgfw. */
#ifndef APOTHECARY_RGFW_H
#define APOTHECARY_RGFW_H
#ifndef RGFW_OPENGL
#define RGFW_OPENGL
#endif
#ifndef RGFWDEF
#define RGFWDEF extern
#endif
#ifdef __cplusplus
extern "C" {
#endif
#include "RGFW.h"
#ifdef __cplusplus
}
#endif
#endif
