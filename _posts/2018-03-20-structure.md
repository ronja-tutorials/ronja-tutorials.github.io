---
layout: post
title: "Structure"
image: /assets/images/posts/001/pipeline.png
---

## Shader Structure

When talking about shaders I want to start at explaining the rough outline of how shaders are set up so we can understand how to customize them.

Most modern shaders have a variable pipeline that consists out of at least a vertex shader and a fragment shader. It's also possible to add a geometry and tesselation stage to this, but you only rarely need those. The vertex shader (sometimes also called vertex stage or function) takes the data that defines the model and transforms it into screenspace so it can be rendered (using matrix multiplication, but we can just accept that it works for now). We can also use custom vertex shaders to animate the position of the vertices without changing the mesh data and pass more data to the fragment shader. After we defined where on the screen the vertices are the triangles between them are turned into pixels by the rasterizer. In addition to deciding which pixel gets rendered for a object the rasterizer also interpolates all data in the output of the vertex shader so pixels that are between vertices also get the inbetween values. After deciding which pixels get rendered the fragment shader (also called pixel shader) decides the color of the pixel.

![Result](/assets/images/posts/001/pipeline.png)

This is just the basic setup of a shader. I'm gonna explain in future tutorials how to write all that, what those "spaces" are, which data we move between the stages and where the data comes from, but I hope just seeing this gives you an idea of the layers of separation a shader has. This is the same in most shading languages and environments. Node based shaders that don't have a concept of vertex and fragment stages still generate those stages internally.

## ShaderLab

Regular shaders in Unity are just text files where the file name has .shader at the end in a similar manner how C# scripts end with .cs. We can also create easly by doing `rightclick > Create > Shader > <any>` to get one of the templates, what we do with the template is mostly irrelevant. To ease you into writing shaders we're going to start with a shader thats fairly similar to the shader you get when you do `rightclick > Create > Shader > Unlit Shader`. The main difference is that our shader won't correctly react to fog and it'll have a texture as well as a tint which are multiplied so you can make objects that have a solid color without creating a texture of that color. The whole shader looks like this and I'm going to explain all parts of it bit by bit over the first few tutorials. This is supposed to be a start for learning shaders, so if you have any troubles understanding this feel free to write me about the problems you have so I can improve the tutorials so future learners have a easier time.

```glsl
Shader "Tutorial/001-004_Basic_Unlit"{
	//show values to edit in inspector
	Properties{
		_Color ("Tint", Color) = (0, 0, 0, 1)
		_MainTex ("Texture", 2D) = "white" {}
	}

	SubShader{
		//the material is completely non-transparent and is rendered at the same time as the other opaque geometry
		Tags{ "RenderType"="Opaque" "Queue"="Geometry" }

		Pass{
			CGPROGRAM

			//include useful shader functions
			#include "UnityCG.cginc"

			//define vertex and fragment shader functions
			#pragma vertex vert
			#pragma fragment frag

			//texture and transforms of the texture
			sampler2D _MainTex;
			float4 _MainTex_ST;

			//tint of the texture
			fixed4 _Color;

			//the mesh data thats read by the vertex shader
			struct appdata{
				float4 vertex : POSITION;
				float2 uv : TEXCOORD0;
			};

			//the data thats passed from the vertex to the fragment shader and interpolated by the rasterizer
			struct v2f{
				float4 position : SV_POSITION;
				float2 uv : TEXCOORD0;
			};

			//the vertex shader function
			v2f vert(appdata v){
				v2f o;
				//convert the vertex positions from object space to clip space so they can be rendered correctly
				o.position = UnityObjectToClipPos(v.vertex);
				//apply the texture transforms to the UV coordinates and pass them to the v2f struct
				o.uv = TRANSFORM_TEX(v.uv, _MainTex);
				return o;
			}

			//the fragment shader function
			fixed4 frag(v2f i) : SV_TARGET{
			    //read the texture color at the uv coordinate
				fixed4 col = tex2D(_MainTex, i.uv);
				//multiply the texture color and tint color
				col *= _Color;
				//return the final color to be drawn on screen
				return col;
			}

			ENDCG
		}
	}
	Fallback "VertexLit"
}
```

## Whats ShaderLab?

Unity Shaders are written in a custom declarative language called "Shaderlab". It defines most things about the context in which models are drawn in unity. Actual shader programs are written in one of the shader languages hlsl, glsl or CG which are contained in blocks inside of shaderlab.

![](/assets/images/posts/002/LanguageAreas.png)

As you can see "pure" shaderlab only takes up a small part of our shader right now. Thats partially because shaderlab isn't executed, instead it just describes things in a more abstract form. And for a minimal shader like this one the default settings are fine for most things.

## Shader/SubShader/Pass

You might have discovered that there are multiple blocks marked by curly braces `{}` inside of each other so lets look at those first.

`Shader` defines the whole shader. The name of the shader as which it appears in the shader menu in materials is also set at the start of the shader block. When setting the name of the shader you can add slashes to the name to group shaders into categories. I put all shaders I write in tutorials in the `Tutorial` shader category and create a new subcategory when theres multiple shaders in a tutorial, but feel free to use whatever categories feel best to you. Theres always only a single shader defined per file, more are not possible. It's also possible to define fallback shaders in the top level of the shader. If you define a fallback shader it will act as if all subshaders of the fallback shader are pasted into your shader file.

