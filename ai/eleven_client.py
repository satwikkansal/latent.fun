import requests
import uuid


headers = {
    'xi-api-key': '',
    'Content-Type': 'application/json',
}


def text_to_speech(text, voice_id, voice_folder):
	json_data = {
    	'text': text,
    	'model_id': 'eleven_multilingual_v2',
    	'voice_settings': {
	        'stability': 0.5,
	        'similarity_boost': 1,
	        'style': 0.5,
	        'use_speaker_boost': True
	    }
	}
	path = voice_folder + "/" + str(uuid.uuid4()) + ".mp3"
	response = requests.post(f'https://api.elevenlabs.io/v1/text-to-speech/{voice_id}', headers=headers, json=json_data)
	with open(path, "wb") as f:
		for chunk in response:
			if chunk:
				f.write(chunk)
	return path
