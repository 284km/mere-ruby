#define main lifecycle_fixture_main
#include "embedding_host.c"
#undef main
#include <unistd.h>
#include <stdint.h>
int main(int argc, char **argv) {
  mere_lib_init();
  if (simple(mere_embedding_setup)) return 10;
  check("false && (later = 1); true || (other = 1)", 0, "");
  check("raise 'short circuit locals' unless later.nil? && other.nil?", 0, "");
  check("local = 'kept'; Class.new { define_method(:value) { local } }.tap { |c| Object.const_set(:EmbedDefined, c) }", 0, "");
  for (int i = 0; i < 100; i++)
    check("raise 'defined method' unless EmbedDefined.new.value == 'kept'; GC.start", 0, "");
  char source[256];
  snprintf(source, sizeof source, "raise 'process identity' unless Process.uid == %ju && Process.gid == %ju", (uintmax_t)getuid(), (uintmax_t)getgid());
  check(source, 0, "");
  check("$embed_file = File.open(ENV.fetch('EMBED_PATH'), 'w'); $embed_file.write('before'); at_exit { $embed_file.write(':exit') }", 0, "");
  int expected = argc > 1 && !strcmp(argv[1], "cleanup-error") ? 1 : 0;
  if (expected) check("at_exit { raise 'cleanup error' }", 0, "");
  if (simple(mere_embedding_cleanup) != expected) return 11;
  FILE *f = fopen(getenv("EMBED_PATH"), "rb");
  char text[64] = {0};
  if (!f || fread(text, 1, sizeof(text)-1, f) != 11 || strcmp(text, "before:exit")) return 12;
  fclose(f);
  mere_lib_shutdown();
  puts("current-main locals, define_method, process identity and cleanup flush passed");
  return 0;
}
