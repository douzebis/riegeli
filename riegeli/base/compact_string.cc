// Copyright 2023 Google LLC
//
// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// You may obtain a copy of the License at
//
//      http://www.apache.org/licenses/LICENSE-2.0
//
// Unless required by applicable law or agreed to in writing, software
// distributed under the License is distributed on an "AS IS" BASIS,
// WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
// See the License for the specific language governing permissions and
// limitations under the License.

#include "riegeli/base/compact_string.h"

#include <stdint.h>

#include <cstring>
#include <limits>
#include <utility>

#include "absl/strings/string_view.h"
#include "riegeli/base/arithmetic.h"
#include "riegeli/base/assert.h"
#include "riegeli/base/estimated_allocated_size.h"

namespace riegeli {

void CompactString::AssignSlow(absl::string_view src) {
  const size_t old_capacity = capacity();
  DeleteRepr(std::exchange(
      repr_,
      MakeRepr(src, UnsignedMax(src.size(), old_capacity + old_capacity / 2))));
}

uintptr_t CompactString::MakeReprSlow(size_t size, size_t capacity) {
  RIEGELI_ASSERT_LE(size, capacity)
      << "Failed precondition of CompactString::MakeReprSlow(): "
         "size exceeds capacity";
  RIEGELI_ASSERT_GT(capacity, kInlineCapacity)
      << "Failed precondition of CompactString::MakeReprSlow(): "
         "representation is inline, use MakeRepr() instead";
  uintptr_t repr;
  if (capacity <= 0xff) {
    const size_t requested =
        UnsignedMin(EstimatedAllocatedSize(capacity + 2), size_t{0xff + 2});
    repr = reinterpret_cast<uintptr_t>(Allocate(requested) + 2);
    set_allocated_capacity<uint8_t>(requested - 2, repr);
    set_allocated_size<uint8_t>(size, repr);
  } else if (capacity <= 0xffff) {
    const size_t requested =
        UnsignedMin(EstimatedAllocatedSize(capacity + 4), size_t{0xffff + 4});
    repr = reinterpret_cast<uintptr_t>(Allocate(requested) + 4);
    set_allocated_capacity<uint16_t>(requested - 4, repr);
    set_allocated_size<uint16_t>(size, repr);
  } else {
    static_assert(sizeof(size_t) % 4 == 0, "Unsupported size_t size");
    RIEGELI_CHECK_LE(capacity,
                     std::numeric_limits<size_t>::max() - 2 * sizeof(size_t))
        << "CompactString capacity overflow";
    const size_t requested =
        EstimatedAllocatedSize(capacity + 2 * sizeof(size_t));
    repr =
        reinterpret_cast<uintptr_t>(Allocate(requested) + 2 * sizeof(size_t));
    set_allocated_capacity<size_t>(requested - 2 * sizeof(size_t), repr);
    set_allocated_size<size_t>(size, repr);
  }
  return repr;
}

char* CompactString::ResizeSlow(size_t new_size, size_t min_capacity,
                                size_t used_size) {
  RIEGELI_ASSERT_LE(new_size, min_capacity)
      << "Failed precondition of CompactString::ResizeSlow(): "
         "size exceeds capacity";
  RIEGELI_ASSERT_LE(used_size, size())
      << "Failed precondition of CompactString::ResizeSlow(): "
         "used size exceeds old size";
  RIEGELI_ASSERT_LE(used_size, new_size)
      << "Failed precondition of CompactString::ResizeSlow(): "
         "used size exceeds new size";
  const size_t old_capacity = capacity();
  const uintptr_t new_repr = MakeRepr(
      new_size, UnsignedMax(min_capacity, old_capacity + old_capacity / 2));
  const uintptr_t tag = new_repr & 7;
  RIEGELI_ASSERT_NE(tag, 1u)
      << "Inline representation has a fixed capacity, so reallocation is never "
         "needed when the new capacity can use inline representation";
  char* ptr = allocated_data(new_repr);
  std::memcpy(ptr, data(), used_size);
  ptr += used_size;
  DeleteRepr(std::exchange(repr_, new_repr));
  return ptr;
}

void CompactString::ShrinkToFitSlow() {
  const uintptr_t tag = repr_ & 7;
  RIEGELI_ASSERT_NE(tag, 1u)
      << "Failed precondition of CompactString::ShrinkToFitSlow(): "
         "representation is inline, use shrink_to_fit() instead";
  size_t size;
  if (tag == 2) {
    size = allocated_size<uint8_t>();
    if (allocated_capacity<uint8_t>() + 2 <=
        UnsignedMin(EstimatedAllocatedSize(size + 2), size_t{0xff + 2})) {
      return;
    }
  } else if (tag == 4) {
    size = allocated_size<uint16_t>();
    if (allocated_capacity<uint16_t>() + 4 <=
        UnsignedMin(EstimatedAllocatedSize(size + 4), size_t{0xffff + 4})) {
      return;
    }
  } else if (tag == 0) {
    size = allocated_size<size_t>();
    if (allocated_capacity<size_t>() + 2 * sizeof(size_t) <=
        EstimatedAllocatedSize(size + 2 * sizeof(size_t))) {
      return;
    }
  } else {
    RIEGELI_ASSERT_UNREACHABLE() << "Impossible tag: " << tag;
  }
  DeleteRepr(std::exchange(
      repr_, MakeRepr(absl::string_view(allocated_data(), size))));
}

}  // namespace riegeli