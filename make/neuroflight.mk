# Check to make sure the directory where the Tensorflow checkpoint is kept is set
ifeq ($(FC_MODEL_DIR),)
  $(error FC_MODEL_DIR not set)
endif

# Check and set up the paths for the Tensorflow tools
# TODO Add Tensorflow and Bazel install to tools.mk
ifndef TENSORFLOW_DIR
  $(error TENSORFLOW_DIR is not set. Please download and build Tensorflow then set the environment variable'TENSORFLOW_DIR' to its location.)
else
ifeq ($(shell [ -d "$(TENSORFLOW_DIR)" ] && echo "exists"), exists)
  TFCOMPILE			= $(TENSORFLOW_DIR)/bazel-bin/tensorflow/compiler/aot/tfcompile
  TRANSFORM_GRAPH	= $(TENSORFLOW_DIR)/bazel-bin/tensorflow/tools/graph_transforms/transform_graph
else 
  $(error Could not find the Tensorflow path $(TENSORFLOW_DIR).)
endif
endif


GRAPH_TOOLS_DIR	= $(TOOLS_DIR)/graph-compiling

# Keep this separate from static source, since its auto-generated it can be safetly wiped
GEN_GRAPH		= $(ROOT)/gen/graph
GEN_SRC			= $(ROOT)/gen/src

# Add the location where auto generated content will be placed
INCLUDE_DIRS    := $(INCLUDE_DIRS) \
                   $(GEN_SRC)

FROZEN_MODEL		= $(GEN_GRAPH)/frozen_model.pb
OPT_MODEL			= $(GEN_GRAPH)/frozen_model_optimized.pb
GRAPH_CPP_CLASS		= "fc::NeuroControl"
GRAPH_HEADER		= $(GEN_SRC)/graph.h
TFCOMPILE_CONFIG	= $(FC_MODEL_DIR)/tf2xla.config.pbtxt

# Parse the node names from the tf2xla configuration file
CONFIG_PARSER		= $(GRAPH_TOOLS_DIR)/get_graph_config_param.py
INPUT_NODE_NAMES	= $(shell python3 $(CONFIG_PARSER) $(FC_MODEL_DIR) --input-node-name)
OUTPUT_NODE_NAMES	= $(shell python3 $(CONFIG_PARSER) $(FC_MODEL_DIR) --output-node-name)

# Notes:
# Memory scope error for std=c++11 required switching to gnu++11
# Include the ANDROID macro to trigger the AOT runtime to use memalign rather than posix_memalign
# for targets other than SITL. However there appears to be a bug  in tensorflow/compiler/aot/runtime.cc 
# which returns "'memalign' was not declared in this scope". memalign is not included in stdlib, need
# to include malloc.h.
# In newest v1.12, runtime.cc has migrated to tensorflow/compiler/tf2xla/cpu_function_runtime.cc
CXXFLAGS = -g
CPPFLAGS = $(ARCH_FLAGS) \
              $(addprefix -D,$(OPTIONS)) \
              $(addprefix -I,$(INCLUDE_DIRS)) \
              $(DEBUG_FLAGS) \
		   	  -std=gnu++11 \
              -Wall -Wextra -Wunsafe-loop-optimizations -Wdouble-promotion \
              -ffunction-sections \
              -fdata-sections \
              -pedantic \
              $(DEVICE_FLAGS) \
              -DUSE_STDPERIPH_DRIVER \
              -D$(TARGET) \
              $(TARGET_FLAGS) \
              -D'__FORKNAME__="$(FORKNAME)"' \
              -D'__TARGET__="$(TARGET)"' \
              -D'__REVISION__="$(REVISION)"' \
              -save-temps=obj \
              -MMD -MP \
              $(EXTRA_FLAGS)

ifneq ($(TARGET),$(filter $(TARGET), $(SITL_TARGETS)))
CPPFLAGS += -D'__ANDROID__'
endif

# Add the auto generated object, and Tensorflow dependencies
# to the list of objects
TARGET_OBJS += $(OBJECT_DIR)/$(TARGET)/graph/graph.o
TARGET_OBJS += $(addsuffix .o,$(addprefix $(OBJECT_DIR)/$(TARGET)/,$(basename $(GRAPH_SRC))))
TARGET_OBJS += $(addsuffix .o,$(addprefix $(OBJECT_DIR)/$(TARGET)/,$(basename $(subst $(TENSORFLOW_DIR)/,,$(AOT_SRC)))))

# Clean neuroflight generatred files
CLEAN_ARTIFACTS += $(TARGET_GRAPH_OBJS)

# Targets
#########################################################################

$(GEN_SRC)/graph_dim.h :
	$(V1) mkdir -p $(dir $@)
	python3 $(GRAPH_TOOLS_DIR)/gen_graph_config_header.py $(FC_MODEL_DIR) $(GEN_SRC)
	echo "%% Generated graph_dim.h"




