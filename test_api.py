import sys
import requests
import json
from pickle import load
from sklearn.metrics import accuracy_score
import pandas as pd
import numpy as np

if __name__ == '__main__':

    # get host:port as first command line argument
    url = 'http://' + sys.argv[1] + '/get_predictions'

    # load test data
    test_df_file = 'test_df.joblib'
    test_df = load(open(test_df_file, 'rb'))
    predictors = test_df.columns[ test_df.columns != 'outcome' ]

    # prep data for API
    tmp = test_df.loc[:, predictors]
    data_to_send = tmp.to_json(orient = 'records')
    json_data = json.dumps(data_to_send)

    # get predictions
    response = requests.post(url, json_data)
    predictions = response.json()

    # evaluate predictions
    test_df['predicted'] = predictions
    eval_df = test_df[['outcome','predicted']]
    acc = accuracy_score(eval_df['outcome'], eval_df['predicted'])

    print(f"Test Set Accuracy = {np.round(acc, 2)}")

