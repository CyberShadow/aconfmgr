#!/bin/bash
source ./lib.bash

# Test ignored files (using shell patterns).

TestPhase_Setup ###############################################################
TestAddFile /strayfile.txt 'Stray file contents'
TestAddFile /strayfile_abc.txt 'Stray file contents'
TestAddFile /strayfile_xyz.txt 'Stray file contents'
TestAddFile /strayfile-one.txt 'Stray file contents'
TestAddFile /strayfile-two.txt 'Stray file contents'
TestAddFile /strayfile-three.txt 'Stray file contents'
TestAddFile '/strayfile aa x b.txt' 'Stray file contents'
TestAddFile '/strayfile c x ddd.txt' 'Stray file contents'
TestAddFile '/strayfile e y ff.txt' 'Stray file contents'
TestAddFile /strayfilea.txt 'Stray file contents'
TestAddFile /strayfileb.txt 'Stray file contents'
TestAddFile /strayfileg.txt 'Stray file contents'
TestAddFile /strayfilex.txt 'Stray file contents'
TestAddFile /strayfiley.txt 'Stray file contents'
TestAddFile /strayfilez.txt 'Stray file contents'
TestAddFile '/strayfile<>.txt' 'Stray file contents'

TestAddConfig IgnorePath /strayfile.txt
TestAddConfig IgnorePath "'"'/strayfile_*.txt'"'"
TestAddConfig IgnorePath "'"'/strayfile_*.txt'"'"
TestAddConfig IgnorePath "'"'/strayfile-???.txt'"'"
TestAddConfig IgnorePath "'"'/strayfile * x*.txt'"'"
TestAddConfig IgnorePath "'"'/strayfile[a-hy].txt'"'"
TestAddConfig IgnorePath "'"'/strayfile\<\>.txt'"'"

TestPhase_Run #################################################################
AconfSave

TestPhase_Check ###############################################################
TestExpectConfig <<"EOF"
printf '%s' 'Stray file contents' > "$(CreateFile /strayfile\ e\ y\ ff.txt)"
printf '%s' 'Stray file contents' > "$(CreateFile /strayfile-three.txt)"
printf '%s' 'Stray file contents' > "$(CreateFile /strayfilex.txt)"
printf '%s' 'Stray file contents' > "$(CreateFile /strayfilez.txt)"
EOF

TestDone ######################################################################
