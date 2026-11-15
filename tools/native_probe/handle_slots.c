/* Test fixture: foreign code retains integer tokens, not Mere pointers.
 * The observer stores a checked string-store index to detect reclamation;
 * it deliberately does not register a GC root. */
static int tokens[256];
static int watched_string;
int mr_probe_slot_put(int slot, int token) {
    if (slot < 0 || slot >= 256 || token < 0) return -1;
    tokens[slot] = token;
    return 0;
}
int mr_probe_slot_get(int slot) {
    return slot < 0 || slot >= 256 ? -1 : tokens[slot];
}
int mr_probe_watch_string(int id) { watched_string = id; return id; }
int mr_probe_watched_string(void) { return watched_string; }
int mr_probe_echo_token(int token) { return token; }
