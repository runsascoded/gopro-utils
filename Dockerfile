FROM golang:1.14.4-buster

RUN git clone https://github.com/ryan-williams/gopro-utils.git
WORKDIR /gopro-utils

# RUN git init
# RUN git remote add upstream https://github.com/ryan-williams/gopro-utils.git
# RUN git fetch upstream
# RUN git checkout -b master -t upstream/master
RUN go install ./...
ENTRYPOINT [ "run.py" ]