---
layout: post
title: "Baking Shaders into Textures"
image: /assets/images/posts/030/MagicEditor.png
hidden: false
---

Calculating everything ony the fly in the shader gives us the most flexibility and is even needed for many effects, but if we don't need the noise to be dynamic we can save it to a texture to save a lot of performance in the shader. You can bake all shader output into textures as long as it doesn't depend on external parameters like object position or lighting.

We're going to make a little editor tool in this tutorial that can be used to bake any shader output into a texture, but I'll work with noise functions for now, because they can be kinda expensive and are easily repeatable which allows us to use smaller textures. If you want to understand and also use noise functions, I have my tutorials about noise listed here: [ronja-tutorials.com/noise.html](/noise.html).

![](/assets/images/posts/030/MagicEditor.png)

## Simple Editor

For the editor we're going to make our own unity editor window. Editor windows are tabs similar to the scene or inspector tab. You'll be able to dock it anywhere or move it as it's own window. To create the window we create a new C# script. We'll put it in a folder called "Editor" or a subfolder of a editor folder. That way the script will not be included if we export our game, but will allow us to access some functions that are only for the unity editor and not games.

First we let the script inherit from the `EditorWindow` class, that will allow us to expand it to make our own window. To have access to that class, we'll import the `UnityEditor` namespace. Then we add a a function to open a new window. We'll mark it with the `static` keyword, that way it can be called even when no window is open currently. In the function we'll call `EditorWindow.GetWindow`. It's a function that will create a new window if none exists or returns a old one if we created one earlier. We'll have to specify what kind of window we want to create though. This is a generic function, so we can put the type in angle brackets between the function name and the round brackets we use for the arguments. This then looks like this: `EditorWindow.GetWindow<YourWindowClass>()`. We then save the return value of the GetWindow function in a variable and call the `Show` method so show the window to the user. To be able to open the window in the Editor, we'll simply add the `MenuItem` attribute to the function, it will add a item to the menu at the top of the menu which will call this function when we click it, it takes the name of the item as a parameter, slashes allow us to put the item in directories.

```cs
using UnityEditor;

public class BakeTextureWindow : EditorWindow {
    [MenuItem ("Tools/Bake material to texture")]
    static void OpenWindow() {
        //create window
        BakeTextureWindow window = EditorWindow.GetWindow<BakeTextureWindow>();
        window.Show();
    }
}
```
![](/assets/images/posts/030/MenuItem.png)

![](/assets/images/posts/030/EmptyEditor.png)

As you can see the editor is completely empty so far, so the next step is to add variables to edit. We want to know which material we want to bake into a texture, how big the texture is and what file we want to save the texture to. We add those variables at the top of our class. The material to bake is a normal material, the image size can be summarized as a 2 dimensional integer vector and the file path is a normal string. We'll also have to declare that we're using the `UnityEngine` namespace to have access to the material and vector classes.

```cs
Material ImageMaterial;
string FilePath = "Assets/MaterialImage.png";
Vector2Int Resolution;
```

This doesn't show the variables to the user though. To display them we have to write our own user interface. To do that we simply create a function called `OnGUI`. It will be called automatically by unity whenever the GUI refreshes. The field for the material basically holds a reference to the material object in our files, so we use `EditorGUILayout.ObjectField`. The first parameter of the ObjectField function is the name we want to display for the field, the second is the value the material has right now, the third is the type of the object (in our case it's a material) and the third parameter is wether we allow users to add objects from the scene to the field, because materials can't exist on their own in the scene we'll just deny that. The ObjectField function will then return the new value as a Object, so to put the new value into our material variable we'll have to cast it to a material.

The second parameter is our resolution. Luckily there is the `EditorGUILayout.Vector2IntField` function, so we can just pass the display name of the variable as the first parameter and the current value as the second. We then directly apply the return value to the resolution again. Similarly for the file path, we'll use a `EditorGUILayout.TextField` for now with the display name and the current value as arguments just like previously.

