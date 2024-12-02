import cloudinary
import cloudinary.uploader

cloudinary.config(
    cloud_name='',
    api_key='',
    api_secret=''
)


def upload_mp3(path):
	response = cloudinary.uploader.upload(
    	file=path,
    	resource_type='video'  # Use 'video' for audio files
	)
	return response['secure_url']
