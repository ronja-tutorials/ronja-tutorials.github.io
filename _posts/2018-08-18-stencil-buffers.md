---
layout: post
title: "Stencil Buffers"
image: /assets/images/posts/022/Result.gif
---

## Summary
The depth buffer helps us compare depths of objects to ensure they occlude each other properly. But theres also a part of the stencil buffer reserved for "stencil operations". This part of the depth buffer is commonly referred to as stecil buffer. Stencil buffers are mostly used to only render parts of objects while discardin others.

This tutorial will go into some of the basics of the stencil buffer and show read and write from it. We will start with the [basic surface shader]({{ site.baseurl }}{% post_url 2018-03-30-simple-surface %})) but it works just as well with all other types of shaders including unlit and postprocessing ones. In any case you should understand [basics shaders](/basics.html) before getting into manipulating stencil buffers.

![](/assets/images/posts/022/Result.gif)

## Reading from the Stencil Buffer
The shader which will read from the stencil buffer will draw itself, but only where the buffer has a specific value, everywhere else it will be discarded.

All stencil operations are done via a small stencil code block outside of our hlsl code. Like most shaderlab things we can write them in our subshader to use them for the whole subshader or in the shader pass to use them only in that one shader pass. Because in surface shaders our shader passes are generated automatically by unity, we'll write it in the subshader in this case.

```glsl
SubShader {
    Tags{ "RenderType"="Opaque" "Queue"="Geometry"}

    Stencil{
        //stencil operation
    }

    //surface shader code...
```

The most important parameter of the stencil operation is `Ref` which marks the reference value we operate on. the default value is 255 which is the maximum value a stencil buffer can have. For now we'll set it to 0 which is the value the stencil buffer has before we write to it.

Another parameter of the stencil operation we need is `Comp` which defines when the stencil operation passes. The default value is `Always`, which means that no matter what reference value we use, the object will always be drawn. For this shader reading from the stencil buffer we'll use `Equal` which results in the object only being drawn when the stencil buffer at that position is at the value we mark as `Ref`.

```glsl
Stencil{
    Ref 0
    Comp Equal
}
```
![](/assets/images/posts/022/NormalMaterial.png)

With this our material looks just like before, that's because the value of the stencil buffer is 0 everywhere and that's the value we compare to. If we change the reference value to any other number our material will be completely invisible because the comparison fails.

```glsl
Stencil{
    Ref 1
    Comp Equal
}
```
![](/assets/images/posts/022/Invisible.png)

Before we start writing a new shader I'd like to add the possibility to change the reference value from the inspector. For that we first add a property with a range going from 0 to 255, that includes all values the stencil buffer can have. Then we add the `[IntRange]` attribute to the property to ensure we can only choose whole values.

```glsl
Properties {
    _Color ("Tint", Color) = (0, 0, 0, 1)
    _MainTex ("Texture", 2D) = "white" {}
    _Smoothness ("Smoothness", Range(0, 1)) = 0
    _Metallic ("Metalness", Range(0, 1)) = 0
    [HDR] _Emission ("Emission", color) = (0,0,0)

    [IntRange] _StencilRef ("Stencil Reference Value", Range(0,255)) = 0
}
```

Then to use the reference value in the stencil operation, we put it behind the `Ref`, but put it in square brackets. In this context the square brackets tell unity to parse the value as a property. With this in place we still only have the choice between visible (0) and invisible (all other values), but we can easily switch between the values.

```glsl
Stencil{
    Ref [_StencilRef]
    Comp Equal
}
```

## Writing to the Stencil Buffer
To make real use from our shader which reads from the stencil buffer, we'll write a second one which reads from it. This second shader will not write to the screen itself and will render before the first shader, so we make sure the stencil buffer already has the correct values written to it when we read from it.

For this shader we start with the shader from the [properties tutorial]({{ site.baseurl }}{% post_url 2018-03-22-properties %}) because it's so simple and we don't need much. For it to not render to the screen at all and just manipulate the stencil buffer we'll add a few other small detail to it though.

First we let the fragment shader just return 0, because we don't care about the return value anyways. Then we set the blending to `Zero One`, which means that the the color that is returned by the shader will be completely ignored and the color that was rendered before will be preserved completely. Another change to make the shader not render is that we'll tell it to not write to the Z buffer. Otherwise it would occlude objects behind it and because we want to see other things though the surface we don't want that at all. And the last change is to ensure the material renders before the materials which might read from the stencil buffer: We change the queue from `geometry` to `geomety-1` which puts it earlier in the render queue.

Then we also delete the color variable and property because they became obsolete.

```glsl
fixed4 frag(v2f i) : SV_TARGET{
    return 0;
}
```
```glsl
Blend Zero One
ZWrite Off
```
```glsl
"Queue"="Geometry-1"
```
```glsl
//show values to edit in inspector
Properties{
    
}
```
![](/assets/images/posts/022/Invisible.png)

