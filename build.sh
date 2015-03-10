#!/bin/sh

if [ "$flex" = "" ]; then
  flex='/usr/local/flex_sdk'
fi

if [ "$warning" != "" ]; then
  warning=''
else
  warning='-warnings=false'
fi

if [ "$debug" != "" ]; then
  debug='-debug=true'
else
  debug='-debug=false'
fi

mxmlc=$flex/bin/mxmlc
$mxmlc $debug $warning  -library-path+=shineMP3_alchemy.swc -static-link-runtime-shared-libraries=true -optimize=true -o recorder.swf -file-specs FlashRecorder.as
