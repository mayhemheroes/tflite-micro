// mayhem/fuzz_tflite.cpp — libFuzzer harness for TFLite flatbuffer pack/unpack
// Converts the original file-input harness to in-process libFuzzer to get real coverage feedback.
#include <cstddef>
#include <cstdint>
#include <cstring>
#include "flatbuffers/flatbuffers.h"
#include "tensorflow/lite/schema/schema_generated.h"

extern "C" int LLVMFuzzerTestOneInput(const uint8_t* data, size_t size) {
  if (size < 8) return 0;
  // GetModel reads a flatbuffer from a raw pointer (no file I/O)
  const tflite::Model* model = tflite::GetModel(data);
  if (!model) return 0;
  tflite::ModelT* unpacked = model->UnPack();
  if (!unpacked) return 0;
  flatbuffers::FlatBufferBuilder fbb;
  auto packed = tflite::Model::Pack(fbb, unpacked);
  fbb.Finish(packed, tflite::ModelIdentifier());
  delete unpacked;
  return 0;
}
