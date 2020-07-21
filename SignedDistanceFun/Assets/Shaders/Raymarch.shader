Shader "Unlit/Raymarch"
{
    Properties
    {
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
                fixed4 diff : COLOR0; // diffuse lighting color
            };

            sampler2D _MainTex;
            float4 _MainTex_ST;

            v2f vert (appdata v)
            {
                v2f o;
                o.vertex = UnityObjectToClipPos(v.vertex);
                o.uv = TRANSFORM_TEX(v.uv, _MainTex);
                o.rayOrigin = mul(unity_WorldToObject, float4(_WorldSpaceCameraPos, 1));
                o.hitPosition = v.vertex;
                return o;
            }
            
            fixed4 frag (v2f i) : SV_Target
            {
                float3 rayOrigin = i.rayOrigin;
                float3 rayDirection = normalize(i.hitPosition - rayOrigin);

                float distance = Raymarch(rayOrigin, rayDirection);

                if (distance > MAXIMUM_DISTANCE)
                    discard;

                fixed4 col = 0;
                float3 position = rayOrigin + rayDirection * distance;
                float3 normal = GetNormal(position);
                col.rgb = normal;
                
                float4 lightPosition = _WorldSpaceLightPos0;

                // ambient lighting

                float4 ambient = 0.1;

                // add in unity's spherical harmonic ambient lighting
                ambient.rgb += ShadeSH9(half4(normal, 1));

                // diffuse lighting

                float4 diffuse = max(0, dot(normal, _WorldSpaceLightPos0.xyz)) * _LightColor0;

                return diffuse + ambient;
            }
            ENDCG
        }

        Pass 
        {
            Tags {"LightMode"="ShadowCaster"}
            
            CGPROGRAM
            #pragma vertex vert
            #pragma fragment frag
            #pragma multi_compile_shadowcaster
            #include "UnityCG.cginc"

            struct v2f 
            { 
                V2F_SHADOW_CASTER;
            };

            v2f vert(appdata_base v)
            {
                v2f o;
                TRANSFER_SHADOW_CASTER_NORMALOFFSET(o)
                return o;
            }

            float4 frag(v2f i) : SV_Target
            {
                SHADOW_CASTER_FRAGMENT(i)
            }
            ENDCG
		}
    }
}
