import requests
import json
from pickle import load
import pandas as pd

url = 'http://127.0.0.1:5000/get_predictions/'

# load test data
test_df_file = '../data/test_df.joblib'
test_df = load(open(test_df_file, 'rb'))
predictors = test_df.columns[ test_df.columns != 'outcome' ]

tmp = test_df.loc[0:2, predictors]
data_to_send = tmp.to_json(orient = 'records')

json_data = json.dumps(data_to_send)
response = requests.post(url, json_data)

predictions = response.text
print(predictions)
