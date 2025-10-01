# simple version

import numpy as np 
import pandas as pd

#_just do the basic data struccture stuff lmao 

N_e = 1600
N_v = 50257

df = pd.read_csv("data/words.csv")
top_50k_words = df["word"][:N_v]
top_50k_ids = pd.Series(top_50k_words.index, index=top_50k_words.values)

def softmax(x):
    e_x = np.exp(x - np.max(x))
    return e_x / e_x.sum(axis=-1, keepdims=True)

class GPT:
    def __init__(self):
        self.tokens = []
        self.w = np.random.rand(N_e, N_v)
      

    def __call__(self, token):
        token_idx = top_50k_ids[token]
        sparse = np.zeros(N_v)
        sparse[token_idx] = 1
        input_proj = self.w @ sparse

        # would process here
        # should be 1600 * 1
        output_proj = input_proj
        # print(output_proj.shape)
        output_logits = self.w.T @ output_proj
        return softmax(output_logits)


def main(): 
    input_text = "hello i would like to" 
    tokens = input_text.split(" ")

    gpt = GPT()

    for i in range(len(tokens)):
        probs = gpt(tokens[i])
        best_token_id = probs.argmax()
        best_word = top_50k_words[best_token_id]
        print(best_word)


if __name__=="__main__":
    main()




# torch version 