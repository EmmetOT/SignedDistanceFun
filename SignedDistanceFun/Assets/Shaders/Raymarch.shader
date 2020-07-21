// Upgrade NOTE: replaced '_Object2World' with 'unity_ObjectToWorld'
// Upgrade NOTE: replaced 'mul(UNITY_MATRIX_MVP,*)' with 'UnityObjectToClipPos(*)'

Shader "Unlit/Raymarch"
{
    Properties
    {
        _Colour("Colour", Color) = (1, 1, 1, 1)
        _SpecularPower("Specular Power", float) = 1
        _Gloss("Gloss", Range(0,1)) = 1
        _MainTex ("Texture", 2D) = "white" {}
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
            
            struct appdata
            {
                float4 vertex : POSITION;
                float2 uv : TEXCOORD0;
            };

            struct v2f
            {
                float4 vertex : SV_POSITION;
                float2 uv : TEXCOORD0;
                float3 rayOrigin : TEXCOORD1;
                float3 hitPosition : TEXCOORD2;
                float3 worldPosition : TEXCOORD3;
            };

            sampler2D _MainTex;
            float4 _MainTex_ST;
            
            float4 _Colour;
            float _SpecularPower;
            float _Gloss;

            v2f vert (appdata v)
            {
                v2f o;
                o.vertex = UnityObjectToClipPos(v.vertex);
                o.uv = TRANSFORM_TEX(v.uv, _MainTex);
                o.rayOrigin = mul(unity_WorldToObject, float4(_WorldSpaceCameraPos, 1));
                o.hitPosition = v.vertex;
                o.worldPosition = mul(unity_ObjectToWorld, v.vertex).xyz;
                return o;
            }
            
            fixed4 SimpleLambert(float3 normal, float3 viewDirection, float3 lightPosition) 
            {
	            float3 lightDir = normalize(lightPosition);
	            fixed3 lightCol = _LightColor0.rgb;

                half NdotL = saturate(dot(normal, lightDir));
                fixed4 c = NdotL;
                c.a = 1;
                c.rgb *= _Colour * lightCol;

                float3 lightReflectDirection = reflect(-lightDir, normal);
                float3 lightSeeDirection = max(0, dot(lightReflectDirection, viewDirection));
                float3 shininessPower = pow(lightSeeDirection, _SpecularPower) * _Gloss;
                c.rgb += shininessPower;

                return c;
            }

            fixed4 frag (v2f i) : SV_Target
            {
                float3 rayOrigin = i.rayOrigin;
                float3 rayDirection = normalize(i.hitPosition - rayOrigin);

                float distance = Raymarch(rayOrigin, rayDirection);

                if (distance > MAXIMUM_DISTANCE)
                    discard;

                float3 position = rayOrigin + rayDirection * distance;
                float3 normal = GetNormal(position);

                // ambient lighting

                float4 ambient = 0.1;

                // diffuse lighting

                float4 diffuse = SimpleLambert(normal, -rayDirection, _WorldSpaceLightPos0.xyz);

                // specular lighting

                return diffuse + ambient;
            }
            ENDCG
        }
    }
}
