# Use this script to re-generate the python source file for the tf2xla.proto if 
# the proto ends up changing in the future.
protoc --proto_path ./proto --python_out ./python-protobuf ./proto/tensorflow/tf2xla/tf2xla.proto
