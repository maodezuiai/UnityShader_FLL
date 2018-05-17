﻿/*
	切线空间的法线纹理之
	在世界空间下进行光照计算

	需要把法向方向从切线空间变换到世界空间下（在片元着色器中进行这些变换）
*/
Shader "Unity Shaders Book/Chapter7/Normal Map In World Space"
{
	Properties
	{
		_Color("Color Tint", Color) = (1.0, 1.0, 1.0, 1.0)	// 控制整体色调
		_MainTex("Main Tex", 2D) = "white"{}				// 纹理
		_BumpMap("Normal Map", 2D) = "bump"{}				// 法线纹理
		_BumpScale("Bump Scale", Float) = 1.0
		_Specular("Specular", Color) = (1.0, 1.0, 1.0, 1.0)
		_Gloss("Gloss", Range(8.0, 256.0)) = 20
	}
	SubShader
	{
		Tags { "LightMode" = "ForwardBase" }

		Pass
		{
			CGPROGRAM

			#pragma vertex vert
			#pragma fragment frag

			#include "UnityCG.cginc"
			#include "Lighting.cginc"

			fixed4 _Color;
			sampler2D _MainTex;
			float4 _MainTex_ST;
			sampler2D _BumpMap;
			float4 _BumpMap_ST;
			float _BumpScale;		// 控制凹凸程度，0的时候表示法线纹理不对光照产生作用
			fixed4 _Specular;
			float _Gloss;
			
			struct a2v{
				float4 vertex : POSITION;
				float3 normal : NORMAL;
				float4 tangent : TANGENT;
				float4 texcoord : TEXCOORD0;
			};

			struct v2f {
				float4 pos : SV_POSITION;
				float4 uv : TEXCOORD0;
				float4 TtoW0 : TEXCOORD1;	// 前三位：存储切线空间到世界空间的变换矩阵的一行；后一位：存储世界空间下顶点的位置
				float4 TtoW1 : TEXCOORD2;
				float4 TtoW2 : TEXCOORD3;
			};

			v2f vert(a2v v)
			{
				v2f o;
				o.pos = mul(UNITY_MATRIX_MVP, v.vertex);

				// 使用 o.uv 存储两个纹理坐标
				o.uv.xy = v.texcoord.xy * _MainTex_ST.xy + _MainTex_ST.zw;
				o.uv.zw = v.texcoord.xy * _BumpMap_ST.xy + _BumpMap_ST.zw;

				float3 worldPos = mul(unity_ObjectToWorld, v.vertex).xyz;
				float3 worldNormal = normalize(mul(v.normal, (float3x3)unity_WorldToObject));
				float3 worldTangent = normalize(mul((float3x3)unity_ObjectToWorld, v.tangent.xyz));
				float3 worldBinormal = cross(worldNormal, worldTangent) * v.tangent.w;
				
				// Compute the matrix that transform directions from tangent space to world Space
				// Put the world position in w component for optimization
				o.TtoW0 = float4(worldTangent.x, worldBinormal.x, worldNormal.x, worldPos.x);
				o.TtoW1 = float4(worldTangent.y, worldBinormal.y, worldNormal.y, worldPos.y);
				o.TtoW2 = float4(worldTangent.z, worldBinormal.z, worldNormal.z, worldPos.z);

				return o;
			}

			fixed4 frag(v2f i) : SV_Target
			{
				fixed3 worldPos = float3(i.TtoW0.w, i.TtoW1.w, i.TtoW2.w);
				fixed3 lightDir = normalize(UnityWorldSpaceLightDir(worldPos));
				fixed3 viewDir = normalize(UnityWorldSpaceViewDir(worldPos));

				// Get the normal in tangent space (mark the texture as "Normal map")
				 fixed3 tangentNormal = UnpackNormal(tex2D(_BumpMap, i.uv.zw));
				tangentNormal.xy *= _BumpScale;
				tangentNormal.z = sqrt(1.0 - saturate(dot(tangentNormal.xy, tangentNormal.xy)));
				// Transform the normal from tangent space to world space
				tangentNormal = normalize(half3(dot(i.TtoW0.xyz, tangentNormal), dot(i.TtoW1.xyz, tangentNormal), dot(i.TtoW2.xyz, tangentNormal)));

				// Use the texture to sample the diffuse color
				fixed3 albedo = tex2D(_MainTex, i.uv).rgb * _Color.rgb;

				fixed3 ambient = UNITY_LIGHTMODEL_AMBIENT.xyz * albedo;

				fixed3 diffuse = _LightColor0.rgb * albedo * saturate(dot(tangentNormal, lightDir));

				fixed3 halfDir = normalize(viewDir + lightDir);
				fixed3 specular = _LightColor0.rgb * _Specular.rgb * pow(saturate(dot(tangentNormal, halfDir)), _Gloss);
				
				return fixed4(ambient + diffuse + specular, 1.0);
			}
		
			ENDCG
		}
	}

	Fallback "Specular"
}
