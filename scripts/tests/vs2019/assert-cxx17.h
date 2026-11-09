#pragma once
#if !defined(_MSC_VER) || _MSC_VER != 1929
#error Expected the MSVC 19.29 (v142) compiler
#endif
#ifdef __cplusplus
#if !defined(_MSVC_LANG) || _MSVC_LANG != 201703L
#error Expected /std:c++17
#endif
#endif
