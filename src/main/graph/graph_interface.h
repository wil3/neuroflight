#ifdef __cplusplus
#define EXTERNC extern "C"
#else
#define EXTERNC
#endif

EXTERNC void compute_motor_values(float *input, float *output, int input_size, int output_size);

#undef EXTERNC

