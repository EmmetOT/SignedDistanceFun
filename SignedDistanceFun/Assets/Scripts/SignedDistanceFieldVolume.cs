using System.Collections;
using System.Collections.Generic;
using UnityEditor;
using UnityEngine;
using NaughtyAttributes;

public class SignedDistanceFieldVolume : Singleton<SignedDistanceFieldVolume>
{
    [SerializeField]
    private List<SDFObject> m_objects;

    [SerializeField]
    private Material m_material;

    [SerializeField]
    [Range(0f, 1f)]
    [OnValueChanged("SetSmoothing")]
    private float m_smoothing = 0.05f;

    private enum AmbientOcclusionMode { ON, OFF, TEST };

    [SerializeField]
    [OnValueChanged("SetAmbientOcclusionKeyword")]
    private AmbientOcclusionMode m_ambientOcclusionMode;

    [SerializeField]
    [OnValueChanged("SetShadowsKeyword")]
    private bool m_enableShadows = true;

    private ComputeBuffer m_objectBuffer;
    private ComputeBuffer m_objectTransformBuffer;

    private readonly List<Matrix4x4> m_objectTransforms = new List<Matrix4x4>();
    private readonly List<SDF_GPU_Data> m_gpuDataObjects = new List<SDF_GPU_Data>();

    private static int m_sdfObjectBufferProperty = -1;
    private static int SDF_OBJECT_BUFFER_PROPERTY => m_sdfObjectBufferProperty != -1 ? m_sdfObjectBufferProperty : (m_sdfObjectBufferProperty = Shader.PropertyToID("ObjectBuffer"));

    private static int m_sdfObjectTransformBufferProperty = -1;
    private static int SDF_OBJECT_TRANSFORM_BUFFER_PROPERTY => m_sdfObjectTransformBufferProperty != -1 ? m_sdfObjectTransformBufferProperty : (m_sdfObjectTransformBufferProperty = Shader.PropertyToID("ObjectTransformsBuffer"));

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
        m_objectBuffer?.Dispose();
        m_objectTransformBuffer?.Dispose();

        m_objectBuffer = new ComputeBuffer(m_objects.Count, SDF_GPU_Data.Stride);
        m_objectTransformBuffer = new ComputeBuffer(m_objects.Count, sizeof(float) * 16);

        Shader.SetGlobalBuffer(SDF_OBJECT_BUFFER_PROPERTY, m_objectBuffer);
        Shader.SetGlobalBuffer(SDF_OBJECT_TRANSFORM_BUFFER_PROPERTY, m_objectTransformBuffer);
        Shader.SetGlobalInt(SDF_OBJECT_COUNT_PROPERTY, m_objects.Count);
        Shader.SetGlobalFloat(SMOOTHING_PROPERTY, m_smoothing);

        UpdateObjectData();
        UpdateTransforms();
    }

    private void SetAmbientOcclusionKeyword()
    {
        string prefix = "AMBIENT_OCCLUSION_";
        foreach (AmbientOcclusionMode mode in System.Enum.GetValues(typeof(AmbientOcclusionMode)))
        {
            string val = prefix + mode.ToString();

            if (mode == m_ambientOcclusionMode)
                m_material.EnableKeyword(val);
            else
                m_material.DisableKeyword(val);
        }
    }

    private void SetShadowsKeyword()
    {
        if (m_enableShadows)
            m_material.EnableKeyword("SHADOWS_ON");
        else
            m_material.DisableKeyword("SHADOWS_ON");
    }

    private void SetSmoothing()
    {
        Shader.SetGlobalFloat(SMOOTHING_PROPERTY, m_smoothing);
    }

    private void OnEnable()
    {   
        SetAmbientOcclusionKeyword();
        SetShadowsKeyword();
        SetSmoothing();

        RefreshBuffer();
    }

    private void OnDisable()
    {
        m_objectBuffer?.Dispose();
        m_objectTransformBuffer?.Dispose();
    }

    private void Update()
    {
        bool hasMovedObjects = false;
        bool hasDirtyObjects = false;

        for (int i = 0; i < m_objects.Count; i++)
        {
            if (m_objects[i].IsDirty)
            {
                hasDirtyObjects = true;
                m_objects[i].SetDirty(false);
            }

            if (m_objects[i].transform.hasChanged)
            {
                hasMovedObjects = true;
                m_objects[i].transform.hasChanged = false;
            }
        }

        if (hasDirtyObjects)
            UpdateObjectData();

        if (hasMovedObjects)
            UpdateTransforms();

#if UNITY_EDITOR
        Transform sceneViewTransform = SceneView.lastActiveSceneView.camera.transform;
        transform.position = sceneViewTransform.position;
        transform.rotation = sceneViewTransform.rotation;
#endif
    }

    private void UpdateTransforms()
    {
        m_objectTransforms.Clear();

        for (int i = 0; i < m_objects.Count; i++)
            m_objectTransforms.Add(m_objects[i].transform.localToWorldMatrix);

        m_objectTransformBuffer.SetData(m_objectTransforms);
    }

    private void UpdateObjectData()
    {
        m_gpuDataObjects.Clear();

        for (int i = 0; i < m_objects.Count; i++)
            m_gpuDataObjects.Add(new SDF_GPU_Data(m_objects[i]));

        m_objectBuffer.SetData(m_gpuDataObjects);
    }
}