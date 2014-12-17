#!/bin/sh

./makebundle.sh ../build/Handmade


# PATH=$PATH:/System/Library/Frameworks

mkdir -p ../build
pushd ../build
g++ -o ../build/Handmade.app/Contents/MacOS/Handmade -std=gnu++11 -Wall -Wno-c++11-compat-deprecated-writable-strings -Wno-null-dereference -Wno-old-style-cast -framework Cocoa -framework QuartzCore -framework AudioToolbox ../code/handmadehero.mac.mm -lobjc -DHANDMADE_INTERNAL=1 -DHANDMADE_SLOW=1
popd