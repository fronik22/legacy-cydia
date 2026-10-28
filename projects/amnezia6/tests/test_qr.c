#include "quirc.h"
#include <assert.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
int main(int argc,char**argv){assert(argc==2);FILE*f=fopen(argv[1],"rb");assert(f);int w,h,max;char magic[3];assert(fscanf(f,"%2s %d %d %d",magic,&w,&h,&max)==4&&!strcmp(magic,"P5")&&max==255&&w>0&&h>0&&w<=2048&&h<=2048);fgetc(f);
 struct quirc*q=quirc_new();assert(q&&!quirc_resize(q,w,h));unsigned char*p=quirc_begin(q,0,0);assert(fread(p,w,h,f)==(size_t)h);fclose(f);quirc_end(q);assert(quirc_count(q)==1);struct quirc_code*code=malloc(sizeof*code);struct quirc_data*data=malloc(sizeof*data);assert(code&&data);quirc_extract(q,0,code);assert(!quirc_decode(code,data));assert(data->payload_len>6&&!memcmp(data->payload,"vpn://",6));
 p=quirc_begin(q,0,0);memset(p,255,w*h);quirc_end(q);assert(quirc_count(q)==0);free(code);free(data);quirc_destroy(q);puts("QR fixture decoded; blank image rejected");}
