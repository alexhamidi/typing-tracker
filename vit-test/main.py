import torch
import requests
from transformers import ViTForImageClassification, ViTImageProcessor
from PIL import Image 

model_name = "google/vit-base-patch16-224"
url = "https://huggingface.co/datasets/huggingface/documentation-images/resolve/main/pipeline-cat-chonk.jpeg"


def main():
    # autoxxx makes it so that it infers the model type based on the path. 
    image_processor = ViTImageProcessor.from_pretrained(
        model_name, 
        use_fast=True
    )

    model = ViTForImageClassification.from_pretrained(
        model_name,
        dtype=torch.float16, 
        device_map='auto'
    )

    image = Image.open(requests.get(url, stream=True).raw)
    inputs = image_processor(image, return_tensors ="pt").to(model.device)

    with torch.no_grad():
        logits: torch.Tensor = model(**inputs).logits


    predicted_class_id = logits.argmax(dim = -1).item()

    class_labels = model.config.id2label
    predicted_class_label = class_labels[predicted_class_id]

    print(f"the predicted class is {predicted_class_label}")

if __name__=="__main__":
    main()