With this we've made another completely invisible shader, but with the advantage that it stays invisble no matter what the stencil buffer value is and that it actually draws something so we can stick a stencil operation to it.

We start by copying the stencil block and the ref property from the first shader. Then we change the comparison operation to `Always` this means the material won't compare the ref value to the buffer and just draw the output of the shader. Then we add a new attribute called `Pass`, it declares what will happen when the comparison with the zbuffer is successful, so what happens if the object isn't occluded. And we set it to the value of `Replace`, which means it'll take the ref value and write it to the stencil buffer. Theres also a attribute called `Fail` if you want to specify what will happen when the object is occluded, but it's set to not do anything by default so we won't touch it.

```glsl
Stencil{
    Ref [_StencilRef]
    Comp Always
    Pass Replace
}
```
![](/assets/images/posts/022/SphereAndQuad.png)

Now you can see the first material when it is at the same pixel on the screen as the second and has the same reference value.

And with those two shaders you already know the basics on how to use stencil buffers in unity. If you want to learn more, you can look at the official documentation of stencil buffers here <https://docs.unity3d.com/Manual/SL-Stencil.html> or just experiment with them to see what possibilities they open.

![](/assets/images/posts/022/WrongStencil.png)

When trying things out I ran into the problem that when using multiple stencil values to read/write the one that's behind can be rendered later and will then overwrite the value from the buffer in the front. If you run into that problem a solution is to change the render queue of the materials. That's because unity sorts all materials with a render queue higher than 2500 so they're rendered furthest away to closest. usually this is done to ensure transparent object are drawn properly, but it works just as well to make sure we render the correct stencil values. In my example I used 2501 for the stencil write materials and 2502 for the stencil read materials. important is just that we render the write materials before the read materials and that we give them a queue order below 3000, otherwise we might mess with drawing of transparent objects.

![](/assets/images/posts/022/WriteInspector.png)

![](/assets/images/posts/022/ReadInspector.png)

![](/assets/images/posts/022/Result.gif)

##Source
```glsl
Shader "Tutorial/022_stencil_buffer/read" {
	Properties {
		_Color ("Tint", Color) = (0, 0, 0, 1)
		_MainTex ("Texture", 2D) = "white" {}
		_Smoothness ("Smoothness", Range(0, 1)) = 0
		_Metallic ("Metalness", Range(0, 1)) = 0
		[HDR] _Emission ("Emission", color) = (0,0,0)

		[IntRange] _StencilRef ("Stencil Reference Value", Range(0,255)) = 0
	}
	SubShader {
		Tags{ "RenderType"="Opaque" "Queue"="Geometry"}

        //stencil operation
		Stencil{
			Ref [_StencilRef]
			Comp Equal
		}

		CGPROGRAM

		#pragma surface surf Standard fullforwardshadows
		#pragma target 3.0

		sampler2D _MainTex;
		fixed4 _Color;

		half _Smoothness;
		half _Metallic;
		half3 _Emission;

		struct Input {
			float2 uv_MainTex;
		};

		void surf (Input i, inout SurfaceOutputStandard o) {
			fixed4 col = tex2D(_MainTex, i.uv_MainTex);
			col *= _Color;
			o.Albedo = col.rgb;
			o.Metallic = _Metallic;
			o.Smoothness = _Smoothness;
			o.Emission = _Emission;
		}
		ENDCG
	}
	FallBack "Standard"
}
```
```glsl
Shader "Tutorial/022_stencil_buffer/write"{
	//show values to edit in inspector
	Properties{
		[IntRange] _StencilRef ("Stencil Reference Value", Range(0,255)) = 0
	}

	SubShader{
		//the material is completely non-transparent and is rendered at the same time as the other opaque geometry
		Tags{ "RenderType"="Opaque" "Queue"="Geometry-1"}

        //stencil operation
		Stencil{
			Ref [_StencilRef]
			Comp Always
			Pass Replace
		}

		Pass{
            //don't draw color or depth
			Blend Zero One
			ZWrite Off

			CGPROGRAM
			#include "UnityCG.cginc"

			#pragma vertex vert
			#pragma fragment frag

			struct appdata{
				float4 vertex : POSITION;
			};

			struct v2f{
				float4 position : SV_POSITION;
			};

			v2f vert(appdata v){
				v2f o;
				//calculate the position in clip space to render the object
				o.position = UnityObjectToClipPos(v.vertex);
				return o;
			}

			fixed4 frag(v2f i) : SV_TARGET{
				return 0;
			}

			ENDCG
		}
	}
}
```

I hope this tutorial helped you understand how to use the stencil buffer and how to archieve cool effects with it.

You can also find the source here:
- <https://github.com/ronja-tutorials/ShaderTutorials/blob/master/Assets/022_Stencil_Buffer/stencil_read.shader>
- <https://github.com/ronja-tutorials/ShaderTutorials/blob/master/Assets/022_Stencil_Buffer/stencil_write.shader>