---
layout: post
title: "Postprocessing with the Depth Texture"
---

## Summary
In the last tutorial I explained how to do very simple postprocessing effects. One important tool to do more advanced effects is access to the depth buffer. It’s a texture in which the distance of pixels from the camera is saved in.

To understand how postprocessing effects with access to the depth buffer work it’s best to understand how postprocessing works in general in unity. I have a tutorial on that here: https://ronja-tutorials.tumblr.com/post/175172770247/postprocessing

![Result](/assets/images/posts/017/Result.gif)

## Read Depth
We will start this with the files we made in the simple postprocessing tutorial and go from there.

The first thing we expand is the C# script which inserts our material into the rendering pipeline. We will expand it so when it starts up it will look for the camera on the same gameobject as itself and tell it to generate a depth buffer for us to use. This is done via the depthtexture mode flags. We could just set it to render the depth buffer, but what we’re going to do is take the existing value and take a bit-or with the flag we want to set, this way we don’t overwrite the flags other scripts might set to render their own effects. (you can read up on bitmasks if you’re curious how that works)

```cs
private void Start(){
    Camera cam = GetComponent<Camera>();
    cam.depthTextureMode = cam.depthTextureMode | DepthTextureMode.Depth;
}
```

That’s already everything we have to change on the C# side to get access to the depth texture, so we can now start writing our shader.

We get access to the depth texture by creating a new texture sampler which we call _CameraDepthTexture. We can read from the sampler like any other texture, so we can just do that and look at how the depth texture looks like. Because the depth is just a single value, it’s only saved in the red value of the texture and the other color channels are empty so we just take the red value.

```glsl
//the depth texture
sampler2D _CameraDepthTexture;
```
```glsl
//the fragment shader
fixed4 frag(v2f i) : SV_TARGET{
    //get depth from depth texture
    float depth = tex2D(_CameraDepthTexture, i.uv).r;

    return depth;
}
```

After doing this and starting the game, chances are high that the game looks mostly black. That’s because the depth isn’t encoded linearly, the distances closer to the camera are more precise than the ones further away because that’s where more precision is needed. If we put the camera very close to objects we should still be able to see some brighter color, indicating that the object is close to the camera. (if you still see black/mostly black when putting the camera close to objects and would like to, try increasing your near clipping distance)

![a image where close objects are bright and then quickly fall off to black as theyre further away](/assets/images/posts/017/Short.png)

To make this more usable for ourselves we have to decode the depth. Luckily unity provides a method for us that takes the depth as we have it now and returns the linear depth between 0 and 1, 0 being in the camera and 1 being at the far clipping plane. (if your image is mostly black with a white skybox here, you can try to lower the far clipping plane of your camera to see more shades)

```glsl
//the fragment shader
fixed4 frag(v2f i) : SV_TARGET{
    //get depth from depth texture
    float depth = tex2D(_CameraDepthTexture, i.uv).r;
    //linear depth between camera and far clipping plane
    depth = Linear01Depth(depth);

    return depth;
}
```
![a image where close objects are bright and then fall off to black as theyre further away](/assets/images/posts/017/LinearDepth.png)

The next step is to completely decouple the depth we have from the camera settings so we can change them again without changing the results of our effects. We archieve that by simply multiplying the linear depth we have now with the distance of the far clipping plane. The near and far clipping planes are provided to us by unity via the projectionparams variable, the far clipping plane is in the z component.

```glsl
//the fragment shader
fixed4 frag(v2f i) : SV_TARGET{
    //get depth from depth texture
    float depth = tex2D(_CameraDepthTexture, i.uv).r;
    //linear depth between camera and far clipping plane
    depth = Linear01Depth(depth);
    //depth as distance from camera in units 
    depth = depth * _ProjectionParams.z;

    return depth;
}
```
![a image where close objects are dark and then quickly fall off to white as theyre further away, most of the image is plain white](/assets/images/posts/017/CorrectDepth.png)

Because most objects are further away than 1 unit from the camera, the image will be primarily white again, but we now have a value we can use that’s independent of the clipping planes of the camera and in a unit of measurement we can understand (unity units).

## Generate Wave
Next I’m going to show you how to use this information to make a wave effect that seemingly wanders through the world, away from the player. We will be able to customize the distance from the player the wave has at the moment, the length of the trail of the wave, and the color of the wave. So the first step we take is to add those variables to the properties and as variables to our shader. We use the header attribute here to write wave in bold letters over the part with variables for the wave in the inspector, it doesn’t change the functionality of the shader at all.

