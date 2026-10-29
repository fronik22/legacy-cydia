#ifndef A6_QR_FRAME_H
#define A6_QR_FRAME_H
#include <stddef.h>
#include <stdint.h>
struct quirc;
/* bpp 1 = gray, 4 = BGRA. Returns UTF-8 byte count, 0 if absent, -1 on invalid input, -2 for multiple symbols. */
int a6_qr_decode_frame(struct quirc *decoder,const uint8_t *pixels,int width,int height,size_t stride,int bpp,char *text,size_t capacity);
#endif
