// Nonpersistent diagnostic: does not create/show a HUD or change preferences.
#define PERF_LOG "/var/tmp/codex-ios7-hud-metrics.log"
#include "../tweak/PerfOverlay.m"
int main(void){@autoreleasepool{
 uint32_t first=0,last=0;BOOL frames=ReadGlobalFrameCounter(&first);double used=0,total=0;BOOL memory=MemoryUsage(&used,&total);CPUUsage();usleep(500000);double cpu=CPUUsage();if(frames)frames=ReadGlobalFrameCounter(&last);int gpu=GPUUtilization();
 vm_statistics_data_t vm={0};mach_msg_type_number_t count=HOST_VM_INFO_COUNT;host_statistics(mach_host_self(),HOST_VM_INFO,(host_info_t)&vm,&count);vm_size_t page=0;host_page_size(mach_host_self(),&page);int sysPage=0;size_t sysSize=sizeof(sysPage);sysctlbyname("hw.pagesize",&sysPage,&sysSize,NULL,0);
 vm_size_t*kernelPage=dlsym(RTLD_DEFAULT,"vm_kernel_page_size");
 NSDictionary*d=@{@"kernel_page_size":@(kernelPage?*kernelPage:0),@"host_page_size":@(page),@"sys_page_size":@(sysPage),@"active_pages":@(vm.active_count),@"inactive_pages":@(vm.inactive_count),@"wire_pages":@(vm.wire_count),@"free_pages":@(vm.free_count),@"collector_bits":@(sizeof(void*)*8),@"global_frames_available":@(frames),@"first_frame_counter":@(first),@"last_frame_counter":@(last),@"frame_counter_delta":@(last-first),@"memory_available":@(memory),@"used_mb":@(used),@"total_mb":@(total),@"cpu_percent":@(cpu),@"cpu_cores":@(gCoreCount),@"gpu_percent":@(gpu),@"gpu_service":@(gGPUService),@"ncsettings_allowed":@(PerfLegacyNCSupported([[[UIDevice currentDevice]systemVersion]intValue]))};
 NSData*data=[NSJSONSerialization dataWithJSONObject:d options:0 error:NULL];if(data){fwrite(data.bytes,1,data.length,stdout);puts("");}return data&&memory&&gCoreCount?0:1;
}}
