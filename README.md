# Local to Cloud ML

The goal of the project is to familiarize myself with deploying statistical models into the cloud. The goal is **not**
to build/create the most interesting statistical model that solves an interesting problem.

# General Map 

![](images/local_to_cloud_ml.png)

## Steps to build & test "ML Prediction Server" (locally)

1. Run [train_model.py](train_model.py).
* Trains & saves a model.
* Saves a test data set.
2. Run `$ docker build --tag ml-server:latest .`.
* Build a docker image using the model build in #1 and [app.py](app.py).
3. Run `$ docker run --publish <host_port>:<container_port> ml-server`, which in this case, is:
	`$ docker run --publish 8080:5000 ml-server`
* Runs the container, mapping port 5000 of the container to port 8080 of the host.
4. (In a separate shell) Run `$ python test_api.py 127.0.0.1:8080` from the command line.
* Loads the test data set from #1, and sends a sample to the Docker Flask API. Should output the class predictions for
  the requested instances.

## Steps to move "ML Prediction Server" to AWS Cloud

1. Complete all steps in "Steps to recreate/test (locally)" to ensure everything works properly.
2. Run [aws_setup/setup_aws_resources.sh](aws_setup/setup_aws_resources.sh).
* Create ECR repo and pushes Docker images to said repo.
3. Via the AWS Console, create an ECR Cluster:
* Use the **EC2 Linux + Networking** template.
* Ok to use defaults for everything **except:**
	* (For demo uses) Choose a instance type that isn't going to cost too much.
	* Any subnet will work (determine which AZ ( within the region ) the cluster will be in ).
	* Set **Auto assign public IP** = **Enabled**.
	* Use default security group.
4. Via the AWS Console, create a Task Definition:
* Choose **EC2** as the Launch Type compatibility.
* Click "Add Container" and in the "image"  section, copy & paste the URI of the repo in ECR.
* Set a soft memory limit of 500 MiB for the container.
* Map port 8080 of the host to port 5000 of the container.
* (Click "Add")
5. Click "Create" which will create the new task definition.
6. Click on "Clusters" in the left-hand pane.
7. Click the name of the cluster you created.
8. In the 'Tasks' pane of your cluster, select "Run new Task":
* Select "EC2" as the Launch type.
* Choose the Task Definition you created in #4.
* Click "Create"
* **Make sure the "Last Status" says "RUNNING" prior to moving forward.**
9. Click on the "ECS Instance" In the "ECS Instances" pane of the cluster view.
10. You will be brought to the EC2 Dashboard; click on the instance ID associated with the cluster;
* In the security pane, make sure that the Inbound Rules allows traffic (both IPv4 & IPv6) on port 8080.
11. Test that the instance is running by going to `<instance_public_ip_address>:8080/`; there should be a welcom
    message.

## Steps to test if the service is working 

1. Run `$ python test_api.py <instance_public_ip_address>:8080`. The accuracy of the test set will be printed.
