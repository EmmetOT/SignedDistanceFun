using NaughtyAttributes;
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
    [OnValueChanged("Internal_SetDirtyTrue")]
    private Type m_type;
    public Type ObjectType => m_type;

    [SerializeField]
    [OnValueChanged("Internal_SetDirtyTrue")]
    private Color m_colour;
    public Color Colour => m_colour;

    [SerializeField]
    [OnValueChanged("Internal_SetDirtyTrue")]
    private Vector3 m_data;
    public Vector3 Data => m_data;

    private bool m_isDirty = false;
    public bool IsDirty => m_isDirty;

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

    private void Internal_SetDirtyTrue()
    {
        SetDirty(true);
    }

    public void SetDirty(bool isDirty)
    {
        if (!Application.isPlaying)
            return;

        m_isDirty = isDirty;
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
