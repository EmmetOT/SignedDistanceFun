// Upgrade NOTE: replaced '_Object2World' with 'unity_ObjectToWorld'
// Upgrade NOTE: replaced 'mul(UNITY_MATRIX_MVP,*)' with 'UnityObjectToClipPos(*)'

Shader "Unlit/Raymarch"
{
    Properties
    {
        _Colour("Colour", Color) = (1, 1, 1, 1)
        _SpecularPower("Specular Power", float) = 1
        _Gloss("Gloss", Range(0,1)) = 1

        _Smoothing("Smoothing", float) = 32
        _AmbientOcclusionSteps("Ambient Occlusion Step", int) = 10
        _AmbientOcclusionStepSize("Ambient Occlusion Step Size", float) = 0.1
    }
    SubShader
    {
        Tags { "LightMode"="ForwardBase" }
        LOD 100

        Pass
        {
            CGPROGRAM
            #pragma vertex vert
            #pragma fragment frag
            #include "Raymarching.cginc"
            #include "UnityCG.cginc" // for UnityObjectToWorldNormal
            #include "UnityLightingCommon.cginc" // for _LightColor0
            #pragma multi_compile AMBIENT_OCCLUSION_ON AMBIENT_OCCLUSION_OFF AMBIENT_OCCLUSION_TEST
            #pragma shader_feature SHADOWS_ON
            

            struct appdata
            {
                float4 vertex : POSITION;
                float2 uv : TEXCOORD0;
            };

            struct v2f
            {
                float4 vertex : SV_POSITION;
                float3 rayOrigin : TEXCOORD1;
                float3 worldPosition : TEXCOORD3;
            };

            float4 _Colour;
            float _SpecularPower;
            float _Gloss;

            int _AmbientOcclusionSteps;
            float _AmbientOcclusionStepSize;

            v2f vert (appdata v)
            {
                v2f o;
                o.vertex = UnityObjectToClipPos(v.vertex);
                o.rayOrigin = _WorldSpaceCameraPos;
                o.worldPosition = mul(unity_ObjectToWorld, v.vertex).xyz;
                return o;
            }
            
            fixed4 SimpleLambert(float3 colour, float3 position, float3 normal, float3 viewDirection, float3 lightPosition) 
            {
	            float3 lightDir = normalize(lightPosition);
	            fixed3 lightCol = _LightColor0.rgb;

                half NdotL = saturate(dot(normal, lightDir));
                fixed4 c = NdotL;
                c.a = 1;
                c.rgb *= colour * lightCol;

                float3 lightReflectDirection = reflect(-lightDir, normal);
                float3 lightSeeDirection = max(0, dot(lightReflectDirection, viewDirection));
                float3 shininessPower = pow(lightSeeDirection, _SpecularPower) * _Gloss;
                c.rgb += shininessPower;

                #if SHADOWS_ON
                // shadows

                float4 rayToLight = Raymarch(position + normal * MIN_SURFACE_DISTANCE * 2, lightDir);
                if (rayToLight.w < MAXIMUM_DISTANCE)
                    c *= 0.1;
                #endif

                return c;
            }

            fixed4 frag (v2f i) : SV_Target
            {
                float3 rayOrigin = i.rayOrigin;
                float3 rayDirection = normalize(i.worldPosition - rayOrigin);

                int steps;
                float4 hit = Raymarch(rayOrigin, rayDirection);

                float3 hitCol = hit.rgb;
                float distance = hit.w;

                if (distance > MAXIMUM_DISTANCE)
                    discard;

                float3 position = rayOrigin + rayDirection * distance;
                float3 normal = GetNormal(position);
                
                float ambientOcclusion = 1;
                
                #ifndef AMBIENT_OCCLUSION_OFF
                ambientOcclusion = AmbientOcclusion(position, normal, 0, _AmbientOcclusionStepSize, _AmbientOcclusionSteps, _AmbientOcclusionStepSize);
                #endif

                #if AMBIENT_OCCLUSION_TEST
                float4 testVal = ambientOcclusion;
                testVal.a = 1;
                return testVal;
                #endif

                // ambient lighting

                float4 ambient = ambientOcclusion * 0.1;

                // diffuse + specular lighting

                float4 diffuse = SimpleLambert(hitCol, position, normal, -rayDirection, _WorldSpaceLightPos0.xyz);

                // specular lighting

                float4 light = (diffuse + ambient);

                return light;
            }
            ENDCG
        }
    }
}
