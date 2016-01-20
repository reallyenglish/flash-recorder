package {
  import flash.display.Sprite;
  import flash.system.Security;
  import flash.external.ExternalInterface;

  public class FlashRecorder extends Sprite {
    public function FlashRecorder() {
      // allow JavaScript access ExternalInterface from any domain
      // should be limit to some domain for better security
      Security.allowDomain("*")
      var recorder = new Recorder();
      recorder.setRecorderInstance(root.loaderInfo.parameters.recorderInstance);
      recorder.addExternalInterfaceCallbacks();
    }
  }
}
