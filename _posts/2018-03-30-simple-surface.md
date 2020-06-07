---
layout: post
title: "Surface Shader Basics"
image: /assets/images/posts/005/Result.png
---

## Summary

In addition to writing shaders almost from the ground up, unity also
allows us to define some parameters and let unity generate the code
which does the complex light calculations. Those shaders are called
"surface shaders".

To understand surface shaders, it’s good to get to know basic unlit shaders first, I have a tutorial on them [here]({{ site.baseurl }}{% post_url 2018-03-23-basic %}).

![Result](/assets/images/posts/005/Result.png)

## Conversion to simple Surface Shader

When using surface shaders we don’t have to do a few things we have to do otherwise, because unity will generate them for us. For the conversion to a surface shader we can delete our vertex shader completely. We can delete the pragma definitions of the vertex and fragment function. We can delete the input as well as the vertex to fragment struct. We can delete the MainTex_ST variable for texture scaling and we can delete the inclusion of the UnityCG include file. And we remove the pass beginning and end, Unity will generate passes for us. After all of that our emptied Shader should look like this:

```glsl
Shader "Tutorial/005_surface" {
	Properties {
		_Color ("Tint", Color) = (0, 0, 0, 1)
		_MainTex ("Texture", 2D) = "white" {}
	}
	SubShader {
		Tags{ "RenderType"="Opaque" "Queue"="Geometry"}

		CGPROGRAM

		sampler2D _MainTex;
		fixed4 _Color;

		fixed4 frag (v2f i) : SV_TARGET {
			fixed4 col = tex2D(_MainTex, i.uv);
			col *= _Color;
			return col;
		}
		ENDCG
	}
	FallBack "Standard"
}
```

Now that we broke our shader, we can add a few things to make it work again as a surface shader.

First we add a new struct and call it Input, this will hold all of the
information that we need to set the color of our surface. For this
simple shader, this is just the UV coordinates. The data type for our
coordinates will be a 2-dimensional float like in the previous shader.
Here the naming is important though, we’ll name it uv_MainTex, this way it will already have the tiling and offset of the
MainTex texture. If the texture had a different name, we’d have to use
uvTextureName to get the coordinates which fit that texture.

```glsl
struct Input {
	float2 uv_MainTex;
};
```

Next we’ll change our fragment function to a surface function. To make that change obvious we’ll rename it to surf. Then we replace the return type (the data type in front of the function name) with void, so the function doesn’t return anything.

Next we extend it to take 2 arguments. First, a instance of the input
struct we just defined so we have access to information that’s defined
on a per-vertex basis. And second, a struct called SurfaceOutputStandard. As the name makes you assume we will use it for
returning information to the generated part of the shader. For that
“returning” to work, we have to write the inout keyword in front of it. That second struct is all of the data which unity will use for it’s lighting calculations. The lighting calculations are physically based (I’ll explain the parameters later in this post).

Next we’ll delete the sv_target attribute from the method, because like the rest, it’s done somewhere else by unity.

The last change we have to make to make the surface method work is to
remove the return statement (that’s why we changed the return type to
void). Instead we set the albedo part of the output struct to our color value.

```glsl
void surf (Input i, inout SurfaceOutputStandard o) {
	fixed4 col = tex2D(_MainTex, i.uv_MainTex);
	col *= _Color;
	o.Albedo = col.rgb;
}
```

The final step to make the shader work again and to make it correctly
handle light is to add a pragma statement, declaring the kind of shader and the methods used. (similar to how we declared the vertex and fragment methods in the basic shader).

The statement starts with #pragma, followed by the kind of shader we’re declaring (surface), then the name of the surface method (surf) and last the lighting model we want it to use (Standard).

With all of that our shader should work again and show correct lighting.

```glsl
Shader "Tutorial/005_surface" {
	Properties {
		_Color ("Tint", Color) = (0, 0, 0, 1)
		_MainTex ("Texture", 2D) = "white" {}
	}
	SubShader {
		Tags{ "RenderType"="Opaque" "Queue"="Geometry"}

		CGPROGRAM

		#pragma surface surf Standard fullforwardshadows

		sampler2D _MainTex;
		fixed4 _Color;

		struct Input {
			float2 uv_MainTex;
		};

		void surf (Input i, inout SurfaceOutputStandard o) {
			fixed4 col = tex2D(_MainTex, i.uv_MainTex);
			col *= _Color;
			o.Albedo = col.rgb;
		}
		ENDCG
	}
}
```

![Simple Albedo Material](/assets/images/posts/005/SimpleAlbedo.png)

## Standard Lighting Properties

To expand the shader we can now make more use of the material properties. The different values in the output struct are:

- Albedo - Albedo is the base color of the material. It will be tinted by the light color of the lights that illuminate it and is dark in the shadows as weexpectthings to be. The albedo color will not affect the specularlighting, soyou can make a black material which is still visiblyglossy. It’s storedas a 3-dimensional color vector.

* Normal \* This is the normal of the material. The normals are in “tangent space”, that means that after returning them, they will be changed into normals that are relative to the world. Having the normals in tangent space meansthat if we write up (0,1,0) into that variable, the normals won’tactuallypoint up, but away from the surface (that’s the way normals are encoded into normal maps so we can copy information directly fromnormalmaps to this variable). Normals are stored as a 3-dimensional directional vector.

* Emission \* With this you can makeyour materials glow. If you only write into this,you shader will looklike the unlit shader we made previously, but is way more expensive.Emissive colors are not affected by light and as suchyou can make spots that are always bright. You can write values with a value higher than 1 into the emission channel if you render with HDR color (you can setthatin the camera settings) which allows you to make things look really bright and make things bloom out more when you use a bloom postprocessing effect. The emissive color is also stored as a 3d color vector.

