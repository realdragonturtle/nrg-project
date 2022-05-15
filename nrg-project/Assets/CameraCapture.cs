using System.IO;
using UnityEngine;

public class CameraCapture : MonoBehaviour
{
    public int fileCounter;
    private float time = 0.0f;
    public float interpolationPeriod = 0.3f;
    public string filepath;
    private Camera Camera
    {
        get
        {
            if (!_camera)
            {
                _camera = Camera.main;
            }
            return _camera;
        }
    }
    private Camera _camera;

    private void LateUpdate()
    {
        time += Time.deltaTime;
        if (time >= interpolationPeriod && fileCounter < 300) // save after some time so that it has time to change randoms
        {
            Capture();
            time = 0.0f;
        }
    }

    public void Capture()
    {
        RenderTexture activeRenderTexture = RenderTexture.active;
        RenderTexture.active = Camera.targetTexture;

        Camera.Render();

        Texture2D image = new Texture2D(Camera.targetTexture.width, Camera.targetTexture.height);
        image.ReadPixels(new Rect(0, 0, Camera.targetTexture.width, Camera.targetTexture.height), 0, 0);
        image.Apply();
        RenderTexture.active = activeRenderTexture;

        byte[] bytes = image.EncodeToPNG();
        Destroy(image);

        int im_c = fileCounter + 10;
        File.WriteAllBytes(filepath + im_c + ".png", bytes);
        fileCounter++;
    }
}
