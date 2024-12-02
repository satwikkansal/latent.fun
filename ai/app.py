from fastapi import FastAPI
from pydantic import BaseModel
import uvicorn
from fastapi.middleware.cors import CORSMiddleware


import azure_client
import video_client
import eleven_client
import cloudinary_client

from contextlib import asynccontextmanager

APPLICATION_PORT = 8000


app = FastAPI()


class Item(BaseModel):
    transcript: str | None = None
    videoUrl: str | None = None

class RoastModel(BaseModel):
    panel: str
    roast: str
    audioUrl: str
    thumbnail: str

assistants_data = [
    {
        "assistant": "TRUMP",
        "assistant_id": "asst_6No1xLNFeAj98k3nbza81esI",
        "voice_id": "SpeK5bcBd7LBqhYBiK1R",
        "thumbnail": "https://www.whitehouse.gov/wp-content/uploads/2021/01/45_donald_trump.jpg?w=1250"
    },
    {
        "assistant": "MICKEY",
        "assistant_id": "asst_gY24HV1yA4oFVIou3MUYeuRl",
        "voice_id": "dfZGXKiIzjizWtJ0NgPy",
        "thumbnail": "https://cdn.pixabay.com/photo/2022/05/30/04/50/mickey-mouse-7230486_1280.png"
    },
    {
        "assistant": "FARHAN AKHTAR",
        "assistant_id": "asst_Gxuwa1HTg7NnmzL0ewWe9JaL",
        "voice_id": "6MoEUz34rbRrmmyxgRm4",
        "thumbnail": "https://upload.wikimedia.org/wikipedia/commons/4/49/Farhan_Akhtar_promoting_The_Sky_Is_Pink_%28cropped%29.jpg"
    },
    {
        "assistant": "ROGAN",
        "assistant_id": "asst_bSVuDSZjJcmCmCSKV3SLYWEF",
        "voice_id": "pujH7g2H19Q7U8Gevr98",
        "thumbnail": "https://img.particlenews.com/image.php?type=thumbnail_580x000&url=2k36nr_0wUP0UgH00"
    }
]

app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)


VIDEO_PATH = "./video.mp4"
VOICE_FOLDER= "./audio"



@app.post("/roast")
async def roast(item: Item):
    transcript = item.transcript
    if not item.transcript and not item.videoUrl:
        return RoastModel()


    if item.videoUrl is not None:
        video_client.download_video(item.videoUrl, VIDEO_PATH)
        transcript = video_client.video_to_text(VIDEO_PATH)

    response = []

    for assistant in assistants_data:
        try:
            name = assistant['assistant']
            assistant_id = assistant['assistant_id']
            voice_id = assistant['voice_id']
            thumbnail = assistant['thumbnail']

            thread_id = azure_client.create_thread()
            message_id = azure_client.add_message_to_thread(thread_id, transcript)
            run_id = azure_client.run(assistant_id, thread_id)
            azure_client.wait_until_run_completed(run_id, thread_id)
            roast_text = azure_client.assistant_output(thread_id)
            audio_path = eleven_client.text_to_speech(roast_text, voice_id, VOICE_FOLDER)
            roast_audio_url = cloudinary_client.upload_mp3(audio_path)
            response.append(RoastModel(panel=name, roast=roast_text, audioUrl=roast_audio_url, thumbnail=thumbnail))
        except Exception as e:
            print('Error', e)
    return response


if __name__ == "__main__":
    uvicorn.run(app, host="0.0.0.0", port=APPLICATION_PORT)


