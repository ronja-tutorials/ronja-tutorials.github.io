---
layout: post
title: "HLSL Basics"
---

## Summary
Unity Shaders are written in a custom environment called "Shaderlab". With it we can customize a lot about how the material that will use our shader will be used internally. Inside of the shaderlab file we will also declare most of the logic of the shader in HLSL. Because Shaderlab is just a way to set some parameters in the material it's pretty easy to learn how to set which parameter when we need it. HLSL is a bit more complex though so I'll explain some of it's basics here. Even though I try to explain everything in this tutorials, I sadly can't explain every basic programming principle so I recommend you learn a different programming language before coming back to shaders.

Because this is the first tutorial in this series I tried to make it as simple as possible, if I failed to do that and assumed that you know things about shaders that you don't, please contact me. In that case I'll fix the tutorial to be more approachable. If the information in this tutorial is clear, but you have difficulties grasping the concepts because it's all a bit theoretical, feel free to jump to the next tutorials where we will use the concepts in praxis which might make things clearer.

## Variables
HLSL is a statically typed language, that means that each variable has a specific data type which has to be explicitely stated and can’t change. I'll quickly go some of the types here, if you want more information you can look at this page of the unity documentation: <https://docs.unity3d.com/Manual/SL-DataTypesAndPrecision.html>

### Scalar Types
The simplest variable types are scalar numbers, they have a single numeric value. There are multiple Types of scalar numbers in HLSL. Choosing a lower precision value can improve the performance of your shaders, but modern graphics cards are pretty fast so the differences will be small. I use floats often in my shaders where half or fixed variables would be enough so use your own judgement and don't overthink it.

- Integer numbers have no fractional part. Because we will mostly manipulate numbers and positions, integer numbers are much less common in graphic programming and especially shaders than numbers with fractional parts, but they're still oten useful, for example as indices when we're working with arrays.
- Fixed point numbers are the lowest precision numbers in unity shaders. They can hold values from -2 to +2 and always have 265 steps between whole values. They are great for colors, because colors are also often only stored in 256 steps per color channel.
- Half precision numbers can have pretty much any value, but they loose precision the further away the value is from 0. Half precision values are great for storing colors that need more range/precision (if we render HDR colors, we should use half) or to store short vectors like normals.
- Floating point numbers technically have double the precision of half numbers, that means they are more accurate, especially for high numbers. They are usually used to store positions.

```glsl
int integer = 3; //number without fractional component
fixed fixed_point = 0.5; //fixed point number between -2 and 2
half low_precision = 3.14; //low precision number
float high_precision = 14.321; //high precision number
```

### Vector Types
Then there are vector values based on the scalar ones. With vector values we can represent things like colors, positions and directions that have multiple values in a variable. To declare them in HLSL we just write the number of dimensions we need at the end of the type, so we get types like float2, int3, half4 etc.. (Note that the maximum here is 4 dimensions, for more you have to use arrays, we won’t get into how to use them here) You can access the different components of vectors via x y z and w or r g b a. The first set is meant to represent the dimensions of vectors and the second set is meant to represent the red, green, blue and alpha channels of a color, but we can use them interchangably. We can also use more than one of the components to rearrange the components, that's called swizzling.

```glsl
fixed4 color = fixed4(1, 0.67, 0.73, 1);
float3 position = float3(1, 1, 0);
float2 textureCoordinates = float2(0.5, 0.5);

position.xy = position.yx; //switch the first two components of position vector
```

### Matrix Types
Also there are the matrix types which are basically a vector of vectors. They are often used to rotate, move and scale vectors in specific ways my multiplying a vector with a matrix. You can create matrices by writing [dimension 1]x[dimension 2] behind a scalar type. In 3d graphics, we need a 3x3 matrix to rotate and scale a vector or a 4x4 matrix to also move it.

```glsl
float4x4 transformMatrix3d; //a matrix that can scale rotate and translate a 3d vector
//a matrix that can scale and rotate a 2d vector, but not translate it
float2x2 rotationMatrix2d = {
    0, 1,
    -1, 0
};

//when doing matrix multiplication we have to use 4d vectors, 
//the 4th component is just used to make moving the vector via matrix multiplication possible
float4 position;

//we rotate, scale and translate a position my multiplying a vector with it 
//(the order of factors is important here)
position = transformMatrix3d * position;
```

### Samplers
There are also samplers which are used to read from textures. When reading from samplers the texture has coordinates from [0,0] to [1,1], 0,0 being the lower left corner and 1,1 being the upper right corner of the texture.

```glsl
sampler2d texture; //we will mostly use 2d textures, but it's possible to feed 3d samplers to a shader.

//we will mostly read from samplers via the tex2d function 
//which takes the position to sample from as a second argument.
float4 color = tex2D(texture, coordinates);
```

### Structs
Finally there are structs, custom datatypes which can hold several other datatypes. We can represent lights, input data and other complex data with structs. To use a struct we first have to define it, then we can use it somewhere else.

```glsl
//define the struct
struct InputData{
    float4 position;
    fixed4 color;
    half4 normal;
};

//create a instance and use the struct
InputData data;
data.position = float4(1, 0, 0, 1);
```

## Functions
While we can define variables outside of functions to give information to the shader, we can only run logical operations in functions. Some functions will be called automatically and will return values that will manipulate the way we handle vertices or draw colors. But we can also call functions ourselves and use the values they return. We write the variable type that is returned by the function in front of the name, the return type can also be void, which means that the function doesn’t return a value. Behind the function name we put the arguments, which is data the function recieves. And in the function we return the value which is then given to the function which called this function.

```glsl
float add(float arg1, float arg2){
    float sum = arg1 + arg2;
    return sum;
}

float function(){
    return add(3.5, 0.7);
}
```

## Include files
You can write code in one file and then include it into others. It works as if the content of the included file was in the file that’s including it at the place the include command stands. All shader files, including include files can include other files. Include files are mostly used as libraries or to split long shaders into multiple files.
```glsl
#include “IncludeFile.cginc”

void function(){
    functionDeclaredInIncludeFile(3, variableInIncludeFile);
}
```