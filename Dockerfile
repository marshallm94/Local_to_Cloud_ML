# syntax=docker/dockerfile:1

FROM python:3.8-slim-buster

WORKDIR /model_server

COPY requirements.txt requirements.txt
RUN pip3 install -r requirements.txt

# copy everything (could probably omit .gitignore and a few other things but we
# can come back to that...)
COPY . .

CMD ["python3", "-m", "flask", "run", "--host=0.0.0.0"]

