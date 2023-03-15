/*
 * Copyright 2021 Percy Camilo Triveño Aucahuasi <percy.camilo.ta@gmail.com>
 */

#include <cudf/column/column_factories.hpp>
#include <cudf/detail/utilities/vector_factories.hpp>
#include <cudf/io/types.hpp>
#include <cudf/strings/convert/convert_datetime.hpp>
#include <cudf/utilities/bit.hpp>
#include <rmm/cuda_stream_view.hpp>
#include <rmm/device_buffer.hpp>

namespace ral {
namespace io {

struct cudf_string_col {
  std::vector<char> chars;
  std::vector<cudf::size_type> offsets;
};


static inline std::unique_ptr<cudf::column>
build_str_cudf_col(cudf_string_col *host_col,
                   const std::vector<cudf::bitmask_type> &null_mask) {
  auto d_chars = cudf::detail::make_device_uvector_sync(host_col->chars, rmm::cuda_stream_default);
  auto d_offsets = cudf::detail::make_device_uvector_sync(host_col->offsets, rmm::cuda_stream_default);
  auto d_bitmask = cudf::detail::make_device_uvector_sync(null_mask, rmm::cuda_stream_default);
  return cudf::make_strings_column(d_chars, d_offsets, d_bitmask);
}

template <typename T>
static inline std::unique_ptr<cudf::column>
build_fixed_width_cudf_col(size_t total_rows,
                           std::vector<T> *host_col,
                           const std::vector<cudf::bitmask_type> &null_mask,
                           cudf::type_id cudf_type_id) {
  const cudf::size_type size = total_rows;
  auto data = rmm::device_buffer{host_col->data(), size * sizeof(T), rmm::cuda_stream_view{}};
  auto data_type = cudf::data_type(cudf_type_id);
  auto null_mask_buff = rmm::device_buffer{
      null_mask.data(), null_mask.size() * sizeof(decltype(null_mask.front())), rmm::cuda_stream_view{}};
  auto ret = std::make_unique<cudf::column>(
      data_type, size, std::move(data), std::move(null_mask_buff), cudf::UNKNOWN_NULL_COUNT);
  return ret;
}

}  // namespace io
}  // namespace ral
