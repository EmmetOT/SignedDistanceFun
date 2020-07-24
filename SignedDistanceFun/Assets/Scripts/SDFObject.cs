using System.Collections;
using System.Collections.Generic;
using UnityEngine;

public class SDFObject : MonoBehaviour
{
    public enum Type
    {
        SPHERE,
        TORUS,
        BOX,
        PLANE
    }

    [SerializeField]
    private Type m_type;
    public Type ObjectType => m_type;

    [SerializeField]
    private Color m_colour;
    public Color Colour => m_colour;

    [SerializeField]
    private Vector3 m_data;
    public Vector3 Data => m_data;

    private void OnEnable()
    {
        if (SignedDistanceFieldVolume.Instance != null)
            SignedDistanceFieldVolume.Instance.RegisterSDFObject(this);
    }

    private void OnDisable()
    {
        if (SignedDistanceFieldVolume.Instance != null) 
            SignedDistanceFieldVolume.Instance.DeregisterSDFObject(this);
    }
}

public struct SDF_GPU_Data
{
    public const int Stride = 8 * 4;

    public Vector3 data;
    public Color col;
    public int type;

    public SDF_GPU_Data(SDFObject obj)
    {
        data = obj.Data;
        col = obj.Colour;
        type = (int)obj.ObjectType;
    }
}
