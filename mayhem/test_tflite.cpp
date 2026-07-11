// mayhem/test_tflite.cpp — behavioral test for TFLite flatbuffer pack/unpack round-trip.
// Reads a seed .tflite model, unpacks it, repacks it, and verifies specific behavioral properties.
// test.sh checks for ALL five output markers; a neutered binary (exit 0) produces none → FAIL.
#include <cstdio>
#include <cstring>
#include <cstdlib>
#include <vector>
#include "flatbuffers/flatbuffers.h"
#include "tensorflow/lite/schema/schema_generated.h"

int main(int argc, char* argv[]) {
  const char* path = argc > 1 ? argv[1]
                               : "/mayhem/mayhem/seeds/hello_world_float.tflite";

  FILE* f = fopen(path, "rb");
  if (!f) { fprintf(stderr, "FAIL: cannot open %s\n", path); return 1; }
  fseek(f, 0, SEEK_END);
  long sz = ftell(f);
  fseek(f, 0, SEEK_SET);
  std::vector<uint8_t> buf((size_t)sz);
  if ((long)fread(buf.data(), 1, (size_t)sz, f) != sz) {
    fclose(f); fprintf(stderr, "FAIL: read error\n"); return 1;
  }
  fclose(f);

  // Must have TFLite magic "TFL3" at byte offset 4
  if (sz < 8 || memcmp(buf.data() + 4, "TFL3", 4) != 0) {
    fprintf(stderr, "FAIL: not a TFLite model (bad magic at offset 4)\n"); return 1;
  }
  printf("magic: OK\n");

  const tflite::Model* model = tflite::GetModel(buf.data());
  if (!model) { fprintf(stderr, "FAIL: GetModel returned null\n"); return 1; }
  printf("parse: OK\n");

  tflite::ModelT* unpacked = model->UnPack();
  if (!unpacked) { fprintf(stderr, "FAIL: UnPack returned null\n"); return 1; }

  int n_subgraphs = (int)unpacked->subgraphs.size();
  printf("subgraphs: %d\n", n_subgraphs);
  if (n_subgraphs < 1) {
    fprintf(stderr, "FAIL: expected at least 1 subgraph, got %d\n", n_subgraphs);
    delete unpacked; return 1;
  }

  int n_ops = (int)unpacked->subgraphs[0]->operators.size();
  printf("operators: %d\n", n_ops);
  if (n_ops < 1) {
    fprintf(stderr, "FAIL: expected at least 1 operator, got %d\n", n_ops);
    delete unpacked; return 1;
  }

  // Round-trip: pack and verify output still carries TFLite magic
  flatbuffers::FlatBufferBuilder fbb;
  auto packed = tflite::Model::Pack(fbb, unpacked);
  fbb.Finish(packed, tflite::ModelIdentifier());
  delete unpacked;

  if (fbb.GetSize() < 8 || memcmp(fbb.GetBufferPointer() + 4, "TFL3", 4) != 0) {
    fprintf(stderr, "FAIL: repacked model has bad magic\n"); return 1;
  }
  printf("repack: OK\n");

  printf("PASS: %ld -> %u bytes, %d subgraph(s), %d op(s)\n",
         sz, fbb.GetSize(), n_subgraphs, n_ops);
  return 0;
}
