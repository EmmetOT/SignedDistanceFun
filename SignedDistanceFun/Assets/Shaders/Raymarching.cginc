#define MAXIMUM_STEPS 100
#define MAXIMUM_DISTANCE 100
#define MIN_SURFACE_DISTANCE 1e-3


float GetDistance_Torus(float3 position, float outerRadius, float innerRadius)
{
    return length(float2(length(position.xz) - outerRadius, position.y)) - innerRadius;
}
            
float GetDistance_Sphere(float3 position, float radius)
{
    return length(position) - radius;
}
            
float3 GetNormal(float3 position)
{
    float2 epsilon = float2(1e-2, 0);

    // three partial deriviatives
    float3 gradient = float3(
        GetDistance_Torus(position - epsilon.xyy, 0.5, 0.1),
        GetDistance_Torus(position - epsilon.yxy, 0.5, 0.1),
        GetDistance_Torus(position - epsilon.yyx, 0.5, 0.1));

    float3 normal = GetDistance_Torus(position, 0.5, 0.1) - gradient;  
                
    return normalize(normal);
}

float Raymarch(float3 rayOrigin, float3 rayDirection)
{
    float distanceFromOrigin = 0;
    float distanceFromSurface;
                
    for (int i = 0; i < MAXIMUM_STEPS; i++)
    {
        float3 position = rayOrigin + distanceFromOrigin * rayDirection;
        distanceFromSurface = GetDistance_Torus(position, 0.5, 0.1);
        distanceFromOrigin += distanceFromSurface;

        if (distanceFromSurface < MIN_SURFACE_DISTANCE || distanceFromOrigin > MAXIMUM_DISTANCE)
            break;
	}
                
    return distanceFromOrigin;
}