Now we can already enter all of the values we need to bake a texture, but we can't trigger the texture baking yet. To trigger the baking, we'll add a button. We add buttons in GUI by calling `GUILayout.Button`. We can give it a string as a argument and it'll use it as a label. The function then returns a boolean which is true in the one frame that a user clicks it, so we can directly use the function as the value for a if condition.

```cs
void OnGUI() {
    ImageMaterial = (Material)EditorGUILayout.ObjectField("Material", ImageMaterial, typeof(Material), false);
    Resolution = EditorGUILayout.Vector2IntField("Image Resolution", Resolution);
    FilePath = EditorGUILayout.TextField("Image Path", FilePath);

    if(GUILayout.Button("Bake")){
        //bake texture
    }
}
```

![](/assets/images/posts/030/VariablesEditor.png)

## 2D Texture Baking

Now that we have a editor, we can implement the baking logic. For easier code management, we'll write the baking logic into it's own function which we'll call when the bake button is pressed.

```cs
if(GUILayout.Button("Bake")){
    BakeTexture();
}
```

```cs
void BakeTexture(){
    // Bake texture
}
```

Similarly as in postprocessing, we'll deal with images via rendertextures here. Because we only need the rendertexture for a short time, we can use a temporary rendertexture which is more convenient and faster than creating a new one. We get the rendertexture by calling `RenderTexture.GetTemporary` and pass the resolution x and y components as the width and height of the rendertexture. After fetching the rendertexture we can then write to it with `Graphics.Blit`. The blit function expects us to give it a input as well as a output texture, but because we'll take all of our data directly from our material we pass `null` as the first parameter. The second parameter is the output texture, so we pass it the new rendertexture we just got. The last parameter is the material we use, so that's the material we set in the inspector.

```cs
//render material to rendertexture
RenderTexture renderTexture = RenderTexture.GetTemporary(Resolution.x, Resolution.y);
Graphics.Blit(null, renderTexture, ImageMaterial);
```

Now, that we have the output of the shader, the next step is to save it to a texture2d to be able to save it. First we create a new texture2d with the size of the resolution. Then we set the rendertexture with our shader output as the active rendertexture, that way it is written to the texture when we call `ReadPixels` on the texture variable. The `ReadPixels` function wants to know which area of the rendertexture we want to copy, so to copy the whole area, we give it a rectangle that starts in the `(0, 0)` corner and has the size of the whole resolution. As the position of where to insert the texture, we also tell it to start in the `(0, 0)` corner. This way the function will copy the whole rendertexture to the texture.

```cs
//transfer image from rendertexture to texture
Texture2D texture = new Texture2D(Resolution.x, Resolution.y);
RenderTexture.active = renderTexture;
texture.ReadPixels(new Rect(Vector2.zero, Resolution), 0, 0);
```

Now we have the image in a texture we can save it as a png. First we encode into png and save the bytes. Then we write the bytes to the path we declared. As a last step we tell unity to refresh it's asset database, this way we make sure it will find the new file and show it to us in the editor. Writing the bytes to a file means we'll have to declare that we're using the `System.IO` namespace, where most C# file input and output classes are located.

```cs
//save texture to file
byte[] png = texture.EncodeToPNG();
File.WriteAllBytes(ImageFile, png);
AssetDatabase.Refresh();
```

At the end of the function we should clean up our variables. We release the rendertexture to be reused by other functions. We'll also set the active rendertexture to null, this shouldn't be nessecary, but it can avoid unexpected behaviour, so we do it just in case. And then we also destroy the texture so it doesn't take up any ram anymore, we have it saved on the harddrive now so we don't need it here anymore. We use DestroyImmediate here because we're running the script while the game is not running and Destroy only works when the game is running.

```cs
//clean up variables
RenderTexture.active = null;
RenderTexture.ReleaseTemporary(renderTexture);
DestroyImmediate(texture);
```

And with this function we have everything we need to bake the output of a shader to a texture. We can then use those textures just like we use all other textures.

![](/assets/images/posts/030/SimpleEditorFilled.png)

![](/assets/images/posts/030/BakedPerlin.png)

## Better Editor

Our editor is functional, but it breaks easily if you enter the wrong input, could be better explained and especially entering the path is unnessecarily compicated, so let's improve that.