```glsl
//show values to edit in inspector
Properties{
    [HideInInspector]_MainTex ("Texture", 2D) = "white" {}
    [Header(Wave)]
    _WaveDistance ("Distance from player", float) = 10
    _WaveTrail ("Length of the trail", Range(0,5)) = 1
    _WaveColor ("Color", Color) = (1,0,0,1)
}
```
```glsl
//variables to control the wave
float _WaveDistance;
float _WaveTrail;
float4 _WaveColor;
```
![a image of the inspector with the variables](/assets/images/posts/017/Inspector.png)

The wave example will have a hard cut at it’s front end and a smooth tail behind that. We start by making a hard cut based on the distance. For this we use the step function which returns 0 if the second value is greater or 1 otherwise.

```glsl
    //calculate wave
    float waveFront = step(depth, _WaveDistance);

    return waveFront;
}
```
![a line at a specific depth that falls off](/assets/images/posts/017/Cutoff.gif)

Then to define the trail we use a smoothstep function which is similar to the step function, except we can define two values to compare the third value to, if the third value is less than the first, the function returns 0, if it’s bigger than the second it returns 1, other values return values between 0 and 1. I like to imagine it like a inverse linear interpolation because you can take the result of the smoothstep and put it into a lerp with the same minimum and maximum values as the smoothstep to get the value of teh third argument.

In this case the value we want to compare to is the depth, our maximum is the wave distance and the minimum is the wave distance minus the trail length.

```glsl
    float waveTrail = smoothstep(_WaveDistance - _WaveTrail, _WaveDistance, depth);
    return waveTrail;
}
```
![a smooth line at a specific depth that falls off](/assets/images/posts/017/Trail.gif)

You might notive that the front and the trail of the wave are opposite, it would be easy to fix that (flip the two arguments of the clip or flip the min orthe max of the smoothstep), but in this case it’s on purpose. Because if we multiply any number by zero it becomes zero, we can now multiply the front and the trail of the wave and it will become zero in front and behind the wave with only a small white wave in the middle at our defined distance.

```glsl
//calculate wave
    float waveFront = step(depth, _WaveDistance);
    float waveTrail = smoothstep(_WaveDistance - _WaveTrail, _WaveDistance, depth);
    float wave = waveFront * waveTrail;

    return wave;
}
```
![a line at a specific depth that falls off](/assets/images/posts/017/WhiteWave.gif)

Now that we have defined our wave, we can bring back color to the image. For that we first have to sample our source image again and then we do a linear interpolation from the source image to our wave color based on the wave parameter we just calculated.

```glsl
//mix wave into source color
fixed4 col = lerp(source, _WaveColor, wave);

return col;
```
![a line at a specific depth that falls off](/assets/images/posts/017/HitSky.gif)

As you can see we have a artefact with this approach when the distance reaches the far clipping plane. Even though the skybox is technically at the distance of the far clipping plane, we don’t want to show the wave when it reaches it.

To fix this we read the source color just after we calculate the depth and return it instantly if the depth is at the far clipping plane.

```glsl
//the fragment shader
fixed4 frag(v2f i) : SV_TARGET{
    //get depth from depth texture
    float depth = tex2D(_CameraDepthTexture, i.uv).r;
    //linear depth between camera and far clipping plane
    depth = Linear01Depth(depth);
    //depth as distance from camera in units 
    depth = depth * _ProjectionParams.z;

    //get source color
    fixed4 source = tex2D(_MainTex, i.uv);
    //skip wave and return source color if we're at the skybox
    if(depth >= _ProjectionParams.z)
        return source;

    //calculate wave
    float waveFront = step(depth, _WaveDistance);
    float waveTrail = smoothstep(_WaveDistance - _WaveTrail, _WaveDistance, depth);
    float wave = waveFront * waveTrail;

    //mix wave into source color
    fixed4 col = lerp(source, _WaveColor, wave);

    return col;
}
```

One last thing I’d like to do is expand the C# script to automatically set the distance for us and make it slowly go away from the player. I’d like to control the speed the wave travels and if the wave is active. Also we have to remember the current distance of the wave. For all of that we add a few new class variables to our script.

```cs
[SerializeField]
private Material postprocessMaterial;
[SerializeField]
private float waveSpeed;
[SerializeField]
private bool waveActive;
```

Then we add the update method which is called by unity automatically every frame. In it we increase the distance of the wave if it’S active and set it to zero when it isn’t, this way the wave is reset and comes from the player every time we enable it again.

```cs
vate void Update(){
    //if the wave is active, make it move away, otherwise reset it
    if(waveActive){
        waveDistance = waveDistance + waveSpeed * Time.deltaTime;
    } else {
        waveDistance = 0;
    }
}
```

And then to use the wavedistance variable in our shader we set it. We do the setting in the OnRenderImage just before the method is used, that way we can make sure that when it’s used it’s set to the correct value.

