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
	import com.adobe.audio.format.WAVWriter;
	import fr.kikko.lab.ShineMP3Encoder;
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
	import mx.utils.Base64Encoder;


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
			ExternalInterface.addCallback("stop",  		this.playStop);
			ExternalInterface.addCallback("pause",  		this.playPause);
			ExternalInterface.addCallback("playback",          this.play);
			ExternalInterface.addCallback("wavData",      this.getWAVData);
			ExternalInterface.addCallback("mp3Data",      this.encodeMP3Data);
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
		private var mp3Encoder:ShineMP3Encoder;

		protected function record():void
		{
			if(!microphone){
				setupMicrophone();
			}

			microphoneWasMuted = microphone.muted;
			if(microphoneWasMuted){
				trace('showFlashRequired');
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

		/* Sample related */
		protected function getWAVByteArray():ByteArray
		{
			var wavData:ByteArray = new ByteArray();
			var wavWriter:WAVWriter = new WAVWriter(); 
			buffer.position = 0;
			wavWriter.numOfChannels = 1; // set the inital properties of the Wave Writer 
			wavWriter.sampleBitRate = 16;
			wavWriter.samplingRate = sampleRate * 1000;
			wavWriter.processSamples(wavData, buffer, sampleRate * 1000, 1);
			wavData.position = 0;
			return wavData;
		}

		/* Sample related */
		protected function getWAVData():String
		{
			var wavData:ByteArray = this.getWAVByteArray();
			var b64:Base64Encoder = new Base64Encoder();
			b64.encodeBytes(wavData);
			return b64.toString();
		}

		protected function encodeMP3Data(): void
		{
			var wavData:ByteArray = this.getWAVByteArray();
			this.mp3Encoder = new ShineMP3Encoder(wavData);
			this.mp3Encoder.addEventListener(Event.COMPLETE, mp3EncodeComplete);
			this.mp3Encoder.addEventListener(ProgressEvent.PROGRESS, mp3EncodeProgress);
			this.mp3Encoder.addEventListener(ErrorEvent.ERROR, mp3EncodeError);
			this.mp3Encoder.start();
		}

		private function mp3EncodeProgress(event : ProgressEvent) : void
		{
			trace(event.bytesLoaded, event.bytesTotal);
		}

		private function mp3EncodeError(event : ErrorEvent) : void
		{
			trace("Error : ", event.text);
		}

		private function mp3EncodeComplete(event : Event) : void
		{
			trace("Done !", this.mp3Encoder.mp3Data.length);
			var b64:Base64Encoder = new Base64Encoder();
			b64.encodeBytes(this.mp3Encoder.mp3Data);
			triggerEvent('mp3Data', b64.toString());
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
