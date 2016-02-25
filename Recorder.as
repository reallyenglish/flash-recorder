/*
 * flash recorder Plugin for JavaScript
 *
 *
 * FlashVars expected: (AS3 property of: loaderInfo.parameters)
 *	recorderInstance:	(URL Encoded: String) Sets the JavaScript recorder object.
 *
 */
package
{
	import flash.events.TimerEvent;
	import flash.events.Event;
	import flash.events.ErrorEvent;
	import flash.events.ProgressEvent;
	import flash.events.SampleDataEvent;
	import flash.external.ExternalInterface;
	import flash.media.Microphone;
	import flash.media.Sound;
	import flash.media.SoundChannel;
	import flash.utils.ByteArray;
	import flash.utils.getTimer;
	import flash.utils.Timer;
	import flash.system.Security;
	import flash.system.SecurityPanel;
	import flash.events.StatusEvent;

	import mx.collections.ArrayCollection;

	public class Recorder
	{
		public function Recorder()
		{
		}

		public function setRecorderInstance(instance:String):void {
			this.recorderInstance = instance + '.';
		}

		public function addExternalInterfaceCallbacks():void {
			ExternalInterface.addCallback("recordStart", 		this.record);
			ExternalInterface.addCallback("isRecording", 		this.inRecording);
			ExternalInterface.addCallback("isMicrophoneMuted", 		this.isMicrophoneMuted);
			ExternalInterface.addCallback("recordStop",  		this.stop);
			ExternalInterface.addCallback("playStop",  		this.playStop);
			ExternalInterface.addCallback("playPause",  		this.playPause);
			ExternalInterface.addCallback("playback",          this.play);
			ExternalInterface.addCallback("showFlash",      this.showFlash);
			ExternalInterface.addCallback("recordingDuration",     this.recordingDuration);
			ExternalInterface.addCallback("playDuration",     this.playDuration);


			trace("Recorder initialized");
			triggerEvent('initialized');
		}


		protected var isRecording:Boolean = false;
		protected var isPlaying:Boolean = false;
		protected var isPaused:Boolean = false;
		protected var microphoneWasMuted:Boolean;
		protected var microphone:Microphone;
		protected var buffer:ByteArray = new ByteArray();
		protected var sound:Sound;
		protected var channel:SoundChannel;
		protected var recordingStartTime = 0;
		protected var duration:int = 0;
		protected static var sampleRate = 44.1;
		private var recorderInstance:String;

		protected function record():void
		{
			if(!microphone){
				setupMicrophone();
			}

			microphoneWasMuted = microphone.muted;
			if(microphoneWasMuted){
				trace('showFlashRequired');
				showFlash();
				triggerEvent('microphoneMuted');
			}else{
				notifyRecordingStarted();
			}

			buffer = new ByteArray();
			microphone.addEventListener(SampleDataEvent.SAMPLE_DATA, recordSampleDataHandler);
		}

		protected function inRecording():Boolean
		{
			return this.isRecording;
		}

		protected function isMicrophoneMuted():Boolean
		{
			return microphoneWasMuted;
		}

		protected function recordStop():int
		{
			trace('stopRecording');
			triggerEvent('stop');
			isRecording = false;
			microphone.removeEventListener(SampleDataEvent.SAMPLE_DATA, recordSampleDataHandler);
			return recordingDuration();
		}

		protected function play():void
		{
			trace('startPlaying');
			isPlaying = true;
			if (!isPaused) {
				buffer.position = 0;
			}
			isPaused = false;
			sound = new Sound();
			sound.addEventListener(SampleDataEvent.SAMPLE_DATA, playSampleDataHandler);

			channel = sound.play();
			channel.addEventListener(Event.SOUND_COMPLETE, function(){
				triggerEvent('ended');
				playStop();
				triggerEvent('ended');
			});
		}

		protected function stop():int
		{
			playStop();
			return recordStop();
		}

		protected function playPause():void
		{
			trace('pausePlaying');
			if(channel){
				channel.stop();
				isPaused = true;
				isPlaying = false;
			}
		}

		protected function playStop():void
		{
			trace('stopPlaying');
			if(channel){
				channel.stop();
				isPaused = false;
				isPlaying = false;
			}
		}

		protected function showFlash():void
		{
			Security.showSettings(SecurityPanel.PRIVACY);
		}

		/* Recording Helper */
		protected function setupMicrophone():void
		{
			trace('setupMicrophone');
			microphone = Microphone.getMicrophone();
			microphone.codec = "Nellymoser";
			microphone.setSilenceLevel(0);
			microphone.rate = sampleRate;
			microphone.gain = 50;
			microphone.addEventListener(StatusEvent.STATUS, function statusHandler(e:Event) {
				trace('Microphone Status Change');
				if(!microphone.muted){
					if(!isRecording){
						notifyRecordingStarted();
					}
				}
			});

			trace('setupMicrophone done: ' + microphone.name + ' ' + microphone.muted);
		}

		protected function notifyRecordingStarted():void
		{
			if(microphoneWasMuted){
				microphoneWasMuted = false;
			}
			recordingStartTime = getTimer();
			trace('startRecording');
			triggerEvent('record');
			isRecording = true;
			duration = 0;
		}

		protected function recordingDuration():int
		{
			if (!duration) {
				duration = Math.max(int(getTimer() - recordingStartTime), 0);
			}
			return duration;
		}

		protected function playDuration():int
		{
			return int(channel.position);
		}

		protected function recordSampleDataHandler(event:SampleDataEvent):void
		{
			while(event.data.bytesAvailable)
			{
				var sample:Number = event.data.readFloat();

				buffer.writeFloat(sample);
				if(buffer.length % 40000 == 0){
				}
			}
		}

		protected function playSampleDataHandler(event:SampleDataEvent):void
		{
			var expectedSampleRate = 44.1;
			var writtenSamples = 0;
			var channels = 2;
			var maxSamples = 8192 * channels;
			// if the sampleRate doesn't match the expectedSampleRate of flash.media.Sound (44.1) write the sample multiple times
			// this will result in a little down pitchshift.
			// also write 2 times for stereo channels
			while(writtenSamples < maxSamples && buffer.bytesAvailable)
			{
				var sample:Number = buffer.readFloat();
			  for (var j:int = 0; j < channels * (expectedSampleRate / sampleRate); j++){
					event.data.writeFloat(sample);
					writtenSamples++;
					if(writtenSamples >= maxSamples){
						break;
					}
				}
			}
			trace("Wrote " + writtenSamples + " samples");
		}

		protected function triggerEvent(eventName:String, arg0=null, arg1 = null):void
		{
			ExternalInterface.call(this.recorderInstance+"triggerEvent", eventName, arg0, arg1);
		}

		protected function log(message:String):void
		{
			ExternalInterface.call('console.log', 'flash: '+message);
		}
	}
}
