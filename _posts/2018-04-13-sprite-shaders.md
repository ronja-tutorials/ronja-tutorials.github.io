---
layout: post
title: "Sprite Shaders"
---
## Summary
In unity the way sprites are rendered is very similar to the way 3d objects are rendered. Most of the work is done by the sprite renderer component. I’ll go a bit over what the component is doing and how we can change our shader to do some of the stuff the default sprite renderer is doing.

This tutorial will build on the transparent shader we made previously so it’s best that you understand that one first:
<https://ronja-tutorials.tumblr.com/post/172658736322/basic-transpararency>

![Result](/assets/images/posts/007/Result.png)

## Scene Setup
To work on sprite shaders I’ll change the scene to be simpler. I made the camera orthographic, replaced the cube I used in previous examples with a sprite renderer and converted the images I use to sprites.

![hierarchy with camera and sprite](/assets/images/posts/007/Hierarchy.png)<br/>
![Inspector window of orthographic camera](/assets/images/posts/007/CameraInspector.png)<br/>
![Inspector window of configured sprite renderer](/assets/images/posts/007/SpriteInspector.png)<br/>
![Inspector window of the sprite importer](/assets/images/posts/007/SpriteImporter.png)

## Changing the Shader
With all of those changes and the transparent material put into the material slot of the sprite renderer, everything already seems to work.

The sprite renderer component automatically generates a mesh based on our image and sets the UV coordinates of it so it works just like the 3d models we’re used to. It puts the color of the sprite renderer into the vertex colors of the generated mesh and it assorts the vertices in a flipped shape when we activate flip X or Y. It also communicates with the unity render pipeline so sprites that have a higher sorting layer get rendered later and are drawn on top.

Our shader currently doesn’t support mirroring and vertex colors, so let’s fix that.

The reason our sprite disappears when we flip it (and reappears when we flip it in x and y) is that to flip the sprite around the x axis, the renderer basically rotates it 180° around the y axis and then we see the back of it and because of a optimisation called “backface culling” the backsides of faces aren’t rendered. Usually backface culling is good, because when we don’t see the inside of a object, why render it. And backfaces usually have wrong lighting anyways, because their normals face away from the camera.

In this case we don’t have to worry about either of those things though, sprites don’t have a “inside” that could be optimised and we also don’t do lighting, so we can just disable backface culling. we can do that in the subshader or the shader pass.

```glsl
Cull Off
```

To get the vertex colors we add a new 4d(red, green, blue, alpha) variable to our input stuct and vertex to fragment struct and mark it as color. Then we transfer the color  from the input to the v2f struct in the vertex shader and in the fragment shader multiply our return color with it;

```glsl
struct appdata{
    float4 vertex : POSITION;
    float2 uv : TEXCOORD0;
    fixed4 color : COLOR;
};

struct v2f{
    float4 position : SV_POSITION;
    float2 uv : TEXCOORD0;
    fixed4 color : COLOR;
};

v2f vert(appdata v){
    v2f o;
    o.position = UnityObjectToClipPos(v.vertex);
    o.uv = TRANSFORM_TEX(v.uv, _MainTex);
    o.color = v.color;
    return o;
}

fixed4 frag(v2f i) : SV_TARGET{
    fixed4 col = tex2D(_MainTex, i.uv);
    col *= _Color;
    col *= i.color;
    return col;
}
```

With those changes the shader will now act as we expect it to and we can expand it to do other stuff we’re interrested in in the future.

![Playing around with the variables](/assets/images/posts/007/AdjustVariables.gif)

```glsl
Shader "Tutorial/007_Sprite"{
	Properties{
		_Color ("Tint", Color) = (0, 0, 0, 1)
		_MainTex ("Texture", 2D) = "white" {}
	}

	SubShader{
		Tags{ 
			"RenderType"="Transparent" 
			"Queue"="Transparent"
		}

		Blend SrcAlpha OneMinusSrcAlpha

		ZWrite off
		Cull off

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
				fixed4 color : COLOR;
			};

			struct v2f{
				float4 position : SV_POSITION;
				float2 uv : TEXCOORD0;
				fixed4 color : COLOR;
			};

			v2f vert(appdata v){
				v2f o;
				o.position = UnityObjectToClipPos(v.vertex);
				o.uv = TRANSFORM_TEX(v.uv, _MainTex);
				o.color = v.color;
				return o;
			}

			fixed4 frag(v2f i) : SV_TARGET{
				fixed4 col = tex2D(_MainTex, i.uv);
				col *= _Color;
				col *= i.color;
				return col;
			}

			ENDCG
		}
	}
}
```

The sprite renderer component also prepares the mesh so spritesheets, polygon sprites and animations work with our shader.

What the sprite shader from unity does support, but ours doesn’t so far is instancing, pixel snapping and a external alpha channel, but that’s either too complex for now or edge cases most people don’t use so I decided to not implement them here.

You can also find the source code here <https://github.com/ronja-tutorials/ShaderTutorials/blob/master/Assets/007_Sprites/sprite.shader>.