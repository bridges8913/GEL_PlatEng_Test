from PIL import Image
from io import BytesIO
from urllib import parse
import json
import boto3

stripped_bucket = "bridgesaws-stripped-bucket"

def lambda_handler(event, context):
    s3_client = boto3.client("s3")

    # Obtain uploaded image
    upload_bucket = event['Records'][0]['s3']['bucket']['name']
    object_key = parse.unquote_plus(event['Records'][0]['s3']['object']['key'])

    print("Image Uploaded:")
    print(object_key)
    print("To Bucket:")
    print(upload_bucket)

    raw_s3_image = s3_client.get_object(Bucket=upload_bucket, Key=object_key)["Body"].read()
    raw_image = Image.open(BytesIO(raw_s3_image))

    # Remove EXIF metadata
    image_data = list(Image.Image.getdata(raw_image))
    modified_image = Image.new(raw_image.mode, raw_image.size)
    modified_image.putdata(image_data)
    new_image = "/tmp/" + object_key
    modified_image.save(new_image)

    print("EXIF data removed from:")
    print(new_image)

    # Upload stripped image
    s3_client.upload_file(new_image, stripped_bucket, object_key)