# Project11 Docker

Very quick startup guide. In the project11_docker directory:

    docker compose build

In a terminal in the project11_docker directory, bring up the robot simulation:

  docker compose up project11-simulation

In new terminal:

  docker exec -it project11_docker-project11-simulation-1 bash

  roslaunch project11_simulation sim_robot.launch

In new terminal, bring up the operator container:

  docker compose up project11-operator-dev

In new terminal:

  docker exec -it project11_docker-project11-operator-dev-1 bash

  roslaunch project11 operator_core.launch robotNamespace:=ben enableBridge:=false

In new terminal:

  docker exec -it project11_docker-project11-operator-dev-1 bash

  roslaunch project11 operator_ui.launch robotNamespace:=ben

Another shell can be opened in the operator container where rviz can be installed and used to see the multibeam sim's soundings pointcloud.
