package {
  import flash.display.Sprite;
  import flash.external.ExternalInterface;

  public class FlashRecorder extends Sprite {
    public function FlashRecorder() {
      var recorder = new Recorder();
      recorder.setRecorderInstance(root.loaderInfo.parameters.recorderInstance);
      recorder.addExternalInterfaceCallbacks();
    }
  }
}
