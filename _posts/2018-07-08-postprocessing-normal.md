---
layout: post
title: "Postprocessing with Normal Texture"
---

## Summary
Another piece of information we can easily get our hands on thats very useful for postprocessing is the normals of the scene. They show in which direction the surface at any given pixel is pointing.

To understand how to get and use the normals of the scene it’s best to know how to access the scene depth first, I made a tutorial on how to do that [here]({{ site.baseurl }}{% post_url 2018-07-08-postprocessing-normal %}).

![Result](/assets/images/posts/018/Result.png)

## Read Depth and Normals
We start this tutorials with the files from the depth postprocessing tutorial and expand them as we need.

The first change is to remove all of the code from the c# script which we used to drive the wave in the previous tutorial.
Then, we don‘t tell the camera to render the depth of objects anymore - instead we tell it to render a texture which includes the depth as well as the normals.

```cs
private void Start(){
    //get the camera and tell it to render a depthnormals texture
    cam = GetComponent<Camera>();
    cam.depthTextureMode = cam.depthTextureMode | DepthTextureMode.DepthNormals;
}
```

And that’s already all of the setup we need to access the normals. Next we edit our shader.

We also remove the all of the code used for the wave function here. Then we rename the _CameraDepthTexture to _CameraDepthNormalsTexture, so it’s written in by unity.

```glsl
//show values to edit in inspector
Properties{
    [HideInInspector]_MainTex ("Texture", 2D) = "white" {}
}
```
```glsl
//the depth normals texture
sampler2D _CameraDepthNormalsTexture;
```

With this setup we can now read from the depthnormals texture in our fragment shader. If we just do that and just draw the texture to the screen, we can already see something interresting.

```glsl
//the fragment shader
fixed4 frag(v2f i) : SV_TARGET{
    //read depthnormal
    float4 depthnormal = tex2D(_CameraDepthNormalsTexture, i.uv);

    return depthnormal;
}
```
![a image where we can see depth and normals, but they are encoded so it looks kinda matte](/assets/images/posts/018/EncodedNormals.png)

But what we can see isn’t what we really want, we only see red and green values and some blue in the distance. That’s because as it’s name suggests, this texture holds the normals as well as the depth texture, so we have to decode it first. Luckily unity provides us a method that does exactly that. We have to give it the depthnormal value as well as two other values the function will write the depth and the normals in.

Unlike the depth texture, the depth value we have now is already linear between the camera and the far plane, so we can easily adapt the code from the previous tutorial to get the distance from the camera again.

```glsl
//the fragment shader
fixed4 frag(v2f i) : SV_TARGET{
    //read depthnormal
    float4 depthnormal = tex2D(_CameraDepthNormalsTexture, i.uv);

    //decode depthnormal
    float3 normal;
    float depth;
    DecodeDepthNormal(depthnormal, depth, normal);

    //get depth as distance from camera in units 
    depth = depth * _ProjectionParams.z;

    return depth;
}
```
![Depth texture](/assets/images/posts/018/Depth.png)

But let’s go back to using the normals. When we just print the normals as colors to the screen we already get a pretty good result.

```glsl
//the fragment shader
fixed4 frag(v2f i) : SV_TARGET{
    //read depthnormal
    float4 depthnormal = tex2D(_CameraDepthNormalsTexture, i.uv);

    //decode depthnormal
    float3 normal;
    float depth;
    DecodeDepthNormal(depthnormal, depth, normal);

    //get depth as distance from camera in units 
    depth = depth * _ProjectionParams.z;

    return float4(normal, 1);
}
```
![](/assets/images/posts/018/DecodedNormals.gif)

But if we rotate the camera, we can can see that one point on a surface doesn’t always have the same normal, that’s because the normals are stored relative to the camera. So if we want the normal in the world we have to go additional steps.

We can easily convert our viewspace normals to world space, but sadly unity doesn’t provide us a function for that so we have to pass it to our shader ourselves. So we go back to our C# script and implement that.

First we get a reference to our camera, we already get the camera in our start method, so we can directly save it to a class variable right there. Then in the OnRenderImage method we get the viewspace to worldspace matrix from the camera and then pass it to our shader. The reason we can’t pass the matrix to our shader once in the start method is that we want to move and rotate our camera after starting the effect and the matrix changes when we do that.

```glsl
using UnityEngine;

//behaviour which should lie on the same gameobject as the main camera
public class NormalPostprocessing : MonoBehaviour {
	//material that's applied when doing postprocessing
	[SerializeField]
	private Material postprocessMaterial;

	private Camera cam;

	private void Start(){
		//get the camera and tell it to render a depthnormals texture
		cam = GetComponent<Camera>();
		cam.depthTextureMode = cam.depthTextureMode | DepthTextureMode.DepthNormals;
	}

	//method which is automatically called by unity after the camera is done rendering
	private void OnRenderImage(RenderTexture source, RenderTexture destination){
		//get viewspace to worldspace matrix and pass it to shader
		Matrix4x4 viewToWorld = cam.cameraToWorldMatrix;
		postprocessMaterial.SetMatrix("_viewToWorld", viewToWorld);
		//draws the pixels from the source texture to the destination texture
		Graphics.Blit(source, destination, postprocessMaterial);
	}
}
```

Next we can use that matrix in our shader. we add a new variable for it and then multiply it with the normal before using it. We cast it to a 3x3 matrix before the multiplication so the position change doesn’t get applied only the rotation, that’s all we need for normals.

