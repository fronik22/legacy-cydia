#include <memory>
#include <vector>
#include <string>
#include <stdexcept>
#include <thread>
#include <mutex>
#include <cassert>
#include <cstdio>
int main(){
    auto value=std::make_shared<std::string>("HEIC runtime");std::vector<std::shared_ptr<std::string>> items(3,value);
    assert(*items.at(2)=="HEIC runtime" && value.use_count()==4);
    bool caught=false;try{throw std::runtime_error("expected");}catch(const std::exception &e){caught=std::string(e.what())=="expected";}
    assert(caught);int count=0;std::mutex lock;std::thread worker([&]{std::lock_guard<std::mutex> guard(lock);count=1;});worker.join();assert(count==1);
    std::puts("PASS private C++ strings/vector/shared ownership, throw/catch, mutex/thread");
}
