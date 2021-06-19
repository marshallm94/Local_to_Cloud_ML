import json
import pandas as pd
import numpy as np
from pickle import load

from flask import Flask, request, jsonify

app = Flask(__name__)

@app.route('/get_predictions/', methods=['POST'])
def predict():
    if request.method == 'POST':
        data = json.loads( request.data )
        X = pd.read_json(data)
        predictions = np.array2string( model.predict(X) )
        return jsonify( predictions )

if __name__ == "__main__":
    model_file = 'prod_model.joblib'
    model = load(open( model_file, 'rb' ))
    app.run(debug=True)

