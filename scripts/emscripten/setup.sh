#!/bin/bash

if [ -z "${EMSDK+x}" ]; then
	echo "Emscripten SDK not yet found"
    # Check if EMSCRIPTEN_PATH is empty
	if [ -z "${EMSCRIPTEN_PATH+x}" ]
	then
		echo "Emscripten EMSCRIPTEN_PATH not yet set in environment variables"
		# Set the EMSCRIPTEN_PATH environment variable to the path where the emscripten SDK is installed  
		export EMSCRIPTEN_PATH=I:/Repositories/emscripten/emsdk
		echo "Emscripten EMSCRIPTEN_PATH set to $EMSCRIPTEN_PATH" 
	fi
	  # Check if the emscripten SDK directory exists
	  if [ -d "$EMSCRIPTEN_PATH" ]
	  then
	    # Run the emsdk_env.sh script to set variables to PATH for this session
	    source "$EMSCRIPTEN_PATH/emsdk_env.sh"
	    
	  else
	    # Print an error message and exit the script
	    echo "Error: emscripten SDK directory not found at $EMSCRIPTEN_PATH"
	    exit 1
	  fi
	
else
  echo "Emscripten SDK found at $EMSDK"
  source "$EMSDK/emsdk_env.sh"
  
fi