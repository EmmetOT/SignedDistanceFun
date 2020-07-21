using System.Collections;
using System.Collections.Generic;
using UnityEngine;
using UnityEngine.Rendering;

public class CommandBufferTest : MonoBehaviour
{
    [SerializeField]
    private Camera m_camera;

    [SerializeField]
    private Renderer m_targetRenderer;

    private RenderTexture m_renderTexture;

    void OnEnable()
    {
        DrawRenderer(m_targetRenderer);
    }

    private void DrawColour(Color colour)
    {
        CommandBuffer commandBuffer = new CommandBuffer
        {
            name = "Clear to Colour"
        };

        commandBuffer.SetRenderTarget(BuiltinRenderTextureType.CameraTarget);
        commandBuffer.ClearRenderTarget(true, true, colour, 1f);
        m_camera.AddCommandBuffer(CameraEvent.AfterEverything, commandBuffer);
    }

    private void DrawRenderer(Renderer targetRenderer)
    {
        m_renderTexture = new RenderTexture(m_camera.pixelWidth, m_camera.pixelHeight, 0);
        RenderTargetIdentifier rtID = new RenderTargetIdentifier(m_renderTexture);

        CommandBuffer commandBuffer = new CommandBuffer
        {
            name = "Draw Renderer"
        };

        commandBuffer.SetRenderTarget(rtID);
        commandBuffer.ClearRenderTarget(true, true, Color.clear, 1f);
        commandBuffer.DrawRenderer(targetRenderer, targetRenderer.sharedMaterial, 0, 0);

        m_camera.AddCommandBuffer(CameraEvent.AfterForwardOpaque, commandBuffer);
    }

    private void OnRenderImage(RenderTexture src, RenderTexture dest)
    {
        Graphics.Blit(m_renderTexture, dest);
    }
}
