/*
 * Codec2Symbols.c — dead-code-stripping guard for Codec2 FFI symbols.
 *
 * The linker flag -force_load includes all object files from libcodec2_ios.a,
 * but Xcode's DEAD_CODE_STRIPPING pass then removes every function that has no
 * compile-time callers, because Dart FFI resolves symbols by name at *runtime*
 * (DynamicLibrary.process().lookup("codec2_create")).  The stripper never sees
 * those string-based calls and assumes the functions are unreachable.
 *
 * Taking the address of each required function inside a __attribute__((used))
 * array creates a genuine compile-time reference.  The linker cannot remove a
 * symbol whose address is stored in an object that is itself marked "used".
 *
 * This file must be compiled as part of the Runner target.
 */

/* Forward-declare only the opaque struct and the functions we need.  We avoid
 * #including codec2.h so that no extra header-search-path configuration is
 * required in the Xcode project. */
struct CODEC2;

extern struct CODEC2 *codec2_create(int mode);
extern void codec2_destroy(struct CODEC2 *c2);
extern void codec2_encode(struct CODEC2 *c2, unsigned char *bits,
                          short *speech_in);
extern void codec2_decode(struct CODEC2 *c2, short *speech_out,
                          const unsigned char *bits);
extern int codec2_samples_per_frame(struct CODEC2 *c2);
extern int codec2_bits_per_frame(struct CODEC2 *c2);
extern int codec2_bytes_per_frame(struct CODEC2 *c2);

/* __attribute__((used)) prevents the array (and therefore each referenced
 * function) from being removed by the dead-code stripper.
 * The array is never called; its sole purpose is to hold live references. */
__attribute__((used)) static void *const _sm_codec2_symbol_refs[] = {
    (void *)codec2_create,
    (void *)codec2_destroy,
    (void *)codec2_encode,
    (void *)codec2_decode,
    (void *)codec2_samples_per_frame,
    (void *)codec2_bits_per_frame,
    (void *)codec2_bytes_per_frame,
};
