import whisper
import urllib.request


model = whisper.load_model("turbo")


def video_to_text(path):
	result = model.transcribe(path)
	return result["text"]

def download_video(url, path):
	urllib.request.urlretrieve(url, path) 
