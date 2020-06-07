---
layout: post
title: "Postprocessing Basics"
image: /assets/images/posts/016/Result.jpg
---

## Summary

We used all shaders we wrote in this tutorial until now to render models to the screen. Another way shaders are commonly used is to manipulate images with them. That includes the image we’re drawing to the screen as we render our game. When manipulating the render output after we rendered our objects to the screen it’s called postprocessing.

Postprocessing still uses the same shader language and structure as shaders that render surfaces, so I’d recommend you to know how to render surfaces first. If you have read/understand my [tutorial about rendering rextures]({{ site.baseurl }}{% post_url 2018-03-23-basic %}) you should be fine.

![Result](/assets/images/posts/016/Result.jpg)

## Postprocessing Shader

As a simple introduction into postprocessing, I’m going to show you how to make a shader which inverts the colors of an image.

Because most of the structure is the same as other shaders, we’re going to use the textured shader as a base for this one, you can find it [here]({{ site.baseurl }}{% post_url 2018-03-23-basic %})

This simple shader already has some things we don’t need if we don’t render surfaces with it which we’re going to remove. I’m removing the tint color(we can keep it if we wanted to tint the image), the tags (unity can read when and how to render objects, but like I mentioned, we’re not rendering objects with the shader), the texture transforms (maintex will be the image before we apply the shader to it and we always want the whole scene), the transform tex macro (because it uses the texture transform and we don’t use that anymore, but we still want to write the uv coordinates into the v2f struct) and the part where the tint color is used.

Then we will add a few details which to make the shader work better as a postprocessing shader. Those are the hide in inspector tag for the main texture property because it will be set from code and markers that tell unity to not perform any culling or writing/reading to the depth buffer.

After those changes, the shader should look roughly like this.

```glsl
Shader "Tutorial/016_Postprocessing"{
    //show values to edit in inspector
    Properties{
        [HideInInspector]_MainTex ("Texture", 2D) = "white" {}
    }

    SubShader{
        // markers that specify that we don't need culling
        // or reading/writing to the depth buffer
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

            //texture and transforms of the texture
            sampler2D _MainTex;

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
                //get source color from texture
                fixed4 col = tex2D(_MainTex, i.uv);
                return col;
            }

            ENDCG
        }
    }
}
```

## Postprocessing C# Script

Now that we have the base of our postprocessing shader, we can write the C# script that will make the camera use the script.

We will need a normal monobehaviour, with only one method called OnRenderImage. The method will automatically be called by unity. It’s passed two arguments, one rendertexture with the rendered image and one rendertexture we can write into that’s used as the rendered image afterwards. To move image data from one rendertexture to the other, we use the blit method.

```cs
using UnityEngine;

//behaviour which should lie on the same gameobject as the main camera
public class Postprocessing : MonoBehaviour {

	//method which is automatically called by unity after the camera is done rendering
	void OnRenderImage(RenderTexture source, RenderTexture destination){
		//draws the pixels from the source texture to the destination texture
		Graphics.Blit(source, destination);
	}
}
```

So far this script wouldn’t do anything because it doesn’t change the image at all. For it to do that we can pass the blit function a material to use to draw the texture as a third parameter. We’ll add a material as a serialized class variable and then pass it to the blit function to do that.

```cs
using UnityEngine;

//behaviour which should lie on the same gameobject as the main camera
public class Postprocessing : MonoBehaviour {
    //material that's applied when doing postprocessing
    [SerializeField]
    private Material postprocessMaterial;

    //method which is automatically called by unity after the camera is done rendering
    void OnRenderImage(RenderTexture source, RenderTexture destination){
        //draws the pixels from the source texture to the destination texture
        Graphics.Blit(source, destination, postprocessMaterial);
    }
}
```

With this set up, we can then set up our scene. First we add a new Material to our project and apply our postprocessing shader to it.

![The inspector of the material without properties](/assets/images/posts/016/EmptyMaterial.png)

Then we take the gameobject with our camera on it and the C# script we wrote. Then we add our new material to the component.

![the camera gameobject with the postprocessing component](/assets/images/posts/016/PostprocessingComponent.png)

## Negative Colors Effect

With this our setup is complete, we should see the image like normal. To use this to invert the colors of our image, we go back into our shader and edit the fragment function. Instead of just returning the color of the input texture, we first invert the color by calculating 1 minus the color and then return it.

```glsl
//the fragment shader
fixed4 frag(v2f i) : SV_TARGET{
    //get source color from texture
    fixed4 col = tex2D(_MainTex, i.uv);
    //invert the color
    col = 1 - col;
    return col;
}
```

![Result](/assets/images/posts/016/Result.jpg)

Inverting the color is obviously not a thing you often want to do, but this opens up many possibilities for future effects, some of which I will show in the next weeks.

```glsl
Shader "Tutorial/016_Postprocessing"{
    //show values to edit in inspector
    Properties{
        [HideInInspector]_MainTex ("Texture", 2D) = "white" {}
    }

    SubShader{
        // markers that specify that we don't need culling
        // or reading/writing to the depth buffer
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

            //texture and transforms of the texture
            sampler2D _MainTex;

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
                //get source color from texture
                fixed4 col = tex2D(_MainTex, i.uv);
                //invert the color
                col = 1 - col;
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
public class Postprocessing : MonoBehaviour {
	//material that's applied when doing postprocessing
	[SerializeField]
	private Material postprocessMaterial;

	//method which is automatically called by unity after the camera is done rendering
	void OnRenderImage(RenderTexture source, RenderTexture destination){
		//draws the pixels from the source texture to the destination texture
		Graphics.Blit(source, destination, postprocessMaterial);
	}
}
```

You can also find the source code for this tutorial here:<br/>
<https://github.com/ronja-tutorials/ShaderTutorials/blob/master/Assets/016_Postprocessing/Postprocessing.shader><br/>
<https://github.com/ronja-tutorials/ShaderTutorials/blob/master/Assets/016_Postprocessing/Postprocessing.cs><br/>

I hope you learned how to do simple postprocessing in unity and are ready to make simple postprocessing shaders yourself.
