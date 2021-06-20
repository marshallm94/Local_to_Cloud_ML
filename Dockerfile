# syntax=docker/dockerfile:1
FROM python:3.8-slim-buster

WORKDIR /model_server

# only a subset of packages are required to run the server itself
COPY ml_server_requirements.txt ml_server_requirements.txt
RUN pip3 install -r ml_server_requirements.txt

# only copy what is necessary for the server
COPY prod_model.joblib prod_model.joblib
COPY app.py app.py

CMD ["python3", "-m", "flask", "run", "--host=0.0.0.0"]