First we're going to add a function that checks what variables are entered. We'll declare boolean variables in the class so we can access which inputs are valid from everywhere. The material counts as entered when it's not null, the resolution counts as valid if both components are above 0 and the file path counts as entered if it points to a png file. The first two are pretty easily checked, for the last one we'll use the utility of the `Path` class. `Path.GetExtension` returns the extension of a path, so we can easily check if that extension is `.png`. But if we give the GetExtension function a invalid path it'll throw a exception which can crash our script. To avoid the exception crashing our script we first set the boolean which saves wether we have a valid file path to false and then check the extension in a try/catch block. That way if the function returns a exception it will just not touch the variable and it'll stay false, which is the value we want it to have for invalid paths. To be able to access the ArgumentException which is the exception type GetExtension can throw we'll also have to declare that we're using the System namespace.

```cs
bool hasMaterial;
bool hasResolution;
bool hasImageFile;
```
```cs
void CheckInput(){
    //check which values are entered already
    hasMaterial = ImageMaterial != null;
    hasResolution = Resolution.x > 0 && Resolution.y > 0;
    hasImageFile = false;
    try{
        string ext = Path.GetExtension(ImageFile);
        hasImageFile = ext.Equals(".png");
    } catch(ArgumentException){}
}
```

Now that we have this function, we should call it to update the variables in 2 situations. When we open a new window and when one of the variables changes. The first one is pretty easy, we just call it on the new window in our static function where we create a new window.

```cs
[MenuItem ("Tools/Bake material to texture")]
static void OpenWindow() {
    //create window
    BakeTextureWindow window = EditorWindow.GetWindow<BakeTextureWindow>();
    window.Show();

    window.CheckInput();
}
```

For the other situation we have to create a change check scope around the variable fields. We can do that either by using `EditorGUI.BeginChangeCheck` and `EditorGUI.EndChangeCheck` or we can use a `ChangeCheckScope` inside of a using block. I personally prefer the second solution, so we'll do that. We write a using block around the variable fields, saving a new `ChangeCheckScope` at it's beginning. Then, after the fields are drawn, we can access it's `changed` property to see wether one of the variables was edited. If it was, we call `CheckInput`.

```cs
void OnGUI(){
    using(var check = new EditorGUI.ChangeCheckScope()){
        ImageMaterial = (Material)EditorGUILayout.ObjectField("Material", ImageMaterial, typeof(Material), false);
        Resolution = EditorGUILayout.Vector2IntField("Image Resolution", Resolution);
        FilePath = EditorGUILayout.TextField("Image Path", FilePath);

        if(check.changed){
            CheckInput();
        }
    }

    if(GUILayout.Button("Bake")){
        BakeTexture();
    }
}
```

Now we always know which input is valid and can work with that information. The first thing we do is to only enable the bake button if all inputs are valid. We toggle wether the button is interactable or not by setting `GUI.enabled` before drawing it. After we've drawn the button we'll set `GUI.enabled` back to true so we don't mess with other interfaces.

```cs
GUI.enabled = hasMaterial && hasResolution && hasFilePath;
if(GUILayout.Button("Bake")){
    BakeTexture();
}
GUI.enabled = true;
```

Then we can also show warnings to the user if specific inputs are not set yet, so they know what's missing. I'll use the `EditorGUILayout.HelpBox` function for this feedback, but there are also other ways, like labels that are less intrusive. We can also set how the helpbox should look like. I use the `MessagyType.Warning` version so we get a obvious yellow triangle showing the user that something is missing.

Put the code for the help boxes where you want to see them in the UI, I put mine at the very bottom under the bake button.

```cs
//tell the user what inputs are missing
if(!hasMaterial){
    EditorGUILayout.HelpBox("You're still missing a material to bake.", MessageType.Warning);
}
if(!hasResolution){
    EditorGUILayout.HelpBox("Please set a size bigger than zero.", MessageType.Warning);
}
if(!hasFilePath){
    EditorGUILayout.HelpBox("No file to save the image to given.", MessageType.Warning);
}
```

Similarly I put a helpbox at the top of the `OnGUI` function to roughly explain how the interface works.

