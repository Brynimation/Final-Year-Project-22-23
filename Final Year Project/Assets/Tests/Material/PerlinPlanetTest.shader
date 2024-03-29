Shader "Custom/PerlinPlanetShader"
{
/*
struct PlanetTerrainProperties
{
    float roughness;
    float baseRoughness;
    float persistence;
    float minVal;
    float noiseStrength;
    float3 noiseCentre;
    int octaves;
};

*/
    Properties
    {
        _MainTex ("Texture", 2D) = "white" {}
        _Roughness("Roughness", Float) = 1.0
        _BaseRoughness("Base Roughness", Float) = 1.0
        _Persistence("Persistence", Float) = 1.0
        _MinVal("Min Val", Float) = 1.0
        _NoiseStrength("Noise Strength", Float) = 1.0 
        _NoiseCentre("Noise Centre", vector) = (0.0, 0.0, 0.0)
        _Octaves("Octaves", int) = 1
        _Testing("Testing", int) = 0
        _Smoothness("Smoothness", Float) = 0.5
        _SpecularColour("Specular Colour", Color) = (1.0, 1.0, 1.0, 1.0)
    }
    SubShader
    {

        Tags { "RenderType"="Opaque" "RenderPipeline" = "UniversalPipeline"}
        LOD 100

        Pass
        {
            HLSLPROGRAM
            #include "Assets/ActualProject/Utility.hlsl"
            #pragma target 5.0
            #pragma vertex vert 
            #pragma fragment frag
            #pragma multi_compile_instancing
            #pragma multi_compile _ _MAIN_LIGHT_SHADOWS

            //below keyword must be defined for specular highlights to work

            TEXTURE2D(_MainTex);
            SAMPLER(sampler_MainTex);
            StructuredBuffer<Planet> _Planets;

            StructuredBuffer<float3> _VertexBuffer;
            StructuredBuffer<float3> _NormalBuffer;
            StructuredBuffer<float2> _UVBuffer;

            uniform float _Roughness;
            uniform float _BaseRoughness;
            uniform float _Persistence;
            uniform float _MinVal;
            uniform float _NoiseStrength;
            uniform float3 _NoiseCentre;
            uniform float _Octaves;
            uniform float _Smoothness;
            uniform float4 _SpecularColour;
            uniform bool _Testing;
            struct Attributes
            {
                float4 vertexPosOS : POSITION;
                float4 colour : COLOR;
                float3 normalOS : NORMAL0;
                float2 uv: TEXCOORD0;
            };

            struct Interpolators
            {
                float2 uv : TEXCOORD0;
                float3 positionWS : TEXCOORD1;
                float4 colour : COLOR;
                float4 positionHCS : SV_POSITION;
                float3 normWS : TEXCOORD2;
            };

            
            Interpolators vert (Attributes i)
            {
                Interpolators o;
                PlanetTerrainProperties planetProperties;
                planetProperties = (PlanetTerrainProperties)0;
                planetProperties.baseRoughness = _BaseRoughness;
                planetProperties.roughness = _Roughness;
                planetProperties.persistence = _Persistence;
                planetProperties.octaves = _Octaves;
                planetProperties.minVal = _MinVal;
                planetProperties.noiseCentre = _NoiseCentre;
                planetProperties.noiseStrength = _NoiseStrength;
                



                //Use perlin noise to perturb the height of this vertex so the planet is no longer perfectly spherical.
                //pNoise returns a value in range [-1, 1], so we compress this to [0, 1]
                float noiseValue = fractalBrownianMotion(i.vertexPosOS, planetProperties);
                float3 vertexPosOS = i.vertexPosOS + i.normalOS * noiseValue;

                VertexPositionInputs positionData = GetVertexPositionInputs(vertexPosOS); //compute world space and clip space position
                VertexNormalInputs normalData = GetVertexNormalInputs(i.normalOS);
                o.positionHCS = positionData.positionCS;


                o.uv = i.uv;
                o.positionWS = positionData.positionWS;
                o.normWS = normalData.normalWS;
                o.positionHCS = positionData.positionCS;
                o.colour = i.colour;
                return o;

            }

            /*
            From SurfaceData.hlsl, included in the URP package:
            vec3 sampledLightPos = SampleRandomPointOnSphere(hitInfo.position, planetData.primaryBodyPos, planetData.primaryBodyRadius, u, v);

            vec3 SampleRandomPointOnSphere(vec3 hitpoint, Sphere sphere, float u, float v)
            {
	
	            vec3 pointToCentre = sphere.position - hitpoint;
	            float distToCentre = length(pointToCentre);
	            //If the point is within the sphere, then we sample it uniformly; the entire sphere is visible to a point within the sphere.
	            if(distToCentre < sphere.radius)//sphere.radius)
	            {
		            return SampleRandomPointOnSphereUniform(sphere, u, v);
	            }
	            //Create local coordinate system with the vector between the hitpoint and sphere centre as the z axis.
	            mat3 localFrame = makeLocalFrame(normalize(pointToCentre));
	
	            //maximum angle of the cone that the visible surface of the sphere subtends
	            float thetaMax = asin(sphere.radius / distToCentre);
	
	            float theta = acos(1.0 - u + u * cos(thetaMax));
	            float phi = 2.0 * v * M_PI;
	
	            //cast a ray from hitpoint in the calculated direction to get the point on the sphere.
	            vec3 dir = makeLocalFrame(pointToCentre) * sphericalToEuclidean(theta, phi);
	            return intersectSphere(Ray(hitpoint, normalize(dir)), sphere, 0.0001, 10000.0).position;
	
            }
            struct SurfaceData
            {
                half3 albedo;
                half3 specular;
                half  metallic;
                half  smoothness;
                half3 normalTS;
                half3 emission;
                half  occlusion;
                half  alpha;
                half  clearCoatMask;
                half  clearCoatSmoothness;
            };
            From input.hlsl, included in the URP package:
            struct InputData {
                float3  positionWS;
                half3   normalWS;
                half3   viewDirectionWS;
                float4  shadowCoord;
                half    fogCoord;
                half3   vertexLighting;
                half3   bakedGI;
                float2  normalizedScreenSpaceUV;
                half4   shadowMask;
            };

                            vec3 shadeFromLight(
                  const Scene scene,
                  const Ray ray,
                  const HitInfo hit_info,
                  const PointLight light)
                { 
                  vec3 hitToLight = light.position - hit_info.position;
  
                  vec3 lightDirection = normalize(hitToLight);
                  vec3 viewDirection = normalize(hit_info.position - ray.origin);
                  vec3 reflectedDirection = reflect(viewDirection, hit_info.normal);
                  float diffuse_term = max(0.0, dot(lightDirection, hit_info.normal));
                  float specular_term  = pow(max(0.0, dot(lightDirection, reflectedDirection)), hit_info.material.glossiness);
  
                #ifdef SOLUTION_SHADOW
	                Ray shadowRay = Ray(hit_info.position, lightDirection);
	                float hitToLightDst = length(hitToLight);
	                HitInfo initialHitInfo = intersectScene(scene, shadowRay, 0.0001, hitToLightDst);
	                float visibility = initialHitInfo.hit ? 0.0 : 1.0;
                #else
                  // Put your shadow test here
                  float visibility = 1.0;
                #endif
                  return 	visibility * 
    		                light.color * (
    		                specular_term * hit_info.material.specular +
      		                diffuse_term * hit_info.material.diffuse);
                }
            
            */

            float4 frag (Interpolators i) : SV_Target
            {
                //return float4(1.0, 0.0, 0.0, 1.0)
                /*Unlike the other bodies in the simulation that are emissive, the planets need to be shaded
                This lighting code is heavily based off of this tutorial: https://www.youtube.com/watch?v=1bm0McKAh9E
                For a given planet, we will only consider the light incident on it from the star that it is orbitting
                */
                //Basic Blinn-Phong lighting, where the star the planet is orbitting is treated as a uniformly coloured point light

                InputData lightingInput = (InputData)0; //stores information about the position and orientation of the mesh at the current fragment
                lightingInput.positionWS = i.positionWS;
                lightingInput.normalWS = normalize(i.normWS); //length of normal vectors must be 1 for lighting to work as expected
                lightingInput.viewDirectionWS = GetWorldSpaceNormalizeViewDir(i.positionWS);
                lightingInput.shadowCoord = TransformWorldToShadowCoord(i.positionWS);

                SurfaceData surfaceInput = (SurfaceData)0; //stores information about the surface material's properties.'
                surfaceInput.albedo = i.colour.rgb;// * baseTex.rgb;
                surfaceInput.alpha = i.colour.a;
                surfaceInput.specular = _SpecularColour;
                surfaceInput.smoothness = _Smoothness;

                return UniversalFragmentBlinnPhong(lightingInput, surfaceInput);
                
            }
            ENDHLSL
        }
    }
}