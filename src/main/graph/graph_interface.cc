#include <platform.h>
#include "common/maths.h"
#include "graph_interface.h"
#include "graph.h"


/**
 * A wrapper for the AOT C++ neural network graph to compute 
 * motor outputs for the given state input.
 *
 * 	input: An input array of the current state
 * 	output: Output array   
 * 	input_size: 
 **/
void compute_motor_values(float *input, float *output, int input_size, int output_size ){

	fc::NeuroControl controller;
	//Copy the input into the buffer
	std::copy(input + 0, input + input_size, controller.arg0_data());
	//Run the graph, the output of the neural network is in rage [-1:1] for each motor output
	controller.Run();

	//Need to convert to range expected by mixer
	for (int i=0; i < output_size; i++){
		//First clip the output because this graph will exeed bounds
        // TODO Make bounds configurable
		 float clippedOutput = constrainf(controller.result0(0,i), -1.0f, 1.0f);
		 //Next tranform the range from tanh to 0:1
		 *(output + i) = clippedOutput; 	
    }
}