```cs
EditorGUILayout.HelpBox("Set the material you want to bake as well as the size "+
        "and location of the texture you want to bake to, then press the \"Bake\" button.", MessageType.None);
```

For the last improvement to the editor we're going to improve how choosing the file path works. For this we'll add another method for drawing a textfield with a choose file button. This new function will take the current value of the path as a argument and will return the new path value. We'll start our custom field by displaying a labelfield with the display name of the path. A labelfield will simply display the text you pass it, not allowing the user to edit anything. I give the labelfield it's own line by doing this, and put the rest of the path field another line because the path can get pretty long.

Then we'll start a horizontal scope. This will change the gui so everything in this scope will be drawn next to each other from left to right instead of under each other. Just like the changecheck field we can either use `BeginHorizontal` and `EndHorizontal` in `EditorGUILayout` or we can use a `HorizontalScope`. I'll also use the second solution here, but you're free to do whatever feels right to you.

Inside the horizonal scope, we'll display two fields, one the textfield we already used previously, but this time we'll only pass it one parameter, this way it just displays a text, without a name in front of it. Second, we display a button to choose a file. 

If we press the button we first need to find out the current directory and file name of the path, but similarly to where we're checking the extension we have to expect having a invalid path. So we set a directory and a file name of our choice as default values and then try to overwrite them with the correct values from the path we get from `Path.GetDirectoryName` and `Path.GetFileName`. If they fail, they'll throw a `ArgumentException` which we'll catch and then completely ignore because we know the default values are still in the variables so we can use them. After we have those values, we can call `EditorUtility.SaveFilePanelInProject` to find a place for our image file. The first argument of the function is the panel header, the second is the file name where to start, the third is the file extension, the fourth is a more detailed description of what we want to file for, as far as I've seen it's not visible when opening the dialogue in windows, but I think it's visible on macOS systems? And the final argument we'll use is the directory where to put the file. We will save the output of this panel in a new string because if we close the panel instead of pressing save, it will return a empty string. Then we check if the string is empty and if isn't we then apply the new path to our path variable. After chosing the path, we'll also manually trigger a redraw of the whole window to update the textfield which doesn't know theres a new value for the image path yet.

At the end of this custom field function we'll simply return the new path. With this new function we can replace the textfield as a means to get the file path and now have a easier way of choosing a file to write to.

```cs
string FileField(string path){
    //allow the user to enter output file both as text or via file browser
    EditorGUILayout.LabelField("Output file");
    using(new GUILayout.HorizontalScope()){
        path = EditorGUILayout.TextField(path);
        if(GUILayout.Button("choose")){
            //set default values for directory, then try to override them with values of existing path
            string directory = "Assets";
            string fileName = "MaterialImage.png";
            try{
                directory = Path.GetDirectoryName(path);
                fileName = Path.GetFileName(path);
            } catch(ArgumentException){}
            string chosenFile = EditorUtility.SaveFilePanelInProject("Choose image file", fileName, 
                    "png", "Please enter a file name to save the image to", directory);
            if(!string.IsNullOrEmpty(chosenFile)){
                path = chosenFile;
            }
            //repaint editor because the file changed and we can't set it in the textfield retroactively
            Repaint();
        }
    }
    return path;
}
```
```cs
FilePath = FileField(FilePath);
```

![](/assets/images/posts/030/EditorWithFileChooser.png)

## 3D Texture Baking

We can get even more flexibility out of our textures by baking them into a volumetric 3d texture. There is no texture format for 3d textures, but we can use unity's internal Texture3D format and save that as a asset. Theres also no easy way I know of to output a 3d volume out of a shader without using compute shaders, something I don't want to get into here. My solution for this is to render different "slices" of the 3d texture, one 2d image at a time and then manually feed them into the 3d texture. To get the different slices out of a shader, I'll add a height property to the shader which we can change between rendering slices.

