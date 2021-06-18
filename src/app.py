import json
import pandas as pd
from pickle import load

from flask import Flask, request, jsonify

app = Flask(__name__)

@app.route('/')
def home():
    return 'you really suck'

@app.route('/api/', methods=['POST'])
def api():
    if request.method == 'POST':
        data = request.data
        print(data)
        return jsonify( {'tmp': 'you get nothing' } )

# @app.route('/predict/', methods=['POST'])
# def predict(model):
#     if request.method == 'POST':
#         data = request.get_json()
#         print(data)
#         #prediction = model.predict(data)
#         #return jsonify(prediction)
#         return jsonify(prediction)
#     print()
# 
#     return model.predict(X)

if __name__ == "__main__":
    model_file = 'prod_model.joblib'
    model = load(open( model_file, 'rb' ))
    app.run(debug=True)

