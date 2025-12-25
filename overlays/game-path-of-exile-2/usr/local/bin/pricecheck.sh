#!/bin/bash

clip=$(wl-paste)
if [[ $clip == *"Item Class"* ]] ; then
  encoded_clip=$(echo "$clip" | base64 -w0)
  xdg-open "http://localhost:5000/item/base64_${encoded_clip}" # search for the item in browser
else
  notify-send -u critical -a sidekick -i /usr/local/share/images/ExaltedOrb.png 'Clipboard invalid' 'Unable to identify a PoE2 item in the clipboard'
fi