For the 3d texture baking we'll start with the 2d version of the texture baking tools, rename the class and menuitem so it doesn't clash with the 2d version and change the resolution. We change the resolution to a `Vector3Int`, change it's gui field to a `Vector3IntField` and make sure the z coordinate is also above 0 in the `CheckInput` method. We'll also save the 3d texture as a unity asset instead of a texture, so we'll change all occurances of `png` to `asset`. After that we'll just have to rewrite the `BakeTexture` function. 

Because we'll be rendering several times, we'll create our texture variable right at the beginning with the rendertexture. We'll also create a 2d texture together with our 2d texture, that's so we can use it to access the data of the rendertexture. The 3d texture has to have a textureformat. I use ARGB32, which means it has 32 bit color depth, or 8 bit per channel which gives us 256 different color values per channel. It also wants to know wether we want to generate mipmaps. I've declined that here, because 3d textures can become pretty big without mipmaps and just become bigger when we enable them(if you make a 128x128x128 px 3d texture, that's the about as big as 128 128x128 2d textures).

```cs
void BakeTexture(){
    //get rendertexture to render layers to and texture3d to save values to as well as 2d texture for transferring data
    RenderTexture renderTexture = RenderTexture.GetTemporary(Resolution.x, Resolution.y);
    Texture3D volumeTexture = new Texture3D(Resolution.x, Resolution.y, Resolution.z, TextureFormat.ARGB32, false);
    Texture2D tempTexture = new Texture2D(Resolution.x, Resolution.y);

    //TODO: loop through slices and write them to 3d texture

    //TODO: save 3d texture
}
```

Before we start the loop we calculate how many voxels the 3d texture has by multiplying the width, height and depth and how many pixels a single slice has by just multiplying the width and height. We then create a array of colors the size of the voxel amount of the texture so we can slowly fill it. We'll use the `Color32` because `Texture2D` as well as `Texture3D` use it internally, so it's a bit faster. We'll also set the rendertexture we have as the active rendertexture so we don't have to do that every iteration of the loop.

```cs
RenderTexture.active = renderTexture;
int voxelAmount = Resolution.x * Resolution.y * Resolution.z;
int slicePixelAmount = Resolution.x * Resolution.y;
Color32[] colors = new Color32[voxelAmount];
```

Then we loop through the slices. We have as many slices as we have resolution in the z axis, so we loop that amount of times. We start the loop calculating the height of the slice. We do that by adding 0.5 to the slice index and dividing it my the depth of the resolution. The 0.5 is so we always hit the middle of the voxels, so a 2 voxel tall texture would have the voxel midpoints at 0.25 and 0.75 instead of 0 and 0.5 which would be edges of the voxels. After we have that value, we can apply it to our material. I'll use the repeating 3d voronoi noise in the material, so the height property is called `_Height`, but you can use a different name or even expose the height property name to the inspector if you want to use different names for the variable in different shaders.

After that we get the slice by just calling the blit function and letting it write to the rendertexture. Then we copy the content of the rendertexture to out temporary texture. The size of the area we copy is the width and height of the volumetric texture. After we have the data in a texture we can retrieve the colors of the texture. Then we calculate the start of the indices of this slice. We get that by simply multiplying the index of the current slice by the amount of pixels in a slice. Then we loop though all pixels in the current slice and copy them into the array of colors for the 3d texture. The index in the target array is the baseIndex of the slice plus the index of the pixel in the slice texture.

```cs
for(int slice=0; slice<Resolution.z; slice++){
    float height = (slice + 0.5f) / Resolution.z;
    ImageMaterial.SetFloat("_Height", height);

    Graphics.Blit(null, renderTexture, ImageMaterial);
    tempTexture.ReadPixels(new Rect(0, 0, Resolution.x, Resolution.y), 0, 0);
    Color32[] sliceColors = tempTexture.GetPixels32();

    int sliceBaseIndex = slice * slicePixelAmount;
    for(int pixel=0; pixel<slicePixelAmount; pixel++){
        colors[sliceBaseIndex + pixel] = sliceColors[pixel];
    }
}
```

After the loop we put the pixels into the 3d texture via the `SetPixels32` function. After we did that we save the texture to a file by calling the `AssetDatabase.CreateAsset` function. We pass it the 3d texture as a first parameter and the path as a second.

