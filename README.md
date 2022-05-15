# NRG project: Comparison of transmittance and distance estimators in light transport

Transmittance estimators implemented in Unity shaders, analysis done on a volumetric cube.

`nrg-project` is a unity project. Inside `nrg-project/Assets/` are shaders and image capture script. 

Inside `images` folder is jupyter notebook where the analysis was performed.

In unity scene there are cubes using different shaders from left to right: ratio next flight, delta next flight, analytical, ratio, delta, stratified MC, ray marcher.

If capturing images, move the main camera before wanted cube, set filepath in script.
