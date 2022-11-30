from PIL import Image
import json
import boto3

stripped_bucket = "bridgesaws_stripped_bucket"

def lambda_handler(event, context):
    s3_client = boto3.client("s3")

    # Obtain uploaded image
    upload_bucket = event['Records'][0]['s3']['bucket']['name']
    object_key = event['Records'][0]['s3']['object']['key']  
    raw_s3_image = s3_client.get_object(Bucket=upload_bucket, Key=object_key)["Body"].read()
    raw_image = Image.open(raw_s3_image)

    # Remove EXIF metadata
    image_data = list(raw_image.getdata())
    modified_image = Image.new(raw_image.mode, raw_image.size)
    modified_image.putdata(image_data)
    modified_image.save(object_key)

    # Upload stripped image
    s3_client.upload_file(modified_image, stripped_bucket, object_key)