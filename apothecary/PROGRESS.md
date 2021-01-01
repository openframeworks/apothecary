| Key     | Meaning                                   
|---------|:--------
| ✗       | requires build, not written
| ☁       | written but doesn't build, etc          
| ✓?      | builds but not tested
| ✓       | builds and tested in an OF project
| ✗C      | copy only, doesn't need build, not written
| ✓C      | copy only, written & tested
| P       | using system-installed package (pkg-config, ... )
| N/A     | not applicable / not used on this platform

| Lib                             | osx | linux | linux64 | linuxarmv6l | linuxarmv7l | vs | msys2  | ios | android |
|---------------------------------|-----|-------|---------|-------------|-------------|----|--------|-----|---------|
| FreeImage                       | ✓   | N/A   | N/A     | N/A         | N/A         | ✗  | P     | ✓   | ✗       |
| FreeType                        | ✓   | N/A   | N/A     | N/A         | N/A         | ?  | P      | ✓   | ?       |
| tess2                           | ✓   | ✗     | ✗      | ✗           | ✗          | ✓? | ✓     | ✓   | ✗       |
| Poco                            | ✓   | ✗     | ✗      | ✗           | ✗          | ✓? | P      | ✓   | ✗       |
| OpenSSL                         | ✓   | ✗     | ✗      | ✗           | ✗          | ✗  | P      | ✓   | N/A     |
| cairo                           | ✓   | N/A   | N/A     | N/A         | N/A         | ✗  | P      | N/A | N/A     |
| fmod                            | ✓C  | ✗     | ✗      | ✗           | ✗          | ✗  | ✓C    | N/A | N/A     |
| glew                            | ✓   | ✗     | ✗      | ✗           | ✗          | ✓  | P      | N/A | N/A     |
| glfw                            | ✓   | ✗     | ✗      | ✗           | ✗          | ✓? | P      | N/A | N/A     |
| glm                             |     |        |        |              |            |     | ✓C    |     |        |
| glu                             | N/A | N/A   | N/A     | N/A         | N/A         | ✗  | ✗      | N/A | N/A     |
| glut                            | ✗   | N/A   | N/A    | N/A          | N/A         | ✗  | ✗      | N/A | N/A     |
| kiss                            | ✓C  | ✗     | ✗      | ✗           | ✗          | ✓C | ✓C     | ✓   | ✓C      |
| portaudio                       | ✓C  | ✓C    | ✓C     | ✗           | ✗           | ✓C | ✓C     | N/A | N/A     |
| quicktime                       | N/A | N/A   | N/A     | N/A         | N/A         | ✗  | ✗      | N/A | N/A     |
| rtAudio                         | ✓?  | ✗     | ✗       | ✗           | ✗           | ✗  | ✗      | N/A | N/A     |
| videoInput                      | N/A | N/A   | N/A     | N/A         | N/A         | ✓  | ✓      | N/A | N/A     |
| ofxAssimpModelLoader -> assimp  | ☁   | ✗     | ✗       | ✗           | ✗           | ✗  | P      | ✓?  | ✗       |
| ofxOpenCV -> opencv             | ✓?  | ✗     | ✗       | ✗           | ✗           | ✗  | P      | ✓?  | ✗       |
| ofxOsc -> oscpack               | ✗C  | ✗C    | ✗C      | ✗C          | ✗C          | ✗C | ✗C     | ✗C  | ✗C      |
| ofxSvg -> svgTiny               | ✗C  | ✗C    | ✗C      | ✗C          | ✗C          | ✗C | ✗C     | ✗C  | ✗C      |
| ofxXmlSettings -> tinyxml       | ✗C  | ✗C    | ✗C      | ✗C          | ✗C          | ✗C | ✗C     | ✗C  | ✗C      |
