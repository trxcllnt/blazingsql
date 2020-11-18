#include "kernel.h"
#include "CodeTimer.h"
#include "communication/CommunicationData.h"

namespace ral {
namespace cache {

kernel::kernel(std::size_t kernel_id, std::string expr, std::shared_ptr<Context> context, kernel_type kernel_type_id) : expression{expr}, kernel_id(kernel_id), context{context}, kernel_type_id{kernel_type_id} {
    parent_id_ = -1;
    has_limit_ = false;
    limit_rows_ = -1;

    logger = spdlog::get("batch_logger");
    events_logger = spdlog::get("events_logger");
    cache_events_logger = spdlog::get("cache_events_logger");

    std::shared_ptr<spdlog::logger> kernels_logger;
    kernels_logger = spdlog::get("kernels_logger");

    if(kernels_logger != nullptr) {
        kernels_logger->info("{ral_id}|{query_id}|{kernel_id}|{is_kernel}|{kernel_type}",
                            "ral_id"_a=context->getNodeIndex(ral::communication::CommunicationData::getInstance().getSelfNode()),
                            "query_id"_a=(this->context ? std::to_string(this->context->getContextToken()) : "null"),
                            "kernel_id"_a=this->get_id(),
                            "is_kernel"_a=1, //true
                            "kernel_type"_a=get_kernel_type_name(this->get_type_id()));
    }
}

std::shared_ptr<ral::cache::CacheMachine> kernel::output_cache(std::string cache_id) {
    cache_id = cache_id.empty() ? std::to_string(this->get_id()) : cache_id;
    return this->output_.get_cache(cache_id);
}

std::shared_ptr<ral::cache::CacheMachine> kernel::input_cache() {
    auto kernel_id = std::to_string(this->get_id());
    return this->input_.get_cache(kernel_id);
}

bool kernel::add_to_output_cache(std::unique_ptr<ral::frame::BlazingTable> table, std::string cache_id,bool always_add) {
    CodeTimer cacheEventTimer(false);

    auto num_rows = table->num_rows();
    auto num_bytes = table->sizeInBytes();

    cacheEventTimer.start();

    std::string message_id = get_message_id();
    message_id = !cache_id.empty() ? cache_id + "_" + message_id : message_id;
    cache_id = cache_id.empty() ? std::to_string(this->get_id()) : cache_id;
    bool added = this->output_.get_cache(cache_id)->addToCache(std::move(table), message_id,always_add);

    cacheEventTimer.stop();

    if(cache_events_logger != nullptr) {
        cache_events_logger->info("{ral_id}|{query_id}|{source}|{sink}|{num_rows}|{num_bytes}|{event_type}|{timestamp_begin}|{timestamp_end}",
                    "ral_id"_a=context->getNodeIndex(ral::communication::CommunicationData::getInstance().getSelfNode()),
                    "query_id"_a=context->getContextToken(),
                    "source"_a=this->get_id(),
                    "sink"_a=this->output_.get_cache(cache_id)->get_id(),
                    "num_rows"_a=num_rows,
                    "num_bytes"_a=num_bytes,
                    "event_type"_a="addCache",
                    "timestamp_begin"_a=cacheEventTimer.start_time(),
                    "timestamp_end"_a=cacheEventTimer.end_time());
    }

    return added;
}

bool kernel::add_to_output_cache(std::unique_ptr<ral::cache::CacheData> cache_data, std::string cache_id, bool always_add) {
    CodeTimer cacheEventTimer(false);

    auto num_rows = cache_data->num_rows();
    auto num_bytes = cache_data->sizeInBytes();

    cacheEventTimer.start();

    std::string message_id = get_message_id();
    message_id = !cache_id.empty() ? cache_id + "_" + message_id : message_id;
    cache_id = cache_id.empty() ? std::to_string(this->get_id()) : cache_id;
    bool added = this->output_.get_cache(cache_id)->addCacheData(std::move(cache_data), message_id, always_add);

    cacheEventTimer.stop();

    if(cache_events_logger != nullptr) {
        cache_events_logger->info("{ral_id}|{query_id}|{source}|{sink}|{num_rows}|{num_bytes}|{event_type}|{timestamp_begin}|{timestamp_end}",
                    "ral_id"_a=context->getNodeIndex(ral::communication::CommunicationData::getInstance().getSelfNode()),
                    "query_id"_a=context->getContextToken(),
                    "source"_a=this->get_id(),
                    "sink"_a=this->output_.get_cache(cache_id)->get_id(),
                    "num_rows"_a=num_rows,
                    "num_bytes"_a=num_bytes,
                    "event_type"_a="addCache",
                    "timestamp_begin"_a=cacheEventTimer.start_time(),
                    "timestamp_end"_a=cacheEventTimer.end_time());
    }

    return added;
}

bool kernel::add_to_output_cache(std::unique_ptr<ral::frame::BlazingHostTable> host_table, std::string cache_id) {
    CodeTimer cacheEventTimer(false);

    auto num_rows = host_table->num_rows();
    auto num_bytes = host_table->sizeInBytes();

    cacheEventTimer.start();

    std::string message_id = get_message_id();
    message_id = !cache_id.empty() ? cache_id + "_" + message_id : message_id;
    cache_id = cache_id.empty() ? std::to_string(this->get_id()) : cache_id;
    bool added = this->output_.get_cache(cache_id)->addHostFrameToCache(std::move(host_table), message_id);

    cacheEventTimer.stop();

    if(cache_events_logger != nullptr) {
        cache_events_logger->info("{ral_id}|{query_id}|{source}|{sink}|{num_rows}|{num_bytes}|{event_type}|{timestamp_begin}|{timestamp_end}",
                    "ral_id"_a=context->getNodeIndex(ral::communication::CommunicationData::getInstance().getSelfNode()),
                    "query_id"_a=context->getContextToken(),
                    "source"_a=this->get_id(),
                    "sink"_a=this->output_.get_cache(cache_id)->get_id(),
                    "num_rows"_a=num_rows,
                    "num_bytes"_a=num_bytes,
                    "event_type"_a="addCache",
                    "timestamp_begin"_a=cacheEventTimer.start_time(),
                    "timestamp_end"_a=cacheEventTimer.end_time());
    }

    return added;
}

// this function gets the estimated num_rows for the output
// the default is that its the same as the input (i.e. project, sort, ...)
std::pair<bool, uint64_t> kernel::get_estimated_output_num_rows(){
    return this->query_graph->get_estimated_input_rows_to_kernel(this->kernel_id);
}

}  // end namespace cache
}  // end namespace ral
