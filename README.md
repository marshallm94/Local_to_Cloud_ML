# Local to Cloud ML

The goal of the project is to familiarize myself with deploying statistical models into the cloud. The goal is **not**
to build/create the most interesting statistical model that solves an interesting problem.

## Steps to recreate/test (locally)

1. Run [train_model.py](train_model.py)
* Trains & saves a model.
* Saves a test data set.
2. Run `$ docker build --tag ml-server:latest .`
* Build a docker image using the model build in #1 and [app.py](app.py)
3. Run `$ docker run --publish 5000:5000 ml-server`
* Runs the container, mapping port 5000 of the container to port 5000 of the host.
4. (In a separate shell) Run [test_api.py](test_api.py)
* Loads the test data set from #1, and sends a sample to the Docker Flask API. Should output the class predictions for
  the requested instances.




