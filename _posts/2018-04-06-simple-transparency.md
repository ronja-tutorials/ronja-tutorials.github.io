---
layout: post
title: "Basic Transparency"
---
## Summary
In addition to just painting color onto the screen, we can also preserve some of the color that was on the screen previously, making the object seem see-through. I’ll explain how we can archieve this effect in a basic shader without lighting.

To understand how to implement transparency, I recommend you know [the basics of writing shaders]({{ site.baseurl }}/basics.html), in this tutorial I'll start with the result of the [tutorial for implementing textures]({{ site.baseurl }}{% post_url 2018-03-23-textures %}).

![Result](/assets/images/posts/006/SemitransparentCube.png)

To make the transparent object render correctly, we have to tell unity that it’s transparent. For that we’ll change the render type as well as the queue. By changing the queue, we make sure the material is rendered later than the opaque materials. If that wasn’t the case, a opaque object that’s behind a transparent one would have to draw over the transparent one, completely covering it.

```glsl
Tags{ "RenderType"="Transparent" "Queue"="Transparent"}
```

Next we define the “blending mode”, it defines how the existing colors and the new colors blend with each other. The blend mode is defined by 2 keywords, the first one defines the value the new color is multiplied with and the second one defines the value the old color is multiplied with. After multiplying the colors, they’re added together and the result is drawn.

When rendering opaque materials, the blend mode is one zero because we take all of the new value and nothing of the old value. In transparent materials, we want to make the blending based on the alpha value (the 4th number in the color we return that did nothing until now). So we set the first blend value to source alpha, the source in this case being the output of the shader. And the second value has to be the inverse of that, so it’s one minus the source alpha.

The blending mode can be defined in the subshader or the shader pass, but has to be outside of the hlsl area.

```glsl
Blend SrcAlpha OneMinusSrcAlpha
```

You can look up the different blend factors (and a few other blending properties I’m going to go into) here: <https://docs.unity3d.com/Manual/SL-Blend.html>

I’m gonna show you 2 small examples of how this works so it’s maybe clearer:

When our fragment shader returns a alpha value of 0.5, the blending will take half of the new color and 1 - 0.5 (0.5) of the old color, blending them equally (when drawing white on black it will be a medium grey).

When our fragment shader returns a alpha value of 0.9, the blending will take 90% of the new color and add 10% of the old color, making the old color barely visible.

With those changes our shader can already be used for a transparent material. Because we preserve the alpha channel in the fragment shader, we can set the alpha of the tint color and it will be the alpha of the material (provided you use a texture that doesn’t use the alpha channel).

![Change Tint](/assets/images/posts/006/AdjustTint.gif)

Another small thing we want to do here is disable z writing. Usually when a object is rendered, it writes it’s distace from the camera into a texture to tell other objects that are behind it not to draw over it. This doesn’t work with transparent objects though, because transparent objects don’t fully occlude everything behind them (to accomodate for that, first the most object furthest away is rendered and then in order until the closest object is rendered last, but unity does that for us so we don’t have to worry about it). Wether to write into the Z buffer or not can be defined in the subshader or shader pass.
```glsl
Blend SrcAlpha OneMinusSrcAlpha
ZWrite Off
```

When our texture does have a alpha channel, this shader will also use it and make the object more see-through where there are low alpha values on the texture.

![Result](/assets/images/posts/006/TextureTransparentCube.png)
```glsl
Shader "Tutorial/006_Basic_Transparency"{
	Properties{
		_Color ("Tint", Color) = (0, 0, 0, 1)
		_MainTex ("Texture", 2D) = "white" {}
	}

	SubShader{
		Tags{ "RenderType"="Transparent" "Queue"="Transparent"}

		Blend SrcAlpha OneMinusSrcAlpha
		ZWrite off

		Pass{
			CGPROGRAM

			#include "UnityCG.cginc"

			#pragma vertex vert
			#pragma fragment frag

			sampler2D _MainTex;
			float4 _MainTex_ST;

			fixed4 _Color;

			struct appdata{
				float4 vertex : POSITION;
				float2 uv : TEXCOORD0;
			};

			struct v2f{
				float4 position : SV_POSITION;
				float2 uv : TEXCOORD0;
			};

			v2f vert(appdata v){
				v2f o;
				o.position = UnityObjectToClipPos(v.vertex);
				o.uv = TRANSFORM_TEX(v.uv, _MainTex);
				return o;
			}

			fixed4 frag(v2f i) : SV_TARGET{
				fixed4 col = tex2D(_MainTex, i.uv);
				col *= _Color;
				return col;
			}

			ENDCG
		}
	}
}
```

You can also find the source code here: <https://github.com/ronja-tutorials/ShaderTutorials/blob/master/Assets/006_Transparency/transparent.shader>