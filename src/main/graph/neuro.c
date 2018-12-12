#include <stdbool.h>
#include <stdint.h>
#include <string.h>
#include <math.h>
#include <platform.h>
#include "build/build_config.h"
#include "build/debug.h"
#include "common/axis.h"
#include "common/maths.h"
#include "drivers/time.h"
#include "fc/fc_core.h"
#include "fc/fc_rc.h"
#include "fc/rc_controls.h"
#include "fc/runtime_config.h"
#include "graph/neuro.h"
#include "flight/imu.h"
#include "flight/mixer.h"
#include "sensors/gyro.h"
#include "graph/graph_interface.h"
#include "graph_dim.h"


/* An array containing inputs for the neural network 
 * where the first element is the oldest
 */
static float graphInput[GRAPH_INPUT_SIZE];
static float graphOutput[GRAPH_OUTPUT_SIZE];
static float controlOutput[GRAPH_OUTPUT_SIZE];

void neuroInit()
{
}

void neuroController(timeUs_t currentTimeUs){
    evaluateGraphWithErrorDerivateError(currentTimeUs);
	mixGraphOutput(currentTimeUs, controlOutput);
}
float transformScale(float value, float oldLow, float oldHigh, float newLow, float newHigh){
	return ((value - oldLow) / (oldHigh - oldLow)) * (newHigh - newLow) + newLow;
}

void evaluateGraphWithErrorDerivateError(timeUs_t currentTimeUs){
    static timeUs_t previousTime;
    static float previousRateError[3];

    const float deltaT = ((float)(currentTimeUs - previousTime))/1000000.0f;
    previousTime = currentTimeUs;

    //Prepare the neural network inputs
    // Set the current error and deriviate
    for (int axis = FD_ROLL; axis <= FD_YAW; axis++) {
        float currentSetpoint = getSetpointRate(axis);
        const float gyroRate = gyro.gyroADCf[axis]; 
		float errorRate = currentSetpoint - gyroRate; 
		graphInput[axis] = errorRate;

        //TODO We need to include delta time because the loop is not fixed
        float delta = (errorRate - previousRateError[axis]);
        graphInput[axis + 3] = delta;

        previousRateError[axis] = errorRate;
    }
    /*  
    if (debugMode == DEBUG_NN_OUT) {
        for (int i = 0; i<GRAPH_INPUT_SIZE; i++){
            debug[i] = (int16_t)(graphInput[i] * 1000.0);
        }
    }
    */

    //Evaluate the neural network graph and convert to range [-1,1]->[0,1]
	compute_motor_values(graphInput, graphOutput, GRAPH_INPUT_SIZE, GRAPH_OUTPUT_SIZE);
    for (int i = 0; i < GRAPH_OUTPUT_SIZE; i++){
        controlOutput[i] = transformScale(graphOutput[i], -1.0f, 1.0f, 0, 1); 
    }

    /* 
    if (debugMode == DEBUG_NN_OUT) {
        for (int i = 0; i<GRAPH_OUTPUT_SIZE; i++){
            debug[GRAPH_INPUT_SIZE + i] = (int16_t)(controlOutput[i] * 1000.0);
        }
    }
    */
}

