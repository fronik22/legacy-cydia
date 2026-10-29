#include "qr_frame.h"
#include "quirc.h"
#include <string.h>
int a6_qr_decode_frame(struct quirc *q,const uint8_t *pixels,int width,int height,size_t stride,int bpp,char *text,size_t capacity) {
    if(!q||!pixels||!text||!capacity||width<=0||height<=0||width>8192||height>8192||(bpp!=1&&bpp!=4)||stride<(size_t)width*bpp)return -1;
    int largest=width>height?width:height;
    int w=largest>1280?width*1280/largest:width,h=largest>1280?height*1280/largest:height;
    if(!w||!h)return -1;
    int oldWidth,oldHeight;uint8_t *gray=quirc_begin(q,&oldWidth,&oldHeight);
    if(oldWidth!=w||oldHeight!=h){if(quirc_resize(q,w,h))return -1;gray=quirc_begin(q,NULL,NULL);}
    for(int y=0;y<h;y++)for(int x=0;x<w;x++){
        const uint8_t *p=pixels+(size_t)(y*height/h)*stride+(size_t)(x*width/w)*bpp;
        gray[y*w+x]=bpp==1?p[0]:(29*p[0]+150*p[1]+77*p[2])>>8;
    }
    quirc_end(q);int found=0,length=0;struct quirc_code code;struct quirc_data data;
    for(int i=0;i<quirc_count(q);i++){
        quirc_extract(q,i,&code);quirc_decode_error_t status=quirc_decode(&code,&data);
        if(status==QUIRC_ERROR_DATA_ECC){quirc_flip(&code);status=quirc_decode(&code,&data);}
        if(status||data.payload_len<=0||memchr(data.payload,0,data.payload_len))continue;
        if((size_t)data.payload_len>=capacity){length=-1;continue;}
        if(++found>1){length=-2;break;}
        length=data.payload_len;memcpy(text,data.payload,length);text[length]=0;
    }
    memset(&data,0,sizeof data);memset(&code,0,sizeof code);return length;
}
