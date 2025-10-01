import random
from fastapi import FastAPI, UploadFile, File, Form
import uvicorn

app = FastAPI()


# f(key, image) -> finger 
@app.post("/infer/{key_code}")
def infer(key_code: str, file: UploadFile = File(...)):
    choices = [
        "lp", 
        "lr",
        "lm",
        "li",
        "lt",
        "rp", 
        "rr",
        "rm",
        "ri",
        "rt",
    ]
    choice = choices[random.randint(0, len(choices) - 1)]
    
    return {"finger": choice}


if __name__ == "__main__":
    uvicorn.run(app, host="0.0.0.0", port=8000)