```cs
//method which is automatically called by unity after the camera is done rendering
private void OnRenderImage(RenderTexture source, RenderTexture destination){
    //sync the distance from the script to the shader
    postprocessMaterial.SetFloat("_WaveDistance", waveDistance);
    //draws the pixels from the source texture to the destination texture
    Graphics.Blit(source, destination, postprocessMaterial);
}
```
![a wave travelling automatically while a bool is true](/assets/images/posts/017/AutoWave.gif)

```glsl
Shader "Tutorial/017_Depth_Postprocessing"{
    //show values to edit in inspector
    Properties{
        [HideInInspector]_MainTex ("Texture", 2D) = "white" {}
        [Header(Wave)]
        _WaveDistance ("Distance from player", float) = 10
        _WaveTrail ("Length of the trail", Range(0,5)) = 1
        _WaveColor ("Color", Color) = (1,0,0,1)
    }

    SubShader{
        // markers that specify that we don't need culling 
        // or comparing/writing to the depth buffer
        Cull Off
        ZWrite Off 
        ZTest Always

        Pass{
            CGPROGRAM
            //include useful shader functions
            #include "UnityCG.cginc"

            //define vertex and fragment shader
            #pragma vertex vert
            #pragma fragment frag

            //the rendered screen so far
            sampler2D _MainTex;

            //the depth texture
            sampler2D _CameraDepthTexture;

            //variables to control the wave
            float _WaveDistance;
            float _WaveTrail;
            float4 _WaveColor;


            //the object data that's put into the vertex shader
            struct appdata{
                float4 vertex : POSITION;
                float2 uv : TEXCOORD0;
            };

            //the data that's used to generate fragments and can be read by the fragment shader
            struct v2f{
                float4 position : SV_POSITION;
                float2 uv : TEXCOORD0;
            };

            //the vertex shader
            v2f vert(appdata v){
                v2f o;
                //convert the vertex positions from object space to clip space so they can be rendered
                o.position = UnityObjectToClipPos(v.vertex);
                o.uv = v.uv;
                return o;
            }

            //the fragment shader
            fixed4 frag(v2f i) : SV_TARGET{
                //get depth from depth texture
                float depth = tex2D(_CameraDepthTexture, i.uv).r;
                //linear depth between camera and far clipping plane
                depth = Linear01Depth(depth);
                //depth as distance from camera in units 
                depth = depth * _ProjectionParams.z;

                //get source color
                fixed4 source = tex2D(_MainTex, i.uv);
                //skip wave and return source color if we're at the skybox
                if(depth >= _ProjectionParams.z)
                    return source;

                //calculate wave
                float waveFront = step(depth, _WaveDistance);
                float waveTrail = smoothstep(_WaveDistance - _WaveTrail, _WaveDistance, depth);
                float wave = waveFront * waveTrail;

                //mix wave into source color
                fixed4 col = lerp(source, _WaveColor, wave);

                return col;
            }
            ENDCG
        }
    }
}
```
```cs
using UnityEngine;

//behaviour which should lie on the same gameobject as the main camera
public class DepthPostprocessing : MonoBehaviour {
    //material that's applied when doing postprocessing
    [SerializeField]
    private Material postprocessMaterial;
    [SerializeField]
    private float waveSpeed;
    [SerializeField]
    private bool waveActive;

    private float waveDistance;

    private void Start(){
        //get the camera and tell it to render a depth texture
        Camera cam = GetComponent<Camera>();
        cam.depthTextureMode = cam.depthTextureMode | DepthTextureMode.Depth;
    }

    private void Update(){
        //if the wave is active, make it move away, otherwise reset it
        if(waveActive){
            waveDistance = waveDistance + waveSpeed * Time.deltaTime;
        } else {
            waveDistance = 0;
        }
    }

    //method which is automatically called by unity after the camera is done rendering
    private void OnRenderImage(RenderTexture source, RenderTexture destination){
        //sync the distance from the script to the shader
        postprocessMaterial.SetFloat("_WaveDistance", waveDistance);
        //draws the pixels from the source texture to the destination texture
        Graphics.Blit(source, destination, postprocessMaterial);
    }
}
```

You can also find the source code for this tutorial here:<br/>
<https://github.com/ronja-tutorials/ShaderTutorials/blob/master/Assets/017_DepthPostprocessing/DepthPostprocessing.shader><br/>
<https://github.com/ronja-tutorials/ShaderTutorials/blob/master/Assets/017_DepthPostprocessing/DepthPostprocessing.cs><br/>

I hope I was able to explain how to use the depth buffer for postprocessing effects and you’ll be able to make your own effects now.