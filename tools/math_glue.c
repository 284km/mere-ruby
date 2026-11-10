/* Ruby 4.0.9 math.c (3e93b23): glibc cbrt receives one Newton refinement.
 * Keep the platform condition: Darwin and musl use their libc result directly. */
#include <math.h>

double mr_math_cbrt(double value) {
    double result = cbrt(value);
#if defined(__GLIBC__)
    if (isfinite(result) && !(value == 0.0 && result == 0.0)) {
        result = (2.0 * result + value / result / result) / 3.0;
    }
#endif
    return result;
}
