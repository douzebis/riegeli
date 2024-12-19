#!/bin/bash

brew reinstall python@3.12
export PYTHON_LIB_PATH=/opt/homebrew/opt/python@3.12/Frameworks/Python.framework/Versions/3.12/lib
brew reinstall protobuf@29

rm -rf venv && python3.12 -m venv venv
. venv/bin/activate
pip install --upgrade pip
pip install setuptools

# Build C++ library
bazel build //python/riegeli:riegeli --sandbox_debug --subcommands --verbose_failures
for i in fd_handle fd_reader fd_mmap_reader fd_writer fd_internal fd_internal_for_headers; do
  bazel build //riegeli/bytes:$i
done

# Build Python library
(cd python && python setup.py bdist_wheel)
(cd python && pip install --force-reinstall dist/riegeli-0.0.1-cp312-cp312-macosx_14_0_arm64.whl)
for i in records_metadata_pb2.py record_position.so record_writer.so record_reader.so; do
  rm -f "venv/lib/python3.12/site-packages/riegeli/records/$i"
  cp "bazel-bin/python/riegeli/records/$i" venv/lib/python3.12/site-packages/riegeli/records/
done
python -c "import riegeli; print(riegeli)" # Minimal smoke test

# Build C wrapper library
g++ -std=c++17 -fPIC -c -o libriegeli/libriegeli.o libriegeli/libriegeli.cpp \-I../riegeli/bazel-riegeli \
-I../riegeli/bazel-out/darwin_arm64-fastbuild/bin \
-I../riegeli/bazel-riegeli/external/abseil-cpp~ \
-I../riegeli/bazel-out/darwin_arm64-fastbuild/bin/external/protobuf~/src/google/protobuf/_virtual_includes/any_proto  \
-I../riegeli/bazel-out/darwin_arm64-fastbuild/bin/external/protobuf~/src/google/protobuf/_virtual_includes/api_proto  \
-I../riegeli/bazel-out/darwin_arm64-fastbuild/bin/external/protobuf~/src/google/protobuf/_virtual_includes/arena  \
-I../riegeli/bazel-out/darwin_arm64-fastbuild/bin/external/protobuf~/src/google/protobuf/_virtual_includes/arena_align  \
-I../riegeli/bazel-out/darwin_arm64-fastbuild/bin/external/protobuf~/src/google/protobuf/_virtual_includes/arena_allocation_policy  \
-I../riegeli/bazel-out/darwin_arm64-fastbuild/bin/external/protobuf~/src/google/protobuf/_virtual_includes/arena_cleanup  \
-I../riegeli/bazel-out/darwin_arm64-fastbuild/bin/external/protobuf~/src/google/protobuf/_virtual_includes/descriptor_legacy  \
-I../riegeli/bazel-out/darwin_arm64-fastbuild/bin/external/protobuf~/src/google/protobuf/_virtual_includes/duration_proto  \
-I../riegeli/bazel-out/darwin_arm64-fastbuild/bin/external/protobuf~/src/google/protobuf/_virtual_includes/empty_proto  \
-I../riegeli/bazel-out/darwin_arm64-fastbuild/bin/external/protobuf~/src/google/protobuf/_virtual_includes/field_mask_proto  \
-I../riegeli/bazel-out/darwin_arm64-fastbuild/bin/external/protobuf~/src/google/protobuf/_virtual_includes/internal_visibility  \
-I../riegeli/bazel-out/darwin_arm64-fastbuild/bin/external/protobuf~/src/google/protobuf/_virtual_includes/port  \
-I../riegeli/bazel-out/darwin_arm64-fastbuild/bin/external/protobuf~/src/google/protobuf/_virtual_includes/protobuf  \
-I../riegeli/bazel-out/darwin_arm64-fastbuild/bin/external/protobuf~/src/google/protobuf/_virtual_includes/protobuf_layering_check_legacy  \
-I../riegeli/bazel-out/darwin_arm64-fastbuild/bin/external/protobuf~/src/google/protobuf/_virtual_includes/protobuf_lite  \
-I../riegeli/bazel-out/darwin_arm64-fastbuild/bin/external/protobuf~/src/google/protobuf/_virtual_includes/source_context_proto  \
-I../riegeli/bazel-out/darwin_arm64-fastbuild/bin/external/protobuf~/src/google/protobuf/_virtual_includes/string_block  \
-I../riegeli/bazel-out/darwin_arm64-fastbuild/bin/external/protobuf~/src/google/protobuf/_virtual_includes/struct_proto  \
-I../riegeli/bazel-out/darwin_arm64-fastbuild/bin/external/protobuf~/src/google/protobuf/_virtual_includes/timestamp_proto  \
-I../riegeli/bazel-out/darwin_arm64-fastbuild/bin/external/protobuf~/src/google/protobuf/_virtual_includes/type_proto  \
-I../riegeli/bazel-out/darwin_arm64-fastbuild/bin/external/protobuf~/src/google/protobuf/_virtual_includes/varint_shuffle  \
-I../riegeli/bazel-out/darwin_arm64-fastbuild/bin/external/protobuf~/src/google/protobuf/_virtual_includes/wrappers_proto \
-I../riegeli/bazel-out/darwin_arm64-fastbuild/bin/external/protobuf~/src/google/protobuf/stubs/_virtual_includes/lite \
-I../riegeli/bazel-out/darwin_arm64-fastbuild/bin/external/protobuf~/src/google/protobuf/io/_virtual_includes/gzip_stream \
-I../riegeli/bazel-out/darwin_arm64-fastbuild/bin/external/protobuf~/src/google/protobuf/io/_virtual_includes/io \
-I../riegeli/bazel-out/darwin_arm64-fastbuild/bin/external/protobuf~/src/google/protobuf/io/_virtual_includes/io_win32 \
-I../riegeli/bazel-out/darwin_arm64-fastbuild/bin/external/protobuf~/src/google/protobuf/io/_virtual_includes/printer \
-I../riegeli/bazel-out/darwin_arm64-fastbuild/bin/external/protobuf~/src/google/protobuf/io/_virtual_includes/tokenizer \
-I../riegeli/bazel-out/darwin_arm64-fastbuild/bin/external/protobuf~/src/google/protobuf/io/_virtual_includes/zero_copy_sink

