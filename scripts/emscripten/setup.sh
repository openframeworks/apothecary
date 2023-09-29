#!/bin/bash

if [ -z "${EMSDK+x}" ]; then
	echo "Emscripten SDK not yet found"
    # Check if EMSCRIPTEN_PATH is empty
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