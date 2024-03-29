Shader "Custom/SingleStarShader"
{//Pseudo Random Number Generators and Voronoi Noise function created with the help of these tutorials: 
//https://www.ronja-tutorials.com/post/024-white-noise/
//https://www.ronja-tutorials.com/post/028-voronoi-noise/

/*
Voronoi noise is a method of partitioning space into a number of distinct regions. A voronoi noise diagram is constructed by starting from a set of points over some 
surface, known as seeds. For each point in space (or every pixel on our suface), the voronoi diagram identifies which seed it is closest to.
This process divides the surface into voronoi cells, where every location/pixel within a cell is closest to the seed that "owns" that cell than any other.
The borders of cells are equidistant between the two nearest seeds. The width of these borders can be controlled.
Voronoi noise is often used to create organic and natural textures, and I felt it could be leveraged to generate the patterns viewed across the surface of a star.
*/
    Properties
    {
        _MainTex ("Texture", 2D) = "white" {}
        _GridSize("Grid Size", Int) = 5
        _NumStarLayers("Num star layers", Int) = 5
        _CellSize("CellSize", Float) = 1.0
        _Colour("Colour", Color) = (1.0, 0.0, 0.0, 1.0)
        _BorderColour("BorderColour", Color) = (1.0, 0.2, 0.2, 1.0)
        _BorderWidth("BorderWidth", Float) = 0.1
        _StartFadeInDist("StartFadeInDist", Float) = 20.0
        _StartFadeOutDist("StartFadeOutDist", Float) = 5.0
        _FadeDist("FadeDist", Float) = 3.0
        _Fade("Fade", Range(0.0, 1.0)) = 0.5
    }
    SubShader
    {
        Tags { "RenderType"="Opaque" "RenderPipeline" = "UniversalPipeline"}
        LOD 100

        HLSLINCLUDE

        #pragma target 5.0
        #include "Assets/ActualProject/Voronoi.hlsl"
        #define PI 3.141519

        TEXTURE2D(_MainTex);
        SAMPLER(sampler_MainTex);
        uniform float _StartFadeInDist;
        uniform float _StartFadeOutDist;
        uniform float _FadeDist;
        uniform float3 playerPosition;

        uniform float3 centre;
        uniform float solarSystemSwitchDist;
        uniform float minDist;

        uniform float _CellSize;
        uniform float4 _Colour;
        uniform float4 _BorderColour;
        uniform float _BorderWidth;
        uniform float _Fade;

        ENDHLSL
        Pass
        {
            HLSLPROGRAM
            #pragma vertex vert
            #pragma fragment frag

            struct Attributes
            {
                float4 positionOS : POSITION;
                float3 normalOS : NORMAL;
                float2 uv : TEXCOORD0;
                uint id : SV_VERTEXID;
            };
            

            struct Interpolators
            {
                float2 uv : TEXCOORD0;
                float fade : TEXCOORD1;
                float4 positionHCS : SV_POSITION;
            };

            

            Interpolators vert (Attributes i)
            {
                
                Interpolators o;
                float noiseValue = pNoise(i.positionOS);
                float wobbleMagnitude = 0.1;
                float4 vertexPosOS = i.positionOS;
                vertexPosOS.xyz += i.normalOS * wobbleMagnitude * sin(_Time.y * noiseValue); 
                float3 worldPos = mul(unity_ObjectToWorld, vertexPosOS);
                o.fade = 0.0;
                float dist = distance(playerPosition, worldPos);
                if(dist > _StartFadeInDist)
                {
                    o.fade = 0.0;    
                }else if(dist < _StartFadeInDist && dist > _StartFadeInDist - _FadeDist)
                {
                    o.fade = lerp(0.0, 1.0, dist / (_StartFadeInDist - _FadeDist));    
                }else if(dist <= _StartFadeInDist - _FadeDist && dist > _StartFadeOutDist)
                {
                    o.fade = 1.0;    
                }else if(dist <= _StartFadeOutDist && dist > _StartFadeOutDist - _FadeDist)
                {
                    o.fade = lerp(1.0, 0.0, dist / (_StartFadeOutDist - _FadeDist)); 
                }else{
                    o.fade = 0.0;    
                }


                o.positionHCS = TransformObjectToHClip(vertexPosOS);
                o.uv = i.uv;
                return o;
            }

            float2x2 Rotate(float angle)
            {
                float s = sin(angle);
                float c = cos(angle);
                return float2x2(c, -s, s, c);
            }

            float4 frag (Interpolators i) : SV_Target
            {
                // sample the texture
                float4 baseTex = SAMPLE_TEXTURE2D(_MainTex, sampler_MainTex, i.uv);
                float dither = InterleavedGradientNoise(i.positionHCS, i.fade);
                clip(i.fade - dither);
                float pulsatingCellSize = _CellSize;

                /*Our voronoi noise function takes as input the uv coordinate of the current fragment, remapped from a range of (9, 1) to (-1, 1) in both the u and v dimensions.
                .This uv cooridnate determines thw location of the current seed on our texture.*/
                float2 p = i.uv * 2.0 - 1.0;
                float2 value = p / pulsatingCellSize;

                //Make cells move by having y be time dependent
                value.y += _Time.y;
                float3 voronoiVal = voronoiNoise(value, _BorderWidth);

                //fwidth(value) is the absolute value of the partial derivative of value; it measures how much value changes across the pixel's surface
	            float valueChange = length(fwidth(value)) * 0.5;
	            float isBorder = 1 - smoothstep(0.05 - valueChange, 0.05 + valueChange, voronoiVal.z); //smoothly interpolate between 0 and 1 as the distance to the border varies around 0.05
                return lerp(_Colour, _BorderColour, isBorder); //linearly interpolate between the border and cell colour based on the value of the parameter above.

            }
            ENDHLSL
        }
    }
}