```glsl
//matrix to convert from view space to world space
float4x4 _viewToWorld;
```
```glsl
    normal = normal = mul((float3x3)_viewToWorld, normal);
    return float4(normal, 1);
}
```
![](/assets/images/posts/018/WorldspaceNormals.gif)

## Color the Top
Now that we have the worldspace normals, we can do a simple effect to get comfortable with them. We can color the top of all objects in the scene in a color.

To do this, we simply compare the normal to the up vector. We do this via a dot product which returns 1 when both normalized vectors point in the same direction(when the surface is flat), 0 when they’re orthogonal (in our case on walls) and -1 when they’re opposite to each other(in our case that would mean a roof over the camera).

```glsl
    float up = dot(float3(0,1,0), normal);
    return up;
}
```
![](/assets/images/posts/018/Topness.png)

To make it more obvious what’s on top and what doesn’t count as on top, we can now take this smooth value and do a step to differentiate between top and not on top. If the second value is smaller, it will return 0 and we will see black, if it’s bigger, we will see white.

```glsl
float up = dot(float3(0,1,0), normal);
up = step(0.5, up);
return up;
```
![](/assets/images/posts/018/TopCutoff.png)

The next step is to bring back the original colors where we don’t define the surface to be on top. For that we just read from the main texture and then do a linear interpolation between that color and the color we define to be on top (white at the moment).

```glsl
float up = dot(float3(0,1,0), normal);
up = step(0.5, up);
float4 source = tex2D(_MainTex, i.uv);
float4 col = lerp(source, float4(1,1,1,1), up);
return col;
```
![](/assets/images/posts/018/WhiteTop.png)

And as a last step we’re going to add some customizability. So we add a property and a global variable for the up cutoff value and the top color.

```glsl
_upCutoff ("up cutoff", Range(0,1)) = 0.7
_topColor ("top color", Color) = (1,1,1,1)
```
```glsl
//effect customisation
float _upCutoff;
float4 _topColor;
```

Then we replace the fixed 0.5 we used previously for our cutoff value with the new cutoff variable and linearly interpolate to the top color instead of the fix white color. We can then also multiply the up color with the alpha value of the top color, that way when we lower the alpha value the top will let some of the original color through.

```glsl
    float up = dot(float3(0,1,0), normal);
    up = step(_upCutoff, up);
    float4 source = tex2D(_MainTex, i.uv);
    float4 col = lerp(source, _topColor, up * _topColor.a);
    return col;
}
```
![](/assets/images/posts/018/Result.png)

This effect was mainly made to show how the depthnormals texture works. If you want a snow effect it’s probably better to just do it in the shader for the object the snow is on instead of a postprocessing effect. I’m sorry I didn’t come up with a better example.

## Source
```glsl
using UnityEngine;

//behaviour which should lie on the same gameobject as the main camera
public class NormalPostprocessing : MonoBehaviour {
    //material that's applied when doing postprocessing
    [SerializeField]
    private Material postprocessMaterial;

    private Camera cam;

    private void Start(){
        //get the camera and tell it to render a depthnormals texture
        cam = GetComponent<Camera>();
        cam.depthTextureMode = cam.depthTextureMode | DepthTextureMode.DepthNormals;
    }

    //method which is automatically called by unity after the camera is done rendering
    private void OnRenderImage(RenderTexture source, RenderTexture destination){
        //get viewspace to worldspace matrix and pass it to shader
        Matrix4x4 viewToWorld = cam.cameraToWorldMatrix;
        postprocessMaterial.SetMatrix("_viewToWorld", viewToWorld);
        //draws the pixels from the source texture to the destination texture
        Graphics.Blit(source, destination, postprocessMaterial);
    }
}
```
```glsl
Shader "Tutorial/018_Normal_Postprocessing"{
    //show values to edit in inspector
    Properties{
        [HideInInspector]_MainTex ("Texture", 2D) = "white" {}
        _upCutoff ("up cutoff", Range(0,1)) = 0.7
        _topColor ("top color", Color) = (1,1,1,1)
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
            //matrix to convert from view space to world space
            float4x4 _viewToWorld;
            //the depth normals texture
            sampler2D _CameraDepthNormalsTexture;

            //effect customisation
            float _upCutoff;
            float4 _topColor;


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
                //read depthnormal
                float4 depthnormal = tex2D(_CameraDepthNormalsTexture, i.uv);

                //decode depthnormal
                float3 normal;
                float depth;
                DecodeDepthNormal(depthnormal, depth, normal);

                //get depth as distance from camera in units 
                depth = depth * _ProjectionParams.z;

                normal = mul((float3x3)_viewToWorld, normal);

                float up = dot(float3(0,1,0), normal);
                up = step(_upCutoff, up);
                float4 source = tex2D(_MainTex, i.uv);
                float4 col = lerp(source, _topColor, up * _topColor.a);
                return col;
            }
            ENDCG
        }
    }
}
```

You can also find the source here:<br/>
<https://github.com/ronja-tutorials/ShaderTutorials/blob/master/Assets/018_NormalPostprocessing/NormalPostprocessing.cs>
<https://github.com/ronja-tutorials/ShaderTutorials/blob/master/Assets/018_NormalPostprocessing/NormalPostprocessing.shader>

I hope that I was able to convey how to access normal textures and that this will be a solid foundation for future effects.