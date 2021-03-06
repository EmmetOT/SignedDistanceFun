﻿#define AMBIENT_OCCLUSION_STEPS 12.0
#define AMBIENT_OCCLUSION_STEP_SIZE 0.01

#define MAXIMUM_STEPS 100
#define MAXIMUM_DISTANCE 100
#define MIN_SURFACE_DISTANCE 1e-3
#define NORMAL_SHARPNESS 1e-2
#define PI 3.14159

struct SDF_GPU_Data 
{
    float3 data;
    float4 col;
    int type;
};

#define TYPE_SPHERE 0
#define TYPE_TORUS 1
#define TYPE_BOX 2
#define TYPE_PLANE 3

StructuredBuffer<SDF_GPU_Data> ObjectBuffer : register(t1);
StructuredBuffer<float4x4> ObjectTransformsBuffer : register(t2);
int ObjectCount : register(t3);
float Smoothing : register(t4);

float3x3 rotate(float3 v, float angle)
{
	float c = cos(angle);
	float s = sin(angle);
	
	return float3x3(c + (1.0 - c) * v.x * v.x, (1.0 - c) * v.x * v.y - s * v.z, (1.0 - c) * v.x * v.z + s * v.y,
		(1.0 - c) * v.x * v.y + s * v.z, c + (1.0 - c) * v.y * v.y, (1.0 - c) * v.y * v.z - s * v.x,
		(1.0 - c) * v.x * v.z - s * v.y, (1.0 - c) * v.y * v.z + s * v.x, c + (1.0 - c) * v.z * v.z
		);
}

// max component of a float3
float vmax(float3 v)
{
    return max(max(v.x, v.y), v.z);
}

float SDF_SmoothMin(float a, float b, float k = 32)
{
	float res = exp(-k * a) + exp(-k * b);
	return -log(max(0.0001, res)) / k;
}

float SDF_Sphere(float3 pos, float3 centre, float radius)
{
    return distance(pos, centre) - radius;
}

float SDF_CheapBox(float3 position, float3 centre, float3 size)
{
 return vmax(abs(position - centre) - size);
}

float SDF_Plane(float3 position, float3 centre)
{
    return position.y - centre.y;
}

float SDF_Box(float3 position, float3 bounds)
{
    float3 q = abs(position) - bounds;
    return length(max(q, 0.0)) + min(max(q.x, max(q.y, q.z)), 0.0);
}

float SDF_Torus(float3 position, float3 centre, float outerRadius, float innerRadius)
{
    return distance(float2(distance(position.xz, centre) - outerRadius, position.y), centre) - innerRadius;
}

float4 SDF_Op_SmoothUnion(float d1, float d2, float3 col1, float3 col2) 
{
    float k = Smoothing;
    float h = clamp( 0.5 + 0.5*(d2-d1)/k, 0.0, 1.0 );
    float4 res = float4(
        lerp( col2.x, col1.x, h ) - k*h*(1.0-h),
        lerp( col2.y, col1.y, h ) - k*h*(1.0-h),
        lerp( col2.z, col1.z, h ) - k*h*(1.0-h),
        lerp( d2, d1, h ) - k*h*(1.0-h)

     );
    return res; 
}

float SDF_Typed(SDF_GPU_Data obj, float3 position, float3 centre)
{
    switch (obj.type)
    {
        case TYPE_SPHERE:
            return SDF_Sphere(position, centre, obj.data.x);
        case TYPE_TORUS:
            return SDF_Torus(position, centre, obj.data.x, obj.data.y);
        case TYPE_BOX:
            return SDF_CheapBox(position, centre, obj.data);
        case TYPE_PLANE:
            return SDF_Plane(position, centre);
	}

    return 0;
}

float box(float3 p, float3 data)
{
    return max(max(abs(p.x)-data.x,abs(p.y)-data.y),abs(p.z)-data.z);
}


float4 StaticMap(float3 p)
{
    float d = -box(p-float3(0, 10, 0),float3(10, 10, 10));
    d = min(d, box(mul(rotate(float3(0, 1, 0), 1), (p - float3(4, 5, 6))), float3(3, 5, 3)));
	d = min(d, box(mul(rotate(float3(0, 1, 0), -1), (p-float3(-4.,2.,0.))), float3(2, 2, 2)));
	d = max(d, -p.z-9.);
	
	return float4(1, 1, 1, d);
}

float4 Map(float3 position)
{
    SDF_GPU_Data obj = ObjectBuffer[0];
    float3 centre = mul(ObjectTransformsBuffer[0], float4(0, 0, 0, 1));
    float radius = obj.data.x;

    float dist = SDF_Typed(obj, position, centre);
    float3 col = obj.col;

    float4 result = float4(col, dist);

    for (int i = 1; i < ObjectCount; i++)
    {
        obj = ObjectBuffer[i];
        centre = mul(ObjectTransformsBuffer[i], float4(0, 0, 0, 1));
        radius = obj.data.x;

        dist = SDF_Typed(obj, position, centre);
        col = obj.col;

        result = SDF_Op_SmoothUnion(result.w, dist, result.rgb, col);
	}

    return result;
}
            
float3 GetNormal(float3 position)
{
    float2 epsilon = float2(NORMAL_SHARPNESS, 0);

    // three partial deriviatives
    float3 gradient = float3(
        Map(position - epsilon.xyy).w,
        Map(position - epsilon.yxy).w,
        Map(position - epsilon.yyx).w);

    float3 normal = Map(position).w - gradient;  
                
    return normalize(normal);
}
float AmbientOcclusion(float3 pos, float3 normal)
{
    float sum = 0;
    float maxSum = 0;

    for (int i = 0; i < AMBIENT_OCCLUSION_STEPS; i ++)
    {
        float increment = (i + 1) * AMBIENT_OCCLUSION_STEP_SIZE;

        float3 p = pos + normal * increment;
        sum    += 1.0 / pow(2.0, i) * Map(p).w;
        maxSum += 1.0 / pow(2.0, i) * increment;
    }

    return saturate(sum / maxSum);
}

float4 Raymarch(float3 rayOrigin, float3 rayDirection)
{
    float4 result = 0;
    float distanceFromSurface;
                
    for (int i = 0; i < MAXIMUM_STEPS; i++)
    {
        float3 position = rayOrigin + result.w * rayDirection;

        float4 distResult = Map(position);

        distanceFromSurface = distResult.w;
        result.w += distanceFromSurface;

        if (abs(distanceFromSurface) < MIN_SURFACE_DISTANCE || result.w > MAXIMUM_DISTANCE)
        {
            result.rgb = distResult.rgb;
            break;
		}
	}

    return result;
}