A `Shader` block can contain one or multiple `Subshader`s. Multiple subshaders can be used to provide different shaders that are used depending on the hardware the shader is used on, but the documentation on how to define which subshader is used when is extremely lacking and in my experience you'll be fine with one subshader usually. One exception is that you often don't want to write your own shadowpass so you can set a fallback shader and unity will automatically use that shadowpass if it can't find one in your shader. Most shaders use the `VertexLit` shader as a fallback to get shadows because it's a very cheap and simple shader (also probably because of tradition and copying shader code around, I don't even know which of the many VertexLit shaders it's using tbh). Inside the subshaders you can define the [subshader tags](https://docs.unity3d.com/Manual/SL-SubShaderTags.html) as well as multiple shader passes and properties that are set for all passes in the subshader.

A `Pass` is a single unit of something being drawn to the screen. If you define multiple passes in the default render pipeline they're drawn one after the other (URP only ever draws one pass afaik). Shaders that do that are sometimes referred to as multipass shaders. In addition to an optional name, [pass tags](https://docs.unity3d.com/Manual/SL-PassTags.html) and the same parameters we can define in subshaders (but this time on a per pass basis, in a subshader with 1 pass it doesn't matter whether the properties are in the pass or subshader) the pass also has the code thats actually managing the rendering.

## Properties and Tags

You might have seen 2 other blocks in the ShaderLab part of our that we haven't talked about yet. The `Properties` in the shader outer block and the `Tags` in the subshader.

If you know a dictionary from other programming languages you can compare the tags to them. They hold key value pairs that the engine can use. Subshader tags mainly define how materials with the shader are shown in the editor, when they're rendered or what operations can be applied to them while pass tags are mainly used to define in the legacy pipeline which pass are used for which step of light calculation. You can find subshader tags [here](https://docs.unity3d.com/Manual/SL-SubShaderTags.html) and pass tags [here](https://docs.unity3d.com/Manual/SL-PassTags.html).

Properties are used to display variables in the material editor. They have some limitations as we're only able to set properties via this that are the same over all objects where the material is used so you'll have to use different techniques if you want to set a property per objects or even per smaller part of the mesh. But since we have access to the texture coordinates by default and we can set the textures via those properties they bring us pretty far. I'm going to go deeper into explaining properties in one of the next tutorials.

Overall this is how the just the rough structure of this shader looks like with a bit of abstraction

```glsl
Shader "Category/Name"{
	Properties{
		//Properties
	}
	Subshader{
		Tags{
			//Subshader Tags
		}

		//Settings for all passes

		Pass{
			Tags{
				//Pass Tags
			}

			//Settings for pass

			CGPROGRAM
			//shader code
			ENDCG
		}
	}
}
```

## Source

All tutorials have the source of the resulting shader linked at the bottom. Since we're just analyzing right now I'm just gonna put the code of a full shader here for now.

- <https://github.com/ronja-tutorials/ShaderTutorials/blob/master/Assets/001-004_basic_unlit/basic_unlit.shader>

```glsl
Shader "Tutorial/001-004_Basic_Unlit"{
	//show values to edit in inspector
	Properties{
//	_Color ("Tint", Color) = (0, 0, 0, 1)
//	_MainTex ("Texture", 2D) = "white" {}
	}

	SubShader{
		//the material is completely non-transparent and is rendered at the same time as the other opaque geometry
		Tags{ "RenderType"="Opaque" "Queue"="Geometry" }

		Pass{
			CGPROGRAM
//
//		//include useful shader functions
//		#include "UnityCG.cginc"
//
//		//define vertex and fragment shader functions
//		#pragma vertex vert
//		#pragma fragment frag
//
//		//texture and transforms of the texture
//		sampler2D _MainTex;
//		float4 _MainTex_ST;
//
//		//tint of the texture
//		fixed4 _Color;
//
//		//the mesh data thats read by the vertex shader
//		struct appdata{
//			float4 vertex : POSITION;
//			float2 uv : TEXCOORD0;
//		};
//
//		//the data thats passed from the vertex to the fragment shader and interpolated by the rasterizer
//		struct v2f{
//			float4 position : SV_POSITION;
//			float2 uv : TEXCOORD0;
//		};
//
//		//the vertex shader function
//		v2f vert(appdata v){
//			v2f o;
//			//convert the vertex positions from object space to clip space so they can be rendered correctly
//			o.position = UnityObjectToClipPos(v.vertex);
//			//apply the texture transforms to the UV coordinates and pass them to the v2f struct
//			o.uv = TRANSFORM_TEX(v.uv, _MainTex);
//			return o;
//		}
//
//		//the fragment shader function
//		fixed4 frag(v2f i) : SV_TARGET{
//			//read the texture color at the uv coordinate
//			fixed4 col = tex2D(_MainTex, i.uv);
//			//multiply the texture color and tint color
//			col *= _Color;
//			//return the final color to be drawn on screen
//			return col;
//
//		}
			ENDCG
		}
	}
	Fallback "VertexLit"
}
```
