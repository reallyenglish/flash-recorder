package {
  import flash.display.Sprite;
  import flash.system.Security;
  import flash.external.ExternalInterface;

  public class FlashRecorder extends Sprite {
    public function FlashRecorder() {
      Security.allowDomain("*")
      var recorder = new Recorder();
      recorder.setRecorderInstance(root.loaderInfo.parameters.recorderInstance);
      recorder.addExternalInterfaceCallbacks();
    }
  }
}
