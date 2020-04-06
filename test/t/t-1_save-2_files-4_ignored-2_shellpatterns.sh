#!/bin/bash
source ./lib.bash

# Test ignored files (using shell patterns).

TestPhase_Setup ###############################################################
TestAddFile /lostfile.txt 'Lost file contents'
TestAddFile /lostfile_abc.txt 'Lost file contents'
TestAddFile /lostfile_xyz.txt 'Lost file contents'
TestAddFile /lostfile-one.txt 'Lost file contents'
TestAddFile /lostfile-two.txt 'Lost file contents'
TestAddFile /lostfile-three.txt 'Lost file contents'
TestAddFile '/lostfile aa x b.txt' 'Lost file contents'
TestAddFile '/lostfile c x ddd.txt' 'Lost file contents'
TestAddFile '/lostfile e y ff.txt' 'Lost file contents'
TestAddFile /lostfilea.txt 'Lost file contents'
TestAddFile /lostfileb.txt 'Lost file contents'
TestAddFile /lostfileg.txt 'Lost file contents'
TestAddFile /lostfilex.txt 'Lost file contents'
TestAddFile /lostfiley.txt 'Lost file contents'
TestAddFile /lostfilez.txt 'Lost file contents'
TestAddFile '/lostfile<>.txt' 'Lost file contents'

TestAddConfig IgnorePath /lostfile.txt
TestAddConfig IgnorePath "'"'/lostfile_*.txt'"'"
TestAddConfig IgnorePath "'"'/lostfile_*.txt'"'"
TestAddConfig IgnorePath "'"'/lostfile-???.txt'"'"
TestAddConfig IgnorePath "'"'/lostfile * x*.txt'"'"
TestAddConfig IgnorePath "'"'/lostfile[a-hy].txt'"'"
TestAddConfig IgnorePath "'"'/lostfile\<\>.txt'"'"

TestPhase_Run #################################################################
AconfSave

TestPhase_Check ###############################################################
TestExpectConfig <<EOF
CopyFile /lostfile\ e\ y\ ff.txt
CopyFile /lostfile-three.txt
CopyFile /lostfilex.txt
CopyFile /lostfilez.txt
EOF

TestDone ######################################################################