```cs
//apply and save 3d texture
volumeTexture.SetPixels32(colors);
AssetDatabase.CreateAsset(volumeTexture, FilePath);
```

At the end we clean up by destroying the textures and releasing the rendertexture.
```cs
//clean up variables
RenderTexture.active = null;
RenderTexture.ReleaseTemporary(renderTexture);
DestroyImmediate(volumeTexture);
DestroyImmediate(tempTexture);
```

![](/assets/images/posts/030/3dTex.png)

## Use 3d textures

So far we've always used 2d textures in our shaders, but using 3d textures isn't much more difficult. We change the property from `2D` to `3D`, change the sampler to a `sampler3D` and read pixels from it with the `tex3D` instead of `tex2D` function which takes a 3d vector as a input. I'll show you a little example shader which takes a height variable from outside, but you can just as well use a position or any other 3d vector. The main downside I see of 3d textures against 2d ones is that the scaling and offset of the UVs only works for 2 dimensions, so we can't do everything with the transforms next to the texture that we can do with them for 2d textures.

```glsl
Properties{
    _Height("Height", Range(0, 1)) = 0
    _Color ("Tint", Color) = (0, 0, 0, 1)
    _MainTex ("Texture", 3D) = "white" {}
}
```

```glsl
//texture and transforms of the texture
sampler3D _MainTex;
float4 _MainTex_ST;

float _Height;
```

```glsl
//the fragment shader
fixed4 frag(v2f i) : SV_TARGET{
    fixed4 col = tex3D(_MainTex, float3(i.uv, _Height));
    col *= _Color;
    return col;
}
```

![](/assets/images/posts/030/StepThrough3dTex.gif)

## Source

### Bake Texture Window
- <https://github.com/ronja-tutorials/ShaderTutorials/blob/master/Assets/030_Bake_Material/Editor/BakeTextureWindow.cs>

```cs
using UnityEngine;
using UnityEditor;
using System.IO;
using System;

public class BakeTextureWindow : EditorWindow {

    Material ImageMaterial;
    string FilePath = "Assets/MaterialImage.png";
    Vector2Int Resolution;

    bool hasMaterial;
    bool hasResolution;
    bool hasFilePath;

    [MenuItem ("Tools/Bake material to texture")]
    static void OpenWindow() {
        //create window
        BakeTextureWindow window = EditorWindow.GetWindow<BakeTextureWindow>();
        window.Show();

        window.CheckInput();
    }

    void OnGUI(){
        EditorGUILayout.HelpBox("Set the material you want to bake as well as the size "+
                "and location of the texture you want to bake to, then press the \"Bake\" button.", MessageType.None);

        using(var check = new EditorGUI.ChangeCheckScope()){
            ImageMaterial = (Material)EditorGUILayout.ObjectField("Material", ImageMaterial, typeof(Material), false);
            Resolution = EditorGUILayout.Vector2IntField("Image Resolution", Resolution);
            FilePath = FileField(FilePath);

            if(check.changed){
                CheckInput();
            }
        }

        GUI.enabled = hasMaterial && hasResolution && hasFilePath;
        if(GUILayout.Button("Bake")){
            BakeTexture();
        }
        GUI.enabled = true;

        //tell the user what inputs are missing
        if(!hasMaterial){
            EditorGUILayout.HelpBox("You're still missing a material to bake.", MessageType.Warning);
        }
        if(!hasResolution){
            EditorGUILayout.HelpBox("Please set a size bigger than zero.", MessageType.Warning);
        }
        if(!hasFilePath){
            EditorGUILayout.HelpBox("No file to save the image to given.", MessageType.Warning);
        }
    }

    void CheckInput(){
        //check which values are entered already
        hasMaterial = ImageMaterial != null;
        hasResolution = Resolution.x > 0 && Resolution.y > 0;
        hasFilePath = false;
        try{
            string ext = Path.GetExtension(FilePath);
            hasFilePath = ext.Equals(".png");
        } catch(ArgumentException){}
    }

    string FileField(string path){
        //allow the user to enter output file both as text or via file browser
        EditorGUILayout.LabelField("Image Path");
        using(new GUILayout.HorizontalScope()){
            path = EditorGUILayout.TextField(path);
            if(GUILayout.Button("choose")){
                //set default values for directory, then try to override them with values of existing path
                string directory = "Assets";
                string fileName = "MaterialImage.png";
                try{
                    directory = Path.GetDirectoryName(path);
                    fileName = Path.GetFileName(path);
                } catch(ArgumentException){}
                string chosenFile = EditorUtility.SaveFilePanelInProject("Choose image file", fileName, 
                        "png", "Please enter a file name to save the image to", directory);
                if(!string.IsNullOrEmpty(chosenFile)){
                    path = chosenFile;
                }
                //repaint editor because the file changed and we can't set it in the textfield retroactively
                Repaint();
            }
        }
        return path;
    }

    void BakeTexture(){
        //render material to rendertexture
        RenderTexture renderTexture = RenderTexture.GetTemporary(Resolution.x, Resolution.y);
        Graphics.Blit(null, renderTexture, ImageMaterial);

        //transfer image from rendertexture to texture
        Texture2D texture = new Texture2D(Resolution.x, Resolution.y);
        RenderTexture.active = renderTexture;
        texture.ReadPixels(new Rect(Vector2.zero, Resolution), 0, 0);

        //save texture to file
        byte[] png = texture.EncodeToPNG();
        File.WriteAllBytes(FilePath, png);
        AssetDatabase.Refresh();

        //clean up variables
        RenderTexture.active = null;
        RenderTexture.ReleaseTemporary(renderTexture);
        DestroyImmediate(texture);
    }
}
```