* Metallic \* Materials look differently when they are metals than when when they aren’t. To make Materials look metallic, you can turn up this value. It will make the object reflect in a different way and the albedo value will tint the reflections instead of the diffuse lighting you get with non-metals. The metallic value is stored as a scalar(1-dimensional) value, where 0 represents a non-metallic material and 1 a completely metallic one.

* Smoothness \* With this value we can specify how smooth a material is. A material with 0 smoothness looks rough, the light will be reflected to alldirectionsand we can’t see a specular highlight or environmental reflections. A material with 1 smoothness looks super polished. "hen you set up your environment correctly you can see it reflected on your material. It’s also so polished that you can’t see specular highlights either, because the specular highlights become infintely small. When you set the smoothness to a value a bit under 1, you begin to see the specular highlights of the surrounding lights. The highlights grow insize andbecome less strong as you lower the smoothness. The smoothness is also stored as a scalar value.

* Occlusion \* Occlusion will remove light from your material. With it you can fake light not getting into cracks of the model, but you will probably barely use it, except if you’re going for a hyperrealistic style. Occlusion is also stored as a scalar value, but counterintuitively 1 means the pixel has it’s full brightness and 0 means it’s in the dark

* Alpha \* Alpha is the transparency of out material. Our current material is “opaque”,that means there can’t be any transparent pixels and the alpha valuewon’t do anything. When making a transparent shader, alpha will define how much we can see the material at that pixel, 1 is completely visible while 0 is completely see-through. Alpha is also stored as a scalar value.

## Implement a few Lighting Properties

We can now add a few of those features into our shader. I’ll use the
emission, metallic and smoothness values for now, but you can obviously also implement the other values.

First we add the 2 scalar values,
smoothness and metalness. We start by adding the values as half
values(that’s the data type used in the surface output struct) to our
global scope (outside of functions or structs).

```glsl
half _Smoothness;
half _Metallic;
```

Then
we also add the values to our properties, to be able change them in the
inspector. Properties don’t know the half type, so we tell them the
variable are of the type float. That’s enough to make the variables show
up in the inspector, but we’re not using them yet.

```glsl
Properties {
	_Color ("Tint", Color) = (0, 0, 0, 1)
	_MainTex ("Texture", 2D) = "white" {}
	_Smoothness ("Smoothness", float) = 0
	_Metallic ("Metalness", float) = 0
}
```

Similar to how we assigned the color variable to the albedo of the material, we can now assign the smoothness to the smoothness of the output struct and the metalness to the metallic output variable.

```glsl
void surf (Input i, inout SurfaceOutputStandard o) {
	fixed4 col = tex2D(_MainTex, i.uv_MainTex);
	col *= _Color;
	o.Albedo = col.rgb;
	o.Metallic = _Metallic;
	o.Smoothness = _Smoothness;
}
```

This works fine, but it’s easy to assign values higher than 1 or lower than 0 to the values and get very wrong results and it’s hard to see how high a value is. To fix that we can assign the values as range properties instead of float properties. Range properties allow us to define a minimum and a maximum and unity will display us a slider between them.

```glsl
Properties {
	_Color ("Tint", Color) = (0, 0, 0, 1)
	_MainTex ("Texture", 2D) = "white" {}
	_Smoothness ("Smoothness", Range(0, 1)) = 0
	_Metallic ("Metalness", Range(0, 1)) = 0
}
```

![Inspector and Material with smoothness und metalness](/assets/images/posts/005/Inspector.png)

Next we add the emissive color. First as a variable in the hlsl code and then as a property. We use the color property type, just like we did for the tint. We store a half3 as a type because it’s a RGB color without alpha and it can have values bigger than 1 (also the output struct uses a half3). Then we also assign the value in the surface output like we did with the others.

```glsl
// ...

_Emission ("Emission", Color) = (0,0,0,1)

// ...

half3 _Emission;

// ...

o.Emission = _Emission;
```

![Emissive Material](/assets/images/posts/005/Emissive.png)

Apart from the fact that a object that glows everywhere looks kinda weird, we also only can assign normal colors to our material, not HDR colors with values over 1. To fix that, we add the hdr tag in front of the emission property. With those changes we can now set the brightness to higher values. To make better use of emission, you should probably use textures, you can implement other textures the same way we implemented the main texture we use for the albedo value.

```glsl
[HDR] _Emission ("Emission", Color) = (0,0,0,1)
```

![HDR Inspector](/assets/images/posts/005/HdrInspector.png)

## Minor Improvements

Finally I’m gonna show you two small things that make your shader look a bit better. Firstly you can add a fallback shader under the subshader. This allows unity to use functions of that other shader and we don’t have to implement them ourselves. For this we will set the standard shader as a fallback and unity will borrow the “shadow pass” from it, making our material throw shadows on other objects. Next we can extend our pragma directives. We add the fullforwardshadows parameter to the surface shader directive, that way we get better shadows. Also we add a directive setting the build target to 3.0, that means unity will use higher precision values that should lead to a bit prettier lighting.

```glsl
Shader "Tutorial/005_surface" {
	Properties {
		_Color ("Tint", Color) = (0, 0, 0, 1)
		_MainTex ("Texture", 2D) = "white" {}
		_Smoothness ("Smoothness", Range(0, 1)) = 0
		_Metallic ("Metalness", Range(0, 1)) = 0
		[HDR] _Emission ("Emission", color) = (0,0,0)
	}
	SubShader {
		Tags{ "RenderType"="Opaque" "Queue"="Geometry"}

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

![Result](/assets/images/posts/005/Result.png)

I hope I was able to show you how to make shaders with good looking lighting with simple tools.

You can find the source code here: <https://github.com/ronja-tutorials/ShaderTutorials/blob/master/Assets/005_Surface_Basics/simple_surface.shader>
