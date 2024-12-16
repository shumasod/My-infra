FROM python:3
USER root
WORKDIR /workspace

# 各種必要なコマンドインストール
RUN apt-get update
RUN apt-get -y install locales lftp sshpass sudo
RUN localedef -f UTF-8 -i ja_JP ja_JP.UTF-8
ENV LANG ja_JP.UTF-8
ENV LANGUAGE ja_JP:ja
ENV LC_ALL ja_JP.UTF-8
ENV TZ JST-9
ENV TERM xterm

# util s2uで必要
RUN apt-get install nkf

RUN apt-get install -y vim less
RUN pip install --upgrade pip
RUN pip install --upgrade setuptools

# pythonで利用したいライブラリのインストール
ADD ./src/requirements.txt /workspace/
RUN pip install -r /workspace/requirements.txt

#nodejs, serverlessのインストール　
RUN curl -sL https://deb.nodesource.com/setup_20.x | bash -
RUN apt-get install -y nodejs
RUN npm install -g serverless

# S3にアクセスするためにawscliをインストール
RUN pip install awscli

WORKDIR /workspace/lib
# cronのテスト用
# RUN apt-get install -y cron
# RUN service cron start

RUN adduser --disabled-password --gecos '' --uid 1000 ec2-user

USER ec2-user

@echo off

echo Building Docker image...

docker build -t my-python-image .

if %ERRORLEVEL% neq 0 (
    echo Error building Docker image.
    exit /b %ERRORLEVEL%
)

echo Docker image built successfully.