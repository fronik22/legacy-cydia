/* Test-only encoder: official Amnezia QDataStream framing + upstream Nayuki QR. */
#include "qrcodegen.hpp"
#include "b64.h"
#include <cassert>
#include <cstdio>
#include <fstream>
#include <iterator>
#include <string>
#include <vector>
#include <zlib.h>
static void be32(std::vector<unsigned char> &v,unsigned n){for(int i=3;i>=0;i--)v.push_back((n>>(8*i))&255);}
int main(int argc,char **argv){
    bool two=argc==4&&std::string(argv[3])=="two";assert(argc==3||two);std::ifstream file(argv[1],std::ios::binary);assert(file);std::string json((std::istreambuf_iterator<char>(file)),{});
    // Deterministic public padding makes a genuine four-part, compressed JSON profile.
    while(json.size()&&(json.back()=='\n'||json.back()=='\r'||json.back()==' '))json.pop_back();assert(json.size()&&json.back()=='}');json.pop_back();json+=",\"qr_test_padding\":\"";
    unsigned rng=12345;for(int i=0;i<(two?900:3800);i++){rng^=rng<<13;rng^=rng>>17;rng^=rng<<5;json+="ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789"[rng%62];}json+="\"}";
    std::ofstream(std::string(argv[2])+"/animated-profile.json",std::ios::binary)<<json;
    uLongf size=compressBound(json.size());std::vector<unsigned char> data;be32(data,json.size());data.resize(size+4);
    assert(compress2(data.data()+4,&size,(const Bytef *)json.data(),json.size(),8)==Z_OK);data.resize(size+4);
    unsigned count=(data.size()+849)/850;assert(count==(two?2u:4u));
    for(unsigned i=0;i<count;i++){
        unsigned n=std::min((size_t)850,data.size()-850*i);std::vector<unsigned char> chunk={7,192,(unsigned char)count,(unsigned char)i};be32(chunk,n);chunk.insert(chunk.end(),data.begin()+850*i,data.begin()+850*i+n);
        char encoded[1200];size_t length=0;assert(!b64_encode(chunk.data(),chunk.size(),encoded,sizeof encoded,&length));std::string text(encoded,length);
        while(text.size()&&text.back()=='=')text.pop_back();for(char &c:text){if(c=='+')c='-';if(c=='/')c='_';}
        std::string path=std::string(argv[2])+"/animated-"+std::to_string(i);std::ofstream(path+".txt")<<text;
        auto qr=qrcodegen::QrCode::encodeText(text.c_str(),qrcodegen::QrCode::Ecc::LOW);int border=4,scale=5,w=(qr.getSize()+2*border)*scale;
        FILE *pgm=fopen((path+".pgm").c_str(),"wb");assert(pgm);fprintf(pgm,"P5\n%d %d\n255\n",w,w);
        for(int y=0;y<w;y++)for(int x=0;x<w;x++)fputc(qr.getModule(x/scale-border,y/scale-border)?0:255,pgm);fclose(pgm);
    }
    printf("Official Amnezia framing: %zu compressed bytes, %u QR parts\n",data.size(),count);
}
