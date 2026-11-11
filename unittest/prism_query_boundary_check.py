#!/usr/bin/env python3
"""Check Prism StringQuery against bytes followed by arbitrary adjacent data."""
import os
from pathlib import Path
import subprocess
import tempfile

ROOT = Path(__file__).resolve().parents[1]
ARCHIVE = ROOT / "vendor/prism/obj/libprism.a"
FIXTURE = r'''#include <assert.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include "prism.h"
typedef struct { long long len; unsigned char data[]; } mere_bytes;
extern int prism_query(int, mere_bytes *, const char *);
static int expected(int kind, const unsigned char *text, size_t len, const char *encoding) {
  if (kind == 0) return pm_string_query_local(text, len, encoding);
  if (kind == 1) return pm_string_query_constant(text, len, encoding);
  return pm_string_query_method_name(text, len, encoding);
}
int main(void) {
  const struct { const char *text; size_t len; const char *encoding; } cases[] = {
    {"_0",2,"UTF-8"}, {"abc",3,"UTF-8"}, {"Abc",3,"UTF-8"},
    {"foo?",4,"UTF-8"}, {"foo!",4,"UTF-8"}, {"foo=",4,"UTF-8"},
    {"_1",2,"UTF-8"}, {"",0,"UTF-8"}, {"a\0b",3,"UTF-8"},
    {"\xc3\xa9",2,"UTF-8"}, {"\xff",1,"UTF-8"}, {"A",1,"UTF-16LE"}
  };
  unsigned checks = 0;
  for (unsigned c = 0; c < sizeof cases / sizeof *cases; c++) {
    size_t len = cases[c].len;
    unsigned char *reference = malloc(len + 1);
    assert(reference);
    memcpy(reference, cases[c].text, len); reference[len] = 0;
    for (int kind = 0; kind < 3; kind++) {
      int want = expected(kind, reference, len, cases[c].encoding);
      for (unsigned adjacent = 0; adjacent < 256; adjacent++) {
        mere_bytes *input = malloc(sizeof *input + len + 1);
        assert(input);
        input->len = (long long)len;
        memcpy(input->data, cases[c].text, len); input->data[len] = (unsigned char)adjacent;
        int got = prism_query(kind, input, cases[c].encoding);
        if (got != want) {
          fprintf(stderr,"case=%u kind=%d adjacent=%u got=%d expected=%d\n",c,kind,adjacent,got,want);
          return 1;
        }
        assert(input->data[len] == adjacent);
        assert(memcmp(input->data, cases[c].text, len) == 0);
        free(input); checks++;
      }
    }
    free(reference);
  }
  printf("Prism query boundaries: %u comparisons passed\n", checks);
  return 0;
}
'''


def main():
    assert ARCHIVE.is_file(), "build the native interpreter first"
    with tempfile.TemporaryDirectory(prefix="mere-prism-query-") as directory:
        temp = Path(directory)
        source = temp / "boundary.c"
        source.write_text(FIXTURE)
        binary = temp / "boundary"
        subprocess.run([os.environ.get("CC", "clang"), "-O2", "-w",
                        "-I" + str(ROOT / "vendor/prism/include"), str(source),
                        str(ROOT / "tools/prism_glue.c"), str(ARCHIVE), "-o", str(binary)],
                       check=True, timeout=120)
        subprocess.run([str(binary)], check=True, timeout=30)


if __name__ == "__main__":
    main()
