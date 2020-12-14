#!/bin/bash


declare filePath=$1
declare sourcePath=$2

echo "Generate Matrix invoked with template file: $filePath"

cd $sourcePath # Change to terraform Directory
layers=($(ls -r | grep -v "01_init")) # List Layers in Reverse excluding Init

insertMatrixDarwin() {
    echo "Darwin detected, running matrix generation for MacOS"
    declare sedFile="$(pwd)/sed.cmd"
    echo "sedFile: $sedFile"
    
    echo "s/__MATRIX_CONTENT__/\\" > $sedFile
    for layer in ${layers[@]}
    do
        echo "      Destroy_${layer}:\\" >> $sedFile
        echo "        layer: ${layer}\\" >> $sedFile
        echo "        deployments: \$(deploymentJson)\\" >> $sedFile
    done
    echo "/" >> $sedFile

    cd ..
    sed -i '' -f $sedFile $filePath 
    echo "File Updated  : $filePath"
    rm $sedFile
}

insertMatrixLinux() {
    echo "Linux detected, running matrix generation for Linux"
    declare layerOuput

    for layer in ${layers[@]}
    do
        
        cd $layer
        layerOutput+="      Destroy_${layer}:\n        layer: ${layer}\n        deployments: \$(deploymentJson)\n"
        cd ..
    
    done
    cd ..
    pwd
    echo  "layerOutput=$layerOuput"
    sed -i "s/__MATRIX_CONTENT__/${layerOutput}/g" $filePath
}

if [[ "$OSTYPE" == "darwin"* ]]; then
    insertMatrixDarwin
else
    insertMatrixLinux
fi