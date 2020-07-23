using System.Collections;
using System.Collections.Generic;
using UnityEditor;
using UnityEngine;

public class SignedDistanceFieldVolume : Singleton<SignedDistanceFieldVolume>
{
    [SerializeField]
    private List<SDFObject> m_objects;

    [SerializeField]
    private Material m_material;

    [SerializeField]
    [Range(0f, 1f)]
    private float m_smoothing = 0.05f;

    private enum AmbientOcclusionMode { ON, OFF, TEST };

    [SerializeField]
    private AmbientOcclusionMode m_ambientOcclusionMode;

    private ComputeBuffer m_objectBuffer;

    private readonly List<SDF_GPU_Data> m_gpuDataObjects = new List<SDF_GPU_Data>();

    private static int m_sdfObjectBufferProperty = -1;
    private static int SDF_OBJECT_BUFFER_PROPERTY => m_sdfObjectBufferProperty != -1 ? m_sdfObjectBufferProperty : (m_sdfObjectBufferProperty = Shader.PropertyToID("ObjectBuffer"));

    private static int m_sdfObjectCountProperty = -1;
    private static int SDF_OBJECT_COUNT_PROPERTY => m_sdfObjectCountProperty != -1 ? m_sdfObjectCountProperty : (m_sdfObjectCountProperty = Shader.PropertyToID("ObjectCount"));

    private static int m_smoothingProperty = -1;
    private static int SMOOTHING_PROPERTY => m_smoothingProperty != -1 ? m_smoothingProperty : (m_smoothingProperty = Shader.PropertyToID("Smoothing"));

    public void RegisterSDFObject(SDFObject obj)
    {
        if (m_objects.Contains(obj))
            return;

        m_objects.Add(obj);

        RefreshBuffer();
    }

    public void DeregisterSDFObject(SDFObject obj)
    {
        if (m_objects.Remove(obj))
            RefreshBuffer();
    }

    private void RefreshBuffer()
    {
        m_objectBuffer = new ComputeBuffer(m_objects.Count, SDF_GPU_Data.Stride);
        Shader.SetGlobalBuffer(SDF_OBJECT_BUFFER_PROPERTY, m_objectBuffer);
        Shader.SetGlobalInt(SDF_OBJECT_COUNT_PROPERTY, m_objects.Count);
        Shader.SetGlobalFloat(SMOOTHING_PROPERTY, m_smoothing);

        SetAmbientOcclusionKeyword();
    }

    private void SetAmbientOcclusionKeyword()
    {
        string prefix = "AMBIENT_OCCLUSION_";
        foreach (AmbientOcclusionMode mode in System.Enum.GetValues(typeof(AmbientOcclusionMode)))
        {
            string val = prefix + mode.ToString();

            if (mode == m_ambientOcclusionMode)
            {
                //Debug.Log("enabling " + val);
                m_material.EnableKeyword(val);
            }
            else
            {
                //Debug.Log("disabling " + val);
                m_material.DisableKeyword(val);
            }
        }

        //Debug.Log("============================");
    }

    private void OnEnable()
    {
        RefreshBuffer();
    }

    private void OnDisable()
    {
        m_objectBuffer.Dispose();
    }

    private void Update()
    {
        SetAmbientOcclusionKeyword();
        UpdateSphereStructs();

        Shader.SetGlobalFloat(SMOOTHING_PROPERTY, m_smoothing);

#if UNITY_EDITOR
        Transform sceneViewTransform = SceneView.lastActiveSceneView.camera.transform;
        transform.position = sceneViewTransform.position;
        transform.rotation = sceneViewTransform.rotation;
#endif
    }

    private void UpdateSphereStructs()
    {
        m_gpuDataObjects.Clear();

        for (int i = 0; i < m_objects.Count; i++)
            m_gpuDataObjects.Add(new SDF_GPU_Data(m_objects[i]));

        m_objectBuffer.SetData(m_gpuDataObjects);
    }
}