# Freeze the graph, then optimize the graph to run on hardware.
# Finally compile the graph to an object
$(OBJECT_DIR)/$(TARGET)/graph/graph.o $(GEN_SRC)/graph.h :  $(FC_MODEL_DIR)/checkpoint

#	$(V1) mkdir -p $(dir $@)
#	python3 $(GRAPH_TOOLS_DIR)/gen_graph_config_header.py $(FC_MODEL_DIR) $(GEN_SRC)
#	echo "%% Generated graph_dim.h"

	$(V1) mkdir -p $(dir $@)
	mkdir -p $(GEN_GRAPH) 
	python $(GRAPH_TOOLS_DIR)/freeze-graph.py\
	   	--model_dir=$(FC_MODEL_DIR)\
	   	--output_node_names=$(OUTPUT_NODE_NAMES)\
		--output=$(FROZEN_MODEL)
	
	$(TRANSFORM_GRAPH)\
	   	--in_graph=$(FROZEN_MODEL)\
	   	--out_graph=$(OPT_MODEL)\
	   	--inputs=$(INPUT_NODE_NAMES)\
	   	--outputs=$(OUTPUT_NODE_NAMES) \
		--transforms='fold_constants(ignore_errors=true) remove_nodes(op=Identity) sort_by_execution_order'

ifeq ($(TARGET),$(filter $(TARGET), $(SITL_TARGETS)))
# Target for if building to run SITL on linux
		$(TFCOMPILE)\
		     --graph=$(OPT_MODEL)\
			 --cpp_class=$(GRAPH_CPP_CLASS)\
			 --config="$(TFCOMPILE_CONFIG)"\
			 --out_function_object="$(@)"\
			 --out_header="$(GRAPH_HEADER)"\
			 --xla_cpu_multi_thread_eigen=false 
else
# TARGET if running on embedded
# TODO pull target_cpu and triple from arch
		$(TFCOMPILE)\
		     --graph=$(OPT_MODEL)\
			 --cpp_class="$(GRAPH_CPP_CLASS)"\
			 --config="$(TFCOMPILE_CONFIG)"\
			 --out_function_object="$(@)"\
			 --out_header="$(GRAPH_HEADER)"\
			 --xla_cpu_multi_thread_eigen=false \
			 --target_cpu="cortex-m7"\
			 --target_triple="armv7em-none-eabi" 
endif

# The main neuro control file needs the dimensions of the graph which is 
# auto generated
$(OBJECT_DIR)/$(TARGET)/graph/neuro.o: $(SRC_DIR)/graph/neuro.c $(GEN_SRC)/graph_dim.h
	$(V1) mkdir -p $(dir $@)
	$(V1) $(if $(findstring $(subst ./src/main/,,$<),$(SPEED_OPTIMISED_SRC)), \
	echo "%% (speed optimised) $(notdir $<)" "$(STDOUT)" && \
	$(CROSS_CC) -c -o $@ $(CFLAGS) $(CC_SPEED_OPTIMISATION) $<, \
	$(if $(findstring $(subst ./src/main/,,$<),$(SIZE_OPTIMISED_SRC)), \
	echo "%% (size optimised) $(notdir $<)" "$(STDOUT)" && \
	$(CROSS_CC) -c -o $@ $(CFLAGS) $(CC_SIZE_OPTIMISATION) $<, \
	echo "%% $(notdir $<)" "$(STDOUT)" && \
	$(CROSS_CC) -c -o $@ $(CFLAGS) $(CC_DEFAULT_OPTIMISATION) $<))

# The graph interface file depends on the auto generated header file from tfcompile
$(OBJECT_DIR)/$(TARGET)/graph/graph_interface.o: $(SRC_DIR)/graph/graph_interface.cc $(GEN_SRC)/graph.h
	$(V1) mkdir -p $(dir $@)
	$(V1) $(if $(findstring $(subst ./src/main/,,$<),$(SPEED_OPTIMISED_SRC)), \
	echo "%% (speed optimised) $(notdir $<)" "$(STDOUT)" && \
	$(CROSS_CXX) -c -o $@ $(CPPFLAGS) $(CC_SPEED_OPTIMISATION) $<, \
	$(if $(findstring $(subst ./src/main/,,$<),$(SIZE_OPTIMISED_SRC)), \
	echo "%% (size optimised) $(notdir $<)" "$(STDOUT)" && \
	$(CROSS_CXX) -c -o $@ $(CPPFLAGS) $(CC_SIZE_OPTIMISATION) $<, \
	echo "%% C++ $(notdir $<)" "$(STDOUT)" && \
	$(CROSS_CXX) -c -o $@ $(CPPFLAGS) $(CC_DEFAULT_OPTIMISATION) $<))

#Compile the Tensorflow tfcompile dependencies
$(OBJECT_DIR)/$(TARGET)/tensorflow/%.o: $(TENSORFLOW_DIR)/tensorflow/%.cc
	$(V1) mkdir -p $(dir $@)
	$(V1) $(CROSS_CXX) -c -o $@ $(CPPFLAGS) $<



