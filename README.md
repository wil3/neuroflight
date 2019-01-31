![Neuroflight](https://github.com/wil3/neuroflight/raw/v3.3.x-neuroflight/logo.png)

## WARNING 
This is experimental firmware, use at your own risk! This repo is intended for academic
and research
purposes. 

There is still a significant amount of research required to validate the
behavior of neuro-flight controllers. If the neural network is not trained properly, instabilities and unpredictable behaviors will occur.  

An executable firmware, suitable for the NF1 reference quadcopter, is available here: <insert link£

## Neuroflight: Next Generation Flight Control Firmware

Neuroflight is the first open source neuro-flight controller software (firmware) for remotely piloting multi-rotors and fixed wing aircraft. Neuroflight's primary focus is to provide optimal flight performance.  

Neuroflight aims to address limitations in PID control used in Betaflight
through the use of neural network flight control (neuro-flight control). Neuro-flight control has been actively researched for more than a decade. In contrast to traditional control algorithms, neuro-flight control has the ability to *adapt*, *plan*, and *learn*. To account for dynamic changes Betaflight has introduced gain scheduling to increase the I gain when certain conditions are met, for example low voltages or high throttle (anti-gravity). On the other hand, neuro-flight control learns the true underlying dynamics of the aircraft allowing for optimal control depending on the current aircraft state. For example neuro-flight control has the potential to learn the batteries discharge rates to dynamically adjust control signal outputs accordingly.  The goal of this work is to provide the community with a
stable platform to innovate and advance development of neuro-flight control design for drones, and to take a step towards
making neuro-flight controllers mainstream. For further details refer to our
[preprint](https://wfk.io/docs/neuroflight.pdf) and please use the following BibTex
entry to cite our work,
```
@article{koch2019neuroflight,
  title={Neuroflight: Next Generation Flight Control Firmware},
  author={Koch, William and Mancuso, Renato and Bestavros, Azer},
  journal={arXiv preprint arXiv:1901.06553},
  year={2019}
}
```

## News

* 2018-11-14 Stable flight has been achieved with Neuroflight [https://youtu.be/c3aDDPasjjQ](https://youtu.be/c3aDDPasjjQ)

## Features

In addition to features provided by Betaflight 3.3.3,

* Neural network based flight control
* Mixing replaced by neural network 

## Supported Neural Network Interfaces 
Interfaces are defined for the sensors available on hardware. As models become
more sophisticated additional sensors will be used (e.g. ESC telemetry, voltage
sensor, etc.)

### Gyro-based Neuro-flight controller 
Input (x) is of size 6, where x = [roll error, pitch error, yaw error, delta roll error, delta pitch error, delta yaw error]. Inputs are unbounded and in degrees/s. Output (y) of size N corresponding
    to motor 1 ... motor N. Each output value is in range [-1, 1].

## Compiling

### Pre-requites 

1) Use [GymFC](https://github.com/wil3/gymfc) to train and create a neural network in the
form of a Tensorflow checkpoint.  

2) Place the checkpoint files (four of them: checkpoint, \*.data, \*.meta,
\*.index-\*) in a directory which can be independently version
controlled. 

3) Create a file called `tf2xla.config.pbtxt` in the directory and define the
neural network configuration according to [https://www.tensorflow.org/xla/tfcompile](https://www.tensorflow.org/xla/tfcompile).

4) Neuroflight was developed using [Tensorflow-1.8.0](https://github.com/tensorflow/tensorflow/releases/tag/v1.8.0). 
There appears to be a bug/issue in Tensorflow-1.8.0-rc1 preventing the ABI type from being passed to tfcompile used to compile the neural network. A quick hack to force the correct ABIType is to modify compiler/xla/service/llvm_ir/llvm_util.cc. At the end of the
function SetTargetOptions place,   
```C++
target_options->FloatABIType = llvm::FloatABI::Hard;
```
Need to investigate whether these bugs have been fixed in newer versions or
come up with a better method to handle this. Install [Bazel](https://bazel.build/) and then build Tensorflow.

5) There appears to be a second bug in which `tensorflow/compiler/aot/runtime.cc` does not import `malloc.h`.

### Neuroflight compilation
1) In `make/local.mk` define `TENSORFLOW_DIR` to the location where you have
installed Tensorflow or alternately export this as an environment variable. 

2) In `make/local.mk` define  `FC_MODEL_DIR` as the directory containing
your neural network checkpoint.

3) Refer to [Betaflight](https://github.com/betaflight/betaflight) or
src/main/target for list of supported FCs.

#### Current Tested Flight Controller Hardware
Any F7 should be fine. Flash memory is sufficient for F4's however it is unknown how the decreased processor speed will affect
execution of the neural network. Flight controllers known to work, 

* Matek F722-STD

## Configuration

Neuroflight is compatible with the [Betaflight
Configurator](https://chrome.google.com/webstore/detail/betaflight-configurator/kdaghagfopacdngbohiknlhcocjccjao)
however any modifications to the PID controller and mixer will not do anything
as they are not used by Neuroflight.

## Development
In order to reduce maintenance, avoid merge conflicts and keep as in sync with
upstream Betaflight, Neuroflight's architecture will maintain a minimal footprint and
isolate its code from Betaflight as much as possible. The following table
describes the  files modified (M), and added (A) for Neuroflight,

| Delta | File | Description |
| --- | --- | --- |
| M     | Makefile                  | Include neuroflight.mk |
| A     | make/neuroflight.mk             | Specifics for compiling the neural network |
| M     | make/source.mk            | Add new sources and Tensorflow dependencies |
| A     | tools/graph-compiling/&ast;    | Tools for compiling the neural network graph |
| M     | src/main/fc/fc_core.c     | Replace PID with neuro-flight controller|
| A     | src/main/graph/&ast;           | Source directory supporting interface and execution of the neuro-flight controller |
| M     | src/main/flight/mixer.&ast;   | Inclusion of throttle mixing | 
| A     | gen/&ast;                | Auto-generated files to support neural network integration |
| M     | src/main/platform.h | Remove poisoning of sprintf functions which is used deep in Tensorflow until we can find a better work around. | 


At the time of
development Neuroflight was forked from Betaflight 3.3.3. Since then, newer versions
of Betaflight have increased in size as more features are packed in. Further
testing is needed to identify if the neural network will fit in newer versions
of the firmware. 

