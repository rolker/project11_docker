ARG GIT_REPO=https://github.com/CCOMJHC
ARG ROS_VERSION=noetic
ARG ROS_BASE=ros:noetic-ros-base

#####################
# CUDA and ROS      #
#####################


FROM nvidia/cuda:12.2.2-cudnn8-devel-ubuntu20.04 as ros-cuda

# Install basic apt packages
ARG DEBIAN_FRONTEND=noninteractive
RUN apt-get update && apt-get install -y \
    locales \
    lsb-release \
&& rm -rf /var/lib/apt/lists/*
RUN dpkg-reconfigure locales

# Install ROS Noetic
RUN sh -c 'echo "deb http://packages.ros.org/ros/ubuntu $(lsb_release -sc) main" > /etc/apt/sources.list.d/ros-latest.list'
RUN apt-key adv --keyserver 'hkp://keyserver.ubuntu.com:80' --recv-key C1CF6E31E6BADE8868B172B4F42ED6FBAB17C654
RUN apt-get update  && apt-get install -y --no-install-recommends \
    ros-noetic-ros-base \
    python3-rosdep \
&& rm -rf /var/lib/apt/lists/*

RUN rosdep init \
 && rosdep fix-permissions \
 && rosdep update
RUN echo "source /opt/ros/noetic/setup.bash" >> ~/.bashrc


#####################
# CUDA, ROS, OpenCV #
#####################


FROM ros-cuda as ros-opencv

ARG OPENCV_VERSION=4.9.0
ARG DEBIAN_FRONTEND=noninteractive

RUN apt-get update && apt-get install -y --no-install-recommends \
    build-essential \
    cmake \
    wget \
    unzip \
&& rm -rf /var/lib/apt/lists/*

WORKDIR /src/build

RUN wget -q --no-check-certificate https://github.com/opencv/opencv/archive/${OPENCV_VERSION}.zip -O /src/opencv.zip
RUN wget -q --no-check-certificate https://github.com/opencv/opencv_contrib/archive/${OPENCV_VERSION}.zip -O /src/opencv_contrib.zip

RUN unzip -qq /src/opencv.zip -d /src && rm -rf /src/opencv.zip
RUN unzip -qq /src/opencv_contrib.zip -d /src && rm -rf /src/opencv_contrib.zip

RUN cmake \
  -D OPENCV_EXTRA_MODULES_PATH=/src/opencv_contrib-${OPENCV_VERSION}/modules \
  -D OPENCV_DNN_CUDA=ON \
  -D WITH_CUDA=ON \
  -D BUILD_opencv_python2=OFF \
  -D BUILD_opencv_python3=OFF \
  -D BUILD_TESTS=OFF \
  /src/opencv-${OPENCV_VERSION}

RUN make -j$(nproc)
RUN make install 

WORKDIR /
RUN rm -rf /src/


#####################
# project11 core    #
#####################


FROM ${ROS_BASE} as project11-core
ARG GIT_REPO
ARG ROS_VERSION

SHELL [ "/bin/bash" , "-c" ]

ARG DEBIAN_FRONTEND=noninteractive
RUN apt-get update && apt-get upgrade -y && apt-get install -y --no-install-recommends \
    git \
    python3-vcstool \
&& rm -rf /var/lib/apt/lists/*    

RUN mkdir -p catkin_ws/src
WORKDIR /catkin_ws/src

COPY ./core.repos.in .
COPY ./tools/set_git_repo.py .
RUN ./set_git_repo.py core.repos.in ${GIT_REPO} ${ROS_VERSION} > core.repos
RUN vcs import < core.repos

WORKDIR /catkin_ws

RUN source /opt/ros/noetic/setup.bash && apt-get update && rosdep update && rosdep install -i -y --from-paths src \
&& rm -rf /var/lib/apt/lists/* 

RUN source /opt/ros/noetic/setup.bash && catkin_make

RUN echo "source /catkin_ws/devel/setup.bash" >> ~/.bashrc


#####################
# project11 robot   #
#####################

FROM project11-core as project11-robot

ARG GIT_REPO
ARG ROS_VERSION
ARG DEBIAN_FRONTEND=noninteractive

SHELL [ "/bin/bash" , "-c" ]

RUN apt-get update && apt-get upgrade -y && apt-get install -y --no-install-recommends \
    wget \
    unzip \
&& rm -rf /var/lib/apt/lists/*    


RUN mkdir -p /data
WORKDIR /data

RUN wget https://charts.noaa.gov/ENCs/All_ENCs.zip && unzip All_ENCs.zip

WORKDIR /catkin_ws/src

COPY ./robot.repos.in .
COPY ./tools/set_git_repo.py .
RUN ./set_git_repo.py robot.repos.in ${GIT_REPO} ${ROS_VERSION} > robot.repos
RUN vcs import < robot.repos

RUN ln -s /data/ENC_ROOT /catkin_ws/src/s57_tools/s57_grids/data/

WORKDIR /catkin_ws

RUN source /opt/ros/noetic/setup.bash && apt-get update && rosdep install -i -y --from-paths src \
&& rm -rf /var/lib/apt/lists/*

RUN source /opt/ros/noetic/setup.bash && catkin_make

######################
# project11 operator #
######################

FROM project11-core as project11-operator

ARG GIT_REPO
ARG ROS_VERSION
ARG DEBIAN_FRONTEND=noninteractive

SHELL [ "/bin/bash" , "-c" ]

WORKDIR /catkin_ws/src

COPY ./operator.repos.in .
COPY ./tools/set_git_repo.py .
RUN ./set_git_repo.py operator.repos.in ${GIT_REPO} ${ROS_VERSION} > operator.repos
RUN vcs import < operator.repos

WORKDIR /catkin_ws

RUN source /opt/ros/noetic/setup.bash && apt-get update && rosdep install -i -y --from-paths src \
&& rm -rf /var/lib/apt/lists/*

RUN source /opt/ros/noetic/setup.bash && catkin_make

########################
# project11 simulation #
########################

FROM project11-robot as project11-simulation

ARG GIT_REPO
ARG ROS_VERSION
ARG DEBIAN_FRONTEND=noninteractive

SHELL [ "/bin/bash" , "-c" ]

WORKDIR /catkin_ws/src

COPY ./simulation.repos.in .
COPY ./tools/set_git_repo.py .
RUN ./set_git_repo.py simulation.repos.in ${GIT_REPO} ${ROS_VERSION} > simulation.repos
RUN vcs import < simulation.repos

WORKDIR /catkin_ws

RUN source /opt/ros/noetic/setup.bash && apt-get update && rosdep install -i -y --from-paths src \
&& rm -rf /var/lib/apt/lists/*

RUN source /opt/ros/noetic/setup.bash && catkin_make

##########################
# project11 operator dev #
##########################

FROM project11-operator as project11-operator-dev

SHELL [ "/bin/bash" , "-c" ]

ARG USERNAME=devuser
ARG UID=1000
ARG GID=${UID}

# Create new user and home directory
RUN groupadd --gid $GID $USERNAME \
 && useradd --uid ${GID} --gid ${UID} --create-home ${USERNAME} \
 && echo ${USERNAME} ALL=\(root\) NOPASSWD:ALL > /etc/sudoers.d/${USERNAME} \
 && chmod 0440 /etc/sudoers.d/${USERNAME} \
 && mkdir -p /home/${USERNAME} \
 && chown -R ${UID}:${GID} /home/${USERNAME} \
 && adduser ${USERNAME} video
 
# Set the ownership of the overlay workspace to the new user
RUN chown -R ${UID}:${GID} /catkin_ws/
 
# Set the user and source entrypoint in the user's .bashrc file
USER ${USERNAME}

RUN echo "source /opt/ros/noetic/setup.bash" >> ~/.bashrc
RUN echo "source /catkin_ws/devel/setup.bash" >> ~/.bashrc
