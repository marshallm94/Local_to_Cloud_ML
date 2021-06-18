import requests
import json
from pickle import load
import pandas as pd

url = 'http://127.0.0.1:5000/api/'

test_df_file = 'test_df.joblib'
test_df = load(open(test_df_file, 'rb'))
tmp = test_df.iloc[0:1,:]
data_to_send = tmp.to_json(orient = 'records')
print(data_to_send)

json_data = json.dumps(data_to_send)
response = requests.post(url, json_data)
print(response)
print(response.text)