### Bake Texture3d Window
- <https://github.com/ronja-tutorials/ShaderTutorials/blob/master/Assets/030_Bake_Material/Editor/BakeTexture3dWindow.cs>

```cs
using UnityEngine;
using UnityEditor;
using System.IO;
using System;

public class BakeTexture3dWindow : EditorWindow {

    Material ImageMaterial;
    string FilePath = "Assets/MaterialImage.asset";
    Vector3Int Resolution;

    bool hasMaterial;
    bool hasResolution;
    bool hasFilePath;

    [MenuItem ("Tools/Bake material to 3d texture")]
    static void OpenWindow() {
        //create window
        BakeTexture3dWindow window = EditorWindow.GetWindow<BakeTexture3dWindow>();
        window.Show();

        window.CheckInput();
    }

    void OnGUI(){
        EditorGUILayout.HelpBox("Set the material you want to bake as well as the size "+
                "and location of the texture you want to bake to, then press the \"Bake\" button.", MessageType.None);

        using(var check = new EditorGUI.ChangeCheckScope()){
            ImageMaterial = (Material)EditorGUILayout.ObjectField("Material", ImageMaterial, typeof(Material), false);
            Resolution = EditorGUILayout.Vector3IntField("Image Resolution", Resolution);
            FilePath = FileField(FilePath);

            if(check.changed){
                CheckInput();
            }
        }

        GUI.enabled = hasMaterial && hasResolution && hasFilePath;
        if(GUILayout.Button("Bake")){
            BakeTexture();
        }
        GUI.enabled = true;

        //tell the user what inputs are missing
        if(!hasMaterial){
            EditorGUILayout.HelpBox("You're still missing a material to bake.", MessageType.Warning);
        }
        if(!hasResolution){
            EditorGUILayout.HelpBox("Please set a size bigger than zero.", MessageType.Warning);
        }
        if(!hasFilePath){
            EditorGUILayout.HelpBox("No file to save the image to given.", MessageType.Warning);
        }
    }

    void CheckInput(){
        //check which values are entered already
        hasMaterial = ImageMaterial != null;
        hasResolution = Resolution.x > 0 && Resolution.y > 0 && Resolution.z > 0;
        hasFilePath = false;
        try{
            string ext = Path.GetExtension(FilePath);
            hasFilePath = ext.Equals(".asset");
        } catch(ArgumentException){}
    }

    string FileField(string path){
        //allow the user to enter output file both as text or via file browser
        EditorGUILayout.LabelField("Image Path");
        using(new GUILayout.HorizontalScope()){
            path = EditorGUILayout.TextField(path);
            if(GUILayout.Button("choose")){
                //set default values for directory, then try to override them with values of existing path
                string directory = "Assets";
                string fileName = "MaterialImage.asset";
                try{
                    directory = Path.GetDirectoryName(path);
                    fileName = Path.GetFileName(path);
                } catch(ArgumentException){}
                string chosenFile = EditorUtility.SaveFilePanelInProject("Choose image file", fileName, 
                        "asset", "Please enter a file name to save the image to", directory);
                if(!string.IsNullOrEmpty(chosenFile)){
                    path = chosenFile;
                }
                //repaint editor because the file changed and we can't set it in the textfield retroactively
                Repaint();
            }
        }
        return path;
    }

    void BakeTexture(){
        //get rendertexture to render layers to and texture3d to save values to as well as 2d texture for transferring data
        RenderTexture renderTexture = RenderTexture.GetTemporary(Resolution.x, Resolution.y);
        Texture3D volumeTexture = new Texture3D(Resolution.x, Resolution.y, Resolution.z, TextureFormat.ARGB32, false);
        Texture2D tempTexture = new Texture2D(Resolution.x, Resolution.y);

        //prepare for loop
        RenderTexture.active = renderTexture;
        int voxelAmount = Resolution.x * Resolution.y * Resolution.z;
        int slicePixelAmount = Resolution.x * Resolution.y;
        Color32[] colors = new Color32[voxelAmount];

        //loop through slices
        for(int slice=0; slice<Resolution.z; slice++){
            //set z coodinate in shader
            float height = (slice + 0.5f) / Resolution.z;
            ImageMaterial.SetFloat("_Height", height);

            //get shader result
            Graphics.Blit(null, renderTexture, ImageMaterial);
            tempTexture.ReadPixels(new Rect(0, 0, Resolution.x, Resolution.y), 0, 0);
            Color32[] sliceColors = tempTexture.GetPixels32();

            //copy slice to data for 3d texture
            int sliceBaseIndex = slice * slicePixelAmount;
            for(int pixel=0; pixel<slicePixelAmount; pixel++){
                colors[sliceBaseIndex + pixel] = sliceColors[pixel];
            }
        }

        //apply and save 3d texture
        volumeTexture.SetPixels32(colors);
        AssetDatabase.CreateAsset(volumeTexture, FilePath);

        //clean up variables
        RenderTexture.active = null;
        RenderTexture.ReleaseTemporary(renderTexture);
        DestroyImmediate(volumeTexture);
        DestroyImmediate(tempTexture);
    }
}
```

