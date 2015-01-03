#!/bin/sh

./makebundle.sh ../build/Handmade

CommonCompilerFlags="-std=gnu++11 -Wall -Wno-c++11-compat-deprecated-writable-strings -Wno-tautological-compare -Wno-null-dereference -Wno-old-style-cast -Wno-unused-variable -Wno-unused-function -DHANDMADE_INTERNAL=1 -DHANDMADE_SLOW=1 -g"

mkdir -p ../build
pushd ../build
g++ -o ../build/Handmade.app/Contents/MacOS/GameCode.dylib ${CommonCompilerFlags} -dynamiclib ../code/casey/handmade.cpp
g++ -o ../build/Handmade.app/Contents/MacOS/Handmade ${CommonCompilerFlags} -framework Cocoa -framework QuartzCore -framework AudioToolbox -lobjc ../code/handmadehero.mac.mm
popd