g++ -std=c++17 -shared -fPIC -o libriegeli/libriegeli.so -framework CoreFoundation \
-I../riegeli/bazel-riegeli \
-I../riegeli/bazel-out/darwin_arm64-fastbuild/bin \
-I../riegeli/bazel-riegeli/external/abseil-cpp~ \
-I../riegeli/bazel-out/darwin_arm64-fastbuild/bin/external/protobuf~/src/google/protobuf/_virtual_includes/any_proto  \
-I../riegeli/bazel-out/darwin_arm64-fastbuild/bin/external/protobuf~/src/google/protobuf/_virtual_includes/api_proto  \
-I../riegeli/bazel-out/darwin_arm64-fastbuild/bin/external/protobuf~/src/google/protobuf/_virtual_includes/arena  \
-I../riegeli/bazel-out/darwin_arm64-fastbuild/bin/external/protobuf~/src/google/protobuf/_virtual_includes/arena_align  \
-I../riegeli/bazel-out/darwin_arm64-fastbuild/bin/external/protobuf~/src/google/protobuf/_virtual_includes/arena_allocation_policy  \
-I../riegeli/bazel-out/darwin_arm64-fastbuild/bin/external/protobuf~/src/google/protobuf/_virtual_includes/arena_cleanup  \
-I../riegeli/bazel-out/darwin_arm64-fastbuild/bin/external/protobuf~/src/google/protobuf/_virtual_includes/descriptor_legacy  \
-I../riegeli/bazel-out/darwin_arm64-fastbuild/bin/external/protobuf~/src/google/protobuf/_virtual_includes/duration_proto  \
-I../riegeli/bazel-out/darwin_arm64-fastbuild/bin/external/protobuf~/src/google/protobuf/_virtual_includes/empty_proto  \
-I../riegeli/bazel-out/darwin_arm64-fastbuild/bin/external/protobuf~/src/google/protobuf/_virtual_includes/field_mask_proto  \
-I../riegeli/bazel-out/darwin_arm64-fastbuild/bin/external/protobuf~/src/google/protobuf/_virtual_includes/internal_visibility  \
-I../riegeli/bazel-out/darwin_arm64-fastbuild/bin/external/protobuf~/src/google/protobuf/_virtual_includes/port  \
-I../riegeli/bazel-out/darwin_arm64-fastbuild/bin/external/protobuf~/src/google/protobuf/_virtual_includes/protobuf  \
-I../riegeli/bazel-out/darwin_arm64-fastbuild/bin/external/protobuf~/src/google/protobuf/_virtual_includes/protobuf_layering_check_legacy  \
-I../riegeli/bazel-out/darwin_arm64-fastbuild/bin/external/protobuf~/src/google/protobuf/_virtual_includes/protobuf_lite  \
-I../riegeli/bazel-out/darwin_arm64-fastbuild/bin/external/protobuf~/src/google/protobuf/_virtual_includes/source_context_proto  \
-I../riegeli/bazel-out/darwin_arm64-fastbuild/bin/external/protobuf~/src/google/protobuf/_virtual_includes/string_block  \
-I../riegeli/bazel-out/darwin_arm64-fastbuild/bin/external/protobuf~/src/google/protobuf/_virtual_includes/struct_proto  \
-I../riegeli/bazel-out/darwin_arm64-fastbuild/bin/external/protobuf~/src/google/protobuf/_virtual_includes/timestamp_proto  \
-I../riegeli/bazel-out/darwin_arm64-fastbuild/bin/external/protobuf~/src/google/protobuf/_virtual_includes/type_proto  \
-I../riegeli/bazel-out/darwin_arm64-fastbuild/bin/external/protobuf~/src/google/protobuf/_virtual_includes/varint_shuffle  \
-I../riegeli/bazel-out/darwin_arm64-fastbuild/bin/external/protobuf~/src/google/protobuf/_virtual_includes/wrappers_proto \
-I../riegeli/bazel-out/darwin_arm64-fastbuild/bin/external/protobuf~/src/google/protobuf/stubs/_virtual_includes/lite \
-I../riegeli/bazel-out/darwin_arm64-fastbuild/bin/external/protobuf~/src/google/protobuf/io/_virtual_includes/gzip_stream \
-I../riegeli/bazel-out/darwin_arm64-fastbuild/bin/external/protobuf~/src/google/protobuf/io/_virtual_includes/io \
-I../riegeli/bazel-out/darwin_arm64-fastbuild/bin/external/protobuf~/src/google/protobuf/io/_virtual_includes/io_win32 \
-I../riegeli/bazel-out/darwin_arm64-fastbuild/bin/external/protobuf~/src/google/protobuf/io/_virtual_includes/printer \
-I../riegeli/bazel-out/darwin_arm64-fastbuild/bin/external/protobuf~/src/google/protobuf/io/_virtual_includes/tokenizer \
-I../riegeli/bazel-out/darwin_arm64-fastbuild/bin/external/protobuf~/src/google/protobuf/io/_virtual_includes/zero_copy_sink \
\
libriegeli/libriegeli.o \
$(find bazel-out/darwin_arm64-fastbuild/bin/external/abseil-cpp~ -type f | egrep '[.]a$') \
$(find bazel-out/darwin_arm64-fastbuild/bin/external/brotli~ -type f | egrep '[.]a$') \
$(find bazel-out/darwin_arm64-fastbuild/bin/external/highwayhash~ -type f | egrep '[.]a$') \
$(find bazel-out/darwin_arm64-fastbuild/bin/external/protobuf~ -type f | egrep '[.]a$') \
$(find bazel-out/darwin_arm64-fastbuild/bin/external/snappy~ -type f | egrep '[.]a$') \
$(find bazel-out/darwin_arm64-fastbuild/bin/external/zstd~ -type f | egrep '[.]a$') \
$(find bazel-out/darwin_arm64-fastbuild/bin/riegeli -type f | egrep '[.]a$')