### Read from 3d Texture
- <https://github.com/ronja-tutorials/ShaderTutorials/blob/master/Assets/030_Bake_Material/Read3dTexture.shader>

```glsl
Shader "Tutorial/030_BakeTextures/Read3dTexture"
{
	//show values to edit in inspector
	Properties{
        _Height("Height", Range(0, 1)) = 0
		_Color ("Tint", Color) = (0, 0, 0, 1)
		_MainTex ("Texture", 3D) = "white" {}
	}

	SubShader{
		//the material is completely non-transparent and is rendered at the same time as the other opaque geometry
		Tags{ "RenderType"="Opaque" "Queue"="Geometry"}

		Pass{
			CGPROGRAM

			//include useful shader functions
			#include "UnityCG.cginc"

			//define vertex and fragment shader
			#pragma vertex vert
			#pragma fragment frag

			//texture and transforms of the texture
			sampler3D _MainTex;
			float4 _MainTex_ST;

			//tint of the texture
			fixed4 _Color;

            float _Height;

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
				o.uv = TRANSFORM_TEX(v.uv, _MainTex);
				return o;
			}

			//the fragment shader
			fixed4 frag(v2f i) : SV_TARGET{
				fixed4 col = tex3D(_MainTex, float3(i.uv, _Height));
				col *= _Color;
				return col;
			}

			ENDCG
		}
	}
}
```

I hope this tool will be as useful to you as it is to me in helpling you create textures to reuse and make shaders that are way cheaper to calculate than they would be with procedural noise.