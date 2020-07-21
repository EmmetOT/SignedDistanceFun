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

float Test_GetDist(float3 position)
{
    return GetDistance_Torus(position, 0.5, 0.1);
    //return GetDistance_Sphere(position, 0.5);
}
            
float3 GetNormal(float3 position)
{
    float2 epsilon = float2(1e-2, 0);

    // three partial deriviatives
    float3 gradient = float3(
        Test_GetDist(position - epsilon.xyy),
        Test_GetDist(position - epsilon.yxy),
        Test_GetDist(position - epsilon.yyx));

    float3 normal = Test_GetDist(position) - gradient;  
                
    return normalize(normal);
}



float Raymarch(float3 rayOrigin, float3 rayDirection)
{
    float distanceFromOrigin = 0;
    float distanceFromSurface;
                
    for (int i = 0; i < MAXIMUM_STEPS; i++)
    {
        float3 position = rayOrigin + distanceFromOrigin * rayDirection;
        distanceFromSurface = Test_GetDist(position);
        distanceFromOrigin += distanceFromSurface;

        if (distanceFromSurface < MIN_SURFACE_DISTANCE || distanceFromOrigin > MAXIMUM_DISTANCE)
            break;
	}
                
    return distanceFromOrigin;
}
