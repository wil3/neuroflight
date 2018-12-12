import argparse
import sys, os
import tensorflow as tf
from google.protobuf import text_format
from python_protobuf.tensorflow.tf2xla.tf2xla_pb2 import Config


def parse(model_dir, input_name, output_name, config_name="tf2xla.config.pbtxt"):
    config_filepath = os.path.join(model_dir, config_name)
    with open(config_filepath) as f:
        txt = f.read()
    config = text_format.Parse(txt, Config())
    if input_name:
        return config.feed[0].id.node_name
    elif output_name:
        return config.fetch[0].id.node_name

if __name__ == '__main__':
    """ Simple script to parse individual values from the tf2xla config we need for compiling the graph """
    parser = argparse.ArgumentParser()
    parser.add_argument("model_dir", help="Directory where the Tensorflow checkpoints are located.")
    parser.add_argument("--config-name", help="Name of the tf2xla proto config file used for tfcompile.", default="tf2xla.config.pbtxt")
    group = parser.add_mutually_exclusive_group(required=True)
    group.add_argument("--input-node-name", action="store_true", help="Return the name of the input node.")
    group.add_argument("--output-node-name", action="store_true", help="Return the name of the output node.")
    args = parser.parse_args()
    param = parse(args.model_dir, args.input_node_name, args.output_node_name, config_name=args.config_name)
    print (